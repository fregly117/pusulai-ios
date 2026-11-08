import SwiftUI

public struct SoccerPitchView: View {
    public let lineups: MatchLineups
    public let homeTeamName: String
    public let awayTeamName: String
    
    public init(lineups: MatchLineups, homeTeamName: String, awayTeamName: String) {
        self.lineups = lineups
        self.homeTeamName = homeTeamName
        self.awayTeamName = awayTeamName
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Futbol Sahası
            ZStack {
                // Çim Zemin
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 26/255.0, green: 90/255.0, blue: 45/255.0), Color(red: 20/255.0, green: 75/255.0, blue: 38/255.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                // Saha Çizgileri
                PitchLinesShape()
                    .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                    .padding(8)
                
                // Ev Sahibi Oyuncuları (Üst Yarı)
                if let home = lineups.homeLineup {
                    GeometryReader { geo in
                        ForEach(home.starters) { p in
                            PlayerDotView(player: p, isHome: true)
                                .position(
                                    x: geo.size.width * CGFloat(p.x),
                                    y: geo.size.height * 0.48 * CGFloat(p.y) + 20
                                )
                        }
                    }
                }
                
                // Deplasman Oyuncuları (Alt Yarı)
                if let away = lineups.awayLineup {
                    GeometryReader { geo in
                        ForEach(away.starters) { p in
                            PlayerDotView(player: p, isHome: false)
                                .position(
                                    x: geo.size.width * CGFloat(p.x),
                                    y: geo.size.height * 0.52 + (geo.size.height * 0.44 * CGFloat(1.0 - p.y))
                                )
                        }
                    }
                }
            }
            .frame(height: 380)
            .padding(.horizontal)
            
            // Sakat ve Cezalılar
            if let hUn = lineups.homeUnavailable, let aUn = lineups.awayUnavailable, (!hUn.isEmpty || !aUn.isEmpty) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Sakat ve Cezalılar")
                        .font(.system(size: 15, weight: .bold))
                        .padding(.horizontal)
                    
                    HStack(alignment: .top, spacing: 12) {
                        // Ev Sahibi Eksikler
                        VStack(alignment: .leading, spacing: 6) {
                            Text(homeTeamName)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            ForEach(hUn) { un in
                                UnavailableRow(player: un)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Divider()
                        
                        // Deplasman Eksikler
                        VStack(alignment: .leading, spacing: 6) {
                            Text(awayTeamName)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            ForEach(aUn) { un in
                                UnavailableRow(player: un)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
        }
    }
}

private struct PlayerDotView: View {
    let player: LineupPlayer
    let isHome: Bool
    
    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(isHome ? Color.blue : Color.red)
                    .frame(width: 22, height: 22)
                    .shadow(radius: 2)
                
                Text(player.number ?? "")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text(player.name.components(separatedBy: " ").last ?? player.name)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .shadow(color: .black, radius: 2)
        }
    }
}

private struct UnavailableRow: View {
    let player: UnavailablePlayer
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: player.type == "suspension" ? "rectangle.fill" : "cross.fill")
                .font(.system(size: 10))
                .foregroundColor(player.type == "suspension" ? .red : .orange)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(player.name)
                    .font(.system(size: 12, weight: .medium))
                if let ret = player.expectedReturn {
                    Text(ret)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// 2D Futbol Saha Çizgileri
private struct PitchLinesShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        // Dış Sınır
        p.addRect(rect)
        // Orta Çizgi
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        // Orta Daire
        let center = CGPoint(x: rect.midX, y: rect.midY)
        p.addEllipse(in: CGRect(x: center.x - 35, y: center.y - 35, width: 70, height: 70))
        // Üst Ceza Sahası
        p.addRect(CGRect(x: rect.midX - 60, y: rect.minY, width: 120, height: 50))
        // Alt Ceza Sahası
        p.addRect(CGRect(x: rect.midX - 60, y: rect.maxY - 50, width: 120, height: 50))
        return p
    }
}
