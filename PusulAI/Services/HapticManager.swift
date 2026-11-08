import UIKit

public final class HapticManager {
    public static let shared = HapticManager()
    
    private init() {}
    
    public func light() {
        DispatchQueue.main.async {
            let gen = UIImpactFeedbackGenerator(style: .light)
            gen.prepare()
            gen.impactOccurred()
        }
    }
    
    public func medium() {
        DispatchQueue.main.async {
            let gen = UIImpactFeedbackGenerator(style: .medium)
            gen.prepare()
            gen.impactOccurred()
        }
    }
    
    public func heavy() {
        DispatchQueue.main.async {
            let gen = UIImpactFeedbackGenerator(style: .heavy)
            gen.prepare()
            gen.impactOccurred()
        }
    }
    
    public func selection() {
        DispatchQueue.main.async {
            let gen = UISelectionFeedbackGenerator()
            gen.prepare()
            gen.selectionChanged()
        }
    }
    
    public func success() {
        DispatchQueue.main.async {
            let gen = UINotificationFeedbackGenerator()
            gen.prepare()
            gen.notificationOccurred(.success)
        }
    }
    
    public func error() {
        DispatchQueue.main.async {
            let gen = UINotificationFeedbackGenerator()
            gen.prepare()
            gen.notificationOccurred(.error)
        }
    }
}
