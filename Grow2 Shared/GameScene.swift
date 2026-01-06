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
    var mapSize: Int = 20
    var resourceDensity: Double = 1.0
    var movementPathLine: SKShapeNode?
    
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
        initializeFogOfWar()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
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
        
        // Resources layer (between map and buildings)
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
        
        // Create map with configured size
        hexMap = HexMap(width: mapSize, height: mapSize)
        hexMap.generateVariedTerrain()
        
        for (coord, tile) in hexMap.tiles {
            let position = HexMap.hexToPixel(q: coord.q, r: coord.r)
            tile.position = position
            mapNode.addChild(tile)
        }
        
        // Spawn resources with density multiplier
        hexMap.spawnResourcesWithDensity(scene: resourcesNode, densityMultiplier: resourceDensity)
        
        let mapCenter = HexMap.hexToPixel(q: hexMap.width / 2, r: hexMap.height / 2)
        cameraNode.position = mapCenter
    }
    
    func debugFogState() {
        guard let player = player else {
            print("❌ DEBUG: No player")
            return
        }
        
        print("\n🔍 FOG DEBUG INFO:")
        print("   Player: \(player.name)")
        print("   FogOfWar exists: \(player.fogOfWar != nil)")
        print("   AllGamePlayers count: \(allGamePlayers.count)")
        print("   Total tiles: \(hexMap.tiles.count)")
        print("   Fog overlays: \(hexMap.fogOverlays.count)")
        print("   Buildings: \(hexMap.buildings.count)")
        print("   Entities: \(hexMap.entities.count)")
        
        // Check visibility of a few tiles
        let testCoords = [
            HexCoordinate(q: 3, r: 3),
            HexCoordinate(q: 5, r: 5),
            HexCoordinate(q: 10, r: 10)
        ]
        
        for coord in testCoords {
            let vis = player.getVisibilityLevel(at: coord)
            print("   Tile (\(coord.q), \(coord.r)): \(vis)")
        }
        print()
    }
    
    func spawnTestEntities() {
        guard let player = player else { return }
        
        // Calculate spawn positions (opposite corners)
        let playerSpawn = HexCoordinate(q: 3, r: 3)
        let aiSpawn = HexCoordinate(q: mapSize - 4, r: mapSize - 4)
        
        // ===== PLAYER SETUP =====
        
        // Player City Center
        let playerCityCenter = BuildingNode(coordinate: playerSpawn, buildingType: .cityCenter, owner: player)
        playerCityCenter.state = .completed
        let playerCityPos = HexMap.hexToPixel(q: playerSpawn.q, r: playerSpawn.r)
        playerCityCenter.position = playerCityPos
        hexMap.addBuilding(playerCityCenter)
        buildingsNode.addChild(playerCityCenter)
        player.addBuilding(playerCityCenter)
        
        // Player Villagers (adjacent to city center)
        let playerVillagerSpawn = HexCoordinate(q: playerSpawn.q + 1, r: playerSpawn.r)
        let playerVillagers = VillagerGroup(
            name: "Starter Villagers",
            coordinate: playerVillagerSpawn,
            villagerCount: 5,
            owner: player
        )
        
        let playerVillagerNode = EntityNode(
            coordinate: playerVillagerSpawn,
            entityType: .villagerGroup,
            entity: playerVillagers,
            currentPlayer: player
        )
        let playerVillagerPos = HexMap.hexToPixel(q: playerVillagerSpawn.q, r: playerVillagerSpawn.r)
        playerVillagerNode.position = playerVillagerPos
        
        hexMap.addEntity(playerVillagerNode)
        entitiesNode.addChild(playerVillagerNode)
        player.addEntity(playerVillagers)
        
        // ===== AI OPPONENT SETUP =====
        
        let aiPlayer = Player(name: "AI Opponent", color: .red)
        player.setDiplomacyStatus(with: aiPlayer, status: .enemy)
        
        // AI City Center
        let aiCityCenter = BuildingNode(coordinate: aiSpawn, buildingType: .cityCenter, owner: aiPlayer)
        aiCityCenter.state = .completed
        let aiCityPos = HexMap.hexToPixel(q: aiSpawn.q, r: aiSpawn.r)
        aiCityCenter.position = aiCityPos
        hexMap.addBuilding(aiCityCenter)
        buildingsNode.addChild(aiCityCenter)
        aiPlayer.addBuilding(aiCityCenter)
        
        // AI Villagers (adjacent to city center)
        let aiVillagerSpawn = HexCoordinate(q: aiSpawn.q - 1, r: aiSpawn.r)
        let aiVillagers = VillagerGroup(
            name: "AI Villagers",
            coordinate: aiVillagerSpawn,
            villagerCount: 5,
            owner: aiPlayer
        )
        
        let aiVillagerNode = EntityNode(
            coordinate: aiVillagerSpawn,
            entityType: .villagerGroup,
            entity: aiVillagers,
            currentPlayer: player
        )
        let aiVillagerPos = HexMap.hexToPixel(q: aiVillagerSpawn.q, r: aiVillagerSpawn.r)
        aiVillagerNode.position = aiVillagerPos
        
        hexMap.addEntity(aiVillagerNode)
        entitiesNode.addChild(aiVillagerNode)
        aiPlayer.addEntity(aiVillagers)
        
        // Store enemy player reference
        self.enemyPlayer = aiPlayer
        
        // ✅ Store all players (NO FOG INITIALIZATION HERE)
        self.allGamePlayers = [player, aiPlayer]
        
        print("✅ Game started!")
        print("  🔵 Player at (\(playerSpawn.q), \(playerSpawn.r))")
        print("  🔴 AI Opponent at (\(aiSpawn.q), \(aiSpawn.r))")
        print("  🗺️ Map Size: \(mapSize)x\(mapSize)")
        print("  💎 Resource Density: \(resourceDensity)x")
    }


    
