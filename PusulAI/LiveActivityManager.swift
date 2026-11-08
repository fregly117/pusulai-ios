import UIKit
import ActivityKit

/// Siteden gelen favori maç durumunu Dinamik Ada / kilit ekranı canlı etkinliklerine dönüştürür.
struct LiveMatch {
    let key: String
    let home: String
    let away: String
    let league: String
    var homeScore: Int
    var awayScore: Int
    var minute: String
    var phase: String
    let homeLogo: String
    let awayLogo: String
    /// Arka planda uygulamanın kendisi skor çekebilsin diye (sitenin /api/live-scores uç noktası)
    let espnEventId: String
    let espnLeague: String
    let fotmobId: Int

    init?(dict d: [String: Any]) {
        guard let key = d["key"] as? String, !key.isEmpty else { return nil }
        self.key = key
        home = d["home"] as? String ?? ""
        away = d["away"] as? String ?? ""
        league = d["league"] as? String ?? ""
        homeScore = (d["hs"] as? NSNumber)?.intValue ?? 0
        awayScore = (d["as"] as? NSNumber)?.intValue ?? 0
        minute = d["minute"] as? String ?? ""
        phase = d["phase"] as? String ?? "live"
        homeLogo = d["homeLogo"] as? String ?? ""
        awayLogo = d["awayLogo"] as? String ?? ""
        espnEventId = d["espnEventId"] as? String ?? ""
        espnLeague = d["espnLeague"] as? String ?? ""
        fotmobId = (d["fotmobId"] as? NSNumber)?.intValue ?? 0
    }

    /// Sitedeki dakika biçimi: "29'", "45+2'", "İY"
    static func shortMinute(_ raw: String) -> String {
        var t = raw
        for ch in ["\u{200E}", "\u{200F}", "'", "\"", "’", "′", "″", "`", "´"] { t = t.replacingOccurrences(of: ch, with: "") }
        t = t.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return "Canlı" }
        let lower = t.lowercased()
        if lower.hasPrefix("ht") || lower.hasPrefix("iy") || lower.hasPrefix("i̇y") || lower.hasPrefix("devre") || lower.hasPrefix("half") || t.hasPrefix("İY") { return "İY" }
        let digits = t.prefix { $0.isNumber || $0 == "+" || $0 == " " }.replacingOccurrences(of: " ", with: "")
        if !digits.isEmpty, digits.first?.isNumber == true { return digits + "'" }
        return t
    }
}

final class LiveActivityManager {

    static let shared = LiveActivityManager()

    /// Bu oturumda biten maçlar (yeniden başlatılmasın)
    private var endedKeys = Set<String>()
    private var observed = Set<String>()
    private var starting = Set<String>()
    private var logoRetried = Set<String>()

