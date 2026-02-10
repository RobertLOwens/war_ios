// ============================================================================
// FILE: AuthService.swift
// LOCATION: Grow2 Shared/Managers/AuthService.swift
// PURPOSE: Firebase Auth wrapper - handles Email/Password and Google sign-in
// ============================================================================

import Foundation
import UIKit
import FirebaseAuth
import GoogleSignIn

// MARK: - Auth User Model

struct AuthUser {
    let uid: String
    let email: String?
    let displayName: String?

    init(firebaseUser: User) {
        self.uid = firebaseUser.uid
        self.email = firebaseUser.email
        self.displayName = firebaseUser.displayName
    }
}

// MARK: - Auth Service

class AuthService: NSObject {

    static let shared = AuthService()

    static let authStateChangedNotification = Notification.Name("AuthService.authStateChanged")

    private(set) var currentUser: AuthUser?

    private override init() {
        super.init()
        // Sync current Firebase user on init
        if let firebaseUser = Auth.auth().currentUser {
            currentUser = AuthUser(firebaseUser: firebaseUser)
        }

        // Listen for Firebase auth state changes
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            if let user = user {
                self?.currentUser = AuthUser(firebaseUser: user)
            } else {
                self?.currentUser = nil
            }
            NotificationCenter.default.post(name: AuthService.authStateChangedNotification, object: nil)
        }
    }

    // MARK: - Check Existing Session

    func checkExistingSession() -> Bool {
        return Auth.auth().currentUser != nil
    }

    // MARK: - Email/Password Sign Up

    func signUp(email: String, password: String, completion: @escaping (Result<AuthUser, Error>) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let firebaseUser = result?.user else {
                completion(.failure(AuthError.unknownError))
                return
            }
            let authUser = AuthUser(firebaseUser: firebaseUser)
            self?.currentUser = authUser
            completion(.success(authUser))
        }
    }

    // MARK: - Email/Password Sign In

    func signIn(email: String, password: String, completion: @escaping (Result<AuthUser, Error>) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let firebaseUser = result?.user else {
                completion(.failure(AuthError.unknownError))
                return
            }
            let authUser = AuthUser(firebaseUser: firebaseUser)
            self?.currentUser = authUser
            completion(.success(authUser))
        }
    }

    // MARK: - Google Sign In

    func signInWithGoogle(presenting viewController: UIViewController, completion: @escaping (Result<AuthUser, Error>) -> Void) {
        guard GIDSignIn.sharedInstance.configuration != nil else {
            completion(.failure(AuthError.googleNotConfigured))
            return
        }
        GIDSignIn.sharedInstance.signIn(withPresenting: viewController) { [weak self] result, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                completion(.failure(AuthError.missingGoogleToken))
                return
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )

            Auth.auth().signIn(with: credential) { [weak self] authResult, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let firebaseUser = authResult?.user else {
                    completion(.failure(AuthError.unknownError))
                    return
                }
                let authUser = AuthUser(firebaseUser: firebaseUser)
                self?.currentUser = authUser
                completion(.success(authUser))
            }
        }
    }

    // MARK: - Sign Out

    func signOut() throws {
        try Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
        currentUser = nil
    }

    // MARK: - Password Management

    var isEmailPasswordUser: Bool {
        guard let providerData = Auth.auth().currentUser?.providerData else { return false }
        return providerData.contains { $0.providerID == "password" }
    }

    func changePassword(currentPassword: String, newPassword: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let user = Auth.auth().currentUser, let email = user.email else {
            completion(.failure(AuthError.notSignedIn))
            return
        }
        let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
        user.reauthenticate(with: credential) { _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            user.updatePassword(to: newPassword) { error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                completion(.success(()))
            }
        }
    }

    // MARK: - Delete Account

    func deleteAccount(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(.failure(AuthError.notSignedIn))
            return
        }
        user.delete { [weak self] error in
            if let error = error {
                completion(.failure(error))
                return
            }
            self?.currentUser = nil
            completion(.success(()))
        }
    }

    // MARK: - Reset Password

    func resetPassword(email: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                completion(.failure(error))
                return
            }
            completion(.success(()))
        }
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case unknownError
    case notSignedIn
    case missingGoogleToken
    case googleNotConfigured

    var errorDescription: String? {
        switch self {
        case .unknownError: return "An unknown authentication error occurred."
        case .notSignedIn: return "No user is currently signed in."
        case .missingGoogleToken: return "Failed to get Google authentication token."
        case .googleNotConfigured: return "Google Sign-In is not configured. Enable Google provider in Firebase Console and re-download GoogleService-Info.plist."
        }
    }
}