//    func spawnTestEntities() {
//        guard let player = player else { return }
//        
//        // Create villager group - OWNED BY PLAYER
//        let villagerGroup = VillagerGroup(
//            name: "Villager Group 1",
//            coordinate: HexCoordinate(q: 10, r: 10),
//            villagerCount: 5,
//            owner: player
//        )
//        
//        // ✅ Pass the VillagerGroup directly as the entity
//        let villagerNode = EntityNode(
//            coordinate: HexCoordinate(q: 10, r: 10),
//            entityType: .villagerGroup,
//            entity: villagerGroup,  // ✅ Direct reference
//            currentPlayer: player
//        )
//        let position = HexMap.hexToPixel(q: 10, r: 10)
//        villagerNode.position = position
//        
//        hexMap.addEntity(villagerNode)
//        entitiesNode.addChild(villagerNode)
//        player.addEntity(villagerGroup)
//        
//        // Create starter army - OWNED BY PLAYER
//        let starterArmy = Army(
//            name: "1st Army",
//            coordinate: HexCoordinate(q: 8, r: 8),
//            commander: Commander(name: "Rob", specialty: .infantry),
//            owner: player
//        )
//        
//        starterArmy.addMilitaryUnits(.swordsman, count: 10)
//        starterArmy.addMilitaryUnits(.archer, count: 5)
//        
//        // ✅ Pass the Army directly as the entity
//        let armyNode = EntityNode(
//            coordinate: HexCoordinate(q: 8, r: 8),
//            entityType: .army,
//            entity: starterArmy,  // ✅ Direct reference
//            currentPlayer: player
//        )
//        let armyPosition = HexMap.hexToPixel(q: 8, r: 8)
//        armyNode.position = armyPosition
//        
//        hexMap.addEntity(armyNode)
//        entitiesNode.addChild(armyNode)
//        player.addEntity(starterArmy)
//        player.addArmy(starterArmy)
//        
//        // 🔴 CREATE ENEMY PLAYER AND ARMY
//        let enemyPlayer = Player(name: "Enemy AI", color: .red)
//        player.setDiplomacyStatus(with: enemyPlayer, status: .enemy)
//        
//        let enemyArmy = Army(
//            name: "Enemy Raiders",
//            coordinate: HexCoordinate(q: 15, r: 15),
//            commander: Commander(name: "Blackfang", specialty: .cavalry),
//            owner: enemyPlayer
//        )
//        
//        enemyArmy.addMilitaryUnits(.swordsman, count: 8)
//        enemyArmy.addMilitaryUnits(.knight, count: 3)
//        
//        let enemyArmyNode = EntityNode(
//            coordinate: HexCoordinate(q: 15, r: 15),
//            entityType: .army,
//            entity: enemyArmy,  // ✅ Direct reference
//            currentPlayer: player
//        )
//        let enemyPosition = HexMap.hexToPixel(q: 15, r: 15)
//        enemyArmyNode.position = enemyPosition
//        
//        hexMap.addEntity(enemyArmyNode)
//        entitiesNode.addChild(enemyArmyNode)
//        enemyPlayer.addEntity(enemyArmy)
//        enemyPlayer.addArmy(enemyArmy)
//        
//        // 🟣 CREATE GUILD PLAYER AND ARMY
//        let guildPlayer = Player(name: "Guild Ally", color: .purple)
//        player.setDiplomacyStatus(with: guildPlayer, status: .guild)
//        
//        let guildArmy = Army(
//            name: "Guild Defenders",
//            coordinate: HexCoordinate(q: 5, r: 15),
//            commander: Commander(name: "Guildmaster Thorne", specialty: .defensive),
//            owner: guildPlayer
//        )
//        guildArmy.addMilitaryUnits(.swordsman, count: 12)
//        guildArmy.addMilitaryUnits(.pikeman, count: 6)
//        
//        let guildArmyNode = EntityNode(
//            coordinate: HexCoordinate(q: 5, r: 15),
//            entityType: .army,
//            entity: guildArmy,  // ✅ Direct reference
//            currentPlayer: player
//        )
//        guildArmyNode.position = HexMap.hexToPixel(q: 5, r: 15)
//        
//        hexMap.addEntity(guildArmyNode)
//        entitiesNode.addChild(guildArmyNode)
//        guildPlayer.addEntity(guildArmy)
//        guildPlayer.addArmy(guildArmy)
//        
//        // 🟢 CREATE ALLY PLAYER AND ARMY
//        let allyPlayer = Player(name: "Allied Forces", color: .green)
//        player.setDiplomacyStatus(with: allyPlayer, status: .ally)
//        
//        let allyArmy = Army(
//            name: "Allied Knights",
//            coordinate: HexCoordinate(q: 15, r: 5),
//            commander: Commander(name: "Sir Galahad", specialty: .cavalry),
//            owner: allyPlayer
//        )
//        allyArmy.addMilitaryUnits(.knight, count: 8)
//        allyArmy.addMilitaryUnits(.archer, count: 4)
//        
//        let allyArmyNode = EntityNode(
//            coordinate: HexCoordinate(q: 15, r: 5),
//            entityType: .army,
//            entity: allyArmy,  // ✅ Direct reference
//            currentPlayer: player
//        )
//        allyArmyNode.position = HexMap.hexToPixel(q: 15, r: 5)
//        
//        hexMap.addEntity(allyArmyNode)
//        entitiesNode.addChild(allyArmyNode)
//        allyPlayer.addEntity(allyArmy)
//        allyPlayer.addArmy(allyArmy)
//        
//        // 🟠 CREATE NEUTRAL PLAYER AND ARMY
//        let neutralPlayer = Player(name: "Neutral Traders", color: .orange)
//        player.setDiplomacyStatus(with: neutralPlayer, status: .neutral)
//        
//        let neutralArmy = Army(
//            name: "Merchant Caravan",
//            coordinate: HexCoordinate(q: 5, r: 5),
//            commander: Commander(name: "Merchant Prince", specialty: .logistics),
//            owner: neutralPlayer
//        )
//        neutralArmy.addMilitaryUnits(.swordsman, count: 5)
//        
//        let neutralArmyNode = EntityNode(
//            coordinate: HexCoordinate(q: 5, r: 5),
//            entityType: .army,
//            entity: neutralArmy,  // ✅ Direct reference
//            currentPlayer: player
//        )
//        
//        neutralArmyNode.position = HexMap.hexToPixel(q: 5, r: 5)
//        
//        hexMap.addEntity(neutralArmyNode)
//        entitiesNode.addChild(neutralArmyNode)
//        neutralPlayer.addEntity(neutralArmy)
//        neutralPlayer.addArmy(neutralArmy)
//        
//        print("✅ Spawned all test entities with diplomacy:")
//          print("  🔵 Player Army at (8, 8)")
//          print("  🔵 Player Villagers at (10, 10)")
//          print("  🔴 Enemy Army at (15, 15)")
//          print("  🟣 Guild Army at (5, 15)")
//          print("  🟢 Ally Army at (15, 5)")
//          print("  🟠 Neutral Army at (5, 5)")
//              
//          self.enemyPlayer = enemyPlayer
//          self.allGamePlayers = [player, enemyPlayer, guildPlayer, allyPlayer, neutralPlayer]
//          
//          // ✅ NOW initialize fog of war AFTER entities exist
//          let fogNode = SKNode()
//          fogNode.name = "fogNode"
//          fogNode.zPosition = 100
//          addChild(fogNode)
//          
//          hexMap.setupFogOverlays(in: fogNode)
//          player.initializeFogOfWar(hexMap: hexMap)
//          
//          // ✅ Update vision with all players (this reveals tiles around entities)
//          player.updateVision(allPlayers: allGamePlayers)
//          
//          // ✅ Apply the fog overlays based on vision
//          hexMap.updateFogOverlays(for: player)
//          
//          // Update visibility for all entities
//          for entity in hexMap.entities {
//              entity.updateVisibility(for: player)
//          }
//          
//          // Update building visibility
//          for building in hexMap.buildings {
//              let displayMode = player.fogOfWar?.shouldShowBuilding(building, at: building.coordinate) ?? .hidden
//              building.updateVisibility(displayMode: displayMode)
//          }
//          
//          print("👁️ Fog of War initialized and updated")
//        
//    }


    
    func selectEntity(_ entity: EntityNode) {
        // ✅ FIX: Check if entity is actually visible
        guard let player = player else { return }
        
        let visibility = player.getVisibilityLevel(at: entity.coordinate)
        guard visibility == .visible else {
            print("❌ Cannot select entity in fog of war")
            showAlert?("Cannot Select", "This unit is not visible due to fog of war.")
            return
        }
        
        // ✅ FIX: Double-check entity visibility through fog system
        if let fogOfWar = player.fogOfWar {
            guard fogOfWar.shouldShowEntity(entity.entity, at: entity.coordinate) else {
                print("❌ Entity not visible according to fog of war")
                showAlert?("Cannot Select", "This unit is not visible.")
                return
            }
        }
        
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
        
        showTileMenu?(entity.coordinate)
    }


    
    override func update(_ currentTime: TimeInterval) {
        let realWorldTime = Date().timeIntervalSince1970
        
        if let player = player {
            player.updateResources(currentTime: realWorldTime)
            
            // Update vision every frame so it follows moving entities
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
            
            // Only update resource display periodically to avoid UI lag
            if lastUpdateTime == nil || currentTime - lastUpdateTime! >= 0.5 {
                updateResourceDisplay?()
                lastUpdateTime = currentTime
            }
        }
        
        // Update building construction and timers
        for building in hexMap.buildings {
            // ✅ Only update timers for buildings that are actually constructing
            if building.state == .constructing {
                building.updateTimerLabel()
            } else {
                // ✅ Ensure no timer elements exist on non-constructing buildings
                building.timerLabel?.removeFromParent()
                building.timerLabel = nil
                building.progressBar?.removeFromParent()
                building.progressBar = nil
            }
        }
        
        for building in hexMap.buildings where building.state == .completed {
            building.updateTraining(currentTime: realWorldTime)
            building.updateVillagerTraining(currentTime: realWorldTime)
        }
        
        // Resource gathering update
        if let player = player {
            for villagerGroup in player.getVillagerGroups() {
                if case .gatheringResource(let resourcePoint) = villagerGroup.currentTask {
                    if resourcePoint.isDepleted() || resourcePoint.parent == nil {
                        villagerGroup.clearTask()
                        resourcePoint.stopGathering()
                        
                        // ✅ ADD: Unlock the entity when gathering completes
                        if let entityNode = hexMap.entities.first(where: {
                            ($0.entity as? VillagerGroup)?.id == villagerGroup.id
                        }) {
                            entityNode.isMoving = false
                        }
                        
                        print("✅ Resource depleted, villagers now idle and unlocked")
                        continue
                    }
                    
                    if villagerGroup.coordinate == resourcePoint.coordinate {
                        let gatherAmount = Int(resourcePoint.resourceType.gatherRate * 0.5)
                        if gatherAmount > 0 {
                            let gathered = resourcePoint.gather(amount: gatherAmount)
                            player.addResource(resourcePoint.resourceType.resourceYield, amount: gathered)
                        }
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
        print("👆 touchesBegan at \(location)")
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        if let lastPos = lastTouchPosition {
            let delta = CGPoint(x: location.x - lastPos.x, y: location.y - lastPos.y)
            let distance = sqrt(delta.x * delta.x + delta.y * delta.y)
            
            if distance > 10 {
                isPanning = true
                print("📱 isPanning = true (distance: \(distance))")
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
        
        print("👆 touchesEnded at \(location), isPanning: \(isPanning)")
        
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
        
        print("🔍 Touch at location: \(location)")
        print("🔍 Found \(nodesAtPoint.count) nodes")
        for (index, node) in nodesAtPoint.enumerated() {
            print("   [\(index)] \(type(of: node)) - name: '\(node.name ?? "nil")' - zPos: \(node.zPosition)")
        }
        
        // ✅ ONLY look for HexTileNode - skip ALL other node types
        for node in nodesAtPoint {
            // Skip entities, resources, buildings - we ONLY want tiles
            if node is EntityNode {
                print("   ⏭️ Skipping EntityNode")
                continue
            }
            if node is ResourcePointNode {
                print("   ⏭️ Skipping ResourcePointNode")
                continue
            }
            if node is BuildingNode {
                print("   ⏭️ Skipping BuildingNode")
                continue
            }
            
            if let hexTile = node as? HexTileNode {
                print("   ✅ Found HexTileNode at (\(hexTile.coordinate.q), \(hexTile.coordinate.r))")
                guard let player = player else {
                    print("⚠️ No player reference")
                    return
                }
                
                let visibility = player.getVisibilityLevel(at: hexTile.coordinate)
                
                if visibility == .visible || visibility == .explored {
                    selectTile(hexTile)
                    return
                } else {
                    print("❌ Cannot interact with unexplored tile at (\(hexTile.coordinate.q), \(hexTile.coordinate.r))")
                    return
                }
            }
        }
        
        print("❌ No HexTileNode found in touch")
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
        
        // Check if entity is currently building or gathering
        if entity.isMoving {
            if let villagerGroup = entity.entity as? VillagerGroup {
                // ✅ ADD: Check for gathering task
                if case .gatheringResource(let resourcePoint) = villagerGroup.currentTask {
                    if !resourcePoint.isDepleted() && resourcePoint.parent != nil {
                        print("❌ Villagers are busy gathering")
                        showAlert?("Cannot Move", "These villagers are gathering \(resourcePoint.resourceType.displayName) and cannot move. Cancel the gathering task first.")
                        return
                    } else {
                        // Resource depleted, unlock them
                        entity.isMoving = false
                        villagerGroup.clearTask()
                    }
                }
                
                if case .building(let building) = villagerGroup.currentTask {
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
        
        // ✅ Draw static path in world coordinates
        drawStaticMovementPath(from: entity.coordinate, path: path)
        
        entity.moveTo(path: path) { [weak self] in
            print("✅ \(entity.entityType.displayName) arrived at destination")
            // Clear the path when movement completes
            self?.clearMovementPath()
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
    
    @objc func handleFogOfWarUpdate(_ notification: Notification) {
        guard let player = player,
              let notifyingPlayer = notification.object as? Player,
              notifyingPlayer.id == player.id else { return }
        
        // Update vision immediately when entities move
        player.updateVision(allPlayers: allGamePlayers)
        hexMap.updateFogOverlays(for: player)
    }
    
    func initializeFogOfWar() {
        guard let player = player else {
            print("❌ Cannot initialize fog: No player")
            return
        }
        
        guard !allGamePlayers.isEmpty else {
            print("❌ Cannot initialize fog: No players in allGamePlayers")
            return
        }
        
        print("👁️ Initializing fog of war...")
        
        // Remove any existing fog node
        childNode(withName: "fogNode")?.removeFromParent()
        
        // Create fresh fog node
        let fogNode = SKNode()
        fogNode.name = "fogNode"
        fogNode.zPosition = 100
        addChild(fogNode)
        
        // Initialize player's fog of war manager
        player.initializeFogOfWar(hexMap: hexMap)
        
        // Setup fog overlays on each tile
        hexMap.setupFogOverlays(in: fogNode)
        
        // Update vision with all players to reveal areas
        player.updateVision(allPlayers: allGamePlayers)
        
        // Apply fog overlays
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
        
        debugFogState()
        print("✅ Fog of war initialized successfully")
        print("   📊 Total tiles: \(hexMap.tiles.count)")
        print("   👁️ Fog overlays: \(hexMap.fogOverlays.count)")
        print("   🏢 Buildings: \(hexMap.buildings.count)")
        print("   🎭 Entities: \(hexMap.entities.count)")
    }

    func debugDrawVisionRange(center: HexCoordinate, radius: Int) {
        // Remove old debug shapes
        enumerateChildNodes(withName: "debugVision") { node, _ in
            node.removeFromParent()
        }
        
        let tiles = getVisionTilesForDebug(center: center, radius: radius)
        
        for coord in tiles {
            let position = HexMap.hexToPixel(q: coord.q, r: coord.r)
            let circle = SKShapeNode(circleOfRadius: 5)
            circle.fillColor = .red
            circle.strokeColor = .white
            circle.lineWidth = 1
            circle.position = position
            circle.zPosition = 200
            circle.name = "debugVision"
            addChild(circle)
        }
        
        print("🎯 Debug: \(tiles.count) tiles at radius \(radius) from (\(center.q), \(center.r))")
    }

    func getVisionTilesForDebug(center: HexCoordinate, radius: Int) -> [HexCoordinate] {
        var tiles: Set<HexCoordinate> = [center]
        
        // Check all tiles on the map
        for (coord, _) in hexMap.tiles {
            let dist = center.distance(to: coord)
            if dist > 0 && dist <= radius {
                tiles.insert(coord)
            }
        }
        
        return Array(tiles)
    }
    
    func debugPrintVisionPattern(center: HexCoordinate, radius: Int) {
        print("\n🎯 Vision Pattern for radius \(radius) from (\(center.q), \(center.r)):")
        
        var tilesAtDistance: [Int: [HexCoordinate]] = [:]
        
        for (coord, _) in hexMap.tiles {
            let dist = center.distance(to: coord)
            if dist <= radius {
                tilesAtDistance[dist, default: []].append(coord)
            }
        }
        
        for dist in 0...radius {
            let coords = tilesAtDistance[dist] ?? []
            print("  Distance \(dist): \(coords.count) tiles")
            if coords.count <= 12 {
                for coord in coords.sorted(by: { $0.q < $1.q }) {
                    print("    (\(coord.q), \(coord.r))")
                }
            }
        }
        print()
    }
    
    func drawStaticMovementPath(from start: HexCoordinate, path: [HexCoordinate]) {
        // Remove old path line
        movementPathLine?.removeFromParent()
        
        guard !path.isEmpty else { return }
        
        // Create path in world coordinates
        let bezierPath = UIBezierPath()
        
        // Start from entity's current position
        let startPos = HexMap.hexToPixel(q: start.q, r: start.r)
        bezierPath.move(to: startPos)
        
        // Draw line through each waypoint
        for coord in path {
            let worldPos = HexMap.hexToPixel(q: coord.q, r: coord.r)
            bezierPath.addLine(to: worldPos)
        }
        
        // Create shape node
        movementPathLine = SKShapeNode(path: bezierPath.cgPath)
        movementPathLine?.strokeColor = UIColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 0.7)
        movementPathLine?.lineWidth = 3
        movementPathLine?.lineCap = .round
        movementPathLine?.lineJoin = .round
        movementPathLine?.zPosition = 8 // Between tiles and entities
        
        // Add arrow at the end
        if let lastCoord = path.last {
            let endPos = HexMap.hexToPixel(q: lastCoord.q, r: lastCoord.r)
            
            // Calculate arrow direction from second-to-last point
            let previousCoord = path.count > 1 ? path[path.count - 2] : start
            let prevPos = HexMap.hexToPixel(q: previousCoord.q, r: previousCoord.r)
            
            let dx = endPos.x - prevPos.x
            let dy = endPos.y - prevPos.y
            let angle = atan2(dy, dx)
            
            // Create arrow head
            let arrowSize: CGFloat = 12
            let arrowPath = UIBezierPath()
            arrowPath.move(to: endPos)
            arrowPath.addLine(to: CGPoint(
                x: endPos.x - arrowSize * cos(angle - .pi / 6),
                y: endPos.y - arrowSize * sin(angle - .pi / 6)
            ))
            arrowPath.move(to: endPos)
            arrowPath.addLine(to: CGPoint(
                x: endPos.x - arrowSize * cos(angle + .pi / 6),
                y: endPos.y - arrowSize * sin(angle + .pi / 6)
            ))
            
            let arrowHead = SKShapeNode(path: arrowPath.cgPath)
            arrowHead.strokeColor = UIColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 0.7)
            arrowHead.lineWidth = 3
            arrowHead.lineCap = .round
            movementPathLine?.addChild(arrowHead)
        }
        
        addChild(movementPathLine!)
    }

    func clearMovementPath() {
        movementPathLine?.removeFromParent()
        movementPathLine = nil
    }
    
    func updateMovementPath(from currentPos: HexCoordinate, remainingPath: [HexCoordinate]) {
        // Remove old path
        movementPathLine?.removeFromParent()
        
        guard !remainingPath.isEmpty else { return }
        
        // Draw path from current position to remaining waypoints
        let bezierPath = UIBezierPath()
        let startPos = HexMap.hexToPixel(q: currentPos.q, r: currentPos.r)
        bezierPath.move(to: startPos)
        
        for coord in remainingPath {
            let worldPos = HexMap.hexToPixel(q: coord.q, r: coord.r)
            bezierPath.addLine(to: worldPos)
        }
        
        // Create new path line
        movementPathLine = SKShapeNode(path: bezierPath.cgPath)
        movementPathLine?.strokeColor = UIColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 0.7)
        movementPathLine?.lineWidth = 3
        movementPathLine?.lineCap = .round
        movementPathLine?.lineJoin = .round
        movementPathLine?.zPosition = 8
        movementPathLine?.name = "movementPath"
        
        // Add arrow at the end
        if let lastCoord = remainingPath.last {
            let endPos = HexMap.hexToPixel(q: lastCoord.q, r: lastCoord.r)
            
            let previousCoord = remainingPath.count > 1 ? remainingPath[remainingPath.count - 2] : currentPos
            let prevPos = HexMap.hexToPixel(q: previousCoord.q, r: previousCoord.r)
            
            let dx = endPos.x - prevPos.x
            let dy = endPos.y - prevPos.y
            let angle = atan2(dy, dx)
            
            let arrowSize: CGFloat = 12
            let arrowPath = UIBezierPath()
            arrowPath.move(to: endPos)
            arrowPath.addLine(to: CGPoint(
                x: endPos.x - arrowSize * cos(angle - .pi / 6),
                y: endPos.y - arrowSize * sin(angle - .pi / 6)
            ))
            arrowPath.move(to: endPos)
            arrowPath.addLine(to: CGPoint(
                x: endPos.x - arrowSize * cos(angle + .pi / 6),
                y: endPos.y - arrowSize * sin(angle + .pi / 6)
            ))
            
            let arrowHead = SKShapeNode(path: arrowPath.cgPath)
            arrowHead.strokeColor = UIColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 0.7)
            arrowHead.lineWidth = 3
            arrowHead.lineCap = .round
            movementPathLine?.addChild(arrowHead)
        }
        
        addChild(movementPathLine!)
    }
    
}
