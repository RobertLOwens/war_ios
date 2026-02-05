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

        // Set up push notification handling
        UNUserNotificationCenter.current().delegate = self
        requestNotificationPermissions()

        return true
    }

    // MARK: - Push Notification Setup

    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("📱 Notification permission error: \(error.localizedDescription)")
            } else if granted {
                print("📱 Notification permissions granted")
            } else {
                print("📱 Notification permissions denied")
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
        
        print("📱 App entered background - game saved")
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        print("📱 App returning to foreground")
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Save exit time
        BackgroundTimeManager.shared.saveExitTime()
        
        // Final save before termination
        saveCurrentGame()
        
        print("📱 App terminating - game saved")
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

    /// Handle notification tap when app is in foreground (won't show banner, but we handle it)
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Don't show push notifications when app is in foreground (we have in-game banners)
        completionHandler([])
    }

    /// Handle notification tap when user opens notification
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo

        // Extract coordinate from userInfo if available
        if let q = userInfo["q"] as? Int,
           let r = userInfo["r"] as? Int {
            // Post notification to jump to coordinate when game scene is ready
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .jumpToCoordinate,
                    object: nil,
                    userInfo: ["q": q, "r": r]
                )
            }
            print("📱 Notification tapped - will jump to coordinate (\(q), \(r))")
        }

        completionHandler()
    }
}

// MARK: - Notification Name Extension

extension Notification.Name {
    static let appWillSaveGame = Notification.Name("appWillSaveGame")
}
