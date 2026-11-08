import SwiftUI

public struct MainTabView: View {
    @ObservedObject var couponStore = CouponStore.shared
    @AppStorage("pusulai_dark_mode") private var darkMode = true
    
    public init() {}
    
    public var body: some View {
        TabView {
            MatchesView()
                .tabItem {
                    Label("Maçlar", systemImage: "soccerball")
                }
            
            FavoritesView()
                .tabItem {
                    Label("Favoriler", systemImage: "star.fill")
                }
            
            CopilotView()
                .tabItem {
                    Label("PusulAI", systemImage: "sparkles")
                }
            
            CouponView()
                .tabItem {
                    Label("Kuponum", systemImage: "ticket.fill")
                }
                .badge(couponStore.items.count > 0 ? "\(couponStore.items.count)" : nil)
            
            SettingsView()
                .tabItem {
                    Label("Daha", systemImage: "ellipsis")
                }
        }
        .tint(Color(red: 55/255.0, green: 77/255.0, blue: 245/255.0))
        .preferredColorScheme(darkMode ? .dark : .light)
    }
}
