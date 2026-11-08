import SwiftUI

public struct MatchesView: View {
    @State private var matches: [Match] = []
    @State private var isLoading = false
    @State private var selectedDay = "today" // "yesterday", "today", "tomorrow"
    @State private var filterOnlyLive = false
    @State private var searchText = ""
    
    let timer = Timer.publish(every: 20, on: .main, in: .common).autoconnect()
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Gün Seçici Bar (Dün - Bugün - Yarın)
                dayPickerBar
                
                // Canlı / Tümü Filtre Şeridi
                filterBar
                
                // Maç Listesi
                if isLoading && matches.isEmpty {
                    Spacer()
                    ProgressView("Bülten güncelleniyor...")
                    Spacer()
                } else if filteredMatches.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(groupedLeagues, id: \.self) { league in
                            Section(header: leagueHeader(league)) {
                                ForEach(matchesFor(league: league)) { match in
                                    NavigationLink(destination: MatchDetailView(match: match)) {
                                        MatchCardView(match: match)
                                    }
                                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await loadMatches()
                    }
                }
            }
            .navigationTitle("PusulAI")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(UIColor.systemGroupedBackground))
            .searchable(text: $searchText, prompt: "Takım veya Lig Ara...")
            .task {
                await loadMatches()
            }
            .onReceive(timer) { _ in
                Task {
                    await loadMatches(silent: true)
                }
            }
        }
    }
    
    // MARK: - Gün Seçici
    private var dayPickerBar: some View {
        HStack(spacing: 8) {
            dayButton(title: "Dün", day: "yesterday")
            dayButton(title: "Bugün", day: "today")
            dayButton(title: "Yarın", day: "tomorrow")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemGroupedBackground))
    }
    
    private func dayButton(title: String, day: String) -> some View {
        let isSelected = selectedDay == day
        return Button {
            HapticManager.shared.selection()
            selectedDay = day
            Task { await loadMatches() }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? Color(red: 55/255.0, green: 77/255.0, blue: 245/255.0) : Color.clear)
                .cornerRadius(8)
        }
    }
    
    // MARK: - Filtre Barı
    private var filterBar: some View {
        HStack {
            Toggle(isOn: $filterOnlyLive) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("Canlı Maçlar (\(liveCount))")
                        .font(.system(size: 13, weight: .bold))
                }
            }
            .toggleStyle(.button)
            .tint(Color.red.opacity(0.15))
            .foregroundColor(filterOnlyLive ? .red : .secondary)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    private var liveCount: Int {
        matches.filter { $0.isLive }.count
    }
    
    // MARK: - Lig Başlığı
    private func leagueHeader(_ league: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 12))
                .foregroundColor(Color(red: 55/255.0, green: 77/255.0, blue: 245/255.0))
            
            Text(league)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Filtreleme Mantığı
    private var filteredMatches: [Match] {
        var list = matches
        if filterOnlyLive {
            list = list.filter { $0.isLive }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            list = list.filter {
                $0.home.lowercased().contains(q) ||
                $0.away.lowercased().contains(q) ||
                $0.league.lowercased().contains(q)
            }
        }
        return list
    }
    
    private var groupedLeagues: [String] {
        let leagues = filteredMatches.map { $0.league }
        var unique: [String] = []
        for l in leagues {
            if !unique.contains(l) { unique.append(l) }
        }
        return unique
    }
    
    private func matchesFor(league: String) -> [Match] {
        filteredMatches.filter { $0.league == league }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "soccerball")
                .font(.system(size: 44))
                .foregroundColor(.secondary)
            Text(filterOnlyLive ? "Şu an canlı maç bulunmuyor." : "Bu tarihte maç bulunamadı.")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    
    private func loadMatches(silent: Bool = false) async {
        if !silent { isLoading = true }
        do {
            let res = try await APIService.shared.fetchFixtures(day: selectedDay)
            if !res.isEmpty {
                self.matches = res
            }
        } catch {
            print("Matches fetch error: \(error)")
        }
        if !silent { isLoading = false }
    }
}
