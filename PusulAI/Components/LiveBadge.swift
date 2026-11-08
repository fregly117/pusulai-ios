import SwiftUI

public struct LiveBadge: View {
    public let text: String
    
    @State private var isPulsing = false
    
    public init(text: String) {
        self.text = text
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.red)
                .frame(width: 6, height: 6)
                .opacity(isPulsing ? 0.3 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
            
            Text(text)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.red)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.red.opacity(0.12))
        .cornerRadius(6)
        .onAppear {
            isPulsing = true
        }
    }
}
