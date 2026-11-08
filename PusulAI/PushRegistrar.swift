import UIKit

/// iPhone'un Apple bildirim anahtarını (APNs), favori maçları ve Dinamik Ada anahtarlarını
/// PusulAI sunucusuna kaydeder. Sunucu (server-push-daemon.js) uygulama tamamen kapalıyken
/// bile bu anahtarlarla gol bildirimi gönderir ve Dinamik Ada'yı günceller.
final class PushRegistrar {

    static let shared = PushRegistrar()
    static let endpoint = URL(string: "https://pusulai.up.railway.app/api/push/ios-register")!

    private let defaults = UserDefaults.standard
    private var deviceToken: String?
    private var favoriteKeys: [String]
    private var liveTokens: [String: String]
    private var startToken: String?
    private var pending: DispatchWorkItem?
    private var bgTask: UIBackgroundTaskIdentifier = .invalid

    /// Sunucu tarafında APNs açık ve bu cihaz kayıtlı → kapalıyken bildirimler sunucudan gelir
    private(set) var remoteActive: Bool

    private init() {
        deviceToken = defaults.string(forKey: "apns.deviceToken")
        favoriteKeys = defaults.stringArray(forKey: "apns.favoriteKeys") ?? []
        liveTokens = (defaults.dictionary(forKey: "apns.liveTokens") as? [String: String]) ?? [:]
        startToken = defaults.string(forKey: "apns.startToken")
        remoteActive = defaults.bool(forKey: "apns.remoteActive")
    }

    func setDeviceToken(_ token: String) {
        onMain {
            guard token != self.deviceToken else { self.schedule(); return }
            self.deviceToken = token
            self.defaults.set(token, forKey: "apns.deviceToken")
            self.schedule()
        }
    }

    func setFavorites(_ keys: [String]) {
        onMain {
            guard keys != self.favoriteKeys else { return }
            self.favoriteKeys = keys
            self.defaults.set(keys, forKey: "apns.favoriteKeys")
            self.schedule()
        }
    }

    func setLiveToken(_ token: String, for key: String) {
        onMain {
            guard self.liveTokens[key] != token else { return }
            self.liveTokens[key] = token
            self.defaults.set(self.liveTokens, forKey: "apns.liveTokens")
            self.schedule()
        }
    }

    func removeLiveToken(for key: String) {
        onMain {
            guard self.liveTokens[key] != nil else { return }
            self.liveTokens[key] = nil
            self.defaults.set(self.liveTokens, forKey: "apns.liveTokens")
            self.schedule()
        }
    }

    func setStartToken(_ token: String) {
        onMain {
            guard token != self.startToken else { return }
            self.startToken = token
            self.defaults.set(token, forKey: "apns.startToken")
            self.schedule()
        }
    }

    func markRemoteUnavailable() {
        onMain {
            self.remoteActive = false
            self.defaults.set(false, forKey: "apns.remoteActive")
        }
    }

    // MARK: - Gönderim

    private func onMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread { block() } else { DispatchQueue.main.async(execute: block) }
    }

    private func schedule() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.send() }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
    }

    private func send() {
        guard let token = deviceToken else { return }
        let body: [String: Any] = [
            "deviceToken": token,
            "topic": Bundle.main.bundleIdentifier ?? "com.klennys.pusulai",
            "favoriteKeys": favoriteKeys,
            "liveTokens": liveTokens,
            "startToken": startToken ?? "",
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        var req = URLRequest(url: PushRegistrar.endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = data
        req.timeoutInterval = 20

        endBackgroundTask()
        bgTask = UIApplication.shared.beginBackgroundTask { [weak self] in self?.endBackgroundTask() }

        URLSession.shared.dataTask(with: req) { [weak self] respData, response, _ in
            let ok = (response as? HTTPURLResponse)?.statusCode == 200
            var apnsReady = false
            if ok, let respData = respData,
               let json = try? JSONSerialization.jsonObject(with: respData) as? [String: Any] {
                apnsReady = json["apns"] as? Bool ?? false
            }
            DispatchQueue.main.async {
                guard let self = self else { return }
                if ok {
                    self.remoteActive = apnsReady
                    self.defaults.set(apnsReady, forKey: "apns.remoteActive")
                }
                self.endBackgroundTask()
            }
        }.resume()
    }

    private func endBackgroundTask() {
        guard bgTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(bgTask)
        bgTask = .invalid
    }
}

extension Data {
    var hexString: String { map { String(format: "%02x", $0) }.joined() }
}
