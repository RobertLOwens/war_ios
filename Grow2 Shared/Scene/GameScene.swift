import UIKit
import SpriteKit

// MARK: - Game Scene

class GameScene: SKScene, BuildingPlacementDelegate, ReinforcementManagerDelegate, VillagerJoinManagerDelegate {
    
    var hexMap: HexMap!
    var mapNode: SKNode!
    var unitsNode: SKNode!
    var buildingsNode: SKNode!
    var entitiesNode: SKNode!
    var selectedTile: HexTileNode?
    var selectedEntity: EntityNode?
    var cameraNode: SKCameraNode!
    var showAlert: ((String, String) -> Void)?
    var attackingArmy: Army?
    var player: Player?
    var enemyPlayer: Player?

    // Camera controller
    var cameraController: GameSceneCameraController!

    // Resource gathering is now handled by ResourceEngine (see GameSceneEngineIntegration)

    // Building placement controller
    var buildingPlacementController: BuildingPlacementController!

    // Reinforcement manager
    var reinforcementManager: ReinforcementManager!

    // Villager join manager
    var villagerJoinManager: VillagerJoinManager!

    // Camera state passthrough properties for external access
    var cameraScale: CGFloat {
        get { cameraController?.cameraScale ?? 1.0 }
        set { cameraController?.cameraScale = newValue }
    }
    var lastTouchPosition: CGPoint? {
        get { cameraController?.lastTouchPosition }
        set { cameraController?.lastTouchPosition = newValue }
    }
    var isPanning: Bool {
        get { cameraController?.isPanning ?? false }
        set { cameraController?.isPanning = newValue }
    }

    var allGamePlayers: [Player] = []
    var mapSize: Int = 20
    var resourceDensity: Double = 1.0
    var movementPathRenderer: MovementPathRenderer!

    // Drag-to-move gesture state
    var dragStartCoordinate: HexCoordinate?
    var dragSourceEntity: EntityNode?
    var isDragging: Bool = false
    var dragPathPreview: SKShapeNode?
    let dragThreshold: CGFloat = 20
    var showMergeOption: ((EntityNode, EntityNode) -> Void)?
    weak var gameDelegate: GameSceneDelegate?
    var lastUpdateTime: TimeInterval?
    var skipInitialSetup: Bool = false
    var isLoading: Bool = false

    // Entrenchment overlays
    var entrenchmentOverlays: [UUID: [SKShapeNode]] = [:]

    private var lastVisionUpdateTime: TimeInterval = 0
    private var lastBuildingTimerUpdateTime: TimeInterval = 0
    private var lastTrainingUpdateTime: TimeInterval = 0
    private var lastCombatUpdateTime: TimeInterval = 0
    private var lastGarrisonDefenseUpdateTime: TimeInterval = 0
    private var lastStaminaUpdateTime: TimeInterval = 0
    private var lastGatheringDepletionTime: TimeInterval = 0

    // Update intervals (in seconds) - tune these based on gameplay feel
    private let visionUpdateInterval: TimeInterval = 0.25       // Fog/vision: 4x per second
    private let buildingTimerUpdateInterval: TimeInterval = 0.5 // Building UI: 2x per second
    private let trainingUpdateInterval: TimeInterval = 1.0      // Training queues: 1x per second
    private let gatheringUpdateInterval: TimeInterval = 0.5
    private let gatheringDepletionInterval: TimeInterval = 1.0  // Resource depletion: 1x per second
    private let combatUpdateInterval: TimeInterval = 1.0        // Combat ticks: 1x per second
    private let garrisonDefenseUpdateInterval: TimeInterval = 1.0  // Garrison defense: 1x per second
    private let staminaUpdateInterval: TimeInterval = 1.0       // Stamina regen: 1x per second

    // Building placement passthrough properties
    var isInBuildingPlacementMode: Bool {
        get { buildingPlacementController?.isInBuildingPlacementMode ?? false }
    }
    var placementBuildingType: BuildingType? {
        get { buildingPlacementController?.placementBuildingType }
    }
    var placementVillagerGroup: VillagerGroup? {
        get { buildingPlacementController?.placementVillagerGroup }
    }
    var onBuildingPlacementSelected: ((HexCoordinate) -> Void)?

    // Rotation preview passthrough properties
    var isInRotationPreviewMode: Bool {
        get { buildingPlacementController?.isInRotationPreviewMode ?? false }
    }
    var rotationPreviewAnchor: HexCoordinate? {
        get { buildingPlacementController?.rotationPreviewAnchor }
    }
    var rotationPreviewType: BuildingType? {
        get { buildingPlacementController?.rotationPreviewType }
    }
    var rotationPreviewRotation: Int {
        get { buildingPlacementController?.rotationPreviewRotation ?? 0 }
    }
    var onRotationConfirmed: ((HexCoordinate, Int) -> Void)?

    // Reinforcement passthrough
    var reinforcementNodes: [ReinforcementNode] {
        get { reinforcementManager?.reinforcementNodes ?? [] }
    }
    private var reinforcementsNode: SKNode?

    // Marching villagers passthrough
    var marchingVillagerNodes: [MarchingVillagerNode] {
        get { villagerJoinManager?.marchingNodes ?? [] }
    }
    private var marchingVillagersNode: SKNode?

    // End game / starvation tracking
    var gameStartTime: TimeInterval = 0
    private var zeroFoodStartTime: TimeInterval?
    private var lastStarvationCheckTime: TimeInterval = 0
    private let starvationCheckInterval: TimeInterval = 1.0
    private let starvationTimeLimit: TimeInterval = 60.0  // 60 seconds with no food
    var isGameOver: Bool = false
    var onGameOver: ((Bool, GameOverReason) -> Void)?  // (isVictory, reason)

