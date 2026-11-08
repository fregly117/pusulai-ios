import SwiftUI

public struct FavoritesView: View {
    @State private var favoriteMatches: [Match] = []
    @State private var isLoading = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack {
                if favoriteMatches.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "star.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("Henüz Favori Maçınız Yok")
                            .font(.system(size: 17, weight: .bold))
                        Text("Bültendeki maçların detayına giderek favorilerinize ekleyebilir ve canlı gol alarmlarını anlık alabilirsiniz.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else {
                    List(favoriteMatches) { match in
                        NavigationLink(destination: MatchDetailView(match: match)) {
                            MatchCardView(match: match)
                        }
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Favoriler & Alarmlar")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(UIColor.systemGroupedBackground))
            .task {
                await loadFavorites()
            }
        }
    }
    
    private func loadFavorites() async {
        // Canlı maçlardan gol alarmı olanları getir
        if let matches = try? await APIService.shared.fetchFixtures(day: "today") {
            self.favoriteMatches = matches.filter { $0.liveAnalysis?.goalWatch?.level == "high" || $0.liveAnalysis?.goalWatch?.level == "medium" }
        }
    }
}
