import UIKit
import SpriteKit

// MARK: - Game Scene

class GameScene: SKScene {
    var hexMap: HexMap!
    var mapNode: SKNode!
    var unitsNode: SKNode!
    var buildingsNode: SKNode!
    var entitiesNode: SKNode!
    var selectedTile: HexTileNode?
    var selectedUnit: UnitNode?
    var selectedEntity: EntityNode?
    var cameraNode: SKCameraNode!
    var showAlert: ((String, String) -> Void)?
    var showCombatTimer: ((CombatRecord, @escaping () -> Void) -> Void)?
    var attackingArmy: Army?
    var player: Player?
    var enemyPlayer: Player?
    var cameraScale: CGFloat = 1.0
    var lastTouchPosition: CGPoint?
    var isPanning = false
    var allGamePlayers: [Player] = []
    
    var lastUpdateTime: TimeInterval?
    
    // Callbacks for UI interactions
    var showTileMenu: ((HexCoordinate) -> Void)?
    var showEntitySelectionForMove: ((HexCoordinate, [EntityNode]) -> Void)?  // ← Must exist!
    var showBuildingMenu: ((HexCoordinate, EntityNode?) -> Void)?
    var updateResourceDisplay: (() -> Void)?
    
    override func didMove(to view: SKView) {
        setupScene()
        setupCamera()
        setupMap()
        spawnTestEntities()
        
    }
    
    func setupScene() {
        backgroundColor = UIColor(red: 0.15, green: 0.2, blue: 0.15, alpha: 1.0)
        scaleMode = .resizeFill
    }
    
    func setupCamera() {
        cameraNode = SKCameraNode()
        camera = cameraNode
        addChild(cameraNode)
        cameraNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
    }
    
    func setupMap() {
        mapNode?.removeFromParent()
        unitsNode?.removeFromParent()
        buildingsNode?.removeFromParent()
        entitiesNode?.removeFromParent()
        
        mapNode = SKNode()
        mapNode.name = "mapNode"
        addChild(mapNode)
        
        // ✅ NEW: Resources layer (between map and buildings)
        let resourcesNode = SKNode()
        resourcesNode.name = "resourcesNode"
        addChild(resourcesNode)
        
        buildingsNode = SKNode()
        buildingsNode.name = "buildingsNode"
        addChild(buildingsNode)
        
        entitiesNode = SKNode()
        entitiesNode.name = "entitiesNode"
        addChild(entitiesNode)
        
        unitsNode = SKNode()
        unitsNode.name = "unitsNode"
        addChild(unitsNode)
        
        hexMap = HexMap(width: 20, height: 20)
        // ✅ CHANGED: Use varied terrain instead of uniform grass
        hexMap.generateVariedTerrain()
        
        for (coord, tile) in hexMap.tiles {
            let position = HexMap.hexToPixel(q: coord.q, r: coord.r)
            tile.position = position
            mapNode.addChild(tile)
        }
        
        // ✅ NEW: Spawn resources
        hexMap.spawnResources(scene: resourcesNode)
        
        let mapCenter = HexMap.hexToPixel(q: hexMap.width / 2, r: hexMap.height / 2)
        cameraNode.position = mapCenter
    }
    
