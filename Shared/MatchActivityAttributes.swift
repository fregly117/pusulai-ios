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
