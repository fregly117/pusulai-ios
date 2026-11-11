import UIKit
import UserNotifications

/// Uygulama arka plandayken favori maçları uygulamanın KENDİSİ takip eder (sayfa uyutulur).
/// Sitenin hızlı skor uç noktasını (/api/live-scores) 8 sn'de bir çağırır; değişiklikte
/// Dinamik Ada'yı günceller, gol / başladı / devre / maç sonu bildirimini sitedeki seslerle gönderir.
/// Sunucu bildirimleri (APNs) açıksa kullanılmaz: o durumda her şey sunucudan gelir.
final class NativeTracker {

    static let shared = NativeTracker()

    private var items: [String: LiveMatch] = [:]
    private var order: [String] = []
    private var timer: Timer?
    private var inFlight = false

    // GOL SİNYALLERİ (arka planda): sayfa uyutulduğu için sinyali sayfa üretemez.
    // Sunucu (server-push-daemon.js) tüm canlı maçlar için sinyali 30 sn'de bir üretip kaydeder;
    // uygulama /api/goal-alerts'i 20 sn'de bir okuyup yeni sinyali sitedeki metin ve sesle bildirir.
    private var signalTimer: Timer?
    private var signalInFlight = false
    private var notifiedSignals = Set<String>()
    private var signalSince: Double = 0 // ms; bundan eski sinyaller bildirilmez
    private static let signalSeenKey = "signals.lastSeenTs"
    private static let goalAlertOptOutKey = "__goal_alerts_off__"

    /// Sayfadan gelen son durum (uygulama açıkken sürekli güncellenir)
    func update(_ matches: [LiveMatch]) {
        var next: [String: LiveMatch] = [:]
        for m in matches { next[m.key] = m }
        items = next
        order = matches.map { $0.key }
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.poll() }
        poll()

