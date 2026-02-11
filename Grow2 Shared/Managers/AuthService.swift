// ============================================================================
// FILE: AuthService.swift
// LOCATION: Grow2 Shared/Managers/AuthService.swift
// PURPOSE: Firebase Auth wrapper - handles Email/Password and Google sign-in
// ============================================================================

import Foundation
import UIKit
import FirebaseAuth
import FirebaseFirestore
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
    static let usernameDidChangeNotification = Notification.Name("AuthService.usernameDidChange")

    private(set) var currentUser: AuthUser?
    private(set) var cachedUsername: String?

    private let db = Firestore.firestore()

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
        cachedUsername = nil
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

        // Release username first, then delete account
        releaseUsername { [weak self] _ in
            user.delete { error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                self?.cachedUsername = nil
                self?.currentUser = nil
                completion(.success(()))
            }
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

    // MARK: - Username System

    /// Check if current user has a username set. Fast path via UserDefaults, fallback to Firestore.
    func checkHasUsername(completion: @escaping (Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }

        // Fast path: check UserDefaults cache
        let key = "hasUsername_\(uid)"
        if UserDefaults.standard.bool(forKey: key) {
            // Also load the cached username from Firestore
            loadUsername { _ in }
            completion(true)
            return
        }

        // Fallback: check Firestore
        db.collection("users").document(uid).getDocument { [weak self] snapshot, error in
            guard let data = snapshot?.data(), let username = data["username"] as? String else {
                completion(false)
                return
            }
            self?.cachedUsername = username
            UserDefaults.standard.set(true, forKey: key)
            completion(true)
        }
    }

    /// Load the username from Firestore into cache.
    func loadUsername(completion: @escaping (String?) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(nil)
            return
        }

        db.collection("users").document(uid).getDocument { [weak self] snapshot, error in
            guard let data = snapshot?.data(), let username = data["username"] as? String else {
                completion(nil)
                return
            }
            self?.cachedUsername = username
            completion(username)
        }
    }

    /// Check if a username is available (case-insensitive).
    func checkUsernameAvailability(_ username: String, completion: @escaping (Bool) -> Void) {
        let lowered = username.lowercased()
        db.collection("usernames").document(lowered).getDocument { snapshot, error in
            if let error = error {
                debugLog("Username availability check error: \(error.localizedDescription)")
                completion(false)
                return
            }
            // Available if doc doesn't exist
            completion(!(snapshot?.exists ?? true))
        }
    }

    /// Claim a username for the current user using a Firestore transaction.
    func claimUsername(_ username: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.failure(AuthError.notSignedIn))
            return
        }

        let lowered = username.lowercased()
        let usernameDocRef = db.collection("usernames").document(lowered)
        let userDocRef = db.collection("users").document(uid)

        db.runTransaction({ (transaction, errorPointer) -> Any? in
            // Check if username is already taken
            let usernameDoc: DocumentSnapshot
            do {
                usernameDoc = try transaction.getDocument(usernameDocRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }

            if usernameDoc.exists {
                let error = NSError(domain: "AuthService", code: 409, userInfo: [
                    NSLocalizedDescriptionKey: "Username is already taken."
                ])
                errorPointer?.pointee = error
                return nil
            }

            // Claim the username
            transaction.setData([
                "uid": uid,
                "originalCase": username,
                "createdAt": FieldValue.serverTimestamp()
            ], forDocument: usernameDocRef)

            // Update user profile
            transaction.setData([
                "username": username,
                "usernameLower": lowered,
                "usernameSetAt": FieldValue.serverTimestamp()
            ], forDocument: userDocRef, merge: true)

            return nil
        }) { [weak self] _, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            // Update Firebase Auth display name
            let changeRequest = Auth.auth().currentUser?.createProfileChangeRequest()
            changeRequest?.displayName = username
            changeRequest?.commitChanges { _ in }

            self?.cachedUsername = username
            if let uid = Auth.auth().currentUser?.uid {
                UserDefaults.standard.set(true, forKey: "hasUsername_\(uid)")
            }
            NotificationCenter.default.post(name: AuthService.usernameDidChangeNotification, object: nil)
            completion(.success(()))
        }
    }

    /// Change the current user's username to a new one via transaction.
    func changeUsername(to newUsername: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.failure(AuthError.notSignedIn))
            return
        }

        let newLowered = newUsername.lowercased()
        let newUsernameDocRef = db.collection("usernames").document(newLowered)
        let userDocRef = db.collection("users").document(uid)

        db.runTransaction({ (transaction, errorPointer) -> Any? in
            // Read current user doc to get old username
            let userDoc: DocumentSnapshot
            do {
                userDoc = try transaction.getDocument(userDocRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }

            let oldUsernameLower = userDoc.data()?["usernameLower"] as? String

            // Check if new username is taken
            let newUsernameDoc: DocumentSnapshot
            do {
                newUsernameDoc = try transaction.getDocument(newUsernameDocRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }

            if newUsernameDoc.exists {
                let error = NSError(domain: "AuthService", code: 409, userInfo: [
                    NSLocalizedDescriptionKey: "Username is already taken."
                ])
                errorPointer?.pointee = error
                return nil
            }

            // Delete old username doc if it exists
            if let oldLower = oldUsernameLower {
                let oldUsernameDocRef = self.db.collection("usernames").document(oldLower)
                transaction.deleteDocument(oldUsernameDocRef)
            }

            // Claim new username
            transaction.setData([
                "uid": uid,
                "originalCase": newUsername,
                "createdAt": FieldValue.serverTimestamp()
            ], forDocument: newUsernameDocRef)

            // Update user profile
            transaction.setData([
                "username": newUsername,
                "usernameLower": newLowered,
                "usernameSetAt": FieldValue.serverTimestamp()
            ], forDocument: userDocRef, merge: true)

            return nil
        }) { [weak self] _, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            let changeRequest = Auth.auth().currentUser?.createProfileChangeRequest()
            changeRequest?.displayName = newUsername
            changeRequest?.commitChanges { _ in }

            self?.cachedUsername = newUsername
            NotificationCenter.default.post(name: AuthService.usernameDidChangeNotification, object: nil)
            completion(.success(()))
        }
    }

    /// Release the current user's username (for account deletion).
    func releaseUsername(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.success(()))
            return
        }

        let userDocRef = db.collection("users").document(uid)
        userDocRef.getDocument { [weak self] snapshot, error in
            guard let data = snapshot?.data(),
                  let usernameLower = data["usernameLower"] as? String else {
                completion(.success(()))
                return
            }

            let usernameDocRef = self?.db.collection("usernames").document(usernameLower)
            let batch = self?.db.batch()
            if let usernameDocRef = usernameDocRef {
                batch?.deleteDocument(usernameDocRef)
            }
            batch?.updateData(["username": FieldValue.delete(), "usernameLower": FieldValue.delete(), "usernameSetAt": FieldValue.delete()], forDocument: userDocRef)
            batch?.commit { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    UserDefaults.standard.removeObject(forKey: "hasUsername_\(uid)")
                    completion(.success(()))
                }
            }
        }
    }

    /// Validate username format: 3-20 chars, alphanumeric + underscores only.
    static func isValidUsername(_ username: String) -> Bool {
        let pattern = "^[a-zA-Z0-9_]{3,20}$"
        return username.range(of: pattern, options: .regularExpression) != nil
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case unknownError
    case notSignedIn
    case missingGoogleToken
    case googleNotConfigured
    case usernameTaken
    case usernameInvalid

    var errorDescription: String? {
        switch self {
        case .unknownError: return "An unknown authentication error occurred."
        case .notSignedIn: return "No user is currently signed in."
        case .missingGoogleToken: return "Failed to get Google authentication token."
        case .googleNotConfigured: return "Google Sign-In is not configured. Enable Google provider in Firebase Console and re-download GoogleService-Info.plist."
        case .usernameTaken: return "This username is already taken."
        case .usernameInvalid: return "Username must be 3-20 characters, using only letters, numbers, and underscores."
        }
    }
}
