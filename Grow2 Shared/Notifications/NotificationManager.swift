// ============================================================================
// FILE: NotificationManager.swift
// LOCATION: Grow2 Shared/Notifications/NotificationManager.swift
// PURPOSE: Centralized manager for processing and displaying game notifications
// ============================================================================

import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(UserNotifications)
import UserNotifications
#endif

// MARK: - Notification Manager

/// Centralized manager for game notifications
/// Handles filtering, deduplication, and posting of notifications to the UI
class NotificationManager {

    // MARK: - Singleton

    static let shared = NotificationManager()

    // MARK: - State

    /// The player ID to filter notifications for (local player only)
    private var localPlayerID: UUID?

    /// Cooldown tracking to prevent notification spam
    private var notificationCooldowns: [String: Date] = [:]

    // MARK: - Notification History

    /// Maximum number of notifications to store in history
    private let maxStoredNotifications: Int = 50

    /// Historical notifications (newest first)
    private(set) var notificationHistory: [GameNotification] = []

    /// Set of unread notification IDs
    private var unreadNotificationIDs: Set<UUID> = []

    /// Number of unread notifications
    var unreadCount: Int { return unreadNotificationIDs.count }

    /// Default cooldown period between duplicate notifications (seconds)
    private let defaultCooldownPeriod: TimeInterval = 5.0

    /// Cooldown periods for specific notification types
    private let specificCooldowns: [String: TimeInterval] = [
        "gathering": 10.0,       // Gathering notifications less frequent
        "resourcesMaxed": 30.0,  // Storage full notifications very infrequent
        "armySighted": 15.0,     // Enemy sightings with longer cooldown
    ]

    /// Track previously visible enemy armies to detect new sightings
    private var knownEnemyArmyPositions: Set<HexCoordinate> = []

    /// Whether the app is currently in the foreground
    private var isAppInForeground: Bool = true

    /// Debug logging enabled
    private let debugLogging: Bool = true

    // MARK: - Initialization

    private init() {
        setupNotificationListeners()
        setupAppStateObservers()
    }

    // MARK: - Setup

    /// Configure the notification manager for a specific player
    func setup(localPlayerID: UUID) {
        self.localPlayerID = localPlayerID
        notificationCooldowns.removeAll()
        knownEnemyArmyPositions.removeAll()
        debugLog("Setup for player: \(localPlayerID)")
    }

    // MARK: - App State Observers

    private func setupAppStateObservers() {
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        #endif
    }

    @objc private func appDidEnterBackground() {
        isAppInForeground = false
        scheduleBackgroundCompletionNotifications()
        debugLog("App entered background - scheduled completion notifications")
    }

    @objc private func appWillEnterForeground() {
        isAppInForeground = true
        debugLog("App entered foreground")
        // Cancel any pending notifications since user is back in app
        #if canImport(UserNotifications)
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        #endif
    }

    // MARK: - Debug Logging

    private func debugLog(_ message: String) {
        if debugLogging {
            print("📢 NotificationManager: \(message)")
        }
    }

    // MARK: - History Management

