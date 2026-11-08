import UIKit
import ActivityKit

/// Siteden gelen favori maç durumunu Dinamik Ada / kilit ekranı canlı etkinliklerine dönüştürür.
struct LiveMatch {
    let key: String
    let home: String
    let away: String
    let league: String
    let homeScore: Int
    let awayScore: Int
    let minute: String
    let phase: String
    let homeLogo: String
    let awayLogo: String

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
    }
}

final class LiveActivityManager {

    static let shared = LiveActivityManager()

    /// Bu oturumda biten maçlar (yeniden başlatılmasın)
    private var endedKeys = Set<String>()
    private var observed = Set<String>()
    private var starting = Set<String>()

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

    func sync(_ matches: [LiveMatch]) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

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

            let newState = LiveActivityManager.state(for: m)
            let old = activity.content.state

            if m.phase == "ended" {
                endedKeys.insert(attrs.matchKey)
                let final = ActivityContent(state: newState, staleDate: nil)
                Task { await activity.end(final, dismissalPolicy: .after(Date().addingTimeInterval(20 * 60))) }
                continue
            }

            guard newState != old else { continue }
            let content = ActivityContent(state: newState, staleDate: Date().addingTimeInterval(30 * 60))

            if newState.homeScore + newState.awayScore > old.homeScore + old.awayScore {
                // GOL → Dinamik Ada büyür, kilit ekranında öne çıkar
                let scorer = newState.homeScore > old.homeScore ? attrs.home : attrs.away
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
                async let homeThumb = LogoLoader.fetch(m.homeLogo)
                async let awayThumb = LogoLoader.fetch(m.awayLogo)
                let thumbs = await (homeThumb, awayThumb)
                DispatchQueue.main.async {
                    self.starting.remove(m.key)
                    self.start(m, homeThumb: thumbs.0, awayThumb: thumbs.1)
                }
            }
        }
    }

    private func start(_ m: LiveMatch, homeThumb: Data?, awayThumb: Data?) {
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
                                            homeThumb: homeThumb,
                                            awayThumb: awayThumb)
        // Canlı etkinlik verisi 4 KB'ı geçemez: sığmazsa gömülü logoları çıkar (ortak klasördeki kalır)
        if let size = try? JSONEncoder().encode(attrs).count, size > 3300 {
            attrs.homeThumb = nil
            attrs.awayThumb = nil
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
        MatchActivityAttributes.ContentState(homeScore: m.homeScore,
                                             awayScore: m.awayScore,
                                             minute: m.minute,
                                             phase: m.phase)
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
