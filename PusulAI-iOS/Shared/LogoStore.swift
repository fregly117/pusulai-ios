import UIKit
import CryptoKit

/// Takım logolarının uygulama ile Dinamik Ada eklentisi arasında paylaşıldığı ortak klasör (App Group).
/// Dinamik Ada kartı internetten resim indiremez (iOS kuralı); uygulama logoyu önceden indirip buraya koyar,
/// kart da buradan okur. SofaScore da aynı yöntemi kullanır.
enum LogoStore {
    static let groupID = "group.com.klennys.pusulai"

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