    /// Add a notification to history
    private func addToHistory(_ notification: GameNotification) {
        // Insert at front (newest first)
        notificationHistory.insert(notification, at: 0)

        // Mark as unread
        unreadNotificationIDs.insert(notification.id)

        // Trim to max size
        if notificationHistory.count > maxStoredNotifications {
            let removedNotifications = notificationHistory.suffix(from: maxStoredNotifications)
            for removed in removedNotifications {
                unreadNotificationIDs.remove(removed.id)
            }
            notificationHistory = Array(notificationHistory.prefix(maxStoredNotifications))
        }

        // Post notification that history changed
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .notificationHistoryChanged, object: nil)
        }
    }

    /// Mark a notification as read
    func markAsRead(_ notificationID: UUID) {
        if unreadNotificationIDs.remove(notificationID) != nil {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .notificationHistoryChanged, object: nil)
            }
        }
    }

    /// Mark all notifications as read
    func markAllAsRead() {
        if !unreadNotificationIDs.isEmpty {
            unreadNotificationIDs.removeAll()
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .notificationHistoryChanged, object: nil)
            }
        }
    }

    /// Clear all notification history
    func clearHistory() {
        notificationHistory.removeAll()
        unreadNotificationIDs.removeAll()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .notificationHistoryChanged, object: nil)
        }
    }

    /// Get recent notifications
    func getRecentNotifications(limit: Int = 50) -> [GameNotification] {
        return Array(notificationHistory.prefix(limit))
    }

    /// Check if a notification is unread
    func isUnread(_ notificationID: UUID) -> Bool {
        return unreadNotificationIDs.contains(notificationID)
    }

    /// Reset the notification manager
    func reset() {
        localPlayerID = nil
        notificationCooldowns.removeAll()
        knownEnemyArmyPositions.removeAll()
        notificationHistory.removeAll()
        unreadNotificationIDs.removeAll()
    }

    // MARK: - Notification Listeners

    private func setupNotificationListeners() {
        // Listen for research completion
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleResearchComplete),
            name: .researchDidComplete,
            object: nil
        )

    }

    @objc private func handleResearchComplete(_ notification: Notification) {
        guard let localPlayerID = localPlayerID else { return }

        if let researchType = notification.userInfo?["researchType"] as? ResearchType {
            let gameNotification = GameNotification(
                type: .researchCompleted(researchName: researchType.displayName),
                playerID: localPlayerID
            )
            postNotification(gameNotification)
        }
    }

    // MARK: - State Change Processing

    /// Process a batch of state changes and generate appropriate notifications
    func processStateChanges(_ changes: [StateChange]) {
        guard let localPlayerID = localPlayerID else {
            debugLog("processStateChanges: No localPlayerID set - skipping \(changes.count) changes")
            return
        }

        debugLog("processStateChanges: Processing \(changes.count) changes")
        for change in changes {
            processStateChange(change, localPlayerID: localPlayerID)
        }
    }

    private func processStateChange(_ change: StateChange, localPlayerID: UUID) {
        switch change {
        // Building completion
        case .buildingCompleted(let buildingID):
            handleBuildingCompletion(buildingID: buildingID, playerID: localPlayerID)

        // Upgrade completion
        case .buildingUpgradeCompleted(let buildingID, let newLevel):
            handleUpgradeCompletion(buildingID: buildingID, newLevel: newLevel, playerID: localPlayerID)

        // Resource point depleted
        case .resourcePointDepleted(let coordinate, let resourceType):
            handleResourceDepleted(coordinate: coordinate, resourceType: resourceType, playerID: localPlayerID)

        // Fog of war updated - check for enemy sighting
        case .fogOfWarUpdated(let playerID, let coordinate, let visibility):
            if playerID == localPlayerID && visibility == "visible" {
                checkForEnemySighting(at: coordinate, playerID: localPlayerID)
            }

        // Combat started - check if player's units are attacked
        case .combatStarted(_, let defenderID, let coordinate):
            handleCombatStarted(defenderID: defenderID, coordinate: coordinate, playerID: localPlayerID)

        // Villager casualties - villagers under attack
        case .villagerCasualties(let villagerGroupID, _, _):
            handleVillagerCasualties(villagerGroupID: villagerGroupID, playerID: localPlayerID)

        // Training completed
        case .trainingCompleted(let buildingID, let unitType, let quantity):
            handleTrainingCompletion(buildingID: buildingID, unitType: unitType, quantity: quantity, playerID: localPlayerID)

        // Villager training completed
        case .villagerTrainingCompleted(let buildingID, let quantity):
            handleTrainingCompletion(buildingID: buildingID, unitType: "Villager", quantity: quantity, playerID: localPlayerID)

        // Entrenchment completed
        case .armyEntrenched(let armyID, let coordinate):
            handleEntrenchmentCompleted(armyID: armyID, coordinate: coordinate, playerID: localPlayerID)

        default:
            break
        }
    }

    // MARK: - Event Handlers

    private func handleBuildingCompletion(buildingID: UUID, playerID: UUID) {
        debugLog("handleBuildingCompletion: buildingID=\(buildingID)")

        guard let gameState = GameEngine.shared.gameState else {
            debugLog("handleBuildingCompletion: No gameState")
            return
        }

        guard let building = gameState.getBuilding(id: buildingID) else {
            debugLog("handleBuildingCompletion: Building not found")
            return
        }

        guard building.ownerID == playerID else {
            debugLog("handleBuildingCompletion: Building owner \(building.ownerID ?? UUID()) != player \(playerID)")
            return
        }

        guard let buildingType = BuildingType(rawValue: building.buildingType.rawValue) else {
            debugLog("handleBuildingCompletion: Invalid building type \(building.buildingType.rawValue)")
            return
        }

        debugLog("handleBuildingCompletion: Creating notification for \(buildingType.displayName)")
        let notification = GameNotification(
            type: .buildingCompleted(buildingType: buildingType, coordinate: building.coordinate),
            playerID: playerID
        )
        postNotification(notification)
    }

    private func handleUpgradeCompletion(buildingID: UUID, newLevel: Int, playerID: UUID) {
        guard let gameState = GameEngine.shared.gameState,
              let building = gameState.getBuilding(id: buildingID),
              building.ownerID == playerID,
              let buildingType = BuildingType(rawValue: building.buildingType.rawValue) else {
            return
        }

        let notification = GameNotification(
            type: .upgradeCompleted(buildingType: buildingType, newLevel: newLevel, coordinate: building.coordinate),
            playerID: playerID
        )
        postNotification(notification)
    }

    private func handleResourceDepleted(coordinate: HexCoordinate, resourceType: String, playerID: UUID) {
        // The resourcePointDepleted state change is only emitted when villagers were
        // actively gathering, so post the notification directly without checking
        // (the check would fail anyway due to timing - task already cleared by the time we get here)
        let notification = GameNotification(
            type: .resourcePointDepleted(resourceType: resourceType, coordinate: coordinate),
            playerID: playerID
        )
        postNotification(notification)
    }

    private func checkForEnemySighting(at coordinate: HexCoordinate, playerID: UUID) {
        guard let gameState = GameEngine.shared.gameState else { return }

        // Check if there's an enemy army at this newly visible coordinate
        for army in gameState.armies.values {
            guard let armyOwnerID = army.ownerID,
                  armyOwnerID != playerID,
                  army.coordinate == coordinate else {
                continue
            }

            // Only notify if this is a new sighting (wasn't previously known)
            if !knownEnemyArmyPositions.contains(coordinate) {
                knownEnemyArmyPositions.insert(coordinate)

                let notification = GameNotification(
                    type: .armySighted(coordinate: coordinate),
                    playerID: playerID
                )
                postNotification(notification)
            }
            return
        }
    }

    private func handleCombatStarted(defenderID: UUID, coordinate: HexCoordinate, playerID: UUID) {
        guard let gameState = GameEngine.shared.gameState else { return }

        // Check if defender is player's army
        if let army = gameState.getArmy(id: defenderID),
           army.ownerID == playerID {
            let notification = GameNotification(
                type: .armyAttacked(armyName: army.name, coordinate: coordinate),
                playerID: playerID
            )
            postNotification(notification)
        }
    }

    private func handleVillagerCasualties(villagerGroupID: UUID, playerID: UUID) {
        guard let gameState = GameEngine.shared.gameState,
              let group = gameState.getVillagerGroup(id: villagerGroupID),
              group.ownerID == playerID else {
            return
        }

        let notification = GameNotification(
            type: .villagerAttacked(coordinate: group.coordinate),
            playerID: playerID
        )
        postNotification(notification)
    }

    private func handleTrainingCompletion(buildingID: UUID, unitType: String, quantity: Int, playerID: UUID) {
        guard let gameState = GameEngine.shared.gameState,
              let building = gameState.getBuilding(id: buildingID),
              building.ownerID == playerID else {
            return
        }

        let notification = GameNotification(
            type: .trainingCompleted(unitType: unitType, quantity: quantity, coordinate: building.coordinate),
            playerID: playerID
        )
        postNotification(notification)
    }

    private func handleEntrenchmentCompleted(armyID: UUID, coordinate: HexCoordinate, playerID: UUID) {
        guard let gameState = GameEngine.shared.gameState,
              let army = gameState.getArmy(id: armyID),
              army.ownerID == playerID else {
            return
        }

        let notification = GameNotification(
            type: .entrenchmentCompleted(armyName: army.name, coordinate: coordinate),
            playerID: playerID
        )
        postNotification(notification)
    }

    // MARK: - Resource Notifications

    /// Called when a resource reaches storage capacity
    func notifyResourceMaxed(resourceType: ResourceTypeData, playerID: UUID) {
        guard playerID == localPlayerID else { return }

        let notification = GameNotification(
            type: .resourcesMaxed(resourceType: resourceType),
            playerID: playerID
        )
        postNotification(notification)
    }

    /// Update known enemy positions (call when vision changes)
    func updateKnownEnemyPositions(visibleEnemyCoordinates: Set<HexCoordinate>) {
        // Remove coordinates that are no longer visible
        knownEnemyArmyPositions = knownEnemyArmyPositions.intersection(visibleEnemyCoordinates)
    }

    // MARK: - Notification Posting

    /// Post a notification to the UI if it passes deduplication and settings allow
    private func postNotification(_ notification: GameNotification) {
        debugLog("postNotification: \(notification.type)")

        guard notification.playerID == localPlayerID else {
            debugLog("postNotification: Player mismatch - notification for \(notification.playerID), local is \(localPlayerID?.uuidString ?? "nil")")
            return
        }

        // Check if this notification type is enabled in settings
        guard isNotificationEnabled(notification.type) else {
            debugLog("postNotification: Notification type disabled in settings")
            return
        }

        // Check cooldown for deduplication
        let key = notification.deduplicationKey
        if let lastNotificationTime = notificationCooldowns[key] {
            let cooldownPeriod = getCooldownPeriod(for: key)
            let elapsed = Date().timeIntervalSince(lastNotificationTime)
            if elapsed < cooldownPeriod {
                debugLog("postNotification: In cooldown (\(String(format: "%.1f", elapsed))s / \(cooldownPeriod)s)")
                return
            }
        }

        // Update cooldown
        notificationCooldowns[key] = Date()

        // Add to history
        addToHistory(notification)

        // If app is in background, schedule a local push notification
        if !isAppInForeground {
            debugLog("postNotification: App in background, scheduling push notification")
            schedulePushNotification(notification)
        }

        // Post to UI on main thread (will be processed when app returns to foreground)
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .gameNotificationReceived,
                object: nil,
                userInfo: ["notification": notification]
            )
        }

        debugLog("Posted notification: \(notification.icon) \(notification.message)")
    }

    // MARK: - Push Notifications

    /// Schedule push notifications for all pending completions when app enters background
    func scheduleBackgroundCompletionNotifications() {
        #if canImport(UserNotifications)
        guard let gameState = GameEngine.shared.gameState,
              let localPlayerID = localPlayerID else { return }

        let now = Date().timeIntervalSince1970

        // Buildings under construction
        for building in gameState.buildings.values {
            guard building.ownerID == localPlayerID,
                  building.state == .constructing,
                  let startTime = building.constructionStartTime else { continue }

            let buildSpeedMultiplier = 1.0 + (Double(building.buildersAssigned - 1) * 0.5)
            let totalTime = building.buildingType.buildTime / buildSpeedMultiplier
            let delay = (startTime + totalTime) - now
            if delay > 1 {
                scheduleDelayedNotification(
                    body: "🏗️ \(building.buildingType.displayName) construction complete",
                    delay: delay,
                    identifier: "building-\(building.id)"
                )
            }
        }

        // Building upgrades
        for building in gameState.buildings.values {
            guard building.ownerID == localPlayerID,
                  building.state == .upgrading,
                  let startTime = building.upgradeStartTime,
                  let upgradeTime = building.getUpgradeTime() else { continue }

            let delay = (startTime + upgradeTime) - now
            if delay > 1 {
                scheduleDelayedNotification(
                    body: "⬆️ \(building.buildingType.displayName) upgrade complete",
                    delay: delay,
                    identifier: "upgrade-\(building.id)"
                )
            }
        }

        // Military training queues
        for building in gameState.buildings.values {
            guard building.ownerID == localPlayerID else { continue }

            for entry in building.trainingQueue {
                let totalTime = entry.unitType.trainingTime * Double(entry.quantity)
                let delay = (entry.startTime + totalTime) - now
                if delay > 1 {
                    scheduleDelayedNotification(
                        body: "⚔️ \(entry.quantity)x \(entry.unitType.displayName) training complete",
                        delay: delay,
                        identifier: "training-\(entry.id)"
                    )
                }
            }

            // Villager training
            for entry in building.villagerTrainingQueue {
                let totalTime = VillagerTrainingEntryData.trainingTimePerVillager * Double(entry.quantity)
                let delay = (entry.startTime + totalTime) - now
                if delay > 1 {
                    scheduleDelayedNotification(
                        body: "👷 \(entry.quantity)x Villager training complete",
                        delay: delay,
                        identifier: "villager-\(entry.id)"
                    )
                }
            }
        }

        // Research
        if let active = ResearchManager.shared.activeResearch {
            let delay = active.getRemainingTime(currentTime: now)
            if delay > 1 {
                scheduleDelayedNotification(
                    body: "🔬 \(active.researchType.displayName) research complete",
                    delay: delay,
                    identifier: "research-\(active.researchType.rawValue)"
                )
            }
        }

        debugLog("Scheduled background completion notifications")
        #endif
    }

    private func scheduleDelayedNotification(body: String, delay: TimeInterval, identifier: String) {
        #if canImport(UserNotifications)
        let content = UNMutableNotificationContent()
        content.title = "Grow2"
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error = error {
                self?.debugLog("Failed to schedule notification: \(error)")
            } else {
                self?.debugLog("Scheduled notification '\(identifier)' for \(Int(delay))s")
            }
        }
        #endif
    }

    /// Schedule a local push notification for when app is backgrounded
    private func schedulePushNotification(_ notification: GameNotification) {
        #if canImport(UserNotifications)
        // Check if push notifications are enabled in settings
        guard isPushNotificationEnabled(notification.type) else {
            debugLog("schedulePushNotification: Push disabled for this type")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Grow2"
        content.body = "\(notification.icon) \(notification.message)"
        content.sound = .default

        // Add coordinate to userInfo for tap-to-jump
        var userInfo: [String: Any] = [
            "notificationType": notification.deduplicationKey
        ]
        if let coordinate = notification.coordinate {
            userInfo["coordinateQ"] = coordinate.q
            userInfo["coordinateR"] = coordinate.r
        }
        content.userInfo = userInfo

        // Deliver immediately (1 second delay to allow batching)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: notification.id.uuidString,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error = error {
                self?.debugLog("schedulePushNotification: Error - \(error.localizedDescription)")
            } else {
                self?.debugLog("schedulePushNotification: Scheduled successfully")
            }
        }
        #endif
    }

    /// Check if push notifications are enabled for a notification type
    private func isPushNotificationEnabled(_ type: GameNotificationType) -> Bool {
        let defaults = UserDefaults.standard

        // Master toggle for push notifications
        guard defaults.object(forKey: "settings.push.enabled") as? Bool ?? true else {
            return false
        }

        // Per-category toggles
        switch type {
        case .armyAttacked, .villagerAttacked:
            return defaults.object(forKey: "settings.push.combatAlerts") as? Bool ?? true

        case .armySighted:
            return defaults.object(forKey: "settings.push.scoutingAlerts") as? Bool ?? true

        case .buildingCompleted, .upgradeCompleted:
            return defaults.object(forKey: "settings.push.buildingComplete") as? Bool ?? true

        case .trainingCompleted:
            return defaults.object(forKey: "settings.push.trainingComplete") as? Bool ?? true

        case .resourcesMaxed, .resourcePointDepleted, .gatheringCompleted:
            return defaults.object(forKey: "settings.push.resourceAlerts") as? Bool ?? true

        case .researchCompleted:
            return defaults.object(forKey: "settings.push.researchComplete") as? Bool ?? true

        case .entrenchmentCompleted:
            return defaults.object(forKey: "settings.push.buildingComplete") as? Bool ?? true
        }
    }

    private func getCooldownPeriod(for key: String) -> TimeInterval {
        // Check for specific cooldowns based on key prefix
        for (prefix, cooldown) in specificCooldowns {
            if key.hasPrefix(prefix) {
                return cooldown
            }
        }
        return defaultCooldownPeriod
    }

    // MARK: - Settings Integration

    /// Check if a notification type is enabled in settings
    private func isNotificationEnabled(_ type: GameNotificationType) -> Bool {
        let defaults = UserDefaults.standard

        // Default to true if key not set
        switch type {
        case .armyAttacked, .villagerAttacked:
            return defaults.object(forKey: "settings.notify.combatAlerts") as? Bool ?? true

        case .armySighted:
            return defaults.object(forKey: "settings.notify.scoutingAlerts") as? Bool ?? true

        case .buildingCompleted, .upgradeCompleted:
            return defaults.object(forKey: "settings.notify.buildingComplete") as? Bool ?? true

        case .trainingCompleted:
            return defaults.object(forKey: "settings.notify.trainingComplete") as? Bool ?? true

        case .resourcesMaxed, .resourcePointDepleted, .gatheringCompleted:
            return defaults.object(forKey: "settings.notify.resourceAlerts") as? Bool ?? true

        case .researchCompleted:
            return defaults.object(forKey: "settings.notify.researchComplete") as? Bool ?? true

        case .entrenchmentCompleted:
            return defaults.object(forKey: "settings.notify.buildingComplete") as? Bool ?? true
        }
    }

    // MARK: - Cleanup

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
