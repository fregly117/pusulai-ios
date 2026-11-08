import SwiftUI

public struct MatchCardView: View {
    public let match: Match
    @ObservedObject var couponStore = CouponStore.shared
    
    public init(match: Match) {
        self.match = match
    }
    
    public var body: some View {
        VStack(spacing: 10) {
            // Üst Satır: Zaman / Canlı Durum & Skor
            HStack(alignment: .center, spacing: 8) {
                // Zaman / Canlı Dakika
                if match.isLive {
                    LiveBadge(text: match.displayMinute)
                } else if match.isFinished {
                    Text("MS")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12))
                        .cornerRadius(4)
                } else {
                    Text(match.time ?? "--:--")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                if let code = match.code, !code.isEmpty {
                    Text(code)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                
                Spacer()
                
                // Canlı / Biten Skor
                if match.isLive || match.isFinished {
                    Text(match.scoreText)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(match.isLive ? Color.red : .primary)
                }
            }
            
            // Takımlar
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    TeamLogoView(urlString: match.homeLogo, teamName: match.home, size: 20)
                    Text(match.home)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Spacer()
                    if let xg = match.xgHome, xg > 0 {
                        Text(String(format: "xG %.2f", xg))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(spacing: 10) {
                    TeamLogoView(urlString: match.awayLogo, teamName: match.away, size: 20)
                    Text(match.away)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Spacer()
                    if let xg = match.xgAway, xg > 0 {
                        Text(String(format: "xG %.2f", xg))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Oran Butonları (1 - X - 2)
            if let odds = match.oddsCurr {
                HStack(spacing: 6) {
                    OddsButton(
                        title: "1",
                        odds: odds.ms1,
                        isSelected: couponStore.isSelected(matchId: match.id, pick: .ms1)
                    ) {
                        couponStore.toggle(match: match, pick: .ms1, odds: odds.ms1)
                    }
                    
                    OddsButton(
                        title: "X",
                        odds: odds.msX,
                        isSelected: couponStore.isSelected(matchId: match.id, pick: .msX)
                    ) {
                        couponStore.toggle(match: match, pick: .msX, odds: odds.msX)
                    }
                    
                    OddsButton(
                        title: "2",
                        odds: odds.ms2,
                        isSelected: couponStore.isSelected(matchId: match.id, pick: .ms2)
                    ) {
                        couponStore.toggle(match: match, pick: .ms2, odds: odds.ms2)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}
