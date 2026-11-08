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

    /// Sayfadan gelen son durum (uygulama açıkken sürekli güncellenir)
    func update(_ matches: [LiveMatch]) {
        var next: [String: LiveMatch] = [:]
        for m in matches { next[m.key] = m }
        items = next
        order = matches.map { $0.key }
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 8, repeats: true) { [weak self] _ in self?.poll() }
        poll()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        guard !inFlight else { return }
        let tracked = order.compactMap { items[$0] }.filter { $0.phase != "ended" }
        var leagues = Set<String>()
        var fotmob = Set<String>()
        for m in tracked {
            if !m.espnEventId.isEmpty, !m.espnLeague.isEmpty { leagues.insert(m.espnLeague) }
            else if m.espnEventId.isEmpty, m.fotmobId > 0 { fotmob.insert(String(m.fotmobId)) }
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
            var src: [String: Any]?
            var clockKey = "clock"
            if !m.espnEventId.isEmpty {
                src = byId[m.espnEventId]
            } else if m.fotmobId > 0 {
                src = byFm[m.fotmobId]
                clockKey = "minute"
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
