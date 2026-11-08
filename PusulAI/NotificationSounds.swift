import UserNotifications
import AVFoundation

/// Sitenin olay seslerini (gol, düdük...) uygulamanın kendi ses çalıcısıyla çalar.
/// Sayfa içinde çalınan ses iPhone'da "müzik çalıyor" gibi kilit ekranı oynatıcısı açıyordu; bu açmaz
/// ve müziğini kesmez.
enum SoundPlayer {
    private static var players: [AVAudioPlayer] = []
    private static let allowed: Set<String> = ["gol", "baslama", "bitis", "devre", "duduk", "sinyal"]

    static func play(_ name: String) {
        let n = name.lowercased()
        guard allowed.contains(n), let url = Bundle.main.url(forResource: n, withExtension: "caf") else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.volume = 0.9
        player.play()
        players.removeAll { !$0.isPlaying }
        players.append(player)
    }
}

/// Sitedeki seslerin (public/sounds) bildirimlerde kullanılan kopyaları: PusulAI/Sounds/*.caf
/// Ses, bildirim etiketinden seçilir (site ve sunucu aynı etiketleri kullanır):
///   pusulai-<maç>-goal-1-0 → gol, -start → başlama, -ht → devre, -2h / -red / -var → düdük,
///   -ft → bitiş, pusulai-goalalert-<maç> → sinyal
enum NotificationSounds {

    static func fileName(forTag tag: String) -> String? {
        let t = tag.lowercased()
        if t.contains("goalalert") { return "sinyal.caf" }
        if t.contains("-goal-") || t.hasPrefix("goal-") || t.hasSuffix("-goal") { return "gol.caf" }
        if t.contains("-var-") || t.contains("-red-") || t.hasSuffix("-2h") { return "duduk.caf" }
        if t.hasSuffix("-start") { return "baslama.caf" }
        if t.hasSuffix("-ht") { return "devre.caf" }
        if t.hasSuffix("-ft") { return "bitis.caf" }
        return nil
    }

    static func sound(forTag tag: String) -> UNNotificationSound {
        guard let name = fileName(forTag: tag) else { return .default }
        return UNNotificationSound(named: UNNotificationSoundName(rawValue: name))
    }
}
