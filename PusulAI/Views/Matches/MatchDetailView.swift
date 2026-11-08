import SwiftUI

public struct MatchDetailView: View {
    public let match: Match
    @State private var selectedTab = 0
    @State private var lineups: MatchLineups?
    @State private var isLoadingLineups = false
    @ObservedObject var couponStore = CouponStore.shared
    
    public init(match: Match) {
        self.match = match
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header: Maç Başlığı, Skor ve Dakika
                headerCard
                
                // Segmented Tab Picker
                Picker("Sekmeler", selection: $selectedTab) {
                    Text("Analiz").tag(0)
                    Text("Kadrolar").tag(1)
                    Text("İstatistik").tag(2)
                    Text("Oranlar").tag(3)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // Tab İçerikleri
                switch selectedTab {
                case 0:
                    analysisTab
                case 1:
                    lineupsTab
                case 2:
                    statsTab
                case 3:
                    oddsTab
                default:
                    EmptyView()
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(match.league)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(UIColor.systemGroupedBackground))
        .task {
            await loadLineups()
        }
    }
    
    // MARK: - Header
    private var headerCard: some View {
        VStack(spacing: 12) {
            if match.isLive {
                LiveBadge(text: match.displayMinute)
            } else {
                Text(match.matchDate ?? "")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            
            HStack(alignment: .center) {
                // Ev Sahibi
                VStack(spacing: 6) {
                    TeamLogoView(urlString: match.homeLogo, teamName: match.home, size: 48)
                    Text(match.home)
                        .font(.system(size: 14, weight: .bold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity)
                
                // Skor / Saat
                VStack(spacing: 4) {
                    Text(match.scoreText)
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundColor(match.isLive ? .red : .primary)
                    
                    if match.isLive {
                        Text("CANLI")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.red)
                    }
                }
                .frame(width: 90)
                
                // Deplasman
                VStack(spacing: 6) {
                    TeamLogoView(urlString: match.awayLogo, teamName: match.away, size: 48)
                    Text(match.away)
                        .font(.system(size: 14, weight: .bold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 8)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - Analiz Sekmesi
    private var analysisTab: some View {
        VStack(spacing: 14) {
            // AI Önerisi
            if let pick = match.liveAnalysis?.recommendedLivePick, !pick.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.yellow)
                        Text("PusulAI Model Tahmini")
                            .font(.system(size: 14, weight: .bold))
                    }
                    Text(pick)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(red: 55/255.0, green: 77/255.0, blue: 245/255.0))
                    
                    if let summary = match.liveAnalysis?.inPlaySummary {
                        Text(summary)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(14)
                .padding(.horizontal)
            }
            
            // Beklenen Goller (xG)
            if let xgH = match.xgHome, let xgA = match.xgAway, (xgH > 0 || xgA > 0) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Beklenen Goller (xG)")
                        .font(.system(size: 14, weight: .bold))
                    
                    StatRowView(title: "xG", homeValue: xgH, awayValue: xgA)
                }
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(14)
                .padding(.horizontal)
            }
            
            // Gol Alarmı (GoalWatch)
            if let gw = match.liveAnalysis?.goalWatch, gw.level != "none" {
                HStack(spacing: 12) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Gol Kapıda Alarmı! (~\(gw.windowMin ?? 10) dk)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.orange)
                        Text(gw.reason ?? "Yoğun baskı tespit edildi")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(14)
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Kadrolar Sekmesi
    private var lineupsTab: some View {
        Group {
            if isLoadingLineups {
                ProgressView("Kadrolar yükleniyor...")
                    .padding(40)
            } else if let l = lineups {
                SoccerPitchView(lineups: l, homeTeamName: match.home, awayTeamName: match.away)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "tshirt")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("Kadrolar maç saatine 45 dakika kala açıklanır.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(40)
            }
        }
    }
    
    // MARK: - İstatistikler Sekmesi
    private var statsTab: some View {
        VStack(spacing: 12) {
            StatRowView(title: "Topla Oynama", homeValue: 54, awayValue: 46, isPercentage: true)
            StatRowView(title: "Toplam Şut", homeValue: 12, awayValue: 9)
            StatRowView(title: "İsabetli Şut", homeValue: 5, awayValue: 3)
            StatRowView(title: "Korner", homeValue: 6, awayValue: 4)
            StatRowView(title: "Fauller", homeValue: 11, awayValue: 14)
            StatRowView(title: "Sarı Kart", homeValue: 2, awayValue: 3)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(14)
        .padding(.horizontal)
    }
    
    // MARK: - Oranlar Sekmesi
    private var oddsTab: some View {
        VStack(spacing: 16) {
            if let odds = match.oddsCurr {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Maç Sonucu (1-X-2)")
                        .font(.system(size: 14, weight: .bold))
                    HStack(spacing: 8) {
                        OddsButton(title: "MS 1", odds: odds.ms1, isSelected: couponStore.isSelected(matchId: match.id, pick: .ms1)) {
                            couponStore.toggle(match: match, pick: .ms1, odds: odds.ms1)
                        }
                        OddsButton(title: "MS X", odds: odds.msX, isSelected: couponStore.isSelected(matchId: match.id, pick: .msX)) {
                            couponStore.toggle(match: match, pick: .msX, odds: odds.msX)
                        }
                        OddsButton(title: "MS 2", odds: odds.ms2, isSelected: couponStore.isSelected(matchId: match.id, pick: .ms2)) {
                            couponStore.toggle(match: match, pick: .ms2, odds: odds.ms2)
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(14)
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("2.5 Gol Alt / Üst")
                        .font(.system(size: 14, weight: .bold))
                    HStack(spacing: 8) {
                        OddsButton(title: "2.5 Üst", odds: odds.over25 ?? 1.75, isSelected: couponStore.isSelected(matchId: match.id, pick: .over25)) {
                            couponStore.toggle(match: match, pick: .over25, odds: odds.over25 ?? 1.75)
                        }
                        OddsButton(title: "2.5 Alt", odds: 1.95, isSelected: couponStore.isSelected(matchId: match.id, pick: .under25)) {
                            couponStore.toggle(match: match, pick: .under25, odds: 1.95)
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(14)
                .padding(.horizontal)
            }
        }
    }
    
    private func loadLineups() async {
        isLoadingLineups = true
        lineups = try? await APIService.shared.fetchLineups(matchId: match.id)
        isLoadingLineups = false
    }
}
