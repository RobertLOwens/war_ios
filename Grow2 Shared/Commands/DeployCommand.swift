// ============================================================================
// FILE: Grow2 Shared/Commands/DeployCommands.swift
// PURPOSE: Commands for deploying units from buildings
// ============================================================================

import Foundation

// MARK: - Deploy Army

struct DeployArmyCommand: GameCommand {
    let id: UUID
    let timestamp: TimeInterval
    let playerID: UUID
    
    let buildingID: UUID
    let units: [MilitaryUnitType: Int]
    
    static var commandType: CommandType { .deployArmy }
    
    init(playerID: UUID, buildingID: UUID, units: [MilitaryUnitType: Int]) {
        self.id = UUID()
        self.timestamp = Date().timeIntervalSince1970
        self.playerID = playerID
        self.buildingID = buildingID
        self.units = units
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

        // Check army limit
        if let error = player.getArmySpawnError() {
            return .failure(reason: error)
        }

        // Check building has enough units
        for (unitType, count) in units {
            let available = building.getGarrisonCount(of: unitType)
            if available < count {
                return .failure(reason: "Not enough \(unitType.displayName) in garrison")
            }
        }

        // Check we can find a spawn location
        guard context.hexMap.findNearestWalkable(to: building.coordinate) != nil else {
            return .failure(reason: "No valid spawn location")
        }

        return .success
    }

    func execute(in context: CommandContext) -> CommandResult {
        guard let player = context.getPlayer(by: playerID),
              let building = context.getBuilding(by: buildingID),
              let spawnCoord = context.hexMap.findNearestWalkable(to: building.coordinate) else {
            return .failure(reason: "Required objects not found")
        }

        // Create commander
        let commander = Commander.createRandom()
        
        // Create army
        let army = Army(name: "Army", coordinate: spawnCoord, commander: commander, owner: player)
        
        // Transfer units
        for (unitType, count) in units {
            let removed = building.removeFromGarrison(unitType: unitType, quantity: count)
            if removed > 0 {
                army.addMilitaryUnits(unitType, count: removed)
            }
        }
        
        // Create entity node - pass actual Army object so armyReference is set correctly
        let armyNode = EntityNode(coordinate: spawnCoord, entityType: .army, entity: army, currentPlayer: context.getPlayer(by: playerID))
        armyNode.position = HexMap.hexToPixel(q: spawnCoord.q, r: spawnCoord.r)
        
        // Add to game
        context.hexMap.addEntity(armyNode)
        player.addArmy(army)

        // Add visual sprite to scene
        context.gameScene?.entitiesNode.addChild(armyNode)

        // Setup health bar for combat visualization
        armyNode.setupHealthBar(currentPlayer: context.getPlayer(by: playerID))

        print("🛡️ Deployed army led by \(commander.name) with \(army.getTotalMilitaryUnits()) units")
        
        return .success
    }
}

// MARK: - Deploy Villagers

struct DeployVillagersCommand: GameCommand {
    let id: UUID
    let timestamp: TimeInterval
    let playerID: UUID
    
    let buildingID: UUID
    let count: Int
    
    static var commandType: CommandType { .deployVillagers }
    
    init(playerID: UUID, buildingID: UUID, count: Int) {
        self.id = UUID()
        self.timestamp = Date().timeIntervalSince1970
        self.playerID = playerID
        self.buildingID = buildingID
        self.count = count
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

        // Check villager group limit
        if let error = player.getVillagerGroupSpawnError() {
            return .failure(reason: error)
        }

        guard building.villagerGarrison >= count else {
            return .failure(reason: "Not enough villagers in garrison")
        }

        guard context.hexMap.findNearestWalkable(to: building.coordinate) != nil else {
            return .failure(reason: "No valid spawn location")
        }

        return .success
    }

    func execute(in context: CommandContext) -> CommandResult {
        guard let player = context.getPlayer(by: playerID),
              let building = context.getBuilding(by: buildingID),
              let spawnCoord = context.hexMap.findNearestWalkable(to: building.coordinate) else {
            return .failure(reason: "Required objects not found")
        }

        // Remove from garrison
        let removed = building.removeVillagersFromGarrison(quantity: count)
        guard removed > 0 else {
            return .failure(reason: "Could not remove villagers")
        }
        
        // Create villager group
        let villagers = VillagerGroup(
            name: "Villagers",
            coordinate: spawnCoord,
            villagerCount: removed,
            owner: player
        )
        
        let villagerNode = EntityNode(
            coordinate: spawnCoord,
            entityType: .villagerGroup,
            entity: villagers,
            currentPlayer: player
        )
        
        let position = HexMap.hexToPixel(q: spawnCoord.q, r: spawnCoord.r)
        villagerNode.position = position
        villagerNode.zPosition = 10

        // Add to hexMap tracking
        context.hexMap.addEntity(villagerNode)

        // ADD VISUAL SPRITE TO SCENE
        context.gameScene?.entitiesNode.addChild(villagerNode)

        // Add to player's entity list
        player.addEntity(villagers)
        
        villagerNode.position = HexMap.hexToPixel(q: spawnCoord.q, r: spawnCoord.r)
        
        // Add to game
        context.hexMap.addEntity(villagerNode)
        player.addEntity(villagers)
        
        print("👷 Deployed \(removed) villagers from \(building.buildingType.displayName)")
        
        return .success
    }
}
