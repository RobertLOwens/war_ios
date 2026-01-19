// ============================================================================
// FILE: Grow2 Shared/Commands/GatherCommand.swift
// PURPOSE: Command to assign villagers to gather resources
// ============================================================================

import Foundation

struct GatherCommand: GameCommand {
    let id: UUID
    let timestamp: TimeInterval
    let playerID: UUID
    
    let villagerGroupID: UUID
    let resourceCoordinate: HexCoordinate
    
    static var commandType: CommandType { .gather }
    
    init(playerID: UUID, villagerGroupID: UUID, resourceCoordinate: HexCoordinate) {
        self.id = UUID()
        self.timestamp = Date().timeIntervalSince1970
        self.playerID = playerID
        self.villagerGroupID = villagerGroupID
        self.resourceCoordinate = resourceCoordinate
    }
    
    func validate(in context: CommandContext) -> CommandResult {
        guard let entity = context.getEntity(by: villagerGroupID),
              let villagers = entity.entity as? VillagerGroup else {
            return .failure(reason: "Villager group not found")
        }
        
        guard villagers.owner?.id == playerID else {
            return .failure(reason: "You don't own these villagers")
        }
        
        guard villagers.currentTask == .idle else {
            return .failure(reason: "Villagers are busy with another task")
        }
        
        guard let resource = context.hexMap.getResourcePoint(at: resourceCoordinate) else {
            return .failure(reason: "No resource at this location")
        }
        
        guard resource.resourceType.isGatherable && !resource.isDepleted() else {
            return .failure(reason: "This resource cannot be gathered")
        }
        
        return .success
    }
    
    func execute(in context: CommandContext) -> CommandResult {
        guard let entity = context.getEntity(by: villagerGroupID),
              let villagers = entity.entity as? VillagerGroup,
              let resource = context.hexMap.getResourcePoint(at: resourceCoordinate),
              let player = context.getPlayer(by: playerID) else {
            return .failure(reason: "Required objects not found")
        }
        
        // Assign gathering task
        villagers.assignTask(.gatheringResource(resource), target: resourceCoordinate)
        entity.isMoving = true
        
        if villagers.coordinate != resourceCoordinate {
            let moveCommand = MoveCommand(
                playerID: playerID,
                entityID: villagerGroupID,
                destination: resourceCoordinate
            )
            let _ = moveCommand.execute(in: context)
            print("🚶 Moving \(villagers.name) to resource at (\(resourceCoordinate.q), \(resourceCoordinate.r))")
        }
        
        // Add villagers to resource's assigned list
        resource.startGathering(by: villagers)
        
        // Update collection rate
        let rateContribution = 0.2 * Double(villagers.villagerCount)
        player.increaseCollectionRate(resource.resourceType.resourceYield, amount: rateContribution)
        
        context.onResourcesChanged?()
        
        print("⛏️ Assigned \(villagers.villagerCount) villagers to gather \(resource.resourceType.displayName)")
        
        return .success
    }
}

// MARK: - Stop Gathering

struct StopGatheringCommand: GameCommand {
    let id: UUID
    let timestamp: TimeInterval
    let playerID: UUID
    
    let villagerGroupID: UUID
    
    static var commandType: CommandType { .stopGathering }
    
    init(playerID: UUID, villagerGroupID: UUID) {
        self.id = UUID()
        self.timestamp = Date().timeIntervalSince1970
        self.playerID = playerID
        self.villagerGroupID = villagerGroupID
    }
    
    func validate(in context: CommandContext) -> CommandResult {
        guard let entity = context.getEntity(by: villagerGroupID),
              let villagers = entity.entity as? VillagerGroup else {
            return .failure(reason: "Villager group not found")
        }
        
        guard villagers.owner?.id == playerID else {
            return .failure(reason: "You don't own these villagers")
        }
        
        guard case .gatheringResource = villagers.currentTask else {
            return .failure(reason: "Villagers are not gathering")
        }
        
        return .success
    }
    
    func execute(in context: CommandContext) -> CommandResult {
        guard let entity = context.getEntity(by: villagerGroupID),
              let villagers = entity.entity as? VillagerGroup,
              let player = context.getPlayer(by: playerID) else {
            return .failure(reason: "Required objects not found")
        }
        
        // Get the resource they were gathering
        if case .gatheringResource(let resource) = villagers.currentTask {
            // Remove from resource's list
            resource.stopGathering(by: villagers)
            
            // Decrease collection rate
            let rateContribution = 0.2 * Double(villagers.villagerCount)
            player.decreaseCollectionRate(resource.resourceType.resourceYield, amount: rateContribution)
        }
        
        // Clear task
        villagers.clearTask()
        entity.isMoving = false
        
        context.onResourcesChanged?()
        
        print("🛑 Stopped gathering for \(villagers.name)")
        
        return .success
    }
}
