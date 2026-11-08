import SwiftUI

public struct StatRowView: View {
    public let title: String
    public let homeValue: Double
    public let awayValue: Double
    public let isPercentage: Bool
    
    public init(title: String, homeValue: Double, awayValue: Double, isPercentage: Bool = false) {
        self.title = title
        self.homeValue = homeValue
        self.awayValue = awayValue
        self.isPercentage = isPercentage
    }
    
    private var total: Double {
        let t = homeValue + awayValue
        return t > 0 ? t : 1.0
    }
    
    private var homeFraction: CGFloat {
        CGFloat(homeValue / total)
    }
    
    public var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(formatVal(homeValue))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(homeValue >= awayValue ? .primary : .secondary)
                
                Spacer()
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(formatVal(awayValue))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(awayValue >= homeValue ? .primary : .secondary)
            }
            
            GeometryReader { geo in
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(homeValue >= awayValue ? Color(red: 55/255.0, green: 77/255.0, blue: 245/255.0) : Color.gray.opacity(0.35))
                        .frame(width: max(4, geo.size.width * homeFraction - 1.5))
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(awayValue > homeValue ? Color(red: 55/255.0, green: 77/255.0, blue: 245/255.0) : Color.gray.opacity(0.35))
                        .frame(width: max(4, geo.size.width * (1.0 - homeFraction) - 1.5))
                }
            }
            .frame(height: 5)
        }
        .padding(.vertical, 4)
    }
    
    private func formatVal(_ v: Double) -> String {
        if isPercentage {
            return "\(Int(v))%"
        }
        if v.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(v))"
        }
        return String(format: "%.1f", v)
    }
}
