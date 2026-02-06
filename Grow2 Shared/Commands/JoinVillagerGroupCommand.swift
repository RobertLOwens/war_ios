// ============================================================================
// FILE: Grow2 Shared/Commands/JoinVillagerGroupCommand.swift
// PURPOSE: Command for sending villagers from a building to join an existing
//          villager group. Villagers march to the target group.
// ============================================================================

import Foundation

struct JoinVillagerGroupCommand: GameCommand {
    let id: UUID
    let timestamp: TimeInterval
    let playerID: UUID

    let buildingID: UUID
    let targetVillagerGroupID: UUID
    let count: Int

    static var commandType: CommandType { .joinVillagerGroup }

    init(playerID: UUID, buildingID: UUID, targetVillagerGroupID: UUID, count: Int) {
        self.id = UUID()
        self.timestamp = Date().timeIntervalSince1970
        self.playerID = playerID
        self.buildingID = buildingID
        self.targetVillagerGroupID = targetVillagerGroupID
        self.count = count
    }

    func validate(in context: CommandContext) -> CommandResult {
        // Check player exists
        guard let player = context.getPlayer(by: playerID) else {
            return .failure(reason: "Player not found")
        }

        // Check building exists and is owned by player
        guard let building = context.getBuilding(by: buildingID) else {
            return .failure(reason: "Building not found")
        }

        guard building.owner?.id == playerID else {
            return .failure(reason: "You don't own this building")
        }

        // Check building is operational
        guard building.isOperational else {
            return .failure(reason: "Building is not operational")
        }

        // Check building has enough villagers
        guard building.villagerGarrison >= count else {
            return .failure(reason: "Not enough villagers in garrison (have \(building.villagerGarrison), need \(count))")
        }

        // Check target villager group exists and is owned by player
        guard let targetGroup = findVillagerGroup(id: targetVillagerGroupID, in: context) else {
            return .failure(reason: "Target villager group not found")
        }

        guard targetGroup.owner?.id == playerID else {
            return .failure(reason: "You don't own this villager group")
        }

        // Check count is valid
        guard count > 0 else {
            return .failure(reason: "Must send at least one villager")
        }

        // Check path exists from building to villager group (pass player for wall/gate checks)
        guard context.hexMap.findPath(from: building.coordinate, to: targetGroup.coordinate, for: player) != nil else {
            return .failure(reason: "No path to villager group location")
        }

        return .success
    }

    func execute(in context: CommandContext) -> CommandResult {
        guard let building = context.getBuilding(by: buildingID),
              let targetGroup = findVillagerGroup(id: targetVillagerGroupID, in: context),
              let player = context.getPlayer(by: playerID),
              let gameScene = context.gameScene else {
            return .failure(reason: "Building, villager group, or game scene not found")
        }

        // Verify VillagerJoinManager is ready BEFORE removing villagers
        guard gameScene.villagerJoinManager.hexMap != nil else {
            return .failure(reason: "Game not ready - please try again")
        }

        // Find path from building to villager group (pass player for wall/gate checks)
        guard let path = context.hexMap.findPath(from: building.coordinate, to: targetGroup.coordinate, for: player) else {
            return .failure(reason: "No path to villager group")
        }

        // Remove villagers from building garrison
        let actualRemoved = building.removeVillagersFromGarrison(quantity: count)

        guard actualRemoved > 0 else {
            return .failure(reason: "Could not remove villagers from garrison")
        }

        // Create marching villager group
        let marchingGroup = MarchingVillagerGroup(
            name: "Villagers to \(targetGroup.name)",
            sourceCoordinate: building.coordinate,
            targetVillagerGroup: targetGroup,
            sourceBuilding: building,
            villagerCount: actualRemoved,
            owner: player
        )
        marchingGroup.movementPath = path

        // Spawn marching villager node and start movement
        // If spawn fails, return villagers to garrison
        gameScene.spawnMarchingVillagerNode(marchingGroup: marchingGroup, path: path) { [weak building] success in
            if success {
                debugLog("Villagers arrived at \(targetGroup.name)")
            } else {
                // Return villagers to garrison on spawn failure
                debugLog("Villager transfer failed - returning to garrison")
                building?.addVillagersToGarrison(quantity: actualRemoved)
            }
        }

        debugLog("Sent \(actualRemoved) villagers to join \(targetGroup.name)")
        debugLog("   Path length: \(path.count) tiles")

        // Notify UI
        context.onAlert?("Villagers Dispatched", "\(actualRemoved) villagers marching to \(targetGroup.name)")

        return .success
    }

    // MARK: - Private Helpers

    private func findVillagerGroup(id: UUID, in context: CommandContext) -> VillagerGroup? {
        // Search through all players' entities
        for player in context.allPlayers {
            if let group = player.entities.first(where: { $0.id == id }) as? VillagerGroup {
                return group
            }
        }
        return nil
    }
}