    func spawnTestEntities() {
        guard let player = player else { return }
        
        // Create villager group - OWNED BY PLAYER
        let villagerGroup = VillagerGroup(
            name: "Villager Group 1",
            coordinate: HexCoordinate(q: 10, r: 10),
            villagerCount: 5,
            owner: player
        )
        
        // ✅ Pass the VillagerGroup directly as the entity
        let villagerNode = EntityNode(
            coordinate: HexCoordinate(q: 10, r: 10),
            entityType: .villagerGroup,
            entity: villagerGroup,  // ✅ Direct reference
            currentPlayer: player
        )
        let position = HexMap.hexToPixel(q: 10, r: 10)
        villagerNode.position = position
        
        hexMap.addEntity(villagerNode)
        entitiesNode.addChild(villagerNode)
        player.addEntity(villagerGroup)
        
        // Create starter army - OWNED BY PLAYER
        let starterArmy = Army(
            name: "1st Army",
            coordinate: HexCoordinate(q: 8, r: 8),
            commander: Commander(name: "Rob", specialty: .infantry),
            owner: player
        )
        
        starterArmy.addMilitaryUnits(.swordsman, count: 10)
        starterArmy.addMilitaryUnits(.archer, count: 5)
        
        // ✅ Pass the Army directly as the entity
        let armyNode = EntityNode(
            coordinate: HexCoordinate(q: 8, r: 8),
            entityType: .army,
            entity: starterArmy,  // ✅ Direct reference
            currentPlayer: player
        )
        let armyPosition = HexMap.hexToPixel(q: 8, r: 8)
        armyNode.position = armyPosition
        
        hexMap.addEntity(armyNode)
        entitiesNode.addChild(armyNode)
        player.addEntity(starterArmy)
        player.addArmy(starterArmy)
        
        // 🔴 CREATE ENEMY PLAYER AND ARMY
        let enemyPlayer = Player(name: "Enemy AI", color: .red)
        player.setDiplomacyStatus(with: enemyPlayer, status: .enemy)
        
        let enemyArmy = Army(
            name: "Enemy Raiders",
            coordinate: HexCoordinate(q: 15, r: 15),
            commander: Commander(name: "Blackfang", specialty: .cavalry),
            owner: enemyPlayer
        )
        
        enemyArmy.addMilitaryUnits(.swordsman, count: 8)
        enemyArmy.addMilitaryUnits(.knight, count: 3)
        
        let enemyArmyNode = EntityNode(
            coordinate: HexCoordinate(q: 15, r: 15),
            entityType: .army,
            entity: enemyArmy,  // ✅ Direct reference
            currentPlayer: player
        )
        let enemyPosition = HexMap.hexToPixel(q: 15, r: 15)
        enemyArmyNode.position = enemyPosition
        
        hexMap.addEntity(enemyArmyNode)
        entitiesNode.addChild(enemyArmyNode)
        enemyPlayer.addEntity(enemyArmy)
        enemyPlayer.addArmy(enemyArmy)
        
        // 🟣 CREATE GUILD PLAYER AND ARMY
        let guildPlayer = Player(name: "Guild Ally", color: .purple)
        player.setDiplomacyStatus(with: guildPlayer, status: .guild)
        
        let guildArmy = Army(
            name: "Guild Defenders",
            coordinate: HexCoordinate(q: 5, r: 15),
            commander: Commander(name: "Guildmaster Thorne", specialty: .defensive),
            owner: guildPlayer
        )
        guildArmy.addMilitaryUnits(.swordsman, count: 12)
        guildArmy.addMilitaryUnits(.pikeman, count: 6)
        
        let guildArmyNode = EntityNode(
            coordinate: HexCoordinate(q: 5, r: 15),
            entityType: .army,
            entity: guildArmy,  // ✅ Direct reference
            currentPlayer: player
        )
        guildArmyNode.position = HexMap.hexToPixel(q: 5, r: 15)
        
        hexMap.addEntity(guildArmyNode)
        entitiesNode.addChild(guildArmyNode)
        guildPlayer.addEntity(guildArmy)
        guildPlayer.addArmy(guildArmy)
        
        // 🟢 CREATE ALLY PLAYER AND ARMY
        let allyPlayer = Player(name: "Allied Forces", color: .green)
        player.setDiplomacyStatus(with: allyPlayer, status: .ally)
        
        let allyArmy = Army(
            name: "Allied Knights",
            coordinate: HexCoordinate(q: 15, r: 5),
            commander: Commander(name: "Sir Galahad", specialty: .cavalry),
            owner: allyPlayer
        )
        allyArmy.addMilitaryUnits(.knight, count: 8)
        allyArmy.addMilitaryUnits(.archer, count: 4)
        
        let allyArmyNode = EntityNode(
            coordinate: HexCoordinate(q: 15, r: 5),
            entityType: .army,
            entity: allyArmy,  // ✅ Direct reference
            currentPlayer: player
        )
        allyArmyNode.position = HexMap.hexToPixel(q: 15, r: 5)
        
        hexMap.addEntity(allyArmyNode)
        entitiesNode.addChild(allyArmyNode)
        allyPlayer.addEntity(allyArmy)
        allyPlayer.addArmy(allyArmy)
        
        // 🟠 CREATE NEUTRAL PLAYER AND ARMY
        let neutralPlayer = Player(name: "Neutral Traders", color: .orange)
        player.setDiplomacyStatus(with: neutralPlayer, status: .neutral)
        
        let neutralArmy = Army(
            name: "Merchant Caravan",
            coordinate: HexCoordinate(q: 5, r: 5),
            commander: Commander(name: "Merchant Prince", specialty: .logistics),
            owner: neutralPlayer
        )
        neutralArmy.addMilitaryUnits(.swordsman, count: 5)
        
        let neutralArmyNode = EntityNode(
            coordinate: HexCoordinate(q: 5, r: 5),
            entityType: .army,
            entity: neutralArmy,  // ✅ Direct reference
            currentPlayer: player
        )
        neutralArmyNode.position = HexMap.hexToPixel(q: 5, r: 5)
        
        hexMap.addEntity(neutralArmyNode)
        entitiesNode.addChild(neutralArmyNode)
        neutralPlayer.addEntity(neutralArmy)
        neutralPlayer.addArmy(neutralArmy)
        
        print("✅ Spawned all test entities with diplomacy:")
        print("  🔵 Player Army at (8, 8)")
        print("  🔵 Player Villagers at (10, 10)")
        print("  🔴 Enemy Army at (15, 15)")
        print("  🟣 Guild Army at (5, 15)")
        print("  🟢 Ally Army at (15, 5)")
        print("  🟠 Neutral Army at (5, 5)")
        
        self.enemyPlayer = enemyPlayer
        
        // ✅ UPDATED: Store all players
        self.allGamePlayers = [player, enemyPlayer, guildPlayer, allyPlayer, neutralPlayer]
        
        // ✅ Force initial fog of war update with all players
        player.updateVision(allPlayers: allGamePlayers)
        hexMap.updateFogOverlays(for: player)
        
        // Update visibility for all entities
        for entity in hexMap.entities {
            entity.updateVisibility(for: player)
        }
        
        print("👁️ Initial fog of war updated with shared vision")
        
    }


    
    func selectEntity(_ entity: EntityNode) {
        selectedEntity = nil
        selectedUnit = nil
        selectedTile?.isSelected = false
        selectedTile = nil
        
        selectedEntity = entity
        
        if let tile = hexMap.getTile(at: entity.coordinate) {
            tile.isSelected = true
            selectedTile = tile
        }
        
        print("Selected \(entity.entityType.displayName) at q:\(entity.coordinate.q), r:\(entity.coordinate.r)")
        
        // ✅ FIX: Always call showTileMenu, which will detect entity type and show appropriate options
        showTileMenu?(entity.coordinate)
    }

    
    override func update(_ currentTime: TimeInterval) {
        let realWorldTime = Date().timeIntervalSince1970
        
        // Update player resources & Fog of war
        if let player = player {
            player.updateResources(currentTime: realWorldTime)
            
            // ✅ SIMPLIFIED: Use stored allGamePlayers
            player.updateVision(allPlayers: allGamePlayers)
            hexMap.updateFogOverlays(for: player)
            
            // Update entity visibility
            for entity in hexMap.entities {
                entity.updateVisibility(for: player)
            }
            
            // Update building visibility
            for building in hexMap.buildings {
                let displayMode = player.fogOfWar?.shouldShowBuilding(building, at: building.coordinate) ?? .hidden
                building.updateVisibility(displayMode: displayMode)
            }
            
            if lastUpdateTime == nil || currentTime - lastUpdateTime! >= 0.5 {
                updateResourceDisplay?()
                lastUpdateTime = currentTime
            }
        }
        
        // Update building construction and timers
        for building in hexMap.buildings {
            if building.state == .constructing {
                building.updateConstruction()
                building.updateTimerLabel()
            }
            
            if building.state == .completed {
                building.updateTraining(currentTime: realWorldTime)
                building.updateVillagerTraining(currentTime: realWorldTime)
            }
        }
        
        // Check and clear completed building tasks
        if let player = player {
            for villagerGroup in player.getVillagerGroups() {
                if case .building(let building) = villagerGroup.currentTask {
                    if building.state == .completed || building.state == .destroyed {
                        villagerGroup.clearTask()
                        print("✅ Auto-cleared completed building task for villager group")
                    }
                }
            }
        }
    }
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        lastTouchPosition = location
        isPanning = false
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        if let lastPos = lastTouchPosition {
            let delta = CGPoint(x: location.x - lastPos.x, y: location.y - lastPos.y)
            let distance = sqrt(delta.x * delta.x + delta.y * delta.y)
            
            if distance > 10 {
                isPanning = true
            }
            
            if isPanning {
                cameraNode.position.x -= delta.x
                cameraNode.position.y -= delta.y
            }
        }
        
