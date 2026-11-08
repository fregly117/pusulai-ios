import Foundation

public enum MatchState: String, Codable, CaseIterable {
    case upcoming
    case live
    case played
    case finished
}

public struct OddsTriplet: Codable, Hashable {
    public let ms1: Double
    public let msX: Double
    public let ms2: Double
    public let over25: Double?
    public let btts: Double?
    
    public init(ms1: Double = 1.0, msX: Double = 1.0, ms2: Double = 1.0, over25: Double? = nil, btts: Double? = nil) {
        self.ms1 = ms1
        self.msX = msX
        self.ms2 = ms2
        self.over25 = over25
        self.btts = btts
    }
}

public struct GoalWatch: Codable, Hashable {
    public let prob: Double?
    public let windowMin: Int?
    public let level: String? // "none", "medium", "high"
    public let side: String?  // "home", "away", "both"
    public let reason: String?
}

public struct LiveAnalysis: Codable, Hashable {
    public let minute: String?
    public let liveScore: String?
    public let homeScore: Int?
    public let awayScore: Int?
    public let isHalftime: Bool?
    public let inPlaySummary: String?
    public let recommendedLivePick: String?
    public let liveOdds: Double?
    public let confidence: Double?
    public let goalWatch: GoalWatch?
}

public struct Match: Codable, Identifiable, Hashable {
    public let id: String
    public let code: String?
    public let matchDate: String?
    public let time: String?
    public let matchState: MatchState
    public let league: String
    public let home: String
    public let away: String
    public let homeLogo: String?
    public let awayLogo: String?
    public let leagueLogo: String?
    public let leagueCountry: String?
    public let liveMinute: String?
    public let liveAnalysis: LiveAnalysis?
    public let oddsCurr: OddsTriplet?
    public let xgHome: Double?
    public let xgAway: Double?
    public let missingInfo: String?
    public let missingHomeCount: Int?
    public let missingAwayCount: Int?
    
    // Computed Helpers
    public var isLive: Bool {
        return matchState == .live
    }
    
    public var isFinished: Bool {
        return matchState == .finished || matchState == .played
    }
    
    public var scoreText: String {
        if let liveScore = liveAnalysis?.liveScore, !liveScore.isEmpty {
            return liveScore
        }
        if let h = liveAnalysis?.homeScore, let a = liveAnalysis?.awayScore {
            return "\(h) - \(a)"
        }
        return time ?? "v"
    }
    
    public var displayMinute: String {
        if let lm = liveMinute, !lm.isEmpty {
            return lm.replacingOccurrences(of: "\u{200E}", with: "")
        }
        if let m = liveAnalysis?.minute, !m.isEmpty {
            return m
        }
        if matchState == .live {
            return "CANLI"
        }
        return time ?? ""
    }
}
