import Foundation

public final class APIService {
    public static let shared = APIService()
    
    public let baseURL = "https://pusulai.up.railway.app"
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15.0
        config.timeoutIntervalForResource = 30.0
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
    }
    
    public func fetchFixtures(day: String = "today") async throws -> [Match] {
        guard let url = URL(string: "\(baseURL)/api/live-fixtures?day=\(day)") else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        
        // API doğrudan [Match] veya { matches: [Match] } dönebilir
        if let directMatches = try? decoder.decode([Match].self, from: data) {
            return directMatches
        }
        
        struct FixturesResponse: Codable {
            let matches: [Match]?
            let liveMatches: [Match]?
        }
        
        if let container = try? decoder.decode(FixturesResponse.self, from: data) {
            if let m = container.matches, !m.isEmpty {
                return m
            }
            if let lm = container.liveMatches, !lm.isEmpty {
                return lm
            }
        }
        
        return []
    }
    
    public func fetchLineups(matchId: String) async throws -> MatchLineups? {
        guard let url = URL(string: "\(baseURL)/api/lineups?matchId=\(matchId)") else {
            return nil
        }
        do {
            let (data, _) = try await session.data(from: url)
            return try JSONDecoder().decode(MatchLineups.self, from: data)
        } catch {
            return nil
        }
    }
}
