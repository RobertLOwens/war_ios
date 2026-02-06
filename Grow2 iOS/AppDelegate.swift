// ============================================================================
// FILE: AppDelegate.swift
// LOCATION: Replace the entire file or update the methods
// ============================================================================

import UIKit
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        window = UIWindow(frame: UIScreen.main.bounds)

        // Start with Main Menu instead of going straight to game
        let mainMenuVC = MainMenuViewController()
        window?.rootViewController = mainMenuVC
        window?.makeKeyAndVisible()

        // Request push notification permissions
        requestNotificationPermissions()

        return true
    }

    // MARK: - Push Notification Setup

    private func requestNotificationPermissions() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                debugLog("📱 Push notification permissions granted")
            } else if let error = error {
                debugLog("📱 Push notification permission error: \(error.localizedDescription)")
            } else {
                debugLog("📱 Push notification permissions denied")
            }
        }
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state.
        // Save game when user switches away
        saveCurrentGame()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Save exit time for background calculations
        BackgroundTimeManager.shared.saveExitTime()
        
        // Also save the game
        saveCurrentGame()
        
        debugLog("📱 App entered background - game saved")
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        debugLog("📱 App returning to foreground")
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Save exit time
        BackgroundTimeManager.shared.saveExitTime()
        
        // Final save before termination
        saveCurrentGame()
        
        debugLog("📱 App terminating - game saved")
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused
    }
    
    // MARK: - Helper to save game from AppDelegate
    
    private func saveCurrentGame() {
        // Post notification that GameViewController can listen to
        NotificationCenter.default.post(name: .appWillSaveGame, object: nil)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {

    /// Handle notification when app is in foreground - suppress it since in-game banners handle this
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Don't show push notification when app is in foreground - in-game banners handle this
        completionHandler([])
    }

    /// Handle notification tap - jump to the coordinate if available
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // Extract coordinate from userInfo
        if let q = userInfo["coordinateQ"] as? Int,
           let r = userInfo["coordinateR"] as? Int {
            let coordinate = HexCoordinate(q: q, r: r)
            debugLog("📱 Notification tapped - jumping to coordinate: \(coordinate)")

            // Post notification for GameViewController to handle
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .jumpToCoordinate,
                    object: nil,
                    userInfo: ["coordinate": coordinate]
                )
            }
        }

        completionHandler()
    }
}

// MARK: - Notification Name Extension

extension Notification.Name {
    static let appWillSaveGame = Notification.Name("appWillSaveGame")
}
