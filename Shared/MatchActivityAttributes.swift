import Foundation
import ActivityKit

/// Dinamik Ada / kilit ekranında gösterilen favori maç.
/// Uygulama ve widget eklentisi bu yapıyı paylaşır.
struct MatchActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var homeScore: Int
        var awayScore: Int
        /// "29'", "45+2'", "İY", "MS" veya başlamadıysa "21:45"
        var minute: String
        /// "pre" | "live" | "ht" | "ended"
        var phase: String
        /// Son golü atan taraf ("home" | "away") ve golün zamanı (Unix saniye).
        /// Gol anında Dinamik Ada'da "⚽ GOL!" gösterilir.
        var goalSide: String? = nil
        var goalTs: Double? = nil
        /// Maç saatinin "0. dakikası"nın zamanı (Unix saniye). Varsa kart dakikayı kendisi akıtır:
        /// uygulama kapalıyken / güncelleme gelmezken bile dakika ilerler (SofaScore gibi).
        var clockStart: Double? = nil

        /// Canlı saat aralığı (başlangıç → +130 dk)
        var clockRange: ClosedRange<Date>? {
            guard phase == "live", let cs = clockStart else { return nil }
            let start = Date(timeIntervalSince1970: cs)
            return start...start.addingTimeInterval(130 * 60)
        }

        /// "67'" → 67, "45+2'" → 47 (bilinmiyorsa nil)
        static func minuteNumber(_ text: String) -> Int? {
            let digits = text.split(whereSeparator: { !$0.isNumber })
            guard let first = digits.first, let base = Int(first) else { return nil }
            let extra = text.contains("+") && digits.count > 1 ? Int(digits[1]) ?? 0 : 0
            return base + extra
        }

        /// Gol son 2 dakika içinde mi oldu?
        var recentGoal: Bool {
            guard let ts = goalTs else { return false }
            return Date().timeIntervalSince1970 - ts < 120
        }
    }

    var matchKey: String
    var home: String
    var away: String
    var homeShort: String
    var awayShort: String
    var league: String

    /// Takım logolarının adresi (ESPN / FotMob). Uygulama bunları indirip ortak klasöre koyar.
    var homeLogoURL: String?
    var awayLogoURL: String?
    /// Etkinliğin içine gömülü küçük logo (ortak klasör kullanılamazsa yedek)
    var homeThumb: Data?
    var awayThumb: Data?
}
