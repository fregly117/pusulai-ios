import Foundation

public struct LineupPlayer: Identifiable, Codable, Hashable {
    public let id: String
    public let name: String
    public let number: String?
    public let position: String?
    public let x: Double // 0.0 - 1.0 (saha genişlik katsayısı)
    public let y: Double // 0.0 - 1.0 (saha derinlik katsayısı)
    public let rating: Double?
}

public struct TeamLineup: Codable, Hashable {
    public let formation: String?
    public let starters: [LineupPlayer]
    public let bench: [LineupPlayer]
    public let coach: String?
}

public struct UnavailablePlayer: Identifiable, Codable, Hashable {
    public var id: String { name }
    public let name: String
    public let type: String // "injury", "suspension", "other"
    public let reason: String?
    public let expectedReturn: String?
    public let doubtful: Bool?
}

public struct MatchLineups: Codable, Hashable {
    public let homeLineup: TeamLineup?
    public let awayLineup: TeamLineup?
    public let homeUnavailable: [UnavailablePlayer]?
    public let awayUnavailable: [UnavailablePlayer]?
}
