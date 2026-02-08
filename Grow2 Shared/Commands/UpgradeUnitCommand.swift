// ============================================================================
// FILE: Grow2 Shared/Commands/UpgradeUnitCommand.swift
// PURPOSE: Command for player-initiated per-unit-type upgrades (blacksmith style)
// ============================================================================

import Foundation

struct UpgradeUnitCommand: GameCommand {
    let id: UUID
    let timestamp: TimeInterval
    let playerID: UUID

    let upgradeTypeRawValue: String
    let buildingID: UUID

    static var commandType: CommandType { .upgradeUnit }

    init(playerID: UUID, upgradeTypeRawValue: String, buildingID: UUID) {
        self.id = UUID()
        self.timestamp = Date().timeIntervalSince1970
        self.playerID = playerID
        self.upgradeTypeRawValue = upgradeTypeRawValue
        self.buildingID = buildingID
    }

    func validate(in context: CommandContext) -> CommandResult {
        guard let upgradeType = UnitUpgradeType(rawValue: upgradeTypeRawValue) else {
            return .failure(reason: "Invalid upgrade type")
        }

        guard let player = context.getPlayer(by: playerID) else {
            return .failure(reason: "Player not found")
        }

        // Check building exists and is owned by player
        guard let building = context.getBuilding(by: buildingID) else {
            return .failure(reason: "Building not found")
        }

        guard building.data.ownerID == playerID else {
            return .failure(reason: "You don't own this building")
        }

        // Check building type matches
        guard building.buildingType == upgradeType.requiredBuildingType else {
            return .failure(reason: "Wrong building type for this upgrade")
        }

        // Check building is completed
        guard building.state == .completed else {
            return .failure(reason: "Building is not completed")
        }

        // Check building level is sufficient
        guard building.level >= upgradeType.requiredBuildingLevel else {
            return .failure(reason: "Building level \(upgradeType.requiredBuildingLevel) required (current: \(building.level))")
        }

        // Check prerequisite
        if let prereq = upgradeType.prerequisite {
            guard player.state.hasCompletedUnitUpgrade(prereq.rawValue) else {
                return .failure(reason: "Prerequisite \(prereq.displayName) not completed")
            }
        }

        // Check not already completed
        guard !player.state.hasCompletedUnitUpgrade(upgradeTypeRawValue) else {
            return .failure(reason: "Upgrade already completed")
        }

        // Check no active unit upgrade
        guard !player.state.isUnitUpgradeActive() else {
            return .failure(reason: "Another unit upgrade is already in progress")
        }

        // Check can afford
        let cost = upgradeType.cost
        for (resource, amount) in cost {
            guard player.getResource(resource) >= amount else {
                return .failure(reason: "Insufficient \(resource.displayName)")
            }
        }

        return .success
    }

    func execute(in context: CommandContext) -> CommandResult {
        guard let upgradeType = UnitUpgradeType(rawValue: upgradeTypeRawValue) else {
            return .failure(reason: "Invalid upgrade type")
        }

        guard let player = context.getPlayer(by: playerID) else {
            return .failure(reason: "Player not found")
        }

        // Deduct resources
        for (resource, amount) in upgradeType.cost {
            player.removeResource(resource, amount: amount)
        }

        // Start the upgrade
        let currentTime = GameEngine.shared.gameState?.currentTime ?? Date().timeIntervalSince1970
        player.state.startUnitUpgrade(upgradeTypeRawValue, buildingID: buildingID, at: currentTime)

        debugLog("⬆️ Player \(player.name) started unit upgrade: \(upgradeType.displayName)")

        return .success
    }
}
