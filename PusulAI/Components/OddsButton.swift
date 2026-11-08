import SwiftUI

public struct OddsButton: View {
    public let title: String
    public let odds: Double?
    public let isSelected: Bool
    public let action: () -> Void
    
    public init(title: String, odds: Double?, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.odds = odds
        self.isSelected = isSelected
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isSelected ? .white.opacity(0.85) : .secondary)
                
                if let o = odds, o > 1.0 {
                    Text(String(format: "%.2f", o))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(isSelected ? .white : .primary)
                } else {
                    Text("-")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color(red: 55/255.0, green: 77/255.0, blue: 245/255.0) : Color(UIColor.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.clear : Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(OddsButtonStyle())
        .disabled(odds == nil || (odds ?? 0) <= 1.0)
    }
}

private struct OddsButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}
