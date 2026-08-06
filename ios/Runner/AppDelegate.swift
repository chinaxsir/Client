import Flutter
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // 允许在后台长时间运行 —— TrollStore 扩展
        // 请求后台任务标识符，防止系统挂起 App
        application.beginBackgroundTask(withName: "xsop_forum_keepalive") {
            // 后台任务即将过期
        }

        // 注册远程通知（如需要推送）
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
        }

        // 设置通知代理
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self
        }

        let controller = FlutterViewController()
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = controller
        self.window = window
        window.makeKeyAndVisible()

        return true
    }

    // TrollStore 扩展：保持后台连接
    func applicationDidEnterBackground(_ application: UIApplication) {
        // 保持 Dart Isolate 运行（Flutter 默认在后台暂停渲染）
        // 可通过 MethodChannel 通知 Dart 侧继续执行
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.alert, .badge, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
}