        lastTouchPosition = location
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        if !isPanning {
            handleTouch(at: location)
        }
        
        lastTouchPosition = nil
        isPanning = false
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        lastTouchPosition = nil
        isPanning = false
    }
    
    func handleTouch(at location: CGPoint) {
        let nodesAtPoint = nodes(at: location)
        
        for node in nodesAtPoint {
            if let hexTile = node as? HexTileNode {
                // ADD THIS CHECK:
                guard let player = player,
                      player.isExplored(hexTile.coordinate) else {
                    print("Cannot interact with unexplored tile")
                    return
                }
                
                selectTile(hexTile)
                return
            }
        }
    }

    
    func selectTile(_ tile: HexTileNode) {
        // Check if we're in attack mode
        if let attacker = attackingArmy {
            executeAttack(attacker: attacker, targetCoordinate: tile.coordinate)
            attackingArmy = nil
            deselectAll()
            return
        }
        
        // If we have a selected entity, this is a move command
        if let entity = selectedEntity {
            moveEntity(entity, to: tile.coordinate)
            deselectAll()
            return
        }
        
        if let unit = selectedUnit {
            moveUnit(unit, to: tile.coordinate)
            deselectAll()
            return
        }
        
        // Otherwise, select the tile and show menu
        selectedTile?.isSelected = false
        selectedUnit = nil
        selectedEntity = nil
        
        tile.isSelected = true
        selectedTile = tile
        
        print("Selected tile at q:\(tile.coordinate.q), r:\(tile.coordinate.r)")
        
        showTileMenu?(tile.coordinate)
    }
    
    func deselectAll() {
        selectedTile?.isSelected = false
        selectedTile = nil
    }
    
    func initiateMove(to destination: HexCoordinate) {
        print("🔍 initiateMove called")
        print("   Destination: (\(destination.q), \(destination.r))")
        
        // ✅ Get all player-owned, non-moving entities
        let availableEntities = hexMap.entities.filter {
            !$0.isMoving && $0.entity.owner?.id == player?.id
        }
        print("   Available player entities: \(availableEntities.count)")
        
        guard !availableEntities.isEmpty else {
            print("❌ No entities available to move")
            showAlert?("Cannot Move", "You don't have any units available to move.")
            return
        }
        
        // ✅ Use the dedicated move menu that doesn't open entity action menus
        print("✅ Calling showMoveSelectionMenu...")
        showEntitySelectionForMove?(destination, availableEntities)
    }

    func moveEntity(_ entity: EntityNode, to destination: HexCoordinate) {
        // ✅ CHECK 1: Only allow moving your own entities
        let diplomacyStatus = player?.getDiplomacyStatus(with: entity.entity.owner) ?? .neutral
        if diplomacyStatus != .me {
            print("❌ Cannot move entities you don't own")
            showAlert?("Cannot Move", "You can only move your own units!")
            return
        }
        
        // ✅ CHECK 2: Cannot move onto enemy tiles
        if let entityAtDestination = hexMap.getEntity(at: destination) {
            let destDiplomacy = player?.getDiplomacyStatus(with: entityAtDestination.entity.owner) ?? .neutral
            if destDiplomacy == .enemy {
                print("❌ Cannot move onto enemy-occupied tile")
                showAlert?("Cannot Move", "Cannot move onto an enemy-occupied tile! Use the Attack command instead.")
                return
            }
        }
        
        // Check if entity is currently building
        if entity.isMoving {
            if let villagerGroup = entity.entity as? VillagerGroup,
               case .building(let building) = villagerGroup.currentTask {
                
                if building.state == .completed {
                    entity.isMoving = false
                    villagerGroup.clearTask()
                    print("✅ Fixed: Unlocked villagers from completed building")
                } else {
                    let progress = Int(building.constructionProgress * 100)
                    print("❌ Villagers are busy building (\(progress)%)")
                    showAlert?("Cannot Move", "These villagers are busy constructing \(building.buildingType.displayName) (\(progress)% complete) and cannot move until construction is complete.")
                    return
                }
            } else {
                print("❌ Entity is already moving")
                showAlert?("Cannot Move", "This entity is already on the move.")
                return
            }
        }
        
        guard let path = hexMap.findPath(from: entity.coordinate, to: destination) else {
            print("❌ No valid path to destination")
            showAlert?("Cannot Move", "No valid path to the destination.")
            return
        }
        
        print("✅ Moving \(entity.entityType.displayName) from (\(entity.coordinate.q), \(entity.coordinate.r)) to (\(destination.q), \(destination.r))")
        print("Path: \(path)")
        
        entity.moveTo(path: path) {
            print("✅ \(entity.entityType.displayName) arrived at destination")
        }
    }

    func moveUnit(_ unit: UnitNode, to destination: HexCoordinate) {
        guard let path = hexMap.findPath(from: unit.coordinate, to: destination) else {
            print("No valid path to destination")
            return
        }
        
        print("Moving \(unit.unitType.displayName) from (\(unit.coordinate.q), \(unit.coordinate.r)) to (\(destination.q), \(destination.r))")
        print("Path: \(path)")
        
        unit.moveTo(path: path) {
            print("\(unit.unitType.displayName) arrived at destination")
        }
    }
    
    func placeBuilding(type: BuildingType, at coordinate: HexCoordinate, owner: Player) {
        // Check if there's already a building on this tile
        if let existingBuilding = hexMap.getBuilding(at: coordinate) {
            print("❌ Building already exists at this location: \(existingBuilding.buildingType.displayName)")
            showAlert?("Cannot Build", "There is already a \(existingBuilding.buildingType.displayName) on this tile.")
            return
        }
        
        // Check if tile is valid for building
        guard hexMap.canPlaceBuilding(at: coordinate) else {
            print("❌ Cannot place building at this location")
            showAlert?("Cannot Build", "This location is blocked or not suitable for building.")
            return
        }
        
        // Check if player has enough resources
        var missingResources: [String] = []
        for (resourceType, amount) in type.buildCost {
            if !owner.hasResource(resourceType, amount: amount) {
                let current = owner.getResource(resourceType)
                missingResources.append("\(resourceType.icon) \(resourceType.displayName): need \(amount), have \(current)")
            }
        }
        
        if !missingResources.isEmpty {
            let message = "Insufficient resources:\n" + missingResources.joined(separator: "\n")
            showAlert?("Cannot Afford", message)
            return
        }
        
        // Find the villager group at this location
        guard let villagerEntity = hexMap.getEntity(at: coordinate),
              villagerEntity.entityType == .villagerGroup else {
            print("❌ No villager group at this location")
            showAlert?("Cannot Build", "You need a villager group at this location to build.")
            return
        }
        
        // Deduct resources
        for (resourceType, amount) in type.buildCost {
            owner.removeResource(resourceType, amount: amount)
        }
        
        // Create building
        let building = BuildingNode(coordinate: coordinate, buildingType: type, owner: owner)
        let position = HexMap.hexToPixel(q: coordinate.q, r: coordinate.r)
        building.position = position
        
        // ✅ Store reference to the builder entity
        building.builderEntity = villagerEntity
        
        // Start construction
        building.startConstruction()
        
        // Add to map and scene
        hexMap.addBuilding(building)
        buildingsNode.addChild(building)
        owner.addBuilding(building)
        
        // ✅ Mark villager entity as busy building
        villagerEntity.isMoving = true
        
        // ✅ Assign task to villager group
        if let villagerGroup = villagerEntity.entity as? VillagerGroup {
            villagerGroup.assignTask(.building(building), target: coordinate)
            print("✅ Assigned building task to \(villagerGroup.name)")
        }
        
        print("✅ Placed \(type.displayName) at (\(coordinate.q), \(coordinate.r))")
        print("✅ Villagers are now locked to this tile until construction completes")
        
        updateResourceDisplay?()
    }
    
    // This method is in GameScene.swift class
    func showBuildingInfo(_ building: BuildingNode) {
        var message = "\(building.buildingType.icon) \(building.buildingType.displayName)\n\n"
        
        switch building.state {
        case .planning:
            message += "Status: Planning\n"
        case .constructing:
            let progress = Int(building.constructionProgress * 100)
            message += "Status: Under Construction (\(progress)%)\n"
            if let startTime = building.constructionStartTime {
                let currentTime = Date().timeIntervalSince1970
                let elapsed = currentTime - startTime
                let buildSpeedMultiplier = 1.0 + (Double(building.buildersAssigned - 1) * 0.5)
                let effectiveBuildTime = building.buildingType.buildTime / buildSpeedMultiplier
                let remaining = max(0, effectiveBuildTime - elapsed)
                let minutes = Int(remaining) / 60
                let seconds = Int(remaining) % 60
                message += "Time Remaining: \(minutes)m \(seconds)s\n"
                message += "Builders: \(building.buildersAssigned)\n"
            }
        case .completed:
            message += "Status: Completed ✓\n"
            message += "Health: \(building.health)/\(building.maxHealth)\n"
            if let bonus = building.buildingType.resourceBonus {
                message += "\nProducing:\n"
                for (resourceType, amount) in bonus {
                    message += "+\(String(format: "%.1f", amount)) \(resourceType.displayName)/s\n"
                }
            }
        case .damaged:
            message += "Status: Damaged ⚠️\n"
            message += "Health: \(building.health)/\(building.maxHealth)\n"
        case .destroyed:
            message += "Status: Destroyed ❌\n"
        }
        
        message += "\n\(building.buildingType.description)"
        
        showTileMenu?(building.coordinate)
    }
    
    func updateBuildingTimers() {
        for building in hexMap.buildings {
            if building.state == .constructing {
                building.updateTimerLabel()
            }
        }
    }
    
    func initiateAttack(attacker: Army) {
        attackingArmy = attacker
        print("🎯 Attack mode activated for \(attacker.name)")
        print("   Select an enemy target to attack")
    }

    func executeAttack(attacker: Army, targetCoordinate: HexCoordinate) {
        // Find target at coordinate
        var target: Any? = nil
        
        // Check for enemy entity
        if let targetEntity = hexMap.getEntity(at: targetCoordinate) {
            if targetEntity.entity.owner?.id != attacker.owner?.id {
                if let targetArmy = targetEntity.entity as? Army {
                    target = targetArmy
                } else if let targetVillagers = targetEntity.entity as? VillagerGroup {
                    target = targetVillagers
                }
            }
        }
        
        // Check for enemy building
        if target == nil, let building = hexMap.getBuilding(at: targetCoordinate) {
            if building.owner?.id != attacker.owner?.id {
                target = building
            }
        }
        
        guard let finalTarget = target else {
            print("❌ No valid target at location")
            return
        }
        
        // Move army to adjacent tile
        guard let adjacentTile = hexMap.findNearestWalkable(to: targetCoordinate, maxDistance: 1) else {
            print("❌ Cannot reach target")
            return
        }
        
        // Find attacker entity node
        guard let attackerNode = hexMap.entities.first(where: {
            ($0.entity as? Army)?.id == attacker.id
        }) else {
            print("❌ Attacker node not found")
            return
        }
        
        // Move to attack
        print("⚔️ \(attacker.name) moving to attack at (\(targetCoordinate.q), \(targetCoordinate.r))")
        moveEntity(attackerNode, to: adjacentTile)
        
        // Wait for movement to complete, then start combat
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.startCombat(attacker: attacker, target: finalTarget, location: targetCoordinate)
        }
    }

    func startCombat(attacker: Army, target: Any, location: HexCoordinate) {
        print("⚔️ COMBAT STARTED!")
        
        // Calculate combat
        let record = CombatSystem.shared.calculateCombat(
            attacker: attacker,
            defender: target,
            defenderCoordinate: location
        )
        
        // Show combat timer
        showCombatTimer?(record) { [weak self] in
            // Apply results after timer completes
            CombatSystem.shared.applyCombatResults(
                record: record,
                attacker: attacker,
                defender: target
            )
            
            // Clean up destroyed entities
            self?.cleanupAfterCombat(attacker: attacker, defender: target)
            
            print("✅ Combat completed: \(record.winner.displayName)")
        }
    }

    func cleanupAfterCombat(attacker: Army, defender: Any) {
        // Remove attacker if destroyed
        if attacker.getTotalUnits() <= 0 {
            if let node = hexMap.entities.first(where: { ($0.entity as? Army)?.id == attacker.id }) {
                hexMap.removeEntity(node)
                node.removeFromParent()
                attacker.owner?.removeArmy(attacker)
                print("💀 \(attacker.name) was destroyed")
            }
        }
        
        // Remove defender if destroyed
        if let defenderArmy = defender as? Army {
            if defenderArmy.getTotalUnits() <= 0 {
                if let node = hexMap.entities.first(where: { ($0.entity as? Army)?.id == defenderArmy.id }) {
                    hexMap.removeEntity(node)
                    node.removeFromParent()
                    defenderArmy.owner?.removeArmy(defenderArmy)
                    print("💀 \(defenderArmy.name) was destroyed")
                }
            }
        } else if let building = defender as? BuildingNode {
            if building.state == .destroyed {
                hexMap.removeBuilding(building)
                building.removeFromParent()
                building.owner?.removeBuilding(building)
                print("💀 \(building.buildingType.displayName) was destroyed")
            }
        } else if let villagers = defender as? VillagerGroup {
            if !villagers.hasVillagers() {
                if let node = hexMap.entities.first(where: { ($0.entity as? VillagerGroup)?.id == villagers.id }) {
                    hexMap.removeEntity(node)
                    node.removeFromParent()
                    villagers.owner?.removeEntity(villagers)
                    print("💀 \(villagers.name) was destroyed")
                }
            }
        }
    }
}
