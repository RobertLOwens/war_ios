// ============================================================================
// FILE: UpgradeCommand.swift
// LOCATION: Grow2 Shared/Commands/UpgradeCommand.swift
// PURPOSE: Commands for building upgrades (upgrade and cancel)
//          Now requires villagers to move to building before upgrading
// ============================================================================

import Foundation

// MARK: - Upgrade Building Command

struct UpgradeCommand: GameCommand, Codable {
    let id: UUID
    let timestamp: TimeInterval
    let playerID: UUID
    
    let buildingID: UUID
    let upgraderEntityID: UUID?
    
    static var commandType: CommandType { .upgrade }
    
    enum CodingKeys: String, CodingKey {
        case id, timestamp, playerID, buildingID, upgraderEntityID
    }
    
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

        // Apply terrain cost multiplier for mountains
        let terrainMultiplier = Self.getTerrainCostMultiplier(for: building, in: context.hexMap)

        // Check resources with terrain-adjusted costs
        for (resourceType, baseAmount) in upgradeCost {
            let adjustedAmount = Int(ceil(Double(baseAmount) * terrainMultiplier))
            if !player.hasResource(resourceType, amount: adjustedAmount) {
                return .failure(reason: "Insufficient \(resourceType.displayName)")
            }
        }
        
        // ✅ NEW: Check if upgrader entity is provided
        if let upgraderID = upgraderEntityID {
            guard let upgraderEntity = context.getEntity(by: upgraderID),
                  let villagers = upgraderEntity.entity as? VillagerGroup else {
                return .failure(reason: "Villager group not found")
            }
            
            // Check villagers aren't busy with another task
            if villagers.currentTask != .idle {
                return .failure(reason: "Villagers are busy with another task")
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

        // Apply terrain cost multiplier for mountains
        let terrainMultiplier = Self.getTerrainCostMultiplier(for: building, in: context.hexMap)

        // Deduct resources immediately (with terrain-adjusted costs)
        for (resourceType, baseAmount) in upgradeCost {
            let adjustedAmount = Int(ceil(Double(baseAmount) * terrainMultiplier))
            player.removeResource(resourceType, amount: adjustedAmount)
        }
        
        // Assign upgrader if provided
        if let upgraderID = upgraderEntityID,
           let upgraderEntity = context.getEntity(by: upgraderID),
           let villagers = upgraderEntity.entity as? VillagerGroup {
            
            building.upgraderEntity = upgraderEntity
            
            // ✅ FIX: Check if villagers need to move to the building first
            if villagers.coordinate != building.coordinate {
                // Assign upgrading task (will complete when they arrive)
                villagers.assignTask(.upgrading(building), target: building.coordinate)
                upgraderEntity.isMoving = true
                
                // Execute move command to get them there
                let moveCommand = MoveCommand(
                    playerID: playerID,
                    entityID: upgraderID,
                    destination: building.coordinate
                )
                let _ = moveCommand.execute(in: context)
                
                // ✅ Mark building as "pending upgrade" - upgrade will start when villagers arrive
                building.pendingUpgrade = true
                
                debugLog("🚶 Villagers moving to \(building.buildingType.displayName) for upgrade")
                debugLog("   From: (\(villagers.coordinate.q), \(villagers.coordinate.r))")
                debugLog("   To: (\(building.coordinate.q), \(building.coordinate.r))")
            } else {
                // Villagers already at building - start immediately
                villagers.assignTask(.upgrading(building), target: building.coordinate)
                upgraderEntity.isMoving = true
                building.startUpgrade()
                debugLog("⬆️ Started upgrading \(building.buildingType.displayName) to Lv.\(building.level + 1)")
            }
        } else {
            // No upgrader assigned - start upgrade immediately (for buildings that don't need workers)
            building.startUpgrade()
            debugLog("⬆️ Started upgrading \(building.buildingType.displayName) to Lv.\(building.level + 1)")
        }
        
        context.onResourcesChanged?()

        return .success
    }

    static func getTerrainCostMultiplier(for building: BuildingNode, in hexMap: HexMap) -> Double {
        let occupiedCoords = building.data.occupiedCoordinates
        let hasAnyMountainTile = occupiedCoords.contains { coord in
            hexMap.getTile(at: coord)?.terrain == .mountain
        }
        return hasAnyMountainTile ? GameConfig.Terrain.mountainBuildingCostMultiplier : 1.0
    }
}

// MARK: - Cancel Upgrade Command

struct CancelUpgradeCommand: GameCommand, Codable {
    let id: UUID
    let timestamp: TimeInterval
    let playerID: UUID
    
    let buildingID: UUID
    
    static var commandType: CommandType { .cancelUpgrade }
    
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
        
        // ✅ Allow canceling pending upgrades too
        guard building.state == .upgrading || building.pendingUpgrade else {
            return .failure(reason: "Building is not upgrading")
        }
        
        return .success
    }
    
    func execute(in context: CommandContext) -> CommandResult {
        guard let player = context.getPlayer(by: playerID),
              let building = context.getBuilding(by: buildingID) else {
            return .failure(reason: "Required objects not found")
        }

        // Apply terrain cost multiplier so refund matches what was actually charged
        let terrainMultiplier = UpgradeCommand.getTerrainCostMultiplier(for: building, in: context.hexMap)

        // Cancel and get refund (base costs, then apply terrain multiplier)
        if let refund = building.cancelUpgrade() {
            for (resourceType, baseAmount) in refund {
                let adjustedAmount = Int(ceil(Double(baseAmount) * terrainMultiplier))
                player.addResource(resourceType, amount: adjustedAmount)
            }
        }

        // Clear pending upgrade flag
        building.pendingUpgrade = false

        context.onResourcesChanged?()

        debugLog("🚫 Cancelled upgrade for \(building.buildingType.displayName)")

        return .success
    }
}
