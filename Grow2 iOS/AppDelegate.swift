// ============================================================================
// FILE: AppDelegate.swift
// LOCATION: Grow2 iOS/AppDelegate.swift
// PURPOSE: App entry point with Firebase auth, Google Sign-In, and auth-gated navigation
// ============================================================================

import UIKit
import UserNotifications
import FirebaseCore
import GoogleSignIn

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Configure Firebase
        FirebaseApp.configure()

        // Configure Google Sign-In (requires CLIENT_ID in GoogleService-Info.plist)
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        } else {
            debugLog("Warning: No CLIENT_ID found — Google Sign-In disabled. Enable Google provider in Firebase Console and re-download GoogleService-Info.plist.")
        }

        window = UIWindow(frame: UIScreen.main.bounds)

        // Auth-gated root VC: if signed in → check username → MainMenu, else → Auth
        if AuthService.shared.checkExistingSession() {
            // Show loading screen while we check username status
            let loadingVC = UIViewController()
            loadingVC.view.backgroundColor = UIColor(red: 0.1, green: 0.12, blue: 0.1, alpha: 1.0)
            let spinner = UIActivityIndicatorView(style: .large)
            spinner.color = .white
            spinner.startAnimating()
            spinner.center = loadingVC.view.center
            spinner.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin]
            loadingVC.view.addSubview(spinner)
            window?.rootViewController = loadingVC
            routeAuthenticatedUser()
        } else {
            window?.rootViewController = AuthViewController()
        }
        window?.makeKeyAndVisible()

        // Listen for auth state changes to swap root VC
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAuthStateChanged),
            name: AuthService.authStateChangedNotification,
            object: nil
        )

        // Request push notification permissions
        requestNotificationPermissions()

        return true
    }

    // MARK: - Google Sign-In URL Handler

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        if GIDSignIn.sharedInstance.configuration != nil {
            return GIDSignIn.sharedInstance.handle(url)
        }
        return false
    }

    // MARK: - Auth State Handler

    @objc private func handleAuthStateChanged() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if AuthService.shared.currentUser != nil {
                // Signed in → check username, then route
                if self.window?.rootViewController is AuthViewController {
                    self.routeAuthenticatedUser()
                }
            } else {
                // Signed out → show auth screen
                if !(self.window?.rootViewController is AuthViewController) {
                    let authVC = AuthViewController()
                    self.window?.rootViewController = authVC
                    UIView.transition(with: self.window!, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
                }
            }
        }
    }

    /// Route authenticated user: check if they have a username, show DisplayNameVC if not.
    private func routeAuthenticatedUser() {
        AuthService.shared.checkHasUsername { [weak self] hasUsername in
            DispatchQueue.main.async {
                guard let self = self, let window = self.window else { return }

                if hasUsername {
                    let mainMenu = MainMenuViewController()
                    window.rootViewController = mainMenu
                    UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
                } else {
                    let displayNameVC = DisplayNameViewController()
                    displayNameVC.isChangingName = false
                    displayNameVC.onUsernameChosen = { [weak self] _ in
                        guard let self = self, let window = self.window else { return }
                        let mainMenu = MainMenuViewController()
                        window.rootViewController = mainMenu
                        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
                    }
                    window.rootViewController = displayNameVC
                    UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
                }
            }
        }
    }

    // MARK: - Push Notification Setup

    private func requestNotificationPermissions() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                debugLog("Push notification permissions granted")
            } else if let error = error {
                debugLog("Push notification permission error: \(error.localizedDescription)")
            } else {
                debugLog("Push notification permissions denied")
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

        debugLog("App entered background - game saved")
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        debugLog("App returning to foreground")
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Save exit time
        BackgroundTimeManager.shared.saveExitTime()

        // Final save before termination
        saveCurrentGame()

        debugLog("App terminating - game saved")
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
            debugLog("Notification tapped - jumping to coordinate: \(coordinate)")

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