        // Uygulama açıkken sayfa kendi sinyallerini bildirdi: yalnızca son 2 dakikadan yenileri
        let nowMs = Date().timeIntervalSince1970 * 1000
        signalSince = max(UserDefaults.standard.double(forKey: NativeTracker.signalSeenKey), nowMs - 2 * 60 * 1000)
        signalTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in self?.pollSignals() }
        pollSignals()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        signalTimer?.invalidate()
        signalTimer = nil
    }

    private func pollSignals() {
        guard !signalInFlight else { return }
        // Sitedeki gol sinyali bildirimi kapalıysa (zil) gönderme
        let keys = UserDefaults.standard.stringArray(forKey: "apns.favoriteKeys") ?? []
        if keys.contains(NativeTracker.goalAlertOptOutKey) { return }
        guard var comps = URLComponents(url: WebViewController.homeURL.appendingPathComponent("api/goal-alerts"),
                                        resolvingAgainstBaseURL: false) else { return }
        comps.queryItems = [URLQueryItem(name: "days", value: "1")]
        guard let url = comps.url else { return }
        var req = URLRequest(url: url)
        req.timeoutInterval = 10
        req.cachePolicy = .reloadIgnoringLocalCacheData
        signalInFlight = true
        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.signalInFlight = false
                if let data = data { self.applySignals(data) }
            }
        }.resume()
    }

    private static func double(_ v: Any?) -> Double {
        if let n = v as? NSNumber { return n.doubleValue }
        if let s = v as? String { return Double(s) ?? 0 }
        return 0
    }

    private static func pct(_ p: Double) -> String { "%\(Int((p * 100).rounded()))" }

    private func applySignals(_ data: Data) {
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let list = json["alerts"] as? [[String: Any]] else { return }
        let nowMs = Date().timeIntervalSince1970 * 1000
        let fresh = list
            .filter { NativeTracker.double($0["ts"]) > signalSince }
            .sorted { NativeTracker.double($0["ts"]) < NativeTracker.double($1["ts"]) }
        guard !fresh.isEmpty else { return }

        var newest = signalSince
        var sent = 0
        for a in fresh {
            let ts = NativeTracker.double(a["ts"])
            newest = max(newest, ts)
            let id = NativeTracker.string(a["id"])
            guard !id.isEmpty, !notifiedSignals.contains(id) else { continue }
            notifiedSignals.insert(id)
            // Sonucu belli olmuş (gol gelmiş) ya da 10 dk'dan eski sinyal artık bildirilmez
            if !NativeTracker.string(a["outcome"]).isEmpty { continue }
            if nowMs - ts > 10 * 60 * 1000 { continue }
            guard sent < 5 else { continue }
            sent += 1
            notifySignal(a)
        }
        signalSince = newest
        UserDefaults.standard.set(newest, forKey: NativeTracker.signalSeenKey)
        if notifiedSignals.count > 500 { notifiedSignals.removeAll() }
    }

    /// Sunucunun gol sinyali push'u ile aynı metin ve etiket (aynı maçta sayfanınkinin yerine geçer)
    private func notifySignal(_ a: [String: Any]) {
        let key = NativeTracker.string(a["key"])
        let home = NativeTracker.string(a["home"])
        let away = NativeTracker.string(a["away"])
        let minute = LiveMatch.shortMinute(NativeTracker.string(a["minute"]))
        let score = NativeTracker.string(a["score"]).isEmpty ? "0 - 0" : NativeTracker.string(a["score"])
        let level = NativeTracker.string(a["level"])
        let side = NativeTracker.string(a["side"])
        let prob = NativeTracker.double(a["prob"])
        let windowMin = Int(NativeTracker.double(a["windowMin"])) == 0 ? 10 : Int(NativeTracker.double(a["windowMin"]))
        let pH = a["probHome"] as? NSNumber
        let pA = a["probAway"] as? NSNumber

        var teamLine = "\(NativeTracker.pct(prob)) olasılıkla \(windowMin) dk içinde gol"
        if side == "both", let h = pH, let w = pA {
            teamLine = "İki takım da baskıda · \(home) \(NativeTracker.pct(h.doubleValue)), \(away) \(NativeTracker.pct(w.doubleValue)) gol atma ihtimali"
        } else if side == "home", let h = pH {
            teamLine = "\(home) baskıda · gol atma ihtimali \(NativeTracker.pct(h.doubleValue))"
        } else if side == "away", let w = pA {
            teamLine = "\(away) baskıda · gol atma ihtimali \(NativeTracker.pct(w.doubleValue))"
        }
        let head = "\(minute == "Canlı" ? "" : minute + " ")\(level == "high" ? "Gol kapıda" : "Gol sinyali"): \(score)"

        let tag = "pusulai-goalalert-\(key)"
        let content = UNMutableNotificationContent()
        content.title = "\(home) - \(away)"
        content.body = "\(head)\n\(teamLine)\n\(windowMin) dk içinde maçta gol: \(NativeTracker.pct(prob))"
        content.sound = NotificationSounds.sound(forTag: tag)
        content.threadIdentifier = "pusulai"
        content.userInfo = ["url": "/#gol-sinyalleri"]
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: tag, content: content, trigger: nil),
                                               withCompletionHandler: nil)
    }

    private func poll() {
        guard !inFlight else { return }
        let tracked = order.compactMap { items[$0] }.filter { $0.phase != "ended" }
        var leagues = Set<String>()
        var fotmob = Set<String>()
        // İki kaynak birden (ESPN + FotMob): golü hangisi önce görürse
        for m in tracked {
            if !m.espnEventId.isEmpty, !m.espnLeague.isEmpty { leagues.insert(m.espnLeague) }
            if m.fotmobId > 0 { fotmob.insert(String(m.fotmobId)) }
        }
        guard !leagues.isEmpty || !fotmob.isEmpty,
              var comps = URLComponents(url: WebViewController.homeURL.appendingPathComponent("api/live-scores"),
                                        resolvingAgainstBaseURL: false) else { return }
        comps.queryItems = [
            URLQueryItem(name: "leagues", value: leagues.sorted().joined(separator: ",")),
            URLQueryItem(name: "fm", value: fotmob.sorted().joined(separator: ",")),
        ]
        guard let url = comps.url else { return }
        var req = URLRequest(url: url)
        req.timeoutInterval = 8
        req.cachePolicy = .reloadIgnoringLocalCacheData
        inFlight = true
        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.inFlight = false
                if let data = data { self.apply(data) }
            }
        }.resume()
    }

    private static func int(_ v: Any?) -> Int {
        if let n = v as? NSNumber { return n.intValue }
        if let s = v as? String { return Int(s) ?? 0 }
        return 0
    }

    private static func string(_ v: Any?) -> String {
        if let s = v as? String { return s }
        if let n = v as? NSNumber { return n.stringValue }
        return ""
    }

    private func apply(_ data: Data) {
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return }
        var byId: [String: [String: Any]] = [:]
        for s in json["scores"] as? [[String: Any]] ?? [] {
            byId[NativeTracker.string(s["eventId"])] = s
        }
        var byFm: [Int: [String: Any]] = [:]
        for f in json["fotmob"] as? [[String: Any]] ?? [] {
            byFm[NativeTracker.int(f["matchId"])] = f
        }

        var changed = false
        for key in order {
            guard var m = items[key], m.phase != "ended" else { continue }
            let espn = m.espnEventId.isEmpty ? nil : byId[m.espnEventId]
            let fm = m.fotmobId > 0 ? byFm[m.fotmobId] : nil
            var src: [String: Any]? = espn ?? fm
            var clockKey = espn != nil ? "clock" : "minute"
            if let e = espn, let f = fm {
                let te = NativeTracker.int(e["homeScore"]) + NativeTracker.int(e["awayScore"])
                let tf = NativeTracker.int(f["homeScore"]) + NativeTracker.int(f["awayScore"])
                let fPost = NativeTracker.string(f["state"]) == "post" && NativeTracker.string(e["state"]) != "post"
                if tf > te || (tf == te && fPost) {
                    src = f
                    clockKey = "minute"
                }
            }
            guard let s = src else { continue }
            let state = NativeTracker.string(s["state"])
            guard state == "in" || state == "post" else { continue }
            let hs = NativeTracker.int(s["homeScore"])
            let aw = NativeTracker.int(s["awayScore"])
            // Eski veriyle skoru geri alma
            if m.phase == "live" && hs + aw < m.homeScore + m.awayScore { continue }
            let halftime = (s["isHalftime"] as? Bool) ?? false
            let phase = state == "post" ? "ended" : (halftime ? "ht" : "live")
            let minute = phase == "ended" ? "MS" : phase == "ht" ? "İY" : LiveMatch.shortMinute(NativeTracker.string(s[clockKey]))

            let prev = m
            m.homeScore = hs
            m.awayScore = aw
            m.phase = phase
            m.minute = minute
            if prev.homeScore != m.homeScore || prev.awayScore != m.awayScore || prev.phase != m.phase || prev.minute != m.minute {
                items[key] = m
                changed = true
                notifyEvents(from: prev, to: m)
            }
        }
        if changed {
            LiveActivityManager.shared.sync(order.compactMap { items[$0] })
        }
    }

    /// Sunucuyla aynı metin ve etiketler (aynı olay iki kez gelirse biri diğerinin yerine geçer)
    private func notifyEvents(from prev: LiveMatch, to m: LiveMatch) {
        let score = "\(m.homeScore) - \(m.awayScore)"
        var events: [(body: String, tag: String)] = []
        if prev.phase == "pre" && (m.phase == "live" || m.phase == "ht") {
            events.append(("Maç başladı", "start"))
        }
        let total = m.homeScore + m.awayScore
        let prevTotal = prev.homeScore + prev.awayScore
        if total > prevTotal {
            let marked = m.homeScore > prev.homeScore ? "[\(m.homeScore)] - \(m.awayScore)" : "\(m.homeScore) - [\(m.awayScore)]"
            events.append(("\(m.minute) Gol: \(marked)", "goal-\(m.homeScore)-\(m.awayScore)"))
        } else if total < prevTotal && prev.phase != "pre" {
            events.append(("\(m.minute) Gol iptal (VAR): \(score)", "var-\(m.homeScore)-\(m.awayScore)"))
        }
        if m.phase == "ht" && prev.phase == "live" { events.append(("Devre arası: \(score)", "ht")) }
        if m.phase == "live" && prev.phase == "ht" { events.append(("İkinci yarı başladı: \(score)", "2h")) }
        if m.phase == "ended" && prev.phase != "ended" { events.append(("Maç sonucu: \(score)", "ft")) }

        for e in events {
            let tag = "pusulai-\(m.key)-\(e.tag)"
            let content = UNMutableNotificationContent()
            content.title = "\(m.home) - \(m.away)"
            content.body = e.body
            content.sound = NotificationSounds.sound(forTag: tag)
            content.threadIdentifier = "pusulai"
            content.userInfo = ["url": "/"]
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: tag, content: content, trigger: nil),
                                                   withCompletionHandler: nil)
        }
    }
}
