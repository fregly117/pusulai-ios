import UIKit
import WebKit
import SafariServices
import UserNotifications

final class WebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {

    static let homeURL = URL(string: "https://pusulai.up.railway.app/")!
    static let appHost = "pusulai.up.railway.app"

    private var webView: WKWebView!
    private let topBar = UIView()
    private let offlineView = OfflineView()
    private let splashView = UIView()
    private let refresh = UIRefreshControl()

    private var started = false
    private var pendingURL: URL?
    private var lastFailedURL: URL?
    private var splashRemoved = false
    private var lastThemeKey: String?
    private var notificationPermission = "default"

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    // MARK: - Kurulum

    override func viewDidLoad() {
        super.viewDidLoad()
        let brand = UIColor(hex: "#374DF5")
        view.backgroundColor = brand
        topBar.backgroundColor = brand

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []   // gol / düdük sesleri dokunmadan çalar
        config.websiteDataStore = .default()                    // giriş, favoriler, tema kalıcı
        config.applicationNameForUserAgent = "Version/18.0 Mobile/15E148 Safari/604.1 PusulAI-iOS/1.0"
        config.userContentController.add(WeakScriptHandler(self), name: "pusulai")

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = false
        webView.isOpaque = false
        webView.backgroundColor = UIColor(hex: "#EDF1F6")
        webView.scrollView.backgroundColor = UIColor(hex: "#EDF1F6")
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        refresh.addTarget(self, action: #selector(pulledToRefresh), for: .valueChanged)
        webView.scrollView.refreshControl = refresh

        webView.translatesAutoresizingMaskIntoConstraints = false
        topBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        view.addSubview(topBar)
        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),

            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        setupOfflineView()
        setupSplash()

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationPermission = WebViewController.permissionString(settings.authorizationStatus)
                self.installUserScripts()
                self.started = true
                self.webView.load(URLRequest(url: self.pendingURL ?? WebViewController.homeURL))
                self.pendingURL = nil
            }
        }
    }

    private func installUserScripts() {
        let ucc = webView.configuration.userContentController
        ucc.removeAllUserScripts()
        let src = BridgeScript.source.replacingOccurrences(of: "__PERMISSION__", with: notificationPermission)
        ucc.addUserScript(WKUserScript(source: src, injectionTime: .atDocumentStart, forMainFrameOnly: true))
    }

    private func setupOfflineView() {
        offlineView.translatesAutoresizingMaskIntoConstraints = false
        offlineView.isHidden = true
        offlineView.onRetry = { [weak self] in self?.retry() }
        view.addSubview(offlineView)
        NSLayoutConstraint.activate([
            offlineView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            offlineView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            offlineView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            offlineView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func setupSplash() {
        splashView.backgroundColor = .black
        splashView.translatesAutoresizingMaskIntoConstraints = false
        let logo = UIImageView(image: UIImage(named: "LaunchLogo"))
        logo.translatesAutoresizingMaskIntoConstraints = false
        splashView.addSubview(logo)
        view.addSubview(splashView)
        NSLayoutConstraint.activate([
            splashView.topAnchor.constraint(equalTo: view.topAnchor),
            splashView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            splashView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            splashView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            logo.centerXAnchor.constraint(equalTo: splashView.centerXAnchor),
            logo.centerYAnchor.constraint(equalTo: splashView.centerYAnchor),
        ])
        DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in self?.removeSplash() }
    }

    private func removeSplash() {
        guard !splashRemoved else { return }
        splashRemoved = true
        UIView.animate(withDuration: 0.25, animations: { self.splashView.alpha = 0 }) { _ in
            self.splashView.removeFromSuperview()
        }
    }

    // MARK: - Dışarıdan çağrılanlar (AppDelegate)

    func openPath(_ raw: String) {
        guard let url = URL(string: raw, relativeTo: WebViewController.homeURL)?.absoluteURL else { return }
        if started {
            webView.load(URLRequest(url: url))
        } else {
            pendingURL = url
        }
    }

    func syncLiveActivities() {
        runJS("window.__pusulaiNative&&window.__pusulaiNative.syncLive()")
    }

    func setKeepAlive(_ on: Bool) {
        runJS("window.__pusulaiNative&&window.__pusulaiNative.keepAlive(\(on ? "true" : "false"))")
    }

    func refreshNotificationPermission() {
        guard started else { return }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                let p = WebViewController.permissionString(settings.authorizationStatus)
                guard p != self.notificationPermission else { return }
                self.notificationPermission = p
                self.installUserScripts()
                self.runJS("window.__pusulaiNative&&window.__pusulaiNative.setPermission('\(p)')")
            }
        }
    }

    // MARK: - Yardımcılar

    private func runJS(_ js: String) {
        guard started else { return }
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    static func permissionString(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized, .provisional, .ephemeral: return "granted"
        case .denied: return "denied"
        case .notDetermined: return "default"
        @unknown default: return "default"
        }
    }

    static func isAppURL(_ url: URL) -> Bool {
        return (url.host ?? "").lowercased() == appHost
    }

    @objc private func pulledToRefresh() {
        if webView.url == nil {
            webView.load(URLRequest(url: WebViewController.homeURL))
        } else {
            webView.reload()
        }
    }

    private func retry() {
        offlineView.isHidden = true
        webView.load(URLRequest(url: lastFailedURL ?? webView.url ?? WebViewController.homeURL))
    }

    private func applyTheme(color: String, dark: Bool) {
        let fallback = dark ? "#0E0E11" : "#374DF5"
        let hex = color.isEmpty ? fallback : color
        let key = hex + (dark ? "d" : "l")
        guard key != lastThemeKey else { return }
        lastThemeKey = key
        let bar = UIColor(hex: hex)
        let page = UIColor(hex: dark ? "#0E0E11" : "#EDF1F6")
        UIView.animate(withDuration: 0.2) {
            self.topBar.backgroundColor = bar
            self.view.backgroundColor = bar
        }
        webView.backgroundColor = page
        webView.scrollView.backgroundColor = page
    }

    private func openExternal(_ url: URL) {
        let scheme = (url.scheme ?? "").lowercased()
        guard scheme == "http" || scheme == "https" else {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            return
        }
        let safari = SFSafariViewController(url: url)
        safari.preferredControlTintColor = UIColor(hex: "#374DF5")
        topMostController().present(safari, animated: true)
    }

    private func topMostController() -> UIViewController {
        var top: UIViewController = self
        while let presented = top.presentedViewController { top = presented }
        return top
    }

    private func presentAlert(_ alert: UIAlertController, fallback: @escaping () -> Void) {
        guard view.window != nil else { fallback(); return }
        topMostController().present(alert, animated: true)
    }

    // MARK: - WKScriptMessageHandler (site → uygulama)

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }

        switch type {
        case "theme":
            applyTheme(color: body["color"] as? String ?? "", dark: body["dark"] as? Bool ?? false)

        case "notify":
            let content = UNMutableNotificationContent()
            content.title = body["title"] as? String ?? "PusulAI"
            content.body = body["body"] as? String ?? ""
            let tag = body["tag"] as? String ?? ""
            content.sound = NotificationSounds.sound(forTag: tag)   // sitedeki gol / düdük / bitiş sesleri
            content.threadIdentifier = "pusulai"
            content.userInfo = ["url": body["url"] as? String ?? "/"]
            let request = UNNotificationRequest(identifier: tag.isEmpty ? UUID().uuidString : tag,
                                                content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)

        case "closeNotification":
            if let tag = body["tag"] as? String, !tag.isEmpty {
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [tag])
            }

        case "requestPermission":
            let id = (body["id"] as? NSNumber)?.intValue ?? 0
            let center = UNUserNotificationCenter.current()
            center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
                center.getNotificationSettings { settings in
                    DispatchQueue.main.async {
                        let p = WebViewController.permissionString(settings.authorizationStatus)
                        self.notificationPermission = p
                        self.installUserScripts()
                        self.runJS("window.__pusulaiNative&&window.__pusulaiNative.resolvePermission(\(id),'\(p)')")
                    }
                }
            }

        case "live":
            let list = (body["matches"] as? [[String: Any]] ?? []).compactMap { LiveMatch(dict: $0) }
            let island = body["island"] as? String ?? ""
            LiveActivityManager.shared.islandKey = island
            PushRegistrar.shared.setIsland(island)
            LiveActivityManager.shared.sync(list)
            NativeTracker.shared.update(list)

        case "sound":
            if let name = body["name"] as? String { SoundPlayer.play(name) }

        case "favorites":
            let keys = (body["keys"] as? [Any] ?? []).compactMap { $0 as? String }
            PushRegistrar.shared.setFavorites(keys)

        case "haptic":
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        default:
            break
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        let scheme = (url.scheme ?? "").lowercased()

        if ["about", "blob", "data", "javascript"].contains(scheme) {
            decisionHandler(.allow); return
        }
        if scheme != "http" && scheme != "https" {
            // tel:, mailto:, whatsapp: vb.
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            decisionHandler(.cancel); return
        }
        let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true
        if !isMainFrame || WebViewController.isAppURL(url) {
            decisionHandler(.allow); return
        }
        // Site dışı bağlantılar uygulama içi Safari penceresinde açılır
        openExternal(url)
        decisionHandler(.cancel)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        offlineView.isHidden = true
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        refresh.endRefreshing()
        offlineView.isHidden = true
        lastFailedURL = nil
        removeSplash()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        refresh.endRefreshing()
        removeSplash()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        refresh.endRefreshing()
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled { return }
        if ns.domain == "WebKitErrorDomain" && (ns.code == 102 || ns.code == 204) { return }
        if let failing = ns.userInfo[NSURLErrorFailingURLErrorKey] as? URL { lastFailedURL = failing }
        offlineView.isHidden = false
        removeSplash()
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        if webView.url == nil {
            webView.load(URLRequest(url: WebViewController.homeURL))
        } else {
            webView.reload()
        }
    }

    // MARK: - WKUIDelegate

    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            if WebViewController.isAppURL(url) {
                webView.load(URLRequest(url: url))
            } else {
                openExternal(url)
            }
        }
        return nil
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Tamam", style: .default) { _ in completionHandler() })
        presentAlert(alert) { completionHandler() }
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Vazgeç", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "Tamam", style: .default) { _ in completionHandler(true) })
        presentAlert(alert) { completionHandler(false) }
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        alert.addTextField { $0.text = defaultText }
        alert.addAction(UIAlertAction(title: "Vazgeç", style: .cancel) { _ in completionHandler(nil) })
        alert.addAction(UIAlertAction(title: "Tamam", style: .default) { _ in
            completionHandler(alert.textFields?.first?.text)
        })
        presentAlert(alert) { completionHandler(nil) }
    }
}

