import Foundation

public enum MarketPickType: String, Codable, CaseIterable {
    case ms1 = "MS 1"
    case msX = "MS X"
    case ms2 = "MS 2"
    case over25 = "2.5 Üst"
    case under25 = "2.5 Alt"
    case bttsYes = "KG Var"
    case bttsNo = "KG Yok"
    
    public var shortTitle: String {
        switch self {
        case .ms1: return "1"
        case .msX: return "X"
        case .ms2: return "2"
        case .over25: return "2.5Ü"
        case .under25: return "2.5A"
        case .bttsYes: return "Var"
        case .bttsNo: return "Yok"
        }
    }
}

public struct SlipItem: Identifiable, Codable, Hashable {
    public var id: String { "\(matchId)_\(pickType.rawValue)" }
    public let matchId: String
    public let homeTeam: String
    public let awayTeam: String
    public let league: String
    public let matchTime: String
    public let pickType: MarketPickType
    public let odds: Double
    
    public init(matchId: String, homeTeam: String, awayTeam: String, league: String, matchTime: String, pickType: MarketPickType, odds: Double) {
        self.matchId = matchId
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.league = league
        self.matchTime = matchTime
        self.pickType = pickType
        self.odds = odds
    }
}