    /// Dinamik Ada'da gösterilecek tek maç (favori anahtarı). Boşsa hiçbiri.
    var islandKey: String {
        get { UserDefaults.standard.string(forKey: "island.key") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "island.key") }
    }

    /// Uygulama açılırken çağrılır: canlı etkinliklerin uzaktan güncelleme anahtarlarını sunucuya iletir.
    /// Sunucu bu anahtarlarla Dinamik Ada'yı uygulama kapalıyken de günceller; iOS 17.2+ cihazlarda
    /// favori maç başladığında etkinliği uygulama kapalıyken bile kendisi başlatır (push-to-start).
    func startObserving() {
        for activity in Activity<MatchActivityAttributes>.activities {
            observe(activity)
        }
        Task {
            for await activity in Activity<MatchActivityAttributes>.activityUpdates {
                DispatchQueue.main.async { self.observe(activity) }
            }
        }
        if #available(iOS 17.2, *) {
            Task {
                for await data in Activity<MatchActivityAttributes>.pushToStartTokenUpdates {
                    PushRegistrar.shared.setStartToken(data.hexString)
                }
            }
        }
    }

    private func observe(_ activity: Activity<MatchActivityAttributes>) {
        guard !observed.contains(activity.id) else { return }
        observed.insert(activity.id)
        let key = activity.attributes.matchKey
        // Sunucunun başlattığı etkinlik (uygulama kapalıyken): logoları ortak klasöre indir
        let homeURL = activity.attributes.homeLogoURL
        let awayURL = activity.attributes.awayLogoURL
        Task {
            _ = await LogoLoader.fetch(homeURL)
            _ = await LogoLoader.fetch(awayURL)
        }
        Task {
            for await data in activity.pushTokenUpdates {
                PushRegistrar.shared.setLiveToken(data.hexString, for: key)
            }
        }
        Task {
            for await state in activity.activityStateUpdates {
                if state == .ended || state == .dismissed {
                    PushRegistrar.shared.removeLiveToken(for: key)
                }
            }
        }
    }

    func sync(_ allMatches: [LiveMatch]) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // Yalnızca seçilen maç Dinamik Ada'da; diğerleri kapatılır (bildirimler etkilenmez)
        let island = islandKey
        let matches = allMatches.filter { $0.key == island }

        var wanted: [String: LiveMatch] = [:]
        for m in matches { wanted[m.key] = m }

        var running = Set<String>()
        for activity in Activity<MatchActivityAttributes>.activities {
            guard activity.activityState == .active || activity.activityState == .stale else { continue }
            let attrs = activity.attributes
            running.insert(attrs.matchKey)

            // Favorilerden çıkarıldı / bültenden düştü → kapat
            guard let m = wanted[attrs.matchKey] else {
                Task { await activity.end(nil, dismissalPolicy: .immediate) }
                continue
            }

            // Logosuz başlamış etkinlik (eski sürüm / logo indirilemedi): uygulama açıkken bir kez logolu yeniden başlat
            if UIApplication.shared.applicationState == .active, !logoRetried.contains(attrs.matchKey),
               !(m.homeLogo.isEmpty && m.awayLogo.isEmpty),
               attrs.homeThumb == nil, attrs.awayThumb == nil,
               LogoStore.fileURL(for: attrs.homeLogoURL).map({ !FileManager.default.fileExists(atPath: $0.path) }) ?? true {
                logoRetried.insert(attrs.matchKey)
                running.remove(attrs.matchKey)
                Task { await activity.end(nil, dismissalPolicy: .immediate) }
                continue
            }

            var newState = LiveActivityManager.state(for: m)
            let old = activity.content.state
            // Gol bilgisini taşı; yeni gol varsa işaretle (Dinamik Ada'da "⚽ GOL!")
            if newState.homeScore + newState.awayScore > old.homeScore + old.awayScore {
                newState.goalSide = newState.homeScore > old.homeScore ? "home" : "away"
                newState.goalTs = Date().timeIntervalSince1970
            } else {
                newState.goalSide = old.goalSide
                newState.goalTs = old.goalTs
            }
            LiveActivityManager.keepClock(&newState, old: old)

            if m.phase == "ended" {
                endedKeys.insert(attrs.matchKey)
                let final = ActivityContent(state: newState, staleDate: nil)
                Task { await activity.end(final, dismissalPolicy: .after(Date().addingTimeInterval(20 * 60))) }
                continue
            }

            // Yalnızca dakika metni değiştiyse ve saat zaten akıyorsa güncelleme gönderme (kart kendisi ilerletiyor)
            var cmp = newState
            if cmp.clockStart != nil && cmp.clockStart == old.clockStart { cmp.minute = old.minute }
            guard cmp != old else { continue }
            let content = ActivityContent(state: newState, staleDate: Date().addingTimeInterval(30 * 60))

            if newState.homeScore + newState.awayScore > old.homeScore + old.awayScore {
                // GOL → Dinamik Ada büyür, kilit ekranında öne çıkar
                let scorer = newState.goalSide == "home" ? attrs.home : attrs.away
                let title = "⚽ GOL! \(scorer)"
                let body = "\(attrs.home) \(newState.homeScore) - \(newState.awayScore) \(attrs.away)  \(newState.minute)"
                let alert = AlertConfiguration(title: LocalizedStringResource(stringLiteral: title),
                                               body: LocalizedStringResource(stringLiteral: body),
                                               sound: .named("gol.caf"))
                Task { await activity.update(content, alertConfiguration: alert) }
            } else {
                Task { await activity.update(content) }
            }
        }

        // iOS yeni canlı etkinliği yalnızca uygulama ekrandayken başlatmaya izin verir
        guard UIApplication.shared.applicationState == .active else { return }
        for m in matches where m.phase != "ended" && !running.contains(m.key)
            && !endedKeys.contains(m.key) && !starting.contains(m.key) {
            starting.insert(m.key)
            Task {
                // Önce takım logolarını indir (SofaScore gibi logolu Dinamik Ada)
                async let homeImage = LogoLoader.fetch(m.homeLogo)
                async let awayImage = LogoLoader.fetch(m.awayLogo)
                let images = await (homeImage, awayImage)
                DispatchQueue.main.async {
                    self.starting.remove(m.key)
                    self.start(m, homeImage: images.0, awayImage: images.1)
                }
            }
        }
    }

    private func start(_ m: LiveMatch, homeImage: UIImage?, awayImage: UIImage?) {
        guard UIApplication.shared.applicationState == .active else { return }
        if Activity<MatchActivityAttributes>.activities.contains(where: {
            $0.attributes.matchKey == m.key && ($0.activityState == .active || $0.activityState == .stale)
        }) { return }

        var attrs = MatchActivityAttributes(matchKey: m.key,
                                            home: m.home,
                                            away: m.away,
                                            homeShort: LiveActivityManager.short(m.home),
                                            awayShort: LiveActivityManager.short(m.away),
                                            league: m.league,
                                            homeLogoURL: m.homeLogo.isEmpty ? nil : m.homeLogo,
                                            awayLogoURL: m.awayLogo.isEmpty ? nil : m.awayLogo,
                                            homeThumb: nil,
                                            awayThumb: nil)
        // Canlı etkinlik verisi 4 KB'ı geçemez: logoları sığana kadar küçült (en net olandan başla)
        if homeImage != nil || awayImage != nil {
            let ladder: [(Int, CGFloat)] = [(40, 0.6), (34, 0.55), (28, 0.5), (24, 0.45), (20, 0.4)]
            var fitted = false
            for (side, quality) in ladder {
                attrs.homeThumb = homeImage.flatMap { LogoLoader.thumb($0, side: side, quality: quality) }
                attrs.awayThumb = awayImage.flatMap { LogoLoader.thumb($0, side: side, quality: quality) }
                if let size = try? JSONEncoder().encode(attrs).count, size <= 3500 { fitted = true; break }
            }
            if !fitted {
                attrs.homeThumb = nil
                attrs.awayThumb = nil
            }
        }
        let content = ActivityContent(state: LiveActivityManager.state(for: m),
                                      staleDate: Date().addingTimeInterval(30 * 60))
        // Önce uzaktan güncellenebilir (push) olarak dene; imza bildirime izin vermiyorsa yerel olarak başlat
        var started: Activity<MatchActivityAttributes>?
        started = try? Activity<MatchActivityAttributes>.request(attributes: attrs, content: content, pushType: .token)
        if started == nil {
            started = try? Activity<MatchActivityAttributes>.request(attributes: attrs, content: content, pushType: nil)
        }
        if let started = started { observe(started) }
    }

    static func state(for m: LiveMatch) -> MatchActivityAttributes.ContentState {
        var st = MatchActivityAttributes.ContentState(homeScore: m.homeScore,
                                                      awayScore: m.awayScore,
                                                      minute: m.minute,
                                                      phase: m.phase)
        // Canlı saat: bilinen dakikadan geriye doğru "0. dakika" zamanı (dakikanın ortası varsayılır)
        if m.phase == "live", let mn = MatchActivityAttributes.ContentState.minuteNumber(m.minute) {
            st.clockStart = Date().timeIntervalSince1970 - Double(mn) * 60 - 30
        }
        return st
    }

    /// Saat zaten doğruysa (±90 sn) eskisini koru: gereksiz güncelleme ve geri sıçrama olmasın
    static func keepClock(_ new: inout MatchActivityAttributes.ContentState, old: MatchActivityAttributes.ContentState) {
        if let n = new.clockStart, let o = old.clockStart, abs(n - o) < 90, old.phase == new.phase {
            new.clockStart = o
        }
    }

    /// "Galatasaray" → "GAL", "AC Milan" → "MIL", "VfB Stuttgart" → "STU"
    static func short(_ name: String) -> String {
        let skip: Set<String> = ["FC", "AFC", "SK", "CF", "SC", "FK", "AS", "AC", "SS", "US", "CD", "UD",
                                 "RC", "SV", "VFB", "VFL", "TSG", "BK", "IF", "KV", "KRC", "1.", "SL"]
        let words = name.split(whereSeparator: { $0 == " " || $0 == "-" }).map { String($0).uppercased() }
        let pick = words.first(where: { !skip.contains($0) && $0.count >= 3 }) ?? words.first ?? name.uppercased()
        return String(pick.prefix(3))
    }
}