    override func didMove(to view: SKView) {
        setupScene()
        setupCamera()

        // Combat is now handled by GameEngine.shared.combatEngine

        // Register notification observers
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFarmCompleted(_:)),
            name: NSNotification.Name("FarmCompletedNotification"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBuildingCompleted(_:)),
            name: .buildingDidComplete,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCampCompleted(_:)),
            name: NSNotification.Name("CampCompletedNotification"),
            object: nil
        )

        // ✅ FIX: Only generate map and entities for NEW games
        if !skipInitialSetup {
            setupMap()
            spawnTestEntities()
            initializeFogOfWar()
        } else {
            setupEmptyNodeStructure()
        }

        // Setup gesture recognizers for smooth camera control
        setupGestureRecognizers()
    }
    
    /// Callback that fires when the scene is fully ready for loading saved game data
    var onSceneReady: (() -> Void)?

    /// Indicates whether the scene's node structure is fully initialized
    private(set) var isSceneReady: Bool = false

    func setupEmptyNodeStructure() {
        mapNode?.removeFromParent()
        unitsNode?.removeFromParent()
        buildingsNode?.removeFromParent()
        entitiesNode?.removeFromParent()
        reinforcementsNode?.removeFromParent()
        marchingVillagersNode?.removeFromParent()

        mapNode = SKNode()
        mapNode.name = "mapNode"
        addChild(mapNode)

        let resourcesNode = SKNode()
        resourcesNode.name = "resourcesNode"
        addChild(resourcesNode)

        buildingsNode = SKNode()
        buildingsNode.name = "buildingsNode"
        addChild(buildingsNode)

        entitiesNode = SKNode()
        entitiesNode.name = "entitiesNode"
        addChild(entitiesNode)

        reinforcementsNode = SKNode()
        reinforcementsNode?.name = "reinforcementsNode"
        addChild(reinforcementsNode!)

        marchingVillagersNode = SKNode()
        marchingVillagersNode?.name = "marchingVillagersNode"
        addChild(marchingVillagersNode!)

        unitsNode = SKNode()
        unitsNode.name = "unitsNode"
        addChild(unitsNode)

        // Mark scene as ready and notify
        isSceneReady = true
        debugLog("📦 Empty node structure created for saved game loading")

        // Notify that scene is ready (on main thread to ensure UI safety)
        DispatchQueue.main.async { [weak self] in
            self?.onSceneReady?()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Updates building placement controller references (call after hexMap/player are set)
    func updateBuildingPlacementControllerReferences() {
        buildingPlacementController?.hexMap = hexMap
        buildingPlacementController?.player = player
    }

    /// Updates reinforcement manager references (call after hexMap/player/reinforcementsNode are set)
    func updateReinforcementManagerReferences() {
        reinforcementManager?.updateReferences(hexMap: hexMap, player: player, reinforcementsNode: reinforcementsNode)
    }

    /// Updates villager join manager references (call after hexMap/player/marchingVillagersNode are set)
    func updateVillagerJoinManagerReferences() {
        villagerJoinManager?.updateReferences(hexMap: hexMap, player: player, marchingVillagersNode: marchingVillagersNode)
    }

    func setupScene() {
        backgroundColor = UIColor(red: 0.15, green: 0.2, blue: 0.15, alpha: 1.0)
        scaleMode = .resizeFill

        // Initialize movement path renderer
        movementPathRenderer = MovementPathRenderer(scene: self)

        // Initialize building placement controller (will be updated when hexMap/player are set)
        buildingPlacementController = BuildingPlacementController(scene: self, hexMap: nil, player: nil)
        buildingPlacementController.delegate = self

        // Initialize reinforcement manager (will be updated when hexMap/player are set)
        reinforcementManager = ReinforcementManager(hexMap: nil, player: nil, reinforcementsNode: nil)
        reinforcementManager.delegate = self

        // Initialize villager join manager (will be updated when hexMap/player are set)
        villagerJoinManager = VillagerJoinManager(hexMap: nil, player: nil, marchingVillagersNode: nil)
        villagerJoinManager.delegate = self
    }
    
    func setupCamera() {
        cameraNode = SKCameraNode()
        camera = cameraNode
        addChild(cameraNode)
        cameraNode.position = CGPoint(x: size.width / 2, y: size.height / 2)

        // Initialize camera controller
        cameraController = GameSceneCameraController(scene: self, cameraNode: cameraNode)
        cameraNode.setScale(cameraScale)
    }

    func setupGestureRecognizers() {
        cameraController.setupGestureRecognizers()
    }

    func calculateMapBounds() {
        cameraController.calculateMapBounds(hexMap: hexMap)
    }

    /// Centers and zooms the camera to a specific coordinate
    func focusCamera(on coordinate: HexCoordinate, zoom: CGFloat? = nil, animated: Bool = true) {
        cameraController.focusCamera(on: coordinate, zoom: zoom, animated: animated)
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

        reinforcementsNode = SKNode()
        reinforcementsNode?.name = "reinforcementsNode"
        addChild(reinforcementsNode!)

        marchingVillagersNode = SKNode()
        marchingVillagersNode?.name = "marchingVillagersNode"
        addChild(marchingVillagersNode!)

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

        // Calculate map bounds for camera constraints
        calculateMapBounds()

        // Center camera on player spawn (3,3) for legacy maps
        let playerSpawn = HexMap.hexToPixel(q: 3, r: 3)
        cameraNode.position = playerSpawn

        // Initialize adjacency bonus manager
        AdjacencyBonusManager.shared.setup(hexMap: hexMap)

        // Update building placement controller references
        updateBuildingPlacementControllerReferences()
        updateReinforcementManagerReferences()
        updateVillagerJoinManagerReferences()
    }

    // MARK: - Map Generator Setup

    /// Sets up the map using a MapGenerator for structured map creation (e.g., Arabia style)
    /// - Parameters:
    ///   - generator: The map generator to use
    ///   - players: Array of players to set up (player at index 0 is the human player)
    func setupMapWithGenerator(_ generator: MapGenerator, players: [Player]) {
        guard players.count >= 2 else {
            debugLog("❌ Arabia map requires at least 2 players")
            return
        }

        // Clear existing nodes
        mapNode?.removeFromParent()
        unitsNode?.removeFromParent()
        buildingsNode?.removeFromParent()
        entitiesNode?.removeFromParent()

        // Create node hierarchy
        mapNode = SKNode()
        mapNode.name = "mapNode"
        addChild(mapNode)

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

        // Create HexMap with generator dimensions
        hexMap = HexMap(width: generator.width, height: generator.height)

        // Generate terrain with elevation
        let terrainData = generator.generateTerrain()

        // Add tiles to map
        for (coord, data) in terrainData {
            let tile = HexTileNode(coordinate: coord, terrain: data.terrain, elevation: data.elevation)
            let position = HexMap.hexToPixel(q: coord.q, r: coord.r)
            tile.position = position
            hexMap.tiles[coord] = tile
            mapNode.addChild(tile)
        }

        // Get starting positions
        let startPositions = generator.getStartingPositions()

        // Set diplomacy between players before creating entities so textures render correct colors
        for i in 0..<players.count {
            for j in (i + 1)..<players.count {
                players[i].setDiplomacyStatus(with: players[j], status: .enemy)
            }
        }

        // Setup each player at their starting position
        for (index, startPos) in startPositions.enumerated() {
            guard index < players.count else { continue }
            let currentPlayer = players[index]

            // Place town center at starting position
            let townCenter = BuildingNode(coordinate: startPos.coordinate, buildingType: .cityCenter, owner: currentPlayer)
            townCenter.state = .completed
            let tcPosition = HexMap.hexToPixel(q: startPos.coordinate.q, r: startPos.coordinate.r)
            townCenter.position = tcPosition
            hexMap.addBuilding(townCenter)
            buildingsNode.addChild(townCenter)
            currentPlayer.addBuilding(townCenter)

            // Spawn starting villagers adjacent to town center
            let villagerSpawn = findAdjacentWalkableCoordinate(near: startPos.coordinate)
            let villagers = VillagerGroup(
                name: index == 0 ? "Starter Villagers" : "\(currentPlayer.name) Villagers",
                coordinate: villagerSpawn,
                villagerCount: 5,
                owner: currentPlayer
            )

            let villagerNode = EntityNode(
                coordinate: villagerSpawn,
                entityType: .villagerGroup,
                entity: villagers,
                currentPlayer: players[0] // Current viewing player
            )
            let villagerPosition = HexMap.hexToPixel(q: villagerSpawn.q, r: villagerSpawn.r)
            villagerNode.position = villagerPosition

            hexMap.addEntity(villagerNode)
            entitiesNode.addChild(villagerNode)
            currentPlayer.addEntity(villagers)

            // Generate and spawn starting resources
            let startingResources = generator.generateStartingResources(around: startPos.coordinate)
            for placement in startingResources {
                spawnResourceAtCoordinate(placement.coordinate, type: placement.resourceType, in: resourcesNode)
            }

            debugLog("✅ Player \(index + 1) (\(currentPlayer.name)) spawned at (\(startPos.coordinate.q), \(startPos.coordinate.r))")
        }

        // Generate and spawn neutral resources
        let startCoords = startPositions.map { $0.coordinate }
        let neutralResources = generator.generateNeutralResources(excludingRadius: 10, aroundPositions: startCoords)
        for placement in neutralResources {
            spawnResourceAtCoordinate(placement.coordinate, type: placement.resourceType, in: resourcesNode)
        }

        debugLog("✅ Spawned \(neutralResources.count) neutral resources")

        // Set player references
        self.player = players[0]
        self.enemyPlayer = players.count > 1 ? players[1] : nil
        self.allGamePlayers = players

        // Calculate map bounds and center camera on player's town center
        calculateMapBounds()
        let playerStart = startPositions[0].coordinate
        let playerTownCenterPos = HexMap.hexToPixel(q: playerStart.q, r: playerStart.r)
        cameraNode.position = playerTownCenterPos

        // Initialize adjacency bonus manager
        AdjacencyBonusManager.shared.setup(hexMap: hexMap)

        // Update building placement controller references
        updateBuildingPlacementControllerReferences()
        updateReinforcementManagerReferences()
        updateVillagerJoinManagerReferences()

        debugLog("Arabia map generated!")
        debugLog("   Map size: \(generator.width)x\(generator.height)")
        debugLog("   Total tiles: \(hexMap.tiles.count)")
        debugLog("   Total resources: \(hexMap.resourcePoints.count)")
    }

    /// Helper to find an adjacent walkable coordinate
    private func findAdjacentWalkableCoordinate(near coord: HexCoordinate) -> HexCoordinate {
        for neighbor in coord.neighbors() {
            if hexMap.isValidCoordinate(neighbor) && hexMap.isWalkable(neighbor) {
                if hexMap.getBuilding(at: neighbor) == nil && hexMap.getEntityCount(at: neighbor) < GameConfig.Stacking.maxEntitiesPerTile {
                    return neighbor
                }
            }
        }
        // Fallback: return offset coordinate
        return HexCoordinate(q: coord.q + 1, r: coord.r)
    }

    /// Helper to spawn a resource at a coordinate
    private func spawnResourceAtCoordinate(_ coord: HexCoordinate, type: ResourcePointType, in parentNode: SKNode) {
        // Skip if coordinate already has a resource
        if hexMap.getResourcePoint(at: coord) != nil { return }

        let resource = ResourcePointNode(coordinate: coord, resourceType: type)
        let position = HexMap.hexToPixel(q: coord.q, r: coord.r)
        resource.position = position
        hexMap.resourcePoints.append(resource)
        parentNode.addChild(resource)
    }

    // MARK: - Arena Map Setup

    /// Sets up a combat test arena using an ArenaMapGenerator
    /// Creates armies with commanders and military units - no buildings or villagers
    /// - Parameters:
    ///   - generator: The arena map generator to use
    ///   - players: Array of players (player at index 0 is the human player)
    ///   - armyConfig: Optional army configuration for unit composition (uses default if nil)
    func setupArenaWithGenerator(_ generator: MapGenerator, players: [Player], armyConfig: ArenaArmyConfiguration? = nil) {
        guard players.count >= 2 else {
            debugLog("Arena map requires at least 2 players")
            return
        }

        // Clear existing nodes
        mapNode?.removeFromParent()
        unitsNode?.removeFromParent()
        buildingsNode?.removeFromParent()
        entitiesNode?.removeFromParent()

        // Create node hierarchy
        mapNode = SKNode()
        mapNode.name = "mapNode"
        addChild(mapNode)

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

        // Create HexMap with generator dimensions
        hexMap = HexMap(width: generator.width, height: generator.height)

        // Generate terrain
        let terrainData = generator.generateTerrain()

        // Add tiles to map
        for (coord, data) in terrainData {
            let tile = HexTileNode(coordinate: coord, terrain: data.terrain, elevation: data.elevation)
            let position = HexMap.hexToPixel(q: coord.q, r: coord.r)
            tile.position = position
            hexMap.tiles[coord] = tile
            mapNode.addChild(tile)
        }

        // Get starting positions
        let startPositions = generator.getStartingPositions()

        // Set diplomacy between players before creating entities so textures render correct colors
        for i in 0..<players.count {
            for j in (i + 1)..<players.count {
                players[i].setDiplomacyStatus(with: players[j], status: .enemy)
            }
        }

        // Setup each player with an army (no buildings, no villagers)
        for (index, startPos) in startPositions.enumerated() {
            guard index < players.count else { continue }
            let currentPlayer = players[index]

            // Create a level 1 infantry commander for the arena
            let commander = Commander(
                name: Commander.randomName(),
                specialty: .infantryAggressive,
                portraitColor: Commander.randomColor(),
                owner: currentPlayer
            )

            // Create army at starting position
            let armyName = index == 0 ? "Player's Army" : "\(currentPlayer.name)'s Army"
            let army = Army(name: armyName, coordinate: startPos.coordinate, commander: commander, owner: currentPlayer)

            // Add units to the army based on config
            let config = armyConfig ?? .default
            let composition = index == 0 ? config.playerArmy : config.enemyArmy
            for (unitType, count) in composition where count > 0 {
                army.addMilitaryUnits(unitType, count: count)
            }

            // Create EntityNode and add to map
            let armyNode = EntityNode(
                coordinate: startPos.coordinate,
                entityType: .army,
                entity: army,
                currentPlayer: players[0]
            )
            let armyPosition = HexMap.hexToPixel(q: startPos.coordinate.q, r: startPos.coordinate.r)
            armyNode.position = armyPosition

            hexMap.addEntity(armyNode)
            entitiesNode.addChild(armyNode)

            // Register army with player (both arrays for compatibility)
            currentPlayer.addArmy(army)
            currentPlayer.addEntity(army)  // For getArmies() to work via entities

            // Explicitly ensure army is registered in GameState for combat/retreat systems
            GameEngine.shared.gameState?.addArmy(army.data)
            debugLog("DEBUG: Army \(army.name) added. In GameState: \(GameEngine.shared.gameState?.getArmy(id: army.id) != nil)")

            // Register commander with player
            currentPlayer.addCommander(commander)

            debugLog("Player \(index + 1) (\(currentPlayer.name)) army spawned at (\(startPos.coordinate.q), \(startPos.coordinate.r))")
            debugLog("   Commander: \(commander.name)")
            for (unitType, count) in composition where count > 0 {
                debugLog("   \(unitType.displayName): \(count)")
            }
        }

        // Create city centers at corners for retreat testing
        let player1CityPos = HexCoordinate(q: 0, r: 0)
        let player2CityPos = HexCoordinate(q: generator.width - 1, r: generator.height - 1)

        // Player 1 city center
        let player1CityCenter = BuildingNode(coordinate: player1CityPos, buildingType: .cityCenter, owner: players[0])
        player1CityCenter.state = .completed
        let p1CityPixelPos = HexMap.hexToPixel(q: player1CityPos.q, r: player1CityPos.r)
        player1CityCenter.position = p1CityPixelPos
        hexMap.addBuilding(player1CityCenter)
        buildingsNode.addChild(player1CityCenter)
        players[0].addBuilding(player1CityCenter)
        // Sync to GameEngine's game state for combat engine to find buildings
        GameEngine.shared.gameState?.addBuilding(player1CityCenter.data)

        // Player 2 city center
        let player2CityCenter = BuildingNode(coordinate: player2CityPos, buildingType: .cityCenter, owner: players[1])
        player2CityCenter.state = .completed
        let p2CityPixelPos = HexMap.hexToPixel(q: player2CityPos.q, r: player2CityPos.r)
        player2CityCenter.position = p2CityPixelPos
        hexMap.addBuilding(player2CityCenter)
        buildingsNode.addChild(player2CityCenter)
        players[1].addBuilding(player2CityCenter)
        GameEngine.shared.gameState?.addBuilding(player2CityCenter.data)

        // Player 2 wooden fort (for testing building protection)
        let player2FortPos = HexCoordinate(q: 2, r: 3)
        let player2Fort = BuildingNode(coordinate: player2FortPos, buildingType: .woodenFort, owner: players[1])
        player2Fort.state = .completed
        let p2FortPixelPos = HexMap.hexToPixel(q: player2FortPos.q, r: player2FortPos.r)
        player2Fort.position = p2FortPixelPos
        hexMap.addBuilding(player2Fort)
        buildingsNode.addChild(player2Fort)
        players[1].addBuilding(player2Fort)
        player2Fort.createTileOverlays(in: self)
        GameEngine.shared.gameState?.addBuilding(player2Fort.data)

        // NOTE: Removed hardcoded archer garrison - garrison should come from game setup config
        // player2Fort.addToGarrison(unitType: .archer, quantity: 5)

        // Player 2 farm adjacent to fort (protected by the fort)
        let player2FarmPos = HexCoordinate(q: 2, r: 2)
        let player2Farm = BuildingNode(coordinate: player2FarmPos, buildingType: .farm, owner: players[1])
        player2Farm.state = .completed
        let p2FarmPixelPos = HexMap.hexToPixel(q: player2FarmPos.q, r: player2FarmPos.r)
        player2Farm.position = p2FarmPixelPos
        hexMap.addBuilding(player2Farm)
        buildingsNode.addChild(player2Farm)
        players[1].addBuilding(player2Farm)
        GameEngine.shared.gameState?.addBuilding(player2Farm.data)

        debugLog("Enemy defensive buildings placed:")
        debugLog("   Wooden Fort: (\(player2FortPos.q), \(player2FortPos.r))")
        debugLog("   Farm (protected by fort): (\(player2FarmPos.q), \(player2FarmPos.r))")

        // Set home bases for armies
        if let player1Army = players[0].armies.first {
            player1Army.setHomeBase(player1CityCenter.data.id)
        }
        if let player2Army = players[1].armies.first {
            player2Army.setHomeBase(player2CityCenter.data.id)
        }

        debugLog("City centers placed at corners for retreat testing")
        debugLog("   Player 1 city center: (\(player1CityPos.q), \(player1CityPos.r))")
        debugLog("   Player 2 city center: (\(player2CityPos.q), \(player2CityPos.r))")

        // Set player references
        self.player = players[0]
        self.enemyPlayer = players.count > 1 ? players[1] : nil
        self.allGamePlayers = players

        // Calculate map bounds and center camera
        calculateMapBounds()
        let centerCoord = HexCoordinate(q: generator.width / 2, r: generator.height / 2)
        let centerPos = HexMap.hexToPixel(q: centerCoord.q, r: centerCoord.r)
        cameraNode.position = centerPos

        // Zoom in slightly for better view of small arena
        cameraScale = 0.8
        cameraNode.setScale(cameraScale)

        // Update building placement controller references
        updateBuildingPlacementControllerReferences()
        updateReinforcementManagerReferences()

        debugLog("Arena map generated!")
        debugLog("   Map size: \(generator.width)x\(generator.height)")
        debugLog("   Total tiles: \(hexMap.tiles.count)")
    }

    func debugFogState() {
        guard let player = player else {
            debugLog("❌ DEBUG: No player")
            return
        }
        
        debugLog("\n🔍 FOG DEBUG INFO:")
        debugLog("   Player: \(player.name)")
        debugLog("   FogOfWar exists: \(player.fogOfWar != nil)")
        debugLog("   AllGamePlayers count: \(allGamePlayers.count)")
        debugLog("   Total tiles: \(hexMap.tiles.count)")
        debugLog("   Fog overlays: \(hexMap.fogOverlays.count)")
        debugLog("   Buildings: \(hexMap.buildings.count)")
        debugLog("   Entities: \(hexMap.entities.count)")
        
        // Check visibility of a few tiles
        let testCoords = [
            HexCoordinate(q: 3, r: 3),
            HexCoordinate(q: 5, r: 5),
            HexCoordinate(q: 10, r: 10)
        ]
        
        for coord in testCoords {
            let vis = player.getVisibilityLevel(at: coord)
            debugLog("   Tile (\(coord.q), \(coord.r)): \(vis)")
        }
        debugLog("")
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

        let aiPlayer = Player(name: "Enemy", color: .red, isAI: true)
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

        // AI Barracks (for military training)
        let aiBarracksSpawn = HexCoordinate(q: aiSpawn.q + 1, r: aiSpawn.r)
        let aiBarracks = BuildingNode(coordinate: aiBarracksSpawn, buildingType: .barracks, owner: aiPlayer)
        aiBarracks.state = .completed
        let aiBarracksPos = HexMap.hexToPixel(q: aiBarracksSpawn.q, r: aiBarracksSpawn.r)
        aiBarracks.position = aiBarracksPos
        hexMap.addBuilding(aiBarracks)
        buildingsNode.addChild(aiBarracks)
        aiPlayer.addBuilding(aiBarracks)

        // Store enemy player reference
        self.enemyPlayer = aiPlayer
        
        // ✅ Store all players (NO FOG INITIALIZATION HERE)
        self.allGamePlayers = [player, aiPlayer]
        
        debugLog("✅ Game started!")
        debugLog("  🔵 Player at (\(playerSpawn.q), \(playerSpawn.r))")
        debugLog("  🔴 Enemy at (\(aiSpawn.q), \(aiSpawn.r))")
        debugLog("  🗺️ Map Size: \(mapSize)x\(mapSize)")
        debugLog("  💎 Resource Density: \(resourceDensity)x")
    }
    
    func selectEntity(_ entity: EntityNode) {
        // ✅ FIX: Check if entity is actually visible
        guard let player = player else { return }
        
        let visibility = player.getVisibilityLevel(at: entity.coordinate)
        guard visibility == .visible else {
            debugLog("❌ Cannot select entity in fog of war")
            gameDelegate?.gameScene(self, showAlertWithTitle: "Cannot Select", message:"This unit is not visible due to fog of war.")
            return
        }
        
        // ✅ FIX: Double-check entity visibility through fog system
        if let fogOfWar = player.fogOfWar {
            guard fogOfWar.shouldShowEntity(entity.entity, at: entity.coordinate) else {
                debugLog("❌ Entity not visible according to fog of war")
                gameDelegate?.gameScene(self, showAlertWithTitle: "Cannot Select", message:"This unit is not visible.")
                return
            }
        }
        
        selectedEntity = nil
        selectedTile?.isSelected = false
        selectedTile = nil
        
        selectedEntity = entity
        
        if let tile = hexMap.getTile(at: entity.coordinate) {
            tile.isSelected = true
            selectedTile = tile
        }
        
        debugLog("Selected \(entity.entityType.displayName) at q:\(entity.coordinate.q), r:\(entity.coordinate.r)")
        
        gameDelegate?.gameScene(self, didRequestMenuForTile: entity.coordinate)
    }
    
    override func update(_ currentTime: TimeInterval) {
        // Skip updates while loading or if map isn't ready
        guard !isLoading, hexMap != nil, !isGameOver else { return }

        let realWorldTime = Date().timeIntervalSince1970

        // =========================================================================
        // ENGINE UPDATE: Process authoritative game state (if enabled)
        // =========================================================================
        updateEngine(currentTime: realWorldTime)

        // =========================================================================
        // EVERY FRAME: Critical updates only
        // =========================================================================
        // Apply camera momentum for smooth panning
        cameraController.applyCameraMomentum()

        // =========================================================================
        // FAST UPDATES (4x per second): Vision & Fog - needs to feel responsive
        // =========================================================================
        if currentTime - lastVisionUpdateTime >= visionUpdateInterval {
            updateVisionAndFog()
            updateEntrenchmentOverlays()
            lastVisionUpdateTime = currentTime
        }
        
        // =========================================================================
        // MEDIUM UPDATES (2x per second): UI elements & display
        // =========================================================================
        if currentTime - lastBuildingTimerUpdateTime >= buildingTimerUpdateInterval {
            updateBuildingTimers()

            lastBuildingTimerUpdateTime = currentTime
        }

        // Resource display update (reuse existing lastUpdateTime)
        if lastUpdateTime == nil || currentTime - lastUpdateTime! >= 0.5 {
            player?.updateResources(currentTime: realWorldTime)
            gameDelegate?.gameSceneDidUpdateResources(self)
            lastUpdateTime = currentTime
        }
        
        // =========================================================================
        // SLOW UPDATES (1x per second): Background processing
        // =========================================================================
        if currentTime - lastTrainingUpdateTime >= trainingUpdateInterval {
            updateTrainingQueues(currentTime: realWorldTime)
            ResearchManager.shared.update(currentTime: realWorldTime)
            lastTrainingUpdateTime = currentTime
        }

        // =========================================================================
        // COMBAT UPDATES: Now handled by GameEngine.shared.combatEngine
        // =========================================================================
        // Combat updates are processed by the engine in updateEngine()

        // =========================================================================
        // GARRISON DEFENSE UPDATES: Now handled by GameEngine.shared.combatEngine
        // =========================================================================
        // Garrison defense is processed by CombatEngine.processGarrisonDefense()

        // =========================================================================
        // STAMINA REGENERATION (1x per second): Commanders regain stamina over time
        // =========================================================================
        if currentTime - lastStaminaUpdateTime >= staminaUpdateInterval {
            updateCommanderStamina(currentTime: realWorldTime)
            lastStaminaUpdateTime = currentTime
        }

        // =========================================================================
        // GATHERING UPDATES: Process resource depletion for active gatherers
        // =========================================================================
        if currentTime - lastGatheringDepletionTime >= gatheringDepletionInterval {
            if !isEngineEnabled {
                processGatheringDepletion()
            }
            lastGatheringDepletionTime = currentTime
        }

        // =========================================================================
        // STARVATION CHECK (1x per second): Check if player has been at 0 food
        // =========================================================================
        if currentTime - lastStarvationCheckTime >= starvationCheckInterval {
            checkStarvationCondition(currentTime: realWorldTime)
            lastStarvationCheckTime = currentTime
        }
    }
    
    // MARK: - Time-Sliced Update Helpers
    
    /// Updates vision and fog of war - runs 4x per second
    private func updateVisionAndFog() {
        guard let player = player else { return }

        // Update player's vision based on unit positions
        player.updateVision(allPlayers: allGamePlayers)

        // Grant 1-tile visibility to own reinforcements
        var reinforcementCoords: [HexCoordinate] = []
        for node in reinforcementNodes {
            guard node.reinforcement.owner?.id == player.id else { continue }
            reinforcementCoords.append(node.coordinate)
        }
        player.fogOfWar?.addReinforcementVision(coordinates: reinforcementCoords)

        // Sync reinforcement positions to GameState for VisionEngine (AI use)
        syncReinforcementPositionsToGameState()

        // Update fog overlay visuals
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
    }

    /// Syncs reinforcement positions to GameState for VisionEngine calculations
    private func syncReinforcementPositionsToGameState() {
        guard let gameState = GameEngine.shared.gameState else { return }
        gameState.activeReinforcementPositions.removeAll()
        for node in reinforcementNodes {
            guard let ownerID = node.reinforcement.owner?.id else { continue }
            gameState.activeReinforcementPositions[ownerID, default: []].insert(node.coordinate)
        }
    }

    // MARK: - Entrenchment Overlays

    /// Updates entrenchment visual overlays for entrenched armies
    private func updateEntrenchmentOverlays() {
        guard let player = player else { return }

        // Collect currently entrenched army IDs
        var currentlyEntrenched: Set<UUID> = []

        for entity in hexMap.entities {
            guard let army = entity.entity as? Army, army.isEntrenched else { continue }
            currentlyEntrenched.insert(army.id)

            // Skip if overlays already exist for this army
            if entrenchmentOverlays[army.id] != nil { continue }

            // Create neighbor hex outlines
            let neighbors = army.coordinate.neighbors()
            var overlayNodes: [SKShapeNode] = []

            for neighbor in neighbors {
                // Only show overlays for tiles that exist on the map
                guard hexMap.getTile(at: neighbor) != nil else { continue }

                // Check visibility - only show if tile is visible to local player
                guard player.isVisible(neighbor) else { continue }

                let position = HexMap.hexToPixel(q: neighbor.q, r: neighbor.r)
                let shape = createEntrenchmentHexOutline(at: position)
                mapNode.addChild(shape)
                overlayNodes.append(shape)
            }

            entrenchmentOverlays[army.id] = overlayNodes
        }

        // Remove overlays for armies that are no longer entrenched
        let staleIDs = entrenchmentOverlays.keys.filter { !currentlyEntrenched.contains($0) }
        for armyID in staleIDs {
            removeEntrenchmentOverlays(for: armyID)
        }

        // Update visibility of existing overlays based on fog of war
        for (armyID, nodes) in entrenchmentOverlays {
            // Find the army to get its coordinate
            guard let entity = hexMap.entities.first(where: { $0.entity.id == armyID }),
                  let army = entity.entity as? Army else {
                continue
            }
            let neighbors = army.coordinate.neighbors()
            for (index, node) in nodes.enumerated() {
                if index < neighbors.count {
                    node.isHidden = !player.isVisible(neighbors[index])
                }
            }
        }
    }

    /// Creates a hex outline shape for entrenchment neighbor tiles
    private func createEntrenchmentHexOutline(at position: CGPoint) -> SKShapeNode {
        let radius: CGFloat = HexTileNode.hexRadius - 2
        let isoRatio = HexTileNode.isoRatio
        let path = UIBezierPath()

        for i in 0..<6 {
            let angle = CGFloat(i) * CGFloat.pi / 3 - CGFloat.pi / 6
            let x = radius * cos(angle)
            let y = radius * sin(angle) * isoRatio

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.close()

        let shape = SKShapeNode(path: path.cgPath)
        shape.position = position
        shape.strokeColor = UIColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 0.8)
        shape.lineWidth = 3
        shape.fillColor = UIColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 0.1)
        shape.glowWidth = 1
        shape.zPosition = 50

        // Pulsing animation
        let fadeOut = SKAction.fadeAlpha(to: 0.4, duration: 0.8)
        let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.8)
        let pulse = SKAction.sequence([fadeOut, fadeIn])
        shape.run(SKAction.repeatForever(pulse))

        return shape
    }

    /// Removes all entrenchment overlays for a specific army
    func removeEntrenchmentOverlays(for armyID: UUID) {
        guard let nodes = entrenchmentOverlays[armyID] else { return }
        for node in nodes {
            node.removeFromParent()
        }
        entrenchmentOverlays.removeValue(forKey: armyID)
    }

    // Garrison defense is now handled by CombatEngine.processGarrisonDefense()
    // This legacy code has been removed

    /// Updates commander stamina regeneration for all players - runs 1x per second
    private func updateCommanderStamina(currentTime: TimeInterval) {
        for gamePlayer in allGamePlayers {
            for army in gamePlayer.armies {
                if let commander = army.commander {
                    commander.regenerateStamina(currentTime: currentTime)
                }
            }
        }
    }

    /// Process resource depletion for all actively gathering villagers
    private func processGatheringDepletion() {
        guard let player = player else { return }

        for entity in hexMap.entities {
            guard let villagers = entity.entity as? VillagerGroup,
                  case .gatheringResource(let resource) = villagers.currentTask else {
                continue
            }

            // Calculate gather amount (base rate per villager)
            let gatherAmount = villagers.villagerCount  // 1 per villager per tick

            // Deplete the resource
            _ = resource.gather(amount: gatherAmount)

            // Check if resource is depleted
            if resource.isDepleted() {
                // Stop gathering and clear task
                resource.stopGathering(by: villagers)
                villagers.clearTask()
                entity.isMoving = false

                // Update collection rate
                let rateContribution = 0.2 * Double(villagers.villagerCount)
                player.decreaseCollectionRate(resource.resourceType.resourceYield, amount: rateContribution)

                debugLog("🏁 Resource depleted - \(villagers.name) now idle")
            }
        }
    }

    /// Updates building construction/upgrade/demolition timer UI - runs 2x per second
    private func updateBuildingTimers() {
        let currentTime = Date().timeIntervalSince1970

        for building in hexMap.buildings {
            switch building.state {
            case .constructing:
                building.updateTimerLabel()
            case .upgrading:
                building.updateUpgradeTimerLabel()
            case .demolishing:
                building.updateDemolitionTimerLabel()
                // Check if demolition is complete
                if building.data.updateDemolition(currentTime: currentTime) {
                    handleDemolitionComplete(building: building)
                }
            default:
                // Clean up any stale UI elements
                if building.timerLabel != nil {
                    building.timerLabel?.removeFromParent()
                    building.timerLabel = nil
                }
                if building.progressBar != nil {
                    building.progressBar?.removeFromParent()
                    building.progressBar = nil
                }
            }

            // Check for pending demolitions (villagers arriving)
            if building.pendingDemolition {
                checkPendingDemolitionArrival(building: building)
            }
        }
    }

    /// Handles demolition completion - refunds resources and removes building
    private func handleDemolitionComplete(building: BuildingNode) {
        guard let player = building.owner else { return }

        // Get refund and add to player
        let refund = building.completeDemolition()
        for (resourceType, amount) in refund {
            player.addResource(resourceType, amount: amount)
        }

        // Remove building from game
        hexMap.removeBuilding(building)
        player.removeBuilding(building)
        building.clearTileOverlays()  // Clean up multi-tile overlays
        building.removeFromParent()

        // Update resource display
        gameDelegate?.gameSceneDidUpdateResources(self)

        // Recalculate adjacency bonuses for nearby buildings
        AdjacencyBonusManager.shared.recalculateAffectedBuildings(near: building.coordinate)

        // Update collection rates (building removal may affect adjacency bonuses)
        if isEngineEnabled {
            GameEngine.shared.resourceEngine.updateCollectionRates(forPlayer: player.id)
        }

        // Post notification
        NotificationCenter.default.post(
            name: NSNotification.Name("BuildingDemolishedNotification"),
            object: self,
            userInfo: ["coordinate": building.coordinate, "refund": refund]
        )

        debugLog("🏚️ Building demolished: \(building.buildingType.displayName) - Refunded: \(refund)")
    }

    /// Checks if villagers have arrived for a pending demolition
    private func checkPendingDemolitionArrival(building: BuildingNode) {
        guard let demolisher = building.demolisherEntity,
              let villagers = demolisher.entity as? VillagerGroup else {
            return
        }

        // Check if villager has arrived at building
        if villagers.coordinate == building.coordinate && !demolisher.isMoving {
            building.pendingDemolition = false
            building.startDemolition(demolishers: villagers.villagerCount)
            debugLog("✅ Villagers arrived - starting demolition of \(building.buildingType.displayName)")
        }
    }
    
    /// Updates training queues for all buildings - runs 1x per second
    private func updateTrainingQueues(currentTime: TimeInterval) {
        for building in hexMap.buildings where building.state == .completed {
            building.updateTraining(currentTime: currentTime)
            building.updateVillagerTraining(currentTime: currentTime)
        }
    }
    
    // MARK: - Entity Lookup Helpers

    /// Finds the EntityNode for a given Army by matching armyReference identity
    func findEntityNode(for army: Army) -> EntityNode? {
        return hexMap?.entities.first { entityNode in
            entityNode.armyReference === army
        }
    }

    // MARK: - Home Base System

    /// Checks if an army has arrived at a valid home base and updates the home base reference
    func checkAndUpdateHomeBase(for army: Army, at coordinate: HexCoordinate) {
        // Check if there's a building at this coordinate
        guard let building = hexMap?.getBuilding(at: coordinate) else { return }

        // Check if building is a valid home base type
        guard Army.canBeHomeBase(building.buildingType) else { return }

        // Check if army owner matches building owner
        guard building.owner?.id == army.owner?.id else { return }

        // Check if building is operational (completed state)
        guard building.data.isOperational else { return }

        // Update the army's home base
        army.setHomeBase(building.data.id)
        debugLog("🏠 Army \(army.name) home base updated to \(building.buildingType.displayName) at (\(coordinate.q), \(coordinate.r))")
    }

    /// Handles building destruction by reassigning home base references for affected armies
    func handleBuildingDestruction(_ building: BuildingNode) {
        // When using the engine, GameState.removeBuilding() handles home base reassignment
        // For legacy mode, reassign to City Center instead of clearing to nil
        guard let player = building.owner else { return }

        let buildingID = building.data.id

        // Find city center for this player
        guard let cityCenter = player.buildings.first(where: { $0.buildingType == .cityCenter }) else {
            return
        }

        for army in player.armies {
            if army.homeBaseID == buildingID {
                army.setHomeBase(cityCenter.data.id)
                debugLog("🏠 Army \(army.name) home base reassigned to City Center (building destroyed)")
            }
        }
    }

    // MARK: - Combat Handling
    // Combat is now handled by GameEngine.shared.combatEngine
    // Visual updates for combat are handled through StateChanges processed by GameVisualLayer

    // MARK: - End Game / Starvation

    /// Checks if the player has been at 0 food for too long
    private func checkStarvationCondition(currentTime: TimeInterval) {
        guard let player = player else { return }

        let currentFood = player.getResource(.food)

        if currentFood <= 0 {
            // Start tracking zero food time if not already
            if zeroFoodStartTime == nil {
                zeroFoodStartTime = currentTime
                debugLog("Warning: Food reached 0! Starvation timer started.")
                // Notify UI immediately so countdown starts without delay
                NotificationCenter.default.post(name: .starvationStarted, object: nil)
            } else {
                // Check if time limit exceeded
                let timeAtZeroFood = currentTime - zeroFoodStartTime!
                if timeAtZeroFood >= starvationTimeLimit {
                    // Game over - starvation
                    triggerGameOver(isVictory: false, reason: .starvation)
                }
            }
        } else {
            // Reset timer if food is above 0
            if zeroFoodStartTime != nil {
                debugLog("Food restored. Starvation timer reset.")
                zeroFoodStartTime = nil
            }
        }
    }

    /// Returns how many seconds remain before starvation (nil if food > 0)
    func getStarvationTimeRemaining() -> TimeInterval? {
        guard let startTime = zeroFoodStartTime else { return nil }
        let elapsed = Date().timeIntervalSince1970 - startTime
        return max(0, starvationTimeLimit - elapsed)
    }

    /// Triggers the end of the game
    func triggerGameOver(isVictory: Bool, reason: GameOverReason) {
        guard !isGameOver else { return }

        isGameOver = true
        debugLog("Game Over! Victory: \(isVictory), Reason: \(reason)")

        // Notify delegate
        onGameOver?(isVictory, reason)
    }

    /// Called when player resigns
    func resignGame() {
        triggerGameOver(isVictory: false, reason: .resignation)
    }

    // Touch handling, drag-to-move, entity selection: see GameScene+InputHandling.swift

    // MARK: - Building Placement Mode

    /// Enters building placement mode and highlights valid tiles
    func enterBuildingPlacementMode(buildingType: BuildingType, villagerGroup: VillagerGroup?) {
        buildingPlacementController.enterBuildingPlacementMode(buildingType: buildingType, villagerGroup: villagerGroup)
    }

    /// Exits building placement mode and clears highlights
    func exitBuildingPlacementMode() {
        buildingPlacementController.exitBuildingPlacementMode()
    }

    // MARK: - Rotation Preview Mode for Multi-Tile Buildings

    /// Enters rotation preview mode for multi-tile buildings (Castle, Fort)
    func enterRotationPreviewMode(buildingType: BuildingType, anchor: HexCoordinate) {
        buildingPlacementController.enterRotationPreviewMode(buildingType: buildingType, anchor: anchor)
    }

    /// Updates the rotation preview highlights to show current rotation
    func updateRotationPreview() {
        buildingPlacementController.updateRotationPreview()
    }

    /// Cycles to the next rotation (0-5)
    func cycleRotationPreview() {
        buildingPlacementController.cycleRotationPreview()
    }

    /// Confirms the current rotation and executes the build
    func confirmRotationPreview() -> Bool {
        return buildingPlacementController.confirmRotationPreview()
    }

    /// Exits rotation preview mode and cleans up
    func exitRotationPreviewMode() {
        buildingPlacementController.exitRotationPreviewMode()
    }

    /// Returns whether the current rotation preview is valid for building
    func isCurrentRotationValid() -> Bool {
        return buildingPlacementController.isCurrentRotationValid()
    }

    // MARK: - BuildingPlacementDelegate

    func buildingPlacementController(_ controller: BuildingPlacementController, didSelectLocation coordinate: HexCoordinate) {
        onBuildingPlacementSelected?(coordinate)
    }

    func buildingPlacementController(_ controller: BuildingPlacementController, didEnterRotationPreviewFor buildingType: BuildingType, at coordinate: HexCoordinate) {
        gameDelegate?.gameScene(self, didEnterRotationPreviewForBuilding: buildingType, at: coordinate)
    }

    func buildingPlacementControllerDidExitRotationPreview(_ controller: BuildingPlacementController) {
        gameDelegate?.gameSceneDidExitRotationPreview(self)
    }

    func buildingPlacementController(_ controller: BuildingPlacementController, showAlertWithTitle title: String, message: String) {
        gameDelegate?.gameScene(self, showAlertWithTitle: title, message: message)
    }

    func buildingPlacementController(_ controller: BuildingPlacementController, didConfirmRotation coordinate: HexCoordinate, rotation: Int) {
        onRotationConfirmed?(coordinate, rotation)
    }

    func selectTile(_ tile: HexTileNode) {
        // Check if we're in attack mode
        if let attacker = attackingArmy,
           let player = player {
            let command = AttackCommand(
                playerID: player.id,
                attackerEntityID: attacker.id,
                targetCoordinate: tile.coordinate
            )
            
            let result = CommandExecutor.shared.execute(command)
            
            if !result.succeeded, let reason = result.failureReason {
                gameDelegate?.gameScene(self, showAlertWithTitle: "Cannot Attack", message: reason)
            }
            
            attackingArmy = nil
            deselectAll()
            return
        }
        
        // Otherwise, select the tile and show menu
        selectedTile?.isSelected = false
        selectedEntity = nil
        
        tile.isSelected = true
        selectedTile = tile
        
        debugLog("Selected tile at q:\(tile.coordinate.q), r:\(tile.coordinate.r)")
        
        gameDelegate?.gameScene(self, didRequestMenuForTile: tile.coordinate)
    }
    
    func deselectAll() {
        selectedTile?.isSelected = false
        selectedTile = nil
    }
    
    func initiateMove(to destination: HexCoordinate) {
        debugLog("🔍 initiateMove called")
        debugLog("   Destination: (\(destination.q), \(destination.r))")

        let availableEntities = hexMap.entities.filter { entity in
            // Must not be currently moving
            guard !entity.isMoving else { return false }

            // Must be owned by player
            guard entity.entity.owner?.id == player?.id else { return false }

            // Villagers are included even if busy (panel will show warning)
            // The MenuCoordinator/MoveEntityPanel handles task cancellation

            // If it's an army, must not be in active combat
            if let army = entity.armyReference {
                guard !GameEngine.shared.combatEngine.isInCombat(armyID: army.id) else { return false }
            }

            return true
        }
        debugLog("   Available player entities: \(availableEntities.count)")
        
        guard !availableEntities.isEmpty else {
            debugLog("❌ No entities available to move")
            gameDelegate?.gameScene(self, showAlertWithTitle: "Cannot Move", message:"You don't have any units available to move.")
            return
        }
        
        // ✅ Use the dedicated move menu that doesn't open entity action menus
        debugLog("✅ Calling showMoveSelectionMenu...")
        gameDelegate?.gameScene(self, didRequestMoveSelection: destination, availableEntities: availableEntities)
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
        case .upgrading:
            message += "Upgrading \n"
        case .demolishing:
            let progress = Int(building.demolitionProgress * 100)
            message += "Status: Demolishing (\(progress)%)\n"
        }

        message += "\n\(building.buildingType.description)"
        
        gameDelegate?.gameScene(self, didRequestMenuForTile: building.coordinate)
    }
    
    func startCombat(attacker: Army, target: Any, location: HexCoordinate) {
        debugLog("⚔️ COMBAT STARTED!")

        let currentTime = GameEngine.shared.gameState?.currentTime ?? 0

        // Use CombatEngine for combat
        if let defenderArmy = target as? Army {
            // Army vs Army combat
            _ = GameEngine.shared.combatEngine.startCombat(
                attackerArmyID: attacker.id,
                defenderArmyID: defenderArmy.id,
                currentTime: currentTime
            )
        } else if let building = target as? BuildingNode {
            // Army vs Building combat
            _ = GameEngine.shared.combatEngine.startBuildingCombat(
                attackerArmyID: attacker.id,
                buildingID: building.data.id,
                currentTime: currentTime
            )
        }

        // Combat results will be processed by CombatEngine's update loop
        // and visual updates will be handled through StateChanges
    }
    
    func cleanupAfterCombat(attacker: Army, defender: Any) {
        // Remove attacker if destroyed
        if attacker.getTotalUnits() <= 0 {
            if let node = hexMap.entities.first(where: { ($0.entity as? Army)?.id == attacker.id }) {
                hexMap.removeEntity(node)
                node.removeFromParent()
                attacker.owner?.removeArmy(attacker)
                debugLog("💀 \(attacker.name) was destroyed")
            }
        }
        
        // Remove defender if destroyed
        if let defenderArmy = defender as? Army {
            if defenderArmy.getTotalUnits() <= 0 {
                if let node = hexMap.entities.first(where: { ($0.entity as? Army)?.id == defenderArmy.id }) {
                    hexMap.removeEntity(node)
                    node.removeFromParent()
                    defenderArmy.owner?.removeArmy(defenderArmy)
                    debugLog("💀 \(defenderArmy.name) was destroyed")
                }
            }
        } else if let building = defender as? BuildingNode {
            if building.state == .destroyed {
                // Clear home base references for any armies using this building
                handleBuildingDestruction(building)

                hexMap.removeBuilding(building)
                building.clearTileOverlays()  // Clean up multi-tile overlays
                building.removeFromParent()
                building.owner?.removeBuilding(building)

                // Update collection rates (building removal may affect adjacency bonuses)
                if isEngineEnabled, let owner = building.owner {
                    GameEngine.shared.resourceEngine.updateCollectionRates(forPlayer: owner.id)
                }

                debugLog("💀 \(building.buildingType.displayName) was destroyed")
            }
        } else if let villagers = defender as? VillagerGroup {
            if !villagers.hasVillagers() {
                if let node = hexMap.entities.first(where: { ($0.entity as? VillagerGroup)?.id == villagers.id }) {
                    hexMap.removeEntity(node)
                    node.removeFromParent()
                    villagers.owner?.removeEntity(villagers)
                    debugLog("💀 \(villagers.name) was destroyed")
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
    
    func initializeFogOfWar(fullyVisible: Bool = false) {
        guard let player = player else {
            debugLog("❌ Cannot initialize fog: No player")
            return
        }

        guard !allGamePlayers.isEmpty else {
            debugLog("❌ Cannot initialize fog: No players in allGamePlayers")
            return
        }

        debugLog("👁️ Initializing fog of war... (fullyVisible: \(fullyVisible))")

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

        // If fully visible mode, reveal entire map
        if fullyVisible {
            player.fogOfWar?.revealAllTiles()
            debugLog("👁️ Full visibility mode - revealing entire map")
        } else {
            // Update vision with all players to reveal areas
            player.updateVision(allPlayers: allGamePlayers)
        }

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
        debugLog("✅ Fog of war initialized successfully")
        debugLog("   📊 Total tiles: \(hexMap.tiles.count)")
        debugLog("   👁️ Fog overlays: \(hexMap.fogOverlays.count)")
        debugLog("   🏢 Buildings: \(hexMap.buildings.count)")
        debugLog("   🎭 Entities: \(hexMap.entities.count)")
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
        
        debugLog("🎯 Debug: \(tiles.count) tiles at radius \(radius) from (\(center.q), \(center.r))")
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
        debugLog("\n🎯 Vision Pattern for radius \(radius) from (\(center.q), \(center.r)):")
        
        var tilesAtDistance: [Int: [HexCoordinate]] = [:]
        
        for (coord, _) in hexMap.tiles {
            let dist = center.distance(to: coord)
            if dist <= radius {
                tilesAtDistance[dist, default: []].append(coord)
            }
        }
        
        for dist in 0...radius {
            let coords = tilesAtDistance[dist] ?? []
            debugLog("  Distance \(dist): \(coords.count) tiles")
            if coords.count <= 12 {
                for coord in coords.sorted(by: { $0.q < $1.q }) {
                    debugLog("    (\(coord.q), \(coord.r))")
                }
            }
        }
        debugLog("")
    }
    
    func drawStaticMovementPath(from start: HexCoordinate, path: [HexCoordinate]) {
        movementPathRenderer.drawStaticMovementPath(from: start, path: path)
    }

    func clearMovementPath() {
        movementPathRenderer.clearMovementPath()
    }

    func updateMovementPath(from currentPos: HexCoordinate, remainingPath: [HexCoordinate]) {
        movementPathRenderer.updateMovementPath(from: currentPos, remainingPath: remainingPath)
    }
    
    func checkAndOfferMerge(at coordinate: HexCoordinate) {
        let entitiesOnTile = hexMap.entities.filter { $0.coordinate == coordinate }
        let villagerGroups = entitiesOnTile.compactMap { $0 as? EntityNode }.filter { $0.entityType == .villagerGroup }
        
        if villagerGroups.count == 2 {
            showMergeOption?(villagerGroups[0], villagerGroups[1])
        }
    }
    
    func performMerge(group1: EntityNode, group2: EntityNode, newCount1: Int, newCount2: Int) {
        guard let villagers1 = group1.entity as? VillagerGroup,
              let villagers2 = group2.entity as? VillagerGroup else {
            debugLog("❌ Error: Cannot merge - not villager groups")
            return
        }
        
        // Calculate the current total
        let currentTotal = villagers1.villagerCount + villagers2.villagerCount
        
        // Calculate how many to add or remove from each group
        let diff1 = newCount1 - villagers1.villagerCount
        let diff2 = newCount2 - villagers2.villagerCount
        
        // ✅ Use the proper methods to modify villager counts
        if diff1 > 0 {
            villagers1.addVillagers(count: diff1)
        } else if diff1 < 0 {
            villagers1.removeVillagers(count: abs(diff1))
        }
        
        if diff2 > 0 {
            villagers2.addVillagers(count: diff2)
        } else if diff2 < 0 {
            villagers2.removeVillagers(count: abs(diff2))
        }
        
        // If one group is now empty, remove it
        if villagers2.villagerCount == 0 {
            if let index = hexMap.entities.firstIndex(where: { $0 === group2 }) {
                hexMap.entities.remove(at: index)
            }
            group2.removeFromParent()
            
            // ✅ Use Player's removeEntity method
            player?.removeEntity(villagers2)
        }
        
        if villagers1.villagerCount == 0 {
            if let index = hexMap.entities.firstIndex(where: { $0 === group1 }) {
                hexMap.entities.remove(at: index)
            }
            group1.removeFromParent()
            
            // ✅ Use Player's removeEntity method
            player?.removeEntity(villagers1)
        }
        
        // ✅ Update the entity textures (this refreshes the displayed count)
        if villagers1.villagerCount > 0 {
            group1.updateTexture(currentPlayer: player)
        }
        if villagers2.villagerCount > 0 {
            group2.updateTexture(currentPlayer: player)
        }
        
        debugLog("✅ Merged villagers: Group 1 now has \(villagers1.villagerCount), Group 2 now has \(villagers2.villagerCount)")
    }
    
    func villagerArrivedForHunt(villagerGroup: VillagerGroup, target: ResourcePointNode, entityNode: EntityNode) {
        debugLog("🏹 GameScene: Villagers arrived for hunt at (\(target.coordinate.q), \(target.coordinate.r))")
        
        // Verify target still exists and is valid
        guard target.parent != nil,
              target.resourceType.isHuntable,
              target.currentHealth > 0 else {
            debugLog("⚠️ Hunt target no longer valid")
            villagerGroup.clearTask()
            entityNode.isMoving = false
            return
        }
        
        // Notify delegate to execute the hunt
        gameDelegate?.gameScene(self, villagerArrivedForHunt: villagerGroup, target: target, entityNode: entityNode)
    }
    
    @objc func handleFarmCompleted(_ notification: Notification) {
        guard let building = notification.object as? BuildingNode,
              let coordinate = notification.userInfo?["coordinate"] as? HexCoordinate else { return }

        // Create farmland resource at farm location
        let farmland = ResourcePointNode(coordinate: coordinate, resourceType: .farmland)
        let position = HexMap.hexToPixel(q: coordinate.q, r: coordinate.r)
        farmland.position = position
        farmland.zPosition = 4  // Above building

        // Add to hexMap's resource points array
        hexMap.addResourcePoint(farmland)

        // Also add to scene's resources node so it's visible
        if let resourcesNode = childNode(withName: "resourcesNode") {
            resourcesNode.addChild(farmland)
        } else {
            // Fallback: add directly to scene
            addChild(farmland)
        }

        // Auto-start gathering if a builder was provided
        if let builderEntity = notification.userInfo?["builder"] as? EntityNode,
           let villagerGroup = builderEntity.entity as? VillagerGroup {
            // Set up gathering task
            villagerGroup.currentTask = .gatheringResource(farmland)
            farmland.startGathering(by: villagerGroup)
            builderEntity.isMoving = true

            // Update collection rate for the player (use engine for accurate rates with adjacency)
            if let farmOwner = building.owner, isEngineEnabled {
                GameEngine.shared.resourceEngine.updateCollectionRates(forPlayer: farmOwner.id)
            } else if let farmOwner = building.owner {
                // Fallback for non-engine mode
                let rateContribution = 0.2 * Double(villagerGroup.villagerCount)
                farmOwner.increaseCollectionRate(.food, amount: rateContribution)
            }

            debugLog("🌾 Farm completed - \(villagerGroup.name) now gathering from farmland at (\(coordinate.q), \(coordinate.r))")
        } else {
            debugLog("🌾 Created farmland at (\(coordinate.q), \(coordinate.r))")
        }
    }

    @objc func handleBuildingCompleted(_ notification: Notification) {
        guard let building = notification.object as? BuildingNode else { return }

        // Recalculate adjacency bonuses for nearby buildings
        AdjacencyBonusManager.shared.recalculateAffectedBuildings(near: building.coordinate)

        // Update collection rates for the building's owner (building may affect adjacency bonuses)
        if isEngineEnabled, let owner = building.owner {
            GameEngine.shared.resourceEngine.updateCollectionRates(forPlayer: owner.id)
        }
    }

    @objc func handleCampCompleted(_ notification: Notification) {
        guard let building = notification.object as? BuildingNode,
              let coordinate = notification.userInfo?["coordinate"] as? HexCoordinate,
              let campType = notification.userInfo?["campType"] as? BuildingType else { return }

        // Find resources in camp range
        let resourcesInRange = hexMap.getResourcesInCampRange(campCoordinate: coordinate, campType: campType)

        guard !resourcesInRange.isEmpty else {
            debugLog("⚠️ \(campType.displayName) completed but no matching resources in range")
            return
        }

        // Auto-start gathering if a builder was provided
        if let builderEntity = notification.userInfo?["builder"] as? EntityNode,
           let villagerGroup = builderEntity.entity as? VillagerGroup {

            // Find the first available resource to gather
            if let targetResource = resourcesInRange.first(where: { $0.canBeGathered() }) {
                // Set up gathering task
                villagerGroup.currentTask = .gatheringResource(targetResource)
                targetResource.startGathering(by: villagerGroup)
                builderEntity.isMoving = true

                // Update collection rate for the player (use engine for accurate rates with adjacency)
                if let campOwner = building.owner, isEngineEnabled {
                    GameEngine.shared.resourceEngine.updateCollectionRates(forPlayer: campOwner.id)
                } else if let campOwner = building.owner {
                    // Fallback for non-engine mode
                    let yieldType = targetResource.resourceType.resourceYield
                    let rateContribution = 0.2 * Double(villagerGroup.villagerCount)
                    campOwner.increaseCollectionRate(yieldType, amount: rateContribution)
                }

                debugLog("⛏️ \(campType.displayName) completed - \(villagerGroup.name) now gathering from \(targetResource.resourceType.displayName) at (\(targetResource.coordinate.q), \(targetResource.coordinate.r))")
            } else {
                // No available resources, unlock the villagers
                builderEntity.isMoving = false
                villagerGroup.clearTask()
                debugLog("⚠️ \(campType.displayName) completed - no available resources to gather")
            }
        } else {
            debugLog("⛏️ \(campType.displayName) completed - resources in range: \(resourcesInRange.count)")
        }
    }

    func checkPendingUpgradeArrival(entity: EntityNode) {
        guard let villagers = entity.entity as? VillagerGroup,
              case .upgrading(let building) = villagers.currentTask else {
            return
        }

        // Check if villager has arrived at building
        if villagers.coordinate == building.coordinate && building.pendingUpgrade {
            // Start the actual upgrade now
            building.pendingUpgrade = false
            building.startUpgrade()
            debugLog("✅ Villagers arrived - starting upgrade of \(building.buildingType.displayName) to Lv.\(building.level + 1)")
        }
    }

    // MARK: - Reinforcement Management

    /// Spawns a reinforcement node and starts its movement to the target army
    func spawnReinforcementNode(
        reinforcement: ReinforcementGroup,
        path: [HexCoordinate],
        completion: @escaping (Bool) -> Void
    ) {
        reinforcementManager.spawnReinforcementNode(reinforcement: reinforcement, path: path, completion: completion)
    }

    /// Gets the reinforcement node for a given reinforcement ID
    func getReinforcementNode(id: UUID) -> ReinforcementNode? {
        return reinforcementManager.getReinforcementNode(id: id)
    }

    /// Cancels a reinforcement and returns it to source
    func cancelReinforcement(id: UUID) {
        reinforcementManager.cancelReinforcement(id: id)
    }

    /// Handles when an army is destroyed while reinforcements are en route
    func handleArmyDestroyed(_ army: Army) {
        reinforcementManager.handleArmyDestroyed(army)
    }

    // MARK: - ReinforcementManagerDelegate

    func reinforcementManager(_ manager: ReinforcementManager, showAlert title: String, message: String) {
        showAlert?(title, message)
    }

    // MARK: - Marching Villager Management

    /// Spawns a marching villager node and starts its movement to the target villager group
    func spawnMarchingVillagerNode(
        marchingGroup: MarchingVillagerGroup,
        path: [HexCoordinate],
        completion: @escaping (Bool) -> Void
    ) {
        villagerJoinManager.spawnMarchingVillagerNode(marchingGroup: marchingGroup, path: path, completion: completion)
    }

    /// Gets the marching villager node for a given ID
    func getMarchingVillagerNode(id: UUID) -> MarchingVillagerNode? {
        return villagerJoinManager.getMarchingVillagerNode(id: id)
    }

    /// Cancels marching villagers and returns them to source
    func cancelMarchingVillagers(id: UUID) {
        villagerJoinManager.cancelMarchingVillagers(id: id)
    }

    /// Handles when a villager group is destroyed while marching villagers are en route
    func handleVillagerGroupDestroyed(_ group: VillagerGroup) {
        villagerJoinManager.handleVillagerGroupDestroyed(group)
    }

    // MARK: - VillagerJoinManagerDelegate

    func villagerJoinManager(_ manager: VillagerJoinManager, showAlert title: String, message: String) {
        showAlert?(title, message)
    }
}
