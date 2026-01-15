// ============================================================================
// FILE: Grow2 Shared/Commands/UpgradeCommand.swift
// PURPOSE: Commands for building upgrades
// ============================================================================

import Foundation

// MARK: - Upgrade Building

struct UpgradeCommand: GameCommand {
    let id: UUID
    let timestamp: TimeInterval
    let playerID: UUID
    
    let buildingID: UUID
    let upgraderEntityID: UUID?
    
    static var commandType: CommandType { .upgrade }
    
    init(playerID: UUID, buildingID: UUID, upgraderEntityID: UUID? = nil) {
        self.id = UUID()
        self.timestamp = Date().timeIntervalSince1970
        self.playerID = playerID
        self.buildingID = buildingID
        self.upgraderEntityID = upgraderEntityID
    }
    
    func validate(in context: CommandContext) -> CommandResult {
        guard let player = context.getPlayer(by: playerID) else {
            return .failure(reason: "Player not found")
        }
        
        guard let building = context.getBuilding(by: buildingID) else {
            return .failure(reason: "Building not found")
        }
        
        guard building.owner?.id == playerID else {
            return .failure(reason: "You don't own this building")
        }
        
        guard building.canUpgrade else {
            if let reason = building.upgradeBlockedReason {
                return .failure(reason: reason)
            }
            return .failure(reason: "Cannot upgrade this building")
        }
        
        guard let upgradeCost = building.getUpgradeCost() else {
            return .failure(reason: "No upgrade available")
        }
        
        // Check resources
        for (resourceType, amount) in upgradeCost {
            if !player.hasResource(resourceType, amount: amount) {
                return .failure(reason: "Insufficient \(resourceType.displayName)")
            }
        }
        
        return .success
    }
    
    func execute(in context: CommandContext) -> CommandResult {
        guard let player = context.getPlayer(by: playerID),
              let building = context.getBuilding(by: buildingID),
              let upgradeCost = building.getUpgradeCost() else {
            return .failure(reason: "Required objects not found")
        }
        
        // Deduct resources
        for (resourceType, amount) in upgradeCost {
            player.removeResource(resourceType, amount: amount)
        }
        
        // Assign upgrader if provided
        if let upgraderID = upgraderEntityID,
           let upgraderEntity = context.getEntity(by: upgraderID),
           let villagers = upgraderEntity.entity as? VillagerGroup {
            building.upgraderEntity = upgraderEntity
            villagers.assignTask(.upgrading(building), target: building.coordinate)
            upgraderEntity.isMoving = true
        }
        
        // Start upgrade
        building.startUpgrade()
        
        context.onResourcesChanged?()
        
        print("⬆️ Started upgrading \(building.buildingType.displayName) to Lv.\(building.level + 1)")
        
        return .success
    }
}

// MARK: - Cancel Upgrade

struct CancelUpgradeCommand: GameCommand {
    let id: UUID
    let timestamp: TimeInterval
    let playerID: UUID
    
    let buildingID: UUID
    
    static var commandType: CommandType { .cancelUpgrade }
    
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
        
        guard building.state == .upgrading else {
            return .failure(reason: "Building is not upgrading")
        }
        
        return .success
    }
    
    func execute(in context: CommandContext) -> CommandResult {
        guard let player = context.getPlayer(by: playerID),
              let building = context.getBuilding(by: buildingID) else {
            return .failure(reason: "Required objects not found")
        }
        
        // Cancel and get refund
        if let refund = building.cancelUpgrade() {
            for (resourceType, amount) in refund {
                player.addResource(resourceType, amount: amount)
            }
        }
        
        context.onResourcesChanged?()
        
        print("🚫 Cancelled upgrade for \(building.buildingType.displayName)")
        
        return .success
    }
}
