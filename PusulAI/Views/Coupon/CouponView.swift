import SwiftUI

public struct CouponView: View {
    @ObservedObject var couponStore = CouponStore.shared
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            Group {
                if couponStore.items.isEmpty {
                    emptyCouponView
                } else {
                    VStack(spacing: 0) {
                        // Maç Listesi
                        List {
                            ForEach(couponStore.items) { item in
                                couponItemRow(item)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                            }
                            .onDelete { indexSet in
                                for idx in indexSet {
                                    couponStore.items.remove(at: idx)
                                }
                            }
                        }
                        .listStyle(.plain)
                        
                        // Alt Özet Kartı
                        bottomSummaryCard
                    }
                }
            }
            .navigationTitle("Kuponum (\(couponStore.items.count))")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(UIColor.systemGroupedBackground))
            .toolbar {
                if !couponStore.items.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Temizle") {
                            couponStore.clear()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
    }
    
    private func couponItemRow(_ item: SlipItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(item.homeTeam) - \(item.awayTeam)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                
                HStack(spacing: 6) {
                    Text(item.league)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(item.matchTime)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(item.pickType.rawValue)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(red: 55/255.0, green: 77/255.0, blue: 245/255.0))
                    
                    Text(String(format: "%.2f", item.odds))
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                }
                
                Button {
                    couponStore.remove(item: item)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    private var bottomSummaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Kupon Tutarı:")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(couponStore.stake)) ₺")
                    .font(.system(size: 15, weight: .bold))
            }
            
            HStack {
                Text("Toplam Oran:")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%.2f", couponStore.totalOdds))
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(red: 55/255.0, green: 77/255.0, blue: 245/255.0))
            }
            
            Divider()
            
            HStack {
                Text("Tahmini Kazanç:")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Text(String(format: "%.2f ₺", couponStore.potentialWinning))
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundColor(.green)
            }
            
            ShareLink(item: shareText) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Kuponu Paylaş")
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color(red: 55/255.0, green: 77/255.0, blue: 245/255.0))
                .cornerRadius(12)
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: -2)
    }
    
    private var shareText: String {
        var str = "🔥 PusulAI İddaa Kuponum:\n\n"
        for item in couponStore.items {
            str += "⚽ \(item.homeTeam) - \(item.awayTeam)\n"
            str += "🎯 Tercih: \(item.pickType.rawValue) (Oran: \(String(format: "%.2f", item.odds)))\n\n"
        }
        str += "📊 Toplam Oran: \(String(format: "%.2f", couponStore.totalOdds))\n"
        str += "📱 PusulAI Pro ile hazırlandı."
        return str
    }
    
    private var emptyCouponView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 54))
                .foregroundColor(.secondary.opacity(0.7))
            Text("Kuponunuz Boş")
                .font(.system(size: 18, weight: .bold))
            Text("Bülten ekranından maç oranlarına dokunarak kuponunuza seçim ekleyebilirsiniz.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}