// MARK: - Yardımcı tipler

/// WKUserContentController hedefi güçlü tuttuğu için döngüyü kırar
@MainActor
final class WeakScriptHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}

/// İnternet yokken gösterilen ekran
final class OfflineView: UIView {
    var onRetry: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: "#0E0E11") : UIColor(hex: "#EDF1F6") }

        let icon = UIImageView(image: UIImage(systemName: "wifi.slash"))
        icon.tintColor = UIColor(hex: "#7A8394")
        icon.contentMode = .scaleAspectFit
        icon.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let title = UILabel()
        title.text = "Bağlantı yok"
        title.font = .systemFont(ofSize: 19, weight: .bold)
        title.textColor = .label

        let subtitle = UILabel()
        subtitle.text = "PusulAI'ye ulaşılamadı. İnternetini kontrol edip tekrar dene."
        subtitle.font = .systemFont(ofSize: 14)
        subtitle.textColor = .secondaryLabel
        subtitle.numberOfLines = 0
        subtitle.textAlignment = .center

        var cfg = UIButton.Configuration.filled()
        cfg.title = "Tekrar dene"
        cfg.baseBackgroundColor = UIColor(hex: "#374DF5")
        cfg.cornerStyle = .large
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 22, bottom: 10, trailing: 22)
        let button = UIButton(configuration: cfg, primaryAction: UIAction { [weak self] _ in self?.onRetry?() })

        let stack = UIStackView(arrangedSubviews: [icon, title, subtitle, button])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.setCustomSpacing(20, after: subtitle)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -30),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) kullanılmıyor") }
}

extension UIColor {
    /// "#374DF5" / "374DF5" / "#FFF"
    convenience init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else {
            self.init(white: 0, alpha: 1)
            return
        }
        self.init(red: CGFloat((v >> 16) & 0xFF) / 255,
                  green: CGFloat((v >> 8) & 0xFF) / 255,
                  blue: CGFloat(v & 0xFF) / 255,
                  alpha: 1)
    }
}
