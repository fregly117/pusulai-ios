import Foundation
import AVFoundation

public final class SoundManager {
    public static let shared = SoundManager()
    
    private var isMuted: Bool = false
    
    private init() {
        configureAudioSession()
    }
    
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("SoundManager: AudioSession setup error \(error)")
        }
    }
    
    public func setMuted(_ muted: Bool) {
        self.isMuted = muted
    }
    
    public func playGoalSound() {
        guard !isMuted else { return }
        // iOS sistem kutlama & bildirim sesi çal
        AudioServicesPlaySystemSound(1005) // SMS Received / alert sound
        HapticManager.shared.heavy()
    }
    
    public func playWhistleSound() {
        guard !isMuted else { return }
        AudioServicesPlaySystemSound(1057) // Tink / Alert
        HapticManager.shared.medium()
    }
}
