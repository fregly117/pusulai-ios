import UIKit
import CryptoKit

/// Takım logolarının uygulama ile Dinamik Ada eklentisi arasında paylaşıldığı ortak klasör (App Group).
/// Dinamik Ada kartı internetten resim indiremez (iOS kuralı); uygulama logoyu önceden indirip buraya koyar,
/// kart da buradan okur. SofaScore da aynı yöntemi kullanır.
enum LogoStore {
    /// Ortak klasör adı. Sideloadly vb. imzalarken adı değiştirebilir (ör. sonuna takım kimliği ekler);
    /// bu yüzden önce uygulamanın kendi imza dosyasındaki (embedded.mobileprovision) gerçek ad okunur.
    static let groupID: String = provisionedGroup() ?? "group.com.klennys.pusulai"

    private static func provisionedGroup() -> String? {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let raw = try? Data(contentsOf: url),
              let text = String(data: raw, encoding: .isoLatin1),
              let start = text.range(of: "<?xml"),
              let end = text.range(of: "</plist>"),
              let xml = String(text[start.lowerBound..<end.upperBound]).data(using: .isoLatin1),
              let plist = (try? PropertyListSerialization.propertyList(from: xml, format: nil)) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any],
              let groups = entitlements["com.apple.security.application-groups"] as? [String],
              !groups.isEmpty else { return nil }
        return groups.first(where: { $0.lowercased().contains("pusulai") }) ?? groups.first
    }

    static var directory: URL? {
        guard let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) else { return nil }
        let dir = base.appendingPathComponent("Logos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func fileURL(for remote: String?) -> URL? {
        guard let remote = remote, !remote.isEmpty, let dir = directory else { return nil }
        let digest = SHA256.hash(data: Data(remote.utf8)).map { String(format: "%02x", $0) }.joined()
        return dir.appendingPathComponent(String(digest.prefix(32)) + ".png")
    }

    /// Ortak klasördeki logo, yoksa etkinliğe gömülü küçük logo
    static func image(url: String?, thumb: Data?) -> UIImage? {
        if let file = fileURL(for: url), let img = UIImage(contentsOfFile: file.path) { return img }
        if let thumb = thumb, let img = UIImage(data: thumb) { return img }
        return nil
    }
}
