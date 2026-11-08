import Foundation
import Combine

@MainActor
public final class CouponStore: ObservableObject {
    public static let shared = CouponStore()
    
    @Published public var items: [SlipItem] = []
    @Published public var stake: Double = 100.0
    
    private init() {}
    
    public var totalOdds: Double {
        guard !items.isEmpty else { return 0.0 }
        return items.reduce(1.0) { $0 * $1.odds }
    }
    
    public var potentialWinning: Double {
        return totalOdds * stake
    }
    
    public func isSelected(matchId: String, pick: MarketPickType) -> Bool {
        return items.contains { $0.matchId == matchId && $0.pickType == pick }
    }
    
    public func selectedPick(for matchId: String) -> MarketPickType? {
        return items.first { $0.matchId == matchId }?.pickType
    }
    
    public func toggle(match: Match, pick: MarketPickType, odds: Double) {
        HapticManager.shared.light()
        
        // Aynı maçtan farklı bir seçim varsa eskisini kaldır (tek maç - tek seçim kuralı)
        if let existingIndex = items.firstIndex(where: { $0.matchId == match.id }) {
            let existing = items[existingIndex]
            if existing.pickType == pick {
                items.remove(at: existingIndex)
                return
            } else {
                items.remove(at: existingIndex)
            }
        }
        
        let newItem = SlipItem(
            matchId: match.id,
            homeTeam: match.home,
            awayTeam: match.away,
            league: match.league,
            matchTime: match.time ?? "",
            pickType: pick,
            odds: odds
        )
        items.append(newItem)
        HapticManager.shared.success()
    }
    
    public func remove(item: SlipItem) {
        HapticManager.shared.selection()
        items.removeAll { $0.id == item.id }
    }
    
    public func clear() {
        HapticManager.shared.selection()
        items.removeAll()
    }
}
