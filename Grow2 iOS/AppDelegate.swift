//
//  AppDelegate.swift
//  Grow2 iOS
//
//  Created by Robert Owens on 11/14/25.
//

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
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Save exit time for background calculations
        BackgroundTimeManager.shared.saveExitTime()
        
        print("📱 App entered background")
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        print("📱 App returning to foreground")
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Save exit time
        BackgroundTimeManager.shared.saveExitTime()
        
        print("📱 App terminating")
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

}

