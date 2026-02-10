// ============================================================================
// FILE: CloudSaveService.swift
// LOCATION: Grow2 Shared/Managers/CloudSaveService.swift
// PURPOSE: Firestore cloud save management - upload, download, list, delete saves
// ============================================================================

import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Cloud Save Metadata

struct CloudSaveMetadata {
    let saveID: String
    let saveName: String
    let saveDate: Date
    let sizeBytes: Int

    init(document: DocumentSnapshot) {
        self.saveID = document.documentID
        let data = document.data() ?? [:]
        self.saveName = data["saveName"] as? String ?? "Unnamed Save"
        self.saveDate = (data["saveDate"] as? Timestamp)?.dateValue() ?? Date()
        self.sizeBytes = data["sizeBytes"] as? Int ?? 0
    }
}

// MARK: - Cloud Save Service

class CloudSaveService {

    static let shared = CloudSaveService()

    private let db = Firestore.firestore()
    private let maxCloudSaves = 5

    private init() {}

    // MARK: - Helpers

    private func currentUserID() -> String? {
        return Auth.auth().currentUser?.uid
    }

    private func savesCollection() -> CollectionReference? {
        guard let uid = currentUserID() else { return nil }
        return db.collection("users").document(uid).collection("saves")
    }

    // MARK: - Upload Save

    func uploadSave(saveData: GameSaveData, saveName: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let collection = savesCollection() else {
            completion(.failure(CloudSaveError.notSignedIn))
            return
        }

        // Check save count limit
        collection.getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                completion(.failure(error))
                return
            }

            let existingCount = snapshot?.documents.count ?? 0
            if existingCount >= self.maxCloudSaves {
                completion(.failure(CloudSaveError.maxSavesReached))
                return
            }

            // Encode save data to JSON
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let jsonData = try encoder.encode(saveData)

                let documentData: [String: Any] = [
                    "saveName": saveName,
                    "saveDate": Timestamp(date: saveData.saveDate),
                    "sizeBytes": jsonData.count,
                    "saveJSON": jsonData.base64EncodedString()
                ]

                let docRef = collection.document()
                docRef.setData(documentData) { error in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }
                    debugLog("☁️ Save uploaded successfully: \(docRef.documentID)")
                    completion(.success(docRef.documentID))
                }
            } catch {
                completion(.failure(error))
            }
        }
    }

    // MARK: - Download Save

    func downloadSave(saveID: String, completion: @escaping (Result<GameSaveData, Error>) -> Void) {
        guard let collection = savesCollection() else {
            completion(.failure(CloudSaveError.notSignedIn))
            return
        }

        collection.document(saveID).getDocument { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = snapshot?.data(),
                  let base64String = data["saveJSON"] as? String,
                  let jsonData = Data(base64Encoded: base64String) else {
                completion(.failure(CloudSaveError.corruptedSave))
                return
            }

            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let saveData = try decoder.decode(GameSaveData.self, from: jsonData)
                debugLog("☁️ Save downloaded successfully: \(saveID)")
                completion(.success(saveData))
            } catch {
                completion(.failure(error))
            }
        }
    }

    // MARK: - List Saves

    func listSaves(completion: @escaping (Result<[CloudSaveMetadata], Error>) -> Void) {
        guard let collection = savesCollection() else {
            completion(.failure(CloudSaveError.notSignedIn))
            return
        }

        collection.order(by: "saveDate", descending: true).getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            let saves = snapshot?.documents.map { CloudSaveMetadata(document: $0) } ?? []
            completion(.success(saves))
        }
    }

    // MARK: - Delete Save

    func deleteSave(saveID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let collection = savesCollection() else {
            completion(.failure(CloudSaveError.notSignedIn))
            return
        }

        collection.document(saveID).delete { error in
            if let error = error {
                completion(.failure(error))
                return
            }
            debugLog("☁️ Cloud save deleted: \(saveID)")
            completion(.success(()))
        }
    }

    // MARK: - Get Latest Save Metadata

    func getLatestSaveMetadata(completion: @escaping (Result<CloudSaveMetadata?, Error>) -> Void) {
        guard let collection = savesCollection() else {
            completion(.failure(CloudSaveError.notSignedIn))
            return
        }

        collection.order(by: "saveDate", descending: true).limit(to: 1).getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            let metadata = snapshot?.documents.first.map { CloudSaveMetadata(document: $0) }
            completion(.success(metadata))
        }
    }
}

// MARK: - Cloud Save Errors

enum CloudSaveError: LocalizedError {
    case notSignedIn
    case maxSavesReached
    case corruptedSave

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "You must be signed in to use cloud saves."
        case .maxSavesReached: return "Maximum of 5 cloud saves reached. Delete a save to upload a new one."
        case .corruptedSave: return "The cloud save data is corrupted or missing."
        }
    }
}
