// ============================================================================
// FILE: DemolishCommand.swift
// LOCATION: Grow2 Shared/Commands/DemolishCommand.swift
// PURPOSE: Commands for demolishing buildings
//          Requires villagers to move to building before demolishing
// ============================================================================

import Foundation

// MARK: - Demolish Building Command

struct DemolishCommand: GameCommand, Codable {
    let id: UUID
    let timestamp: TimeInterval
    let playerID: UUID

    let buildingID: UUID
    let demolisherEntityID: UUID?

    static var commandType: CommandType { .demolish }

    enum CodingKeys: String, CodingKey {
        case id, timestamp, playerID, buildingID, demolisherEntityID
    }

    init(playerID: UUID, buildingID: UUID, demolisherEntityID: UUID? = nil) {
        self.id = UUID()
        self.timestamp = Date().timeIntervalSince1970
        self.playerID = playerID
        self.buildingID = buildingID
        self.demolisherEntityID = demolisherEntityID
    }

    func validate(in context: CommandContext) -> CommandResult {
        guard context.getPlayer(by: playerID) != nil else {
            return .failure(reason: "Player not found")
        }

        guard let building = context.getBuilding(by: buildingID) else {
            return .failure(reason: "Building not found")
        }

        guard building.owner?.id == playerID else {
            return .failure(reason: "You don't own this building")
        }

        // Cannot demolish City Center
        guard building.buildingType != .cityCenter else {
            return .failure(reason: "Cannot demolish City Center")
        }

        // Can only demolish completed buildings
        guard building.state == .completed else {
            return .failure(reason: "Building must be completed to demolish")
        }

        // Check if building has garrisoned units
        if building.getTotalGarrisonCount() > 0 {
            return .failure(reason: "Remove garrisoned units first")
        }

        // Check if demolisher entity is provided
        if let demolisherID = demolisherEntityID {
            guard let demolisherEntity = context.getEntity(by: demolisherID),
                  let villagers = demolisherEntity.entity as? VillagerGroup else {
                return .failure(reason: "Villager group not found")
            }

            // Check villagers aren't busy with an incompatible task
            switch villagers.currentTask {
            case .building, .upgrading, .demolishing:
                return .failure(reason: "Villagers are busy with another task")
            default:
                break
            }
        }

        return .success
    }

    func execute(in context: CommandContext) -> CommandResult {
        guard let building = context.getBuilding(by: buildingID) else {
            return .failure(reason: "Building not found")
        }

        // Assign demolisher if provided
        if let demolisherID = demolisherEntityID,
           let demolisherEntity = context.getEntity(by: demolisherID),
           let villagers = demolisherEntity.entity as? VillagerGroup {

            building.demolisherEntity = demolisherEntity

            // Cancel active gathering if villagers were gathering
            if case .gatheringResource(let resource) = villagers.currentTask,
               let player = context.getPlayer(by: playerID) {
                resource.stopGathering(by: villagers)

                let rateContribution = 0.2 * Double(villagers.villagerCount)
                player.decreaseCollectionRate(resource.resourceType.resourceYield, amount: rateContribution)

                if let gameScene = context.gameScene, gameScene.isEngineEnabled {
                    GameEngine.shared.resourceEngine.updateCollectionRates(forPlayer: player.id)
                }

                context.onResourcesChanged?()
            }

            // Check if villagers need to move to the building first
            if villagers.coordinate != building.coordinate {
                // Assign demolishing task (will complete when they arrive)
                villagers.assignTask(.demolishing(building), target: building.coordinate)
                demolisherEntity.isMoving = true

                // Execute move command to get them there
                let moveCommand = MoveCommand(
                    playerID: playerID,
                    entityID: demolisherID,
                    destination: building.coordinate
                )
                let _ = moveCommand.execute(in: context)

                // Mark building as "pending demolition" - demolition will start when villagers arrive
                building.pendingDemolition = true

                debugLog("🚶 Villagers moving to \(building.buildingType.displayName) for demolition")
                debugLog("   From: (\(villagers.coordinate.q), \(villagers.coordinate.r))")
                debugLog("   To: (\(building.coordinate.q), \(building.coordinate.r))")
            } else {
                // Villagers already at building - start immediately
                villagers.assignTask(.demolishing(building), target: building.coordinate)
                demolisherEntity.isMoving = true
                building.startDemolition(demolishers: villagers.villagerCount)
                debugLog("🏚️ Started demolishing \(building.buildingType.displayName)")
            }
        } else {
            // No demolisher assigned - start demolition immediately
            building.startDemolition()
            debugLog("🏚️ Started demolishing \(building.buildingType.displayName)")
        }

        return .success
    }
}

// MARK: - Cancel Demolition Command

struct CancelDemolitionCommand: GameCommand, Codable {
    let id: UUID
    let timestamp: TimeInterval
    let playerID: UUID

    let buildingID: UUID

    static var commandType: CommandType { .cancelDemolition }

    enum CodingKeys: String, CodingKey {
        case id, timestamp, playerID, buildingID
    }

    init(playerID: UUID, buildingID: UUID) {
        self.id = UUID()
        self.timestamp = Date().timeIntervalSince1970
        self.playerID = playerID
        self.buildingID = buildingID
    }

    func validate(in context: CommandContext) -> CommandResult {
        guard let building = context.getBuilding(by: buildingID) else {
            return .failure(reason: "Building not found")
        }

        guard building.owner?.id == playerID else {
            return .failure(reason: "You don't own this building")
        }

        // Allow canceling pending demolitions too
        guard building.state == .demolishing || building.pendingDemolition else {
            return .failure(reason: "Building is not being demolished")
        }

        return .success
    }

    func execute(in context: CommandContext) -> CommandResult {
        guard let building = context.getBuilding(by: buildingID) else {
            return .failure(reason: "Building not found")
        }

        // Cancel demolition
        building.cancelDemolition()

        debugLog("🚫 Cancelled demolition for \(building.buildingType.displayName)")

        return .success
    }
}
