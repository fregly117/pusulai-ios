import UIKit

/// Takım logolarını indirir: büyük hali ortak klasöre (Dinamik Ada eklentisi okur),
/// küçük beyaz zeminli JPEG hali etkinliğin içine gömülmek üzere döner.
enum LogoLoader {

    private static var thumbCache: [String: Data] = [:]
    private static let lock = NSLock()

    static func absolute(_ raw: String?) -> URL? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        return URL(string: raw, relativeTo: WebViewController.homeURL)?.absoluteURL
    }

    /// İndirir, ortak klasöre yazar, küçük logoyu döner (en fazla ~5 sn)
    static func fetch(_ raw: String?) async -> Data? {
        guard let raw = raw, let url = absolute(raw) else { return nil }
        lock.lock()
        let cached = thumbCache[raw]
        lock.unlock()
        if let cached = cached { return cached }

        var req = URLRequest(url: url)
        req.timeoutInterval = 5
        guard let result = try? await URLSession.shared.data(for: req) else { return nil }
        let (data, response) = result
        let status = (response as? HTTPURLResponse)?.statusCode ?? 200
        guard status < 400, let image = UIImage(data: data) else { return nil }

        // Ortak klasör: 120x120 şeffaf PNG
        if let file = LogoStore.fileURL(for: raw), let png = render(image, side: 120, opaque: false, inset: 0).pngData() {
            try? png.write(to: file, options: .atomic)
        }
        // Gömülü yedek: 32x32 beyaz zeminli JPEG (~1 KB)
        let thumb = render(image, side: 32, opaque: true, inset: 4).jpegData(compressionQuality: 0.6)
        if let thumb = thumb {
            lock.lock()
            thumbCache[raw] = thumb
            lock.unlock()
        }
        return thumb
    }

    private static func render(_ image: UIImage, side: CGFloat, opaque: Bool, inset: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = opaque
        let size = CGSize(width: side, height: side)
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            if opaque {
                UIColor.white.setFill()
                ctx.fill(CGRect(origin: .zero, size: size))
            }
            let box = CGRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)
            let w = max(image.size.width, 1), h = max(image.size.height, 1)
            let scale = min(box.width / w, box.height / h)
            let fit = CGSize(width: w * scale, height: h * scale)
            image.draw(in: CGRect(x: box.midX - fit.width / 2, y: box.midY - fit.height / 2,
                                  width: fit.width, height: fit.height))
        }
    }
}
