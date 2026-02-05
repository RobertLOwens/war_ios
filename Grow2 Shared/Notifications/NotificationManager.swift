// ============================================================================
// FILE: NotificationManager.swift
// LOCATION: Grow2 Shared/Notifications/NotificationManager.swift
// PURPOSE: Centralized manager for processing and displaying game notifications
// ============================================================================

import Foundation

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

    // MARK: - Initialization

    private init() {
        setupNotificationListeners()
    }

    // MARK: - Setup

    /// Configure the notification manager for a specific player
    func setup(localPlayerID: UUID) {
        self.localPlayerID = localPlayerID
        notificationCooldowns.removeAll()
        knownEnemyArmyPositions.removeAll()
        print("📢 NotificationManager setup for player: \(localPlayerID)")
    }

    /// Reset the notification manager
    func reset() {
        localPlayerID = nil
        notificationCooldowns.removeAll()
        knownEnemyArmyPositions.removeAll()
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

        // Listen for building completion
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBuildingComplete),
            name: .buildingDidComplete,
            object: nil
        )

        // Listen for training completion
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTrainingComplete),
            name: .trainingDidComplete,
            object: nil
        )

        // Listen for phased combat started (army attacked)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCombatStartedNotification),
            name: .phasedCombatStarted,
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

    @objc private func handleBuildingComplete(_ notification: Notification) {
        guard let localPlayerID = localPlayerID else { return }

        // Building completion is handled via StateChange processing
        // This listener is for cases where Building posts directly
        if let userInfo = notification.userInfo,
           let buildingType = userInfo["buildingType"] as? BuildingType,
           let coordinate = userInfo["coordinate"] as? HexCoordinate,
           let ownerID = userInfo["ownerID"] as? UUID,
           ownerID == localPlayerID {
            let gameNotification = GameNotification(
                type: .buildingCompleted(buildingType: buildingType, coordinate: coordinate),
                playerID: localPlayerID
            )
            postNotification(gameNotification)
        }
    }

    @objc private func handleTrainingComplete(_ notification: Notification) {
        guard let localPlayerID = localPlayerID else { return }

        if let userInfo = notification.userInfo,
           let playerID = userInfo["playerID"] as? UUID,
           playerID == localPlayerID,
           let unitType = userInfo["unitType"] as? String,
           let quantity = userInfo["quantity"] as? Int,
           let coordinate = userInfo["coordinate"] as? HexCoordinate {
            let gameNotification = GameNotification(
                type: .trainingCompleted(unitType: unitType, quantity: quantity, coordinate: coordinate),
                playerID: localPlayerID
            )
            postNotification(gameNotification)
        }
    }

    @objc private func handleCombatStartedNotification(_ notification: Notification) {
        guard let localPlayerID = localPlayerID,
              let combat = notification.object as? ActiveCombat else { return }

        // Check if local player is the defender (they're being attacked)
        let gameState = GameEngine.shared.gameState

        // Check if any defender army belongs to local player
        for defenderState in [combat.defenderArmies.first].compactMap({ $0 }) {
            if let army = gameState?.getArmy(id: defenderState.armyID),
               army.ownerID == localPlayerID {
                let gameNotification = GameNotification(
                    type: .armyAttacked(armyName: defenderState.armyName, coordinate: combat.location),
                    playerID: localPlayerID
                )
                postNotification(gameNotification)
                return
            }
        }
    }

    // MARK: - State Change Processing

    /// Process a batch of state changes and generate appropriate notifications
    func processStateChanges(_ changes: [StateChange]) {
        guard let localPlayerID = localPlayerID else { return }

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

        default:
            break
        }
    }

    // MARK: - Event Handlers

    private func handleBuildingCompletion(buildingID: UUID, playerID: UUID) {
        guard let gameState = GameEngine.shared.gameState,
              let building = gameState.getBuilding(id: buildingID),
              building.ownerID == playerID,
              let buildingType = BuildingType(rawValue: building.buildingType.rawValue) else {
            return
        }

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
        // Check if player has villagers assigned to this resource
        guard let gameState = GameEngine.shared.gameState else { return }

        let playerVillagers = gameState.getVillagerGroupsForPlayer(id: playerID)
        let hasVillagersAtResource = playerVillagers.contains { group in
            group.taskTargetCoordinate == coordinate
        }

        if hasVillagersAtResource {
            let notification = GameNotification(
                type: .resourcePointDepleted(resourceType: resourceType, coordinate: coordinate),
                playerID: playerID
            )
            postNotification(notification)
        }
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

    /// Post a notification to the UI if it passes deduplication
    private func postNotification(_ notification: GameNotification) {
        guard notification.playerID == localPlayerID else { return }

        // Check cooldown for deduplication
        let key = notification.deduplicationKey
        if let lastNotificationTime = notificationCooldowns[key] {
            let cooldownPeriod = getCooldownPeriod(for: key)
            let elapsed = Date().timeIntervalSince(lastNotificationTime)
            if elapsed < cooldownPeriod {
                // Still in cooldown, skip this notification
                return
            }
        }

        // Update cooldown
        notificationCooldowns[key] = Date()

        // Post to UI on main thread
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .gameNotificationReceived,
                object: nil,
                userInfo: ["notification": notification]
            )
        }

        print("📢 Posted notification: \(notification.icon) \(notification.message)")
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

    // MARK: - Cleanup

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
