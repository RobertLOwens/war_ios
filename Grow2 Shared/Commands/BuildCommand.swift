// ============================================================================
// FILE: Grow2 Shared/Commands/BuildCommand.swift
// PURPOSE: Command to construct a building
// ============================================================================

import Foundation

struct BuildCommand: GameCommand {
    let id: UUID
    let timestamp: TimeInterval
    let playerID: UUID
    
    let buildingType: BuildingType
    let coordinate: HexCoordinate
    let builderEntityID: UUID?
    
    static var commandType: CommandType { .build }
    
    init(playerID: UUID, buildingType: BuildingType, coordinate: HexCoordinate, builderEntityID: UUID? = nil) {
        self.id = UUID()
        self.timestamp = Date().timeIntervalSince1970
        self.playerID = playerID
        self.buildingType = buildingType
        self.coordinate = coordinate
        self.builderEntityID = builderEntityID
    }
    
    func validate(in context: CommandContext) -> CommandResult {
        guard let player = context.getPlayer(by: playerID) else {
            return .failure(reason: "Player not found")
        }
        
        // Check tile is valid for building
        guard let tile = context.hexMap.getTile(at: coordinate) else {
            return .failure(reason: "Invalid location")
        }
        
        // Check terrain allows building
        guard tile.terrain != .water && tile.terrain != .mountain else {
            return .failure(reason: "Cannot build on \(tile.terrain)")
        }
        
        // Check no building already exists
        if context.getBuilding(at: coordinate) != nil {
            return .failure(reason: "A building already exists here")
        }
        
        // Check City Center level requirement
        let ccLevel = player.getCityCenterLevel()
        if buildingType.requiredCityCenterLevel > ccLevel {
            return .failure(reason: "Requires City Center Level \(buildingType.requiredCityCenterLevel)")
        }
        
        // Check resources
        for (resourceType, amount) in buildingType.buildCost {
            if !player.hasResource(resourceType, amount: amount) {
                let current = player.getResource(resourceType)
                return .failure(reason: "Need \(amount) \(resourceType.displayName), have \(current)")
            }
        }
        
        // Special checks for camps
        if buildingType == .miningCamp {
            guard let resource = context.hexMap.getResourcePoint(at: coordinate),
                  resource.resourceType == .stoneQuarry || resource.resourceType == .oreMine else {
                return .failure(reason: "Mining Camps must be built on Stone or Ore deposits")
            }
        }
        
        if buildingType == .lumberCamp {
            guard let resource = context.hexMap.getResourcePoint(at: coordinate),
                  resource.resourceType == .trees else {
                return .failure(reason: "Lumber Camps must be built on Trees")
            }
        }
        
        return .success
    }
    
    func execute(in context: CommandContext) -> CommandResult {
        guard let player = context.getPlayer(by: playerID) else {
            return .failure(reason: "Player not found")
        }
        
        // Deduct resources
        for (resourceType, amount) in buildingType.buildCost {
            player.removeResource(resourceType, amount: amount)
        }
        
        // Create building
        let building = BuildingNode(coordinate: coordinate, buildingType: buildingType, owner: player)
        building.position = HexMap.hexToPixel(q: coordinate.q, r: coordinate.r)
        
        // Assign builder if provided
        if let builderID = builderEntityID,
           let builderEntity = context.getEntity(by: builderID),
           let villagers = builderEntity.entity as? VillagerGroup {
            building.builderEntity = builderEntity
            villagers.assignTask(.building(building), target: coordinate)
            builderEntity.isMoving = true
        }
        
        // Start construction
        building.startConstruction()
        
        let position = HexMap.hexToPixel(q: coordinate.q, r: coordinate.r)
        building.position = position
        building.zPosition = 5
        context.gameScene?.buildingsNode.addChild(building)
        
        // Add to map and player
        context.hexMap.addBuilding(building)
        player.addBuilding(building)
        
        // Remove resource if building on top of one (except for camps)
        if buildingType != .miningCamp && buildingType != .lumberCamp {
            if let resource = context.hexMap.getResourcePoint(at: coordinate) {
                context.hexMap.removeResourcePoint(resource)
                resource.removeFromParent()
            }
        }
        
        context.onResourcesChanged?()
        
        print("🏗️ Started building \(buildingType.displayName) at (\(coordinate.q), \(coordinate.r))")
        
        return .success
    }
}
