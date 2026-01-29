// ============================================================================
// FILE: AppDelegate.swift
// LOCATION: Replace the entire file or update the methods
// ============================================================================

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        window = UIWindow(frame: UIScreen.main.bounds)
        
        // Start with Main Menu instead of going straight to game
        let mainMenuVC = MainMenuViewController()
        window?.rootViewController = mainMenuVC
        window?.makeKeyAndVisible()
        
        return true
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

// MARK: - Notification Name Extension

extension Notification.Name {
    static let appWillSaveGame = Notification.Name("appWillSaveGame")
}
