import UserNotifications

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
