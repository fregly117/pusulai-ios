import UIKit
import UserNotifications

@main
final class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?
    let webVC = WebViewController()

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        BackgroundKeeper.shared.configureSession()

        // Apple bildirim sunucusuna kayıt (uygulama kapalıyken gelen bildirimler + Dinamik Ada güncellemeleri)
        application.registerForRemoteNotifications()
        LiveActivityManager.shared.startObserving()

        let w = UIWindow(frame: UIScreen.main.bounds)
        w.backgroundColor = .black
        w.rootViewController = webVC
        w.makeKeyAndVisible()
        window = w
        return true
    }

    // MARK: - Yaşam döngüsü

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Sunucu bildirimleri açıksa (APNs) bildirimler ve Dinamik Ada uygulama kapalıyken de sunucudan gelir:
        // pil harcamamak için uygulamayı arka planda uyanık tutmaya gerek yok.
        if PushRegistrar.shared.remoteActive { return }

        // Aksi halde: arka plana geçerken sayfanın JS'i (canlı skor, gol sesi, bildirim, Dinamik Ada) çalışmaya devam etsin
        endBackgroundTask()
        bgTask = application.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        BackgroundKeeper.shared.start { [weak self] in
            self?.webVC.setKeepAlive(false)
        }
        webVC.setKeepAlive(true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.endBackgroundTask()
        }
    }

    private var bgTask: UIBackgroundTaskIdentifier = .invalid

    private func endBackgroundTask() {
        guard bgTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(bgTask)
        bgTask = .invalid
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        BackgroundKeeper.shared.stop()
        webVC.setKeepAlive(false)
        webVC.refreshNotificationPermission()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Arka planda başlatılamayan Dinamik Ada etkinlikleri şimdi başlasın
        webVC.syncLiveActivities()
    }

    // MARK: - Uzak bildirim (APNs) kaydı

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushRegistrar.shared.setDeviceToken(deviceToken.hexString)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Ücretsiz Apple ID ile imzalandıysa bildirim izni yoktur: uygulama arka planda uyanık kalarak çalışır
        PushRegistrar.shared.markRemoteUnavailable()
    }

    // MARK: - Bildirimler

    // Uygulama açıkken: sayfa kendi sesini çaldığı için sessiz banner göster
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list])
    }

    // Bildirime dokunulunca ilgili sayfayı aç
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if let url = response.notification.request.content.userInfo["url"] as? String, !url.isEmpty {
            webVC.openPath(url)
        }
        completionHandler()
    }
}
