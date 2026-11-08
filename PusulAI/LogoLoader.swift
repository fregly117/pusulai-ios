import UIKit
import ImageIO

/// Takım logolarını indirir: büyük hali ortak klasöre (Dinamik Ada eklentisi okur),
/// küçük beyaz zeminli JPEG hali Dinamik Ada etkinliğinin içine gömülür (4 KB sınırına sığacak boyutta).
enum LogoLoader {

    private static var imageCache: [String: UIImage] = [:]
    private static let lock = NSLock()

    static func absolute(_ raw: String?) -> URL? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        return URL(string: raw, relativeTo: WebViewController.homeURL)?.absoluteURL
    }

    /// İndirir, ortak klasöre yazar, logoyu döner (en fazla ~6 sn)
    static func fetch(_ raw: String?) async -> UIImage? {
        guard let raw = raw, let url = absolute(raw) else { return nil }
        lock.lock()
        let cached = imageCache[raw]
        lock.unlock()
        if let cached = cached { return cached }

        var req = URLRequest(url: url)
        req.timeoutInterval = 6
        guard let result = try? await URLSession.shared.data(for: req) else { return nil }
        let (data, response) = result
        let status = (response as? HTTPURLResponse)?.statusCode ?? 200
        guard status < 400, let image = UIImage(data: data) else { return nil }

        // Ortak klasör: 120x120 şeffaf PNG (Dinamik Ada eklentisi tam kalitede okur)
        if let file = LogoStore.fileURL(for: raw), let png = render(image, side: 120).pngData() {
            try? png.write(to: file, options: .atomic)
        }
        lock.lock()
        imageCache[raw] = image
        lock.unlock()
        return image
    }

    /// Beyaz zeminli küçük JPEG; renk profili gömülmez (her bayt önemli)
    static func thumb(_ image: UIImage, side: Int, quality: CGFloat) -> Data? {
        guard let cg = render(image, side: CGFloat(side * 2)).cgImage else { return nil }
        let space = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
        ctx.interpolationQuality = .high
        let inset = CGFloat(side) * 0.14
        let box = CGFloat(side) - inset * 2
        ctx.draw(cg, in: CGRect(x: inset, y: inset, width: box, height: box))
        guard let out = ctx.makeImage() else { return nil }

        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, out, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }

    /// Kare, şeffaf, logoyu ortalayıp sığdırır
    private static func render(_ image: UIImage, side: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        format.preferredRange = .standard
        let size = CGSize(width: side, height: side)
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            let w = max(image.size.width, 1), h = max(image.size.height, 1)
            let scale = min(side / w, side / h)
            let fit = CGSize(width: w * scale, height: h * scale)
            image.draw(in: CGRect(x: (side - fit.width) / 2, y: (side - fit.height) / 2,
                                  width: fit.width, height: fit.height))
        }
    }
}
