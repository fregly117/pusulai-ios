import SwiftUI

public struct TeamLogoView: View {
    public let urlString: String?
    public let teamName: String
    public let size: CGFloat
    
    public init(urlString: String?, teamName: String, size: CGFloat = 22) {
        self.urlString = urlString
        self.teamName = teamName
        self.size = size
    }
    
    public var body: some View {
        if let s = urlString, let url = URL(string: s) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: size, height: size)
                default:
                    placeholderView
                }
            }
        } else {
            placeholderView
        }
    }
    
    private var placeholderView: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [Color.blue.opacity(0.7), Color.indigo.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: size, height: size)
            
            Text(initials)
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    private var initials: String {
        let words = teamName.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        }
        return String(teamName.prefix(2)).uppercased()
    }
}
