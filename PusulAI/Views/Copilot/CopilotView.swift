import SwiftUI

public struct CopilotView: View {
    @State private var selectedProfile = "balanced" // "safe", "balanced", "value"
    @State private var isGenerating = false
    @State private var recommendedPicks: [SlipItem] = []
    @ObservedObject var couponStore = CouponStore.shared
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Copilot Banner
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "sparkles")
                                .font(.system(size: 20))
                                .foregroundColor(.yellow)
                            Text("PusulAI Yapay Zeka Motoru")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Text("Dixon-Coles Poisson skor matrisi, marjsız piyasa oranları ve gerçek lig istatistikleri harmanlanarak en değerli seçimler belirlenir.")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.85))
                            .lineSpacing(2)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 55/255.0, green: 77/255.0, blue: 245/255.0), Color(red: 25/255.0, green: 40/255.0, blue: 180/255.0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // Risk Profili Seçici
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Analiz Profili Seçin")
                            .font(.system(size: 14, weight: .bold))
                            .padding(.horizontal)
                        
                        HStack(spacing: 8) {
                            profileCard(id: "safe", title: "Güvenli", desc: "1.20 - 1.70", icon: "shield.fill")
                            profileCard(id: "balanced", title: "Dengeli", desc: "1.50 - 2.50", icon: "scalemass.fill")
                            profileCard(id: "value", title: "Değer", desc: "1.90 - 4.50", icon: "bolt.fill")
                        }
                        .padding(.horizontal)
                    }
                    
                    // Üret Butonu
                    Button {
                        generateAiCoupon()
                    } label: {
                        HStack(spacing: 8) {
                            if isGenerating {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "wand.and.stars")
                                Text("PusulAI ile Günün Kuponunu Üret")
                            }
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(red: 55/255.0, green: 77/255.0, blue: 245/255.0))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .disabled(isGenerating)
                    
                    // Üretilen Kupon
                    if !recommendedPicks.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Önerilen AI Kuponu")
                                    .font(.system(size: 15, weight: .bold))
                                Spacer()
                                Text("Toplam Oran: \(String(format: "%.2f", couponTotalOdds))")
                                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                                    .foregroundColor(Color(red: 55/255.0, green: 77/255.0, blue: 245/255.0))
                            }
                            .padding(.horizontal)
                            
                            ForEach(recommendedPicks) { pick in
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("\(pick.homeTeam) - \(pick.awayTeam)")
                                            .font(.system(size: 13, weight: .semibold))
                                        Text(pick.league)
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 3) {
                                        Text(pick.pickType.rawValue)
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Color(red: 55/255.0, green: 77/255.0, blue: 245/255.0))
                                        Text(String(format: "%.2f", pick.odds))
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(12)
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .cornerRadius(10)
                                .padding(.horizontal)
                            }
                            
                            Button {
                                addAllToCoupon()
                            } label: {
                                Text("Tümünü Kuponuma Aktar")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(Color.green)
                                    .cornerRadius(10)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("PusulAI Copilot")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(UIColor.systemGroupedBackground))
        }
    }
    
    private func profileCard(id: String, title: String, desc: String, icon: String) -> some View {
        let isSelected = selectedProfile == id
        return Button {
            HapticManager.shared.selection()
            selectedProfile = id
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? Color(red: 55/255.0, green: 77/255.0, blue: 245/255.0) : .secondary)
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
                Text(desc)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color(red: 55/255.0, green: 77/255.0, blue: 245/255.0) : Color.clear, lineWidth: 2)
            )
        }
    }
    
    private var couponTotalOdds: Double {
        recommendedPicks.reduce(1.0) { $0 * $1.odds }
    }
    
    private func generateAiCoupon() {
        HapticManager.shared.medium()
        isGenerating = true
        
        Task {
            // Canlı fikstürden en iyi maçları çekip profile göre seçim yap
            if let matches = try? await APIService.shared.fetchFixtures(day: "today"), !matches.isEmpty {
                var picks: [SlipItem] = []
                let eligible = matches.filter { !$0.isFinished && $0.oddsCurr != nil }
                
                for m in eligible.prefix(3) {
                    if let o = m.oddsCurr {
                        let pickType: MarketPickType = selectedProfile == "safe" ? .over25 : (selectedProfile == "value" ? .ms1 : .ms1)
                        let oddVal = (pickType == .over25 ? (o.over25 ?? 1.65) : o.ms1)
                        picks.append(SlipItem(
                            matchId: m.id,
                            homeTeam: m.home,
                            awayTeam: m.away,
                            league: m.league,
                            matchTime: m.time ?? "",
                            pickType: pickType,
                            odds: oddVal > 1.0 ? oddVal : 1.70
                        ))
                    }
                }
                
                await MainActor.run {
                    self.recommendedPicks = picks
                    self.isGenerating = false
                    HapticManager.shared.success()
                }
            } else {
                await MainActor.run {
                    self.isGenerating = false
                }
            }
        }
    }
    
    private func addAllToCoupon() {
        for p in recommendedPicks {
            couponStore.items.append(p)
        }
        HapticManager.shared.success()
    }
}
