import UIKit
import SpriteKit

// MARK: - Game Scene

class GameScene: SKScene, CombatSystemDelegate {
    
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

    // Camera control properties
    var cameraScale: CGFloat = 1.0
    private let minCameraScale: CGFloat = 0.5   // Zoomed in (closer)
    private let maxCameraScale: CGFloat = 2.5   // Zoomed out (further)
    var lastTouchPosition: CGPoint?
    var isPanning = false
    private var cameraVelocity: CGPoint = .zero
    private var panGestureRecognizer: UIPanGestureRecognizer?
    private var pinchGestureRecognizer: UIPinchGestureRecognizer?
    private var lastPanTranslation: CGPoint = .zero
    private var mapBounds: CGRect = .zero
    var allGamePlayers: [Player] = []
    var mapSize: Int = 20
    var resourceDensity: Double = 1.0
    var movementPathLine: SKShapeNode?
    var showMergeOption: ((EntityNode, EntityNode) -> Void)?
    weak var gameDelegate: GameSceneDelegate?
    var lastUpdateTime: TimeInterval?
    var skipInitialSetup: Bool = false
    var isLoading: Bool = false
    private var gatherAccumulators: [HexCoordinate: Double] = [:]
    private var lastGatherUpdateTime: TimeInterval?
    
    private var lastVisionUpdateTime: TimeInterval = 0
    private var lastBuildingTimerUpdateTime: TimeInterval = 0
    private var lastTrainingUpdateTime: TimeInterval = 0
    private var lastCombatUpdateTime: TimeInterval = 0

    // Update intervals (in seconds) - tune these based on gameplay feel
    private let visionUpdateInterval: TimeInterval = 0.25       // Fog/vision: 4x per second
    private let buildingTimerUpdateInterval: TimeInterval = 0.5 // Building UI: 2x per second
    private let trainingUpdateInterval: TimeInterval = 1.0      // Training queues: 1x per second
    private let gatheringUpdateInterval: TimeInterval = 0.5
    private let combatUpdateInterval: TimeInterval = 1.0        // Combat ticks: 1x per second

    // Building placement mode
    var isInBuildingPlacementMode: Bool = false
    var placementBuildingType: BuildingType?
    var placementVillagerGroup: VillagerGroup?
    private var highlightedTiles: [SKShapeNode] = []
    private var validPlacementCoordinates: [HexCoordinate] = []
    var onBuildingPlacementSelected: ((HexCoordinate) -> Void)?

    // Rotation preview mode for multi-tile buildings
    var isInRotationPreviewMode: Bool = false
    var rotationPreviewAnchor: HexCoordinate?
    var rotationPreviewType: BuildingType?
    var rotationPreviewRotation: Int = 0
    private var rotationPreviewHighlights: [SKShapeNode] = []
    var onRotationConfirmed: ((HexCoordinate, Int) -> Void)?

    // Reinforcement management
    var reinforcementNodes: [ReinforcementNode] = []
    private var reinforcementsNode: SKNode?


    override func didMove(to view: SKView) {
        setupScene()
        setupCamera()

        // Set up combat system delegate
        CombatSystem.shared.delegate = self

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
    
    func setupEmptyNodeStructure() {
        mapNode?.removeFromParent()
        unitsNode?.removeFromParent()
        buildingsNode?.removeFromParent()
        entitiesNode?.removeFromParent()
        reinforcementsNode?.removeFromParent()

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

        unitsNode = SKNode()
        unitsNode.name = "unitsNode"
        addChild(unitsNode)

        print("📦 Empty node structure created for saved game loading")
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
        cameraNode.setScale(cameraScale)
    }

    func setupGestureRecognizers() {
        guard let view = self.view else { return }

        // Remove existing gesture recognizers if any
        if let panGR = panGestureRecognizer {
            view.removeGestureRecognizer(panGR)
        }
        if let pinchGR = pinchGestureRecognizer {
            view.removeGestureRecognizer(pinchGR)
        }

        // Pan gesture for smooth scrolling
        let panGR = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGR.minimumNumberOfTouches = 1
        panGR.maximumNumberOfTouches = 1
        view.addGestureRecognizer(panGR)
        panGestureRecognizer = panGR

        // Pinch gesture for zooming
        let pinchGR = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
        view.addGestureRecognizer(pinchGR)
        pinchGestureRecognizer = pinchGR
    }

    func calculateMapBounds() {
        // Calculate the bounds of the map in scene coordinates
        guard hexMap != nil else { return }

        let hexRadius = HexTileNode.hexRadius

        // Use hexMap dimensions (handles both new and loaded games)
        let width = hexMap.width
        let height = hexMap.height

        // Get corner positions
        let minPos = HexMap.hexToPixel(q: 0, r: 0)
        let maxPos = HexMap.hexToPixel(q: width - 1, r: height - 1)

        // Add padding for hex size
        let padding = hexRadius * 2
        mapBounds = CGRect(
            x: minPos.x - padding,
            y: minPos.y - padding,
            width: (maxPos.x - minPos.x) + padding * 2,
            height: (maxPos.y - minPos.y) + padding * 2
        )
    }

    @objc func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        guard let view = self.view else { return }

        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)

        switch gesture.state {
        case .began:
            isPanning = true
            cameraVelocity = .zero
            lastPanTranslation = .zero

        case .changed:
            // Calculate delta from last translation
            let delta = CGPoint(
                x: translation.x - lastPanTranslation.x,
                y: translation.y - lastPanTranslation.y
            )
            lastPanTranslation = translation

            // Apply movement (inverted and scaled)
            let scaledDelta = CGPoint(
                x: -delta.x * cameraScale,
                y: delta.y * cameraScale  // Inverted Y for SpriteKit coordinate system
            )
            cameraNode.position.x += scaledDelta.x
            cameraNode.position.y += scaledDelta.y

            // Constrain camera position
            constrainCameraPosition()

        case .ended, .cancelled:
            // Apply momentum based on velocity
            cameraVelocity = CGPoint(
                x: -velocity.x * cameraScale * 0.1,
                y: velocity.y * cameraScale * 0.1
            )

            // Limit maximum velocity
            let maxVelocity: CGFloat = 1500
            let speed = sqrt(cameraVelocity.x * cameraVelocity.x + cameraVelocity.y * cameraVelocity.y)
            if speed > maxVelocity {
                let scale = maxVelocity / speed
                cameraVelocity.x *= scale
                cameraVelocity.y *= scale
            }

            isPanning = false

        default:
            break
        }
    }

    @objc func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
        guard let view = self.view else { return }

        switch gesture.state {
        case .began, .changed:
            // Get the pinch center in scene coordinates
            let pinchCenter = gesture.location(in: view)
            let scenePoint = convertPoint(fromView: pinchCenter)

            // Calculate new scale
            let newScale = cameraScale / gesture.scale
            let clampedScale = min(max(newScale, minCameraScale), maxCameraScale)

            // Only apply if scale actually changed
            if clampedScale != cameraScale {
                // Calculate the offset to zoom towards the pinch point
                let scaleDiff = clampedScale / cameraScale
                let offsetX = (scenePoint.x - cameraNode.position.x) * (1 - scaleDiff)
                let offsetY = (scenePoint.y - cameraNode.position.y) * (1 - scaleDiff)

                cameraScale = clampedScale
                cameraNode.setScale(cameraScale)

                // Adjust camera position to zoom towards pinch point
                cameraNode.position.x += offsetX
                cameraNode.position.y += offsetY

                // Constrain camera position
                constrainCameraPosition()
            }

            // Reset gesture scale to 1 to get incremental changes
            gesture.scale = 1.0

        case .ended, .cancelled:
            break

        default:
            break
        }
    }

    func constrainCameraPosition() {
        guard mapBounds != .zero else { return }

        // Calculate the visible area based on current scale
        let visibleWidth = size.width * cameraScale
        let visibleHeight = size.height * cameraScale

        // Calculate allowed camera position range
        // Add vertical padding for better north/south edge visibility
        let verticalPadding: CGFloat = 200
        let minX = mapBounds.minX + visibleWidth / 2
        let maxX = mapBounds.maxX - visibleWidth / 2
        let minY = mapBounds.minY + visibleHeight / 2 - verticalPadding
        let maxY = mapBounds.maxY - visibleHeight / 2 + verticalPadding

        // If the map is smaller than the view, center it
        if minX > maxX {
            cameraNode.position.x = mapBounds.midX
        } else {
            cameraNode.position.x = min(max(cameraNode.position.x, minX), maxX)
        }

        if minY > maxY {
            cameraNode.position.y = mapBounds.midY
        } else {
            cameraNode.position.y = min(max(cameraNode.position.y, minY), maxY)
        }
    }

    func applyCameraMomentum() {
        // Apply velocity with friction
        let friction: CGFloat = 0.92

        if abs(cameraVelocity.x) > 0.5 || abs(cameraVelocity.y) > 0.5 {
            cameraNode.position.x += cameraVelocity.x * 0.016  // Approximate frame time
            cameraNode.position.y += cameraVelocity.y * 0.016

            cameraVelocity.x *= friction
            cameraVelocity.y *= friction

            // Constrain after momentum
            constrainCameraPosition()
        } else {
            cameraVelocity = .zero
        }
    }

    /// Centers and zooms the camera to a specific coordinate
    func focusCamera(on coordinate: HexCoordinate, zoom: CGFloat? = nil, animated: Bool = true) {
        let targetPosition = HexMap.hexToPixel(q: coordinate.q, r: coordinate.r)

        if animated {
            let moveAction = SKAction.move(to: targetPosition, duration: 0.3)
            moveAction.timingMode = .easeInEaseOut
            cameraNode.run(moveAction)

            if let targetZoom = zoom {
                let zoomAction = SKAction.scale(to: targetZoom, duration: 0.3)
                zoomAction.timingMode = .easeInEaseOut
                cameraNode.run(zoomAction) { [weak self] in
                    self?.cameraScale = targetZoom
                }
            }
        } else {
            cameraNode.position = targetPosition
            if let targetZoom = zoom {
                cameraScale = targetZoom
                cameraNode.setScale(cameraScale)
            }
        }

        constrainCameraPosition()
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
    }

    // MARK: - Map Generator Setup

    /// Sets up the map using a MapGenerator for structured map creation (e.g., Arabia style)
    /// - Parameters:
    ///   - generator: The map generator to use
    ///   - players: Array of players to set up (player at index 0 is the human player)
    func setupMapWithGenerator(_ generator: MapGenerator, players: [Player]) {
        guard players.count >= 2 else {
            print("❌ Arabia map requires at least 2 players")
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

            print("✅ Player \(index + 1) (\(currentPlayer.name)) spawned at (\(startPos.coordinate.q), \(startPos.coordinate.r))")
        }

        // Generate and spawn neutral resources
        let startCoords = startPositions.map { $0.coordinate }
        let neutralResources = generator.generateNeutralResources(excludingRadius: 10, aroundPositions: startCoords)
        for placement in neutralResources {
            spawnResourceAtCoordinate(placement.coordinate, type: placement.resourceType, in: resourcesNode)
        }

        print("✅ Spawned \(neutralResources.count) neutral resources")

        // Set player references
        self.player = players[0]
        self.enemyPlayer = players.count > 1 ? players[1] : nil
        self.allGamePlayers = players

        // Set diplomacy between players
        for i in 0..<players.count {
            for j in (i + 1)..<players.count {
                players[i].setDiplomacyStatus(with: players[j], status: .enemy)
            }
        }

        // Calculate map bounds and center camera on player's town center
        calculateMapBounds()
        let playerStart = startPositions[0].coordinate
        let playerTownCenterPos = HexMap.hexToPixel(q: playerStart.q, r: playerStart.r)
        cameraNode.position = playerTownCenterPos

        // Initialize adjacency bonus manager
        AdjacencyBonusManager.shared.setup(hexMap: hexMap)

        print("✅ Arabia map generated!")
        print("   Map size: \(generator.width)x\(generator.height)")
        print("   Total tiles: \(hexMap.tiles.count)")
        print("   Total resources: \(hexMap.resourcePoints.count)")
    }

    /// Helper to find an adjacent walkable coordinate
    private func findAdjacentWalkableCoordinate(near coord: HexCoordinate) -> HexCoordinate {
        for neighbor in coord.neighbors() {
            if hexMap.isValidCoordinate(neighbor) && hexMap.isWalkable(neighbor) {
                if hexMap.getBuilding(at: neighbor) == nil && hexMap.getEntity(at: neighbor) == nil {
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
    /// Creates armies with commanders and swordsmen - no buildings or villagers
    /// - Parameters:
    ///   - generator: The arena map generator to use
    ///   - players: Array of players (player at index 0 is the human player)
    func setupArenaWithGenerator(_ generator: MapGenerator, players: [Player]) {
        guard players.count >= 2 else {
            print("Arena map requires at least 2 players")
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

        // Setup each player with an army (no buildings, no villagers)
        for (index, startPos) in startPositions.enumerated() {
            guard index < players.count else { continue }
            let currentPlayer = players[index]

            // Create a level 1 infantry commander for the arena
            let commander = Commander(
                name: Commander.randomName(),
                specialty: .infantry,
                baseLeadership: 10,
                baseTactics: 10,
                portraitColor: Commander.randomColor(),
                owner: currentPlayer
            )

            // Create army at starting position
            let armyName = index == 0 ? "Player's Army" : "\(currentPlayer.name)'s Army"
            let army = Army(name: armyName, coordinate: startPos.coordinate, commander: commander, owner: currentPlayer)

            // Add 5 swordsmen to the army
            army.addMilitaryUnits(.swordsman, count: 5)

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

            // Register commander with player
            currentPlayer.addCommander(commander)

            // Setup health bar for the army
            armyNode.setupHealthBar(currentPlayer: players[0])

            print("Player \(index + 1) (\(currentPlayer.name)) army spawned at (\(startPos.coordinate.q), \(startPos.coordinate.r))")
            print("   Commander: \(commander.name)")
            print("   Swordsmen: 5")
        }

        // Set player references
        self.player = players[0]
        self.enemyPlayer = players.count > 1 ? players[1] : nil
        self.allGamePlayers = players

        // Set diplomacy between players
        for i in 0..<players.count {
            for j in (i + 1)..<players.count {
                players[i].setDiplomacyStatus(with: players[j], status: .enemy)
            }
        }

        // Calculate map bounds and center camera
        calculateMapBounds()
        let centerCoord = HexCoordinate(q: generator.width / 2, r: generator.height / 2)
        let centerPos = HexMap.hexToPixel(q: centerCoord.q, r: centerCoord.r)
        cameraNode.position = centerPos

        // Zoom in slightly for better view of small arena
        cameraScale = 0.8
        cameraNode.setScale(cameraScale)

        print("Arena map generated!")
        print("   Map size: \(generator.width)x\(generator.height)")
        print("   Total tiles: \(hexMap.tiles.count)")
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

        let aiPlayer = Player(name: "Enemy", color: .red)
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
        print("  🔴 Enemy at (\(aiSpawn.q), \(aiSpawn.r))")
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
            gameDelegate?.gameScene(self, showAlertWithTitle: "Cannot Select", message:"This unit is not visible due to fog of war.")
            return
        }
        
        // ✅ FIX: Double-check entity visibility through fog system
        if let fogOfWar = player.fogOfWar {
            guard fogOfWar.shouldShowEntity(entity.entity, at: entity.coordinate) else {
                print("❌ Entity not visible according to fog of war")
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
        
        print("Selected \(entity.entityType.displayName) at q:\(entity.coordinate.q), r:\(entity.coordinate.r)")
        
        gameDelegate?.gameScene(self, didRequestMenuForTile: entity.coordinate)
    }
    
    override func update(_ currentTime: TimeInterval) {
        // Skip updates while loading or if map isn't ready
        guard !isLoading, hexMap != nil else { return }
        
        let realWorldTime = Date().timeIntervalSince1970
        
        // =========================================================================
        // EVERY FRAME: Critical updates only
        // =========================================================================
        // Apply camera momentum for smooth panning
        applyCameraMomentum()

        // =========================================================================
        // FAST UPDATES (4x per second): Vision & Fog - needs to feel responsive
        // =========================================================================
        if currentTime - lastVisionUpdateTime >= visionUpdateInterval {
            updateVisionAndFog()
            lastVisionUpdateTime = currentTime
        }
        
        // =========================================================================
        // MEDIUM UPDATES (2x per second): UI elements & display
        // =========================================================================
        if currentTime - lastBuildingTimerUpdateTime >= buildingTimerUpdateInterval {
            updateBuildingTimers()

            // Update entity health bars
            for entity in hexMap.entities {
                entity.updateHealthBar()
            }

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
        // COMBAT UPDATES (1x per second): Phased combat simulation
        // =========================================================================
        if currentTime - lastCombatUpdateTime >= combatUpdateInterval {
            CombatSystem.shared.updateCombats(deltaTime: combatUpdateInterval)
            lastCombatUpdateTime = currentTime
        }

        // =========================================================================
        // GATHERING UPDATES (2x per second): Resource gathering with accumulators
        // =========================================================================
        updateResourceGathering(realWorldTime: realWorldTime)
    }
    
    // MARK: - Time-Sliced Update Helpers
    
    /// Updates vision and fog of war - runs 4x per second
    private func updateVisionAndFog() {
        guard let player = player else { return }
        
        // Update player's vision based on unit positions
        player.updateVision(allPlayers: allGamePlayers)
        
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

        // Post notification
        NotificationCenter.default.post(
            name: NSNotification.Name("BuildingDemolishedNotification"),
            object: self,
            userInfo: ["coordinate": building.coordinate, "refund": refund]
        )

        print("🏚️ Building demolished: \(building.buildingType.displayName) - Refunded: \(refund)")
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
            print("✅ Villagers arrived - starting demolition of \(building.buildingType.displayName)")
        }
    }
    
    /// Updates training queues for all buildings - runs 1x per second
    private func updateTrainingQueues(currentTime: TimeInterval) {
        for building in hexMap.buildings where building.state == .completed {
            building.updateTraining(currentTime: currentTime)
            building.updateVillagerTraining(currentTime: currentTime)
        }
    }
    
    /// Updates resource gathering with time-based accumulators - runs ~2x per second
    private func updateResourceGathering(realWorldTime: TimeInterval) {
        guard let player = player else { return }

        // Calculate time delta for accurate timing
        let gatherDeltaTime: TimeInterval
        if let lastGather = lastGatherUpdateTime {
            gatherDeltaTime = realWorldTime - lastGather
        } else {
            lastGatherUpdateTime = realWorldTime
            return  // Skip first frame to establish baseline
        }

        // Only update every 0.5 seconds (2x per second)
        // Skip if delta is too large (app was backgrounded)
        guard gatherDeltaTime >= 0.5 else { return }
        guard gatherDeltaTime < 2.0 else {
            // Reset baseline if app was backgrounded
            lastGatherUpdateTime = realWorldTime
            return
        }

        // Update last gather time AFTER the guard succeeds
        lastGatherUpdateTime = realWorldTime
        
        // Process all resource points that are being gathered
        for resourcePoint in hexMap.resourcePoints where resourcePoint.isBeingGathered {
            processResourceGathering(
                resourcePoint: resourcePoint,
                player: player,
                deltaTime: gatherDeltaTime
            )
        }
    }
    
    /// Processes gathering for a single resource point
    private func processResourceGathering(resourcePoint: ResourcePointNode, player: Player, deltaTime: TimeInterval) {
        
        // Handle farmland wood cost
        if resourcePoint.resourceType == .farmland {
            if !processFarmlandWoodCost(resourcePoint: resourcePoint, player: player, deltaTime: deltaTime) {
                return  // Farm stopped due to no wood
            }
        }
        
        // Check if depleted
        if resourcePoint.isDepleted() {
            handleDepletedResource(resourcePoint: resourcePoint, player: player)
            return
        }
        
        // Calculate gather rate from all villagers ON the tile
        var gatherRatePerSecond = 0.0
        for villagerGroup in resourcePoint.assignedVillagerGroups {
            // Only gather if villagers have arrived at the resource
            if villagerGroup.coordinate == resourcePoint.coordinate {
                var baseRate = 0.2 * Double(villagerGroup.villagerCount)

                // Apply research bonus
                let resourceYield = resourcePoint.resourceType.resourceYield
                switch resourceYield {
                case .wood:
                    baseRate *= ResearchManager.shared.getWoodGatheringMultiplier()
                case .food:
                    baseRate *= ResearchManager.shared.getFoodGatheringMultiplier()
                case .stone:
                    baseRate *= ResearchManager.shared.getStoneGatheringMultiplier()
                case .ore:
                    baseRate *= ResearchManager.shared.getOreGatheringMultiplier()
                }

                // Apply adjacency bonus from mills/warehouses
                let adjacencyBonus = getAdjacencyBonusForResource(resourcePoint: resourcePoint)
                baseRate *= (1.0 + adjacencyBonus)

                gatherRatePerSecond += baseRate
            }
        }
        
        // Skip if no villagers are actually gathering
        guard gatherRatePerSecond > 0 else { return }
        
        // Calculate amount gathered this frame
        let gatherThisFrame = gatherRatePerSecond * deltaTime
        
        // Get/create accumulator
        let currentAccumulator = gatherAccumulators[resourcePoint.coordinate] ?? 0
        let newAccumulator = currentAccumulator + gatherThisFrame
        
        // Only deplete whole numbers
        let wholeAmount = Int(newAccumulator)
        if wholeAmount > 0 {
            // ✅ FIX: Directly update remaining amount and call updateLabel
            let actualGathered = min(wholeAmount, resourcePoint.remainingAmount)
            resourcePoint.setRemainingAmount(resourcePoint.remainingAmount - actualGathered)
            
            // Keep the fractional remainder
            gatherAccumulators[resourcePoint.coordinate] = newAccumulator - Double(wholeAmount)
            
            // Occasional logging
            if actualGathered > 0 && Int.random(in: 0...60) == 0 {
                print("⛏️ Depleted \(actualGathered) from \(resourcePoint.resourceType.displayName) (\(resourcePoint.remainingAmount) remaining)")
            }
        } else {
            gatherAccumulators[resourcePoint.coordinate] = newAccumulator
        }
    }
    
    /// Calculates gather rate for a villager group with research bonuses
    private func calculateGatherRate(villagerGroup: VillagerGroup, resourceType: ResourcePointType) -> Double {
        var baseRate = 0.2 * Double(villagerGroup.villagerCount)
        
        // Apply research bonus based on resource type
        switch resourceType.resourceYield {
        case .wood:
            baseRate *= ResearchManager.shared.getWoodGatheringMultiplier()
        case .food:
            baseRate *= ResearchManager.shared.getFoodGatheringMultiplier()
        case .stone:
            baseRate *= ResearchManager.shared.getStoneGatheringMultiplier()
        case .ore:
            baseRate *= ResearchManager.shared.getOreGatheringMultiplier()
        default:
            break
        }
        
        return baseRate
    }

    /// Gets the adjacency bonus for a resource point based on nearby buildings
    private func getAdjacencyBonusForResource(resourcePoint: ResourcePointNode) -> Double {
        // For farmland, the bonus comes from the farm building at the same coordinate
        if resourcePoint.resourceType == .farmland {
            if let farm = hexMap.getBuilding(at: resourcePoint.coordinate),
               farm.buildingType == .farm,
               farm.state == .completed {
                return AdjacencyBonusManager.shared.getGatherRateBonus(for: farm.data.id)
            }
        }

        // For trees, the bonus comes from the lumber camp covering this resource
        if resourcePoint.resourceType == .trees {
            // Find the lumber camp that covers this resource
            for building in hexMap.buildings {
                if building.buildingType == .lumberCamp && building.state == .completed {
                    // Check if this camp covers the resource (direct adjacency or via roads)
                    let reachable = hexMap.getExtendedCampReach(from: building.coordinate)
                    if reachable.contains(resourcePoint.coordinate) {
                        return AdjacencyBonusManager.shared.getGatherRateBonus(for: building.data.id)
                    }
                }
            }
        }

        // For ore/stone, the bonus comes from the mining camp covering this resource
        if resourcePoint.resourceType == .oreMine || resourcePoint.resourceType == .stoneQuarry {
            // Find the mining camp that covers this resource
            for building in hexMap.buildings {
                if building.buildingType == .miningCamp && building.state == .completed {
                    // Check if this camp covers the resource (direct adjacency or via roads)
                    let reachable = hexMap.getExtendedCampReach(from: building.coordinate)
                    if reachable.contains(resourcePoint.coordinate) {
                        return AdjacencyBonusManager.shared.getGatherRateBonus(for: building.data.id)
                    }
                }
            }
        }

        return 0.0
    }

    /// Applies gathering to a resource point using accumulator for fractional amounts
    private func applyGathering(resourcePoint: ResourcePointNode, rate: Double, deltaTime: TimeInterval) {
        let gatherThisFrame = rate * deltaTime
        let currentAccumulator = gatherAccumulators[resourcePoint.coordinate] ?? 0
        let newAccumulator = currentAccumulator + gatherThisFrame
        
        // Only deplete whole numbers
        let wholeAmount = Int(newAccumulator)
        if wholeAmount > 0 {
            let gathered = resourcePoint.gather(amount: wholeAmount)
            
            // Keep the fractional remainder
            gatherAccumulators[resourcePoint.coordinate] = newAccumulator - Double(wholeAmount)
            
            // Occasional logging to reduce spam
            if gathered > 0 && Int.random(in: 0...60) == 0 {
                print("⛏️ Depleted \(gathered) from \(resourcePoint.resourceType.displayName) (\(resourcePoint.remainingAmount) remaining)")
            }
        } else {
            gatherAccumulators[resourcePoint.coordinate] = newAccumulator
        }
    }
    
    /// Processes wood cost for farmland, returns false if farm should stop
    private func processFarmlandWoodCost(resourcePoint: ResourcePointNode, player: Player, deltaTime: TimeInterval) -> Bool {
        let woodCostPerSecond = 0.1
        let woodCostThisFrame = woodCostPerSecond * deltaTime
        
        // Use a separate key for wood cost accumulator
        let farmWoodKey = HexCoordinate(q: resourcePoint.coordinate.q + 10000, r: resourcePoint.coordinate.r + 10000)
        let currentAcc = gatherAccumulators[farmWoodKey] ?? 0.0
        let newAcc = currentAcc + woodCostThisFrame
        let wholeAmount = Int(newAcc)
        
        if wholeAmount > 0 {
            let currentWood = player.getResource(.wood)
            if currentWood >= wholeAmount {
                player.removeResource(.wood, amount: wholeAmount)
                gatherAccumulators[farmWoodKey] = newAcc - Double(wholeAmount)
            } else {
                // No wood - stop all villagers on this farm
                print("⚠️ Farm stopped at (\(resourcePoint.coordinate.q), \(resourcePoint.coordinate.r)) - out of wood!")
                stopVillagersAtResource(resourcePoint: resourcePoint, player: player, resourceYield: .food)
                gatherAccumulators.removeValue(forKey: farmWoodKey)
                return false
            }
        } else {
            gatherAccumulators[farmWoodKey] = newAcc
        }
        
        return true
    }
    
    /// Handles a depleted resource - clears villagers and cleans up
    private func handleDepletedResource(resourcePoint: ResourcePointNode, player: Player) {
        stopVillagersAtResource(resourcePoint: resourcePoint, player: player, resourceYield: resourcePoint.resourceType.resourceYield)
        gatherAccumulators.removeValue(forKey: resourcePoint.coordinate)

        // Remove the resource node from the map and scene
        hexMap?.removeResourcePoint(resourcePoint)
        let fadeOut = SKAction.fadeOut(withDuration: 0.5)
        resourcePoint.run(fadeOut) { [weak resourcePoint] in
            resourcePoint?.removeFromParent()
        }

        print("✅ Resource depleted and removed, all villagers now idle")
    }
    
    /// Stops all villagers gathering at a resource point
    private func stopVillagersAtResource(resourcePoint: ResourcePointNode, player: Player, resourceYield: ResourceType) {
        for villagerGroup in resourcePoint.assignedVillagerGroups {
            // Revert collection rate
            let rateContribution = 0.2 * Double(villagerGroup.villagerCount)
            player.decreaseCollectionRate(resourceYield, amount: rateContribution)
            
            villagerGroup.clearTask()
            
            // Unlock the entity
            if let entityNode = hexMap.entities.first(where: {
                ($0.entity as? VillagerGroup)?.id == villagerGroup.id
            }) {
                entityNode.isMoving = false
            }
        }
        resourcePoint.stopGathering()
    }

    // MARK: - Entity Lookup Helpers

    /// Finds the EntityNode for a given Army by matching armyReference identity
    func findEntityNode(for army: Army) -> EntityNode? {
        return hexMap?.entities.first { entityNode in
            entityNode.armyReference === army
        }
    }

    // MARK: - CombatSystemDelegate

    func combatSystem(_ system: CombatSystem, didStartPhasedCombat combat: ActiveCombat) {
        gameDelegate?.gameScene(self, didStartPhasedCombat: combat)
        NotificationCenter.default.post(name: .phasedCombatStarted, object: combat)

        // Debug logging for HP bar positioning
        print("🔍 Combat started - searching for EntityNodes...")
        print("   Attacker army: \(combat.attackerArmy?.name ?? "nil")")
        print("   Defender army: \(combat.defenderArmy?.name ?? "nil")")
        print("   Total entities in hexMap: \(hexMap?.entities.count ?? 0)")

        // Position HP bars for combat visualization: attacker on top, defender on bottom
        // Note: setupHealthBar() is NOT called here - bars are already created at entity spawn
        if let attackerArmy = combat.attackerArmy,
           let attackerNode = findEntityNode(for: attackerArmy) {
            print("   ✅ Found attacker node - setting to TOP")
            attackerNode.updateHealthBarCombatPosition(isAttacker: true)
        } else {
            print("   ❌ Attacker node NOT FOUND")
            if let attackerArmy = combat.attackerArmy {
                print("      Looking for army with id: \(attackerArmy.id)")
                for (index, entity) in (hexMap?.entities ?? []).enumerated() {
                    if let armyRef = entity.armyReference {
                        print("      Entity[\(index)] armyRef id: \(armyRef.id), name: \(armyRef.name)")
                    }
                }
            }
        }
        if let defenderArmy = combat.defenderArmy,
           let defenderNode = findEntityNode(for: defenderArmy) {
            print("   ✅ Found defender node - setting to BOTTOM")
            defenderNode.updateHealthBarCombatPosition(isAttacker: false)
        } else {
            print("   ❌ Defender node NOT FOUND")
            if let defenderArmy = combat.defenderArmy {
                print("      Looking for army with id: \(defenderArmy.id)")
                for (index, entity) in (hexMap?.entities ?? []).enumerated() {
                    if let armyRef = entity.armyReference {
                        print("      Entity[\(index)] armyRef id: \(armyRef.id), name: \(armyRef.name)")
                    }
                }
            }
        }
    }

    func combatSystem(_ system: CombatSystem, didUpdateCombat combat: ActiveCombat) {
        gameDelegate?.gameScene(self, didUpdatePhasedCombat: combat)
        NotificationCenter.default.post(name: .phasedCombatUpdated, object: combat)

        // Update HP bars during combat
        if let attackerArmy = combat.attackerArmy,
           let attackerNode = findEntityNode(for: attackerArmy) {
            attackerNode.updateHealthBar()
        }
        if let defenderArmy = combat.defenderArmy,
           let defenderNode = findEntityNode(for: defenderArmy) {
            defenderNode.updateHealthBar()
        }
    }

    func combatSystem(_ system: CombatSystem, didEndCombat combat: ActiveCombat, result: CombatResult) {
        gameDelegate?.gameScene(self, didEndPhasedCombat: combat, result: result)
        NotificationCenter.default.post(name: .phasedCombatEnded, object: combat, userInfo: ["result": result])

        // Reset HP bar positions after combat ends
        if let attackerArmy = combat.attackerArmy,
           let attackerNode = findEntityNode(for: attackerArmy) {
            attackerNode.resetHealthBarPosition()
        }
        if let defenderArmy = combat.defenderArmy,
           let defenderNode = findEntityNode(for: defenderArmy) {
            defenderNode.resetHealthBarPosition()
        }

        // Only show notification if player is involved
        guard let player = self.player,
              combat.attackerArmy?.owner?.id == player.id ||
              combat.defenderArmy?.owner?.id == player.id else { return }

        let isPlayerAttacker = combat.attackerArmy?.owner?.id == player.id
        let playerWon = (isPlayerAttacker && result == .attackerVictory) ||
                        (!isPlayerAttacker && result == .defenderVictory)

        // Calculate stats
        let playerCasualties: Int
        let enemyCasualties: Int
        if isPlayerAttacker {
            playerCasualties = combat.attackerState.initialUnitCount - combat.attackerState.totalUnits
            enemyCasualties = combat.defenderState.initialUnitCount - combat.defenderState.totalUnits
        } else {
            playerCasualties = combat.defenderState.initialUnitCount - combat.defenderState.totalUnits
            enemyCasualties = combat.attackerState.initialUnitCount - combat.attackerState.totalUnits
        }

        // Notify delegate to show alert
        let title = playerWon ? "Victory!" : "Defeat"
        let message = """
        Units Lost: \(playerCasualties)
        Enemy Casualties: \(enemyCasualties)
        """

        gameDelegate?.showBattleEndNotification(
            title: title,
            message: message,
            isVictory: playerWon
        )
    }

    // MARK: - Touch Handling
    // Note: Panning is handled by UIPanGestureRecognizer for smooth scrolling
    // Touch handlers are used for tap detection to interact with tiles/entities

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        lastTouchPosition = touch.location(in: self)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Panning is handled by gesture recognizer
        // This is kept for compatibility but doesn't do camera movement
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // Only handle as tap if not panning (gesture recognizer sets isPanning)
        if !isPanning {
            handleTouch(at: location)
        }

        lastTouchPosition = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        lastTouchPosition = nil
    }
    
    func handleTouch(at location: CGPoint) {
        let nodesAtPoint = nodes(at: location)

        print("🔍 Touch at location: \(location)")
        print("🔍 Found \(nodesAtPoint.count) nodes")
        for (index, node) in nodesAtPoint.enumerated() {
            print("   [\(index)] \(type(of: node)) - name: '\(node.name ?? "nil")' - zPos: \(node.zPosition)")
        }

        // Check if we're in building placement mode
        if isInBuildingPlacementMode {
            handleBuildingPlacementTouch(at: location, nodesAtPoint: nodesAtPoint)
            return
        }

        // Normal touch handling - ONLY look for HexTileNode - skip ALL other node types
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

    // MARK: - Building Placement Mode

    /// Enters building placement mode and highlights valid tiles
    func enterBuildingPlacementMode(buildingType: BuildingType, villagerGroup: VillagerGroup?) {
        isInBuildingPlacementMode = true
        placementBuildingType = buildingType
        placementVillagerGroup = villagerGroup

        // Find all valid placement coordinates
        validPlacementCoordinates = findValidBuildingLocations(for: buildingType)

        // Highlight valid tiles
        highlightValidPlacementTiles()

        print("🏗️ Entered building placement mode for \(buildingType.displayName)")
        print("   Found \(validPlacementCoordinates.count) valid locations")
    }

    /// Exits building placement mode and clears highlights
    func exitBuildingPlacementMode() {
        isInBuildingPlacementMode = false
        placementBuildingType = nil
        placementVillagerGroup = nil
        validPlacementCoordinates = []
        clearPlacementHighlights()

        print("🏗️ Exited building placement mode")
    }

    /// Finds all valid locations for a building type
    private func findValidBuildingLocations(for buildingType: BuildingType) -> [HexCoordinate] {
        guard let player = player else { return [] }

        var validCoordinates: [HexCoordinate] = []

        for (coord, tile) in hexMap.tiles {
            // Check visibility
            let visibility = player.getVisibilityLevel(at: coord)
            guard visibility == .visible else { continue }

            // Check if building can be placed (basic terrain check)
            guard hexMap.canPlaceBuilding(at: coord, buildingType: buildingType) else { continue }

            // For multi-tile buildings, we need to check all rotations
            if buildingType.requiresRotation {
                // For now, just check if ANY rotation works
                for rotation in 0..<6 {
                    let occupiedCoords = buildingType.getOccupiedCoordinates(anchor: coord, rotation: rotation)
                    let allValid = occupiedCoords.allSatisfy { occupied in
                        hexMap.canPlaceBuildingOnTile(at: occupied)
                    }
                    if allValid {
                        validCoordinates.append(coord)
                        break
                    }
                }
            } else {
                validCoordinates.append(coord)
            }
        }

        return validCoordinates
    }

    /// Highlights valid placement tiles with a green stroke
    private func highlightValidPlacementTiles() {
        clearPlacementHighlights()

        for coord in validPlacementCoordinates {
            let position = HexMap.hexToPixel(q: coord.q, r: coord.r)

            // Create a hexagon highlight shape
            let highlight = createHexHighlight(at: position, color: UIColor(red: 0.3, green: 0.9, blue: 0.3, alpha: 0.8))
            highlight.name = "placementHighlight_\(coord.q)_\(coord.r)"
            highlight.zPosition = 50

            addChild(highlight)
            highlightedTiles.append(highlight)

            // Add pulsing animation
            let pulse = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.4, duration: 0.5),
                SKAction.fadeAlpha(to: 0.8, duration: 0.5)
            ])
            highlight.run(SKAction.repeatForever(pulse))
        }
    }

    /// Creates a hexagon-shaped highlight node
    private func createHexHighlight(at position: CGPoint, color: UIColor) -> SKShapeNode {
        let radius: CGFloat = HexTileNode.hexRadius - 2
        let path = UIBezierPath()

        for i in 0..<6 {
            let angle = CGFloat(i) * CGFloat.pi / 3 - CGFloat.pi / 6
            let x = radius * cos(angle)
            let y = radius * sin(angle)

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.close()

        let shape = SKShapeNode(path: path.cgPath)
        shape.position = position
        shape.strokeColor = color
        shape.lineWidth = 4
        shape.fillColor = color.withAlphaComponent(0.2)
        shape.glowWidth = 2

        return shape
    }

    /// Clears all placement highlight nodes
    private func clearPlacementHighlights() {
        for highlight in highlightedTiles {
            highlight.removeFromParent()
        }
        highlightedTiles.removeAll()
    }

    /// Handles touch during building placement mode
    private func handleBuildingPlacementTouch(at location: CGPoint, nodesAtPoint: [SKNode]) {
        // Find the hex coordinate at this location
        let hexCoord = HexMap.pixelToHex(point: location)

        // Check if this is a valid placement location
        if validPlacementCoordinates.contains(hexCoord) {
            print("✅ Valid placement location selected: (\(hexCoord.q), \(hexCoord.r))")

            // Notify callback with selected coordinate
            onBuildingPlacementSelected?(hexCoord)

            // Exit placement mode
            exitBuildingPlacementMode()
        } else {
            print("❌ Invalid placement location: (\(hexCoord.q), \(hexCoord.r))")
            // Optionally show feedback that this isn't valid
        }
    }

    // MARK: - Rotation Preview Mode for Multi-Tile Buildings

    /// Enters rotation preview mode for multi-tile buildings (Castle, Fort)
    func enterRotationPreviewMode(buildingType: BuildingType, anchor: HexCoordinate) {
        // Exit any existing placement mode
        exitBuildingPlacementMode()

        isInRotationPreviewMode = true
        rotationPreviewAnchor = anchor
        rotationPreviewType = buildingType
        rotationPreviewRotation = 0

        // Show initial preview at rotation 0
        updateRotationPreview()

        // Notify delegate to show UI buttons
        gameDelegate?.gameScene(self, didEnterRotationPreviewForBuilding: buildingType, at: anchor)

        print("🔄 Entered rotation preview mode for \(buildingType.displayName) at (\(anchor.q), \(anchor.r))")
    }

    /// Updates the rotation preview highlights to show current rotation
    func updateRotationPreview() {
        // Remove previous highlights
        clearRotationPreviewHighlights()

        guard let anchor = rotationPreviewAnchor,
              let buildingType = rotationPreviewType else { return }

        // Get the coordinates this rotation would occupy
        let occupiedCoords = buildingType.getOccupiedCoordinates(anchor: anchor, rotation: rotationPreviewRotation)

        // Check if all tiles are valid (use single-tile check, not multi-tile recalculation)
        let allValid = occupiedCoords.allSatisfy { coord in
            hexMap.canPlaceBuildingOnTile(at: coord)
        }

        // Create highlight for each tile
        for (index, coord) in occupiedCoords.enumerated() {
            let position = HexMap.hexToPixel(q: coord.q, r: coord.r)
            let isValid = hexMap.canPlaceBuildingOnTile(at: coord)

            // Color based on validity
            let highlightColor: UIColor
            if isValid {
                if buildingType == .castle {
                    highlightColor = UIColor(red: 0.5, green: 0.5, blue: 0.6, alpha: 0.8)  // Gray for castle
                } else {
                    highlightColor = UIColor(red: 0.6, green: 0.45, blue: 0.3, alpha: 0.8)  // Brown for fort
                }
            } else {
                highlightColor = UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 0.8)  // Red for blocked
            }

            let highlight = createHexFillShape(at: position, fillColor: highlightColor, isAnchor: index == 0)
            highlight.name = "rotationPreview_\(coord.q)_\(coord.r)"
            highlight.zPosition = 50

            addChild(highlight)
            rotationPreviewHighlights.append(highlight)
        }

        // Add direction arrow on anchor tile to show rotation orientation
        if let anchorPosition = occupiedCoords.first.map({ HexMap.hexToPixel(q: $0.q, r: $0.r) }) {
            let arrow = createRotationArrow(at: anchorPosition, rotation: rotationPreviewRotation)
            arrow.name = "rotationArrow"
            arrow.zPosition = 55
            addChild(arrow)
            rotationPreviewHighlights.append(arrow)
        }

        // Add pulsing animation to all highlights
        for highlight in rotationPreviewHighlights {
            let pulse = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.5, duration: 0.4),
                SKAction.fadeAlpha(to: 1.0, duration: 0.4)
            ])
            highlight.run(SKAction.repeatForever(pulse))
        }
    }

    /// Creates a filled hexagon shape for rotation preview
    private func createHexFillShape(at position: CGPoint, fillColor: UIColor, isAnchor: Bool) -> SKShapeNode {
        let radius: CGFloat = HexTileNode.hexRadius - 2
        let path = CGMutablePath()

        for i in 0..<6 {
            let angle = CGFloat(i) * CGFloat.pi / 3 - CGFloat.pi / 6
            let x = radius * cos(angle)
            let y = radius * sin(angle)

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()

        let shape = SKShapeNode(path: path)
        shape.position = position
        shape.fillColor = fillColor
        shape.strokeColor = isAnchor ? .white : fillColor.withAlphaComponent(0.5)
        shape.lineWidth = isAnchor ? 3 : 2
        shape.glowWidth = isAnchor ? 2 : 0

        // Add label on anchor tile
        if isAnchor, let buildingType = rotationPreviewType {
            let label = SKLabelNode(fontNamed: "Helvetica-Bold")
            label.text = buildingType == .castle ? "CASTLE" : "FORT"
            label.fontSize = 10
            label.fontColor = .white
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            label.zPosition = 5
            shape.addChild(label)
        }

        return shape
    }

    /// Creates an arrow showing the rotation direction
    private func createRotationArrow(at position: CGPoint, rotation: Int) -> SKShapeNode {
        let arrowPath = CGMutablePath()
        let arrowLength: CGFloat = 15
        let arrowWidth: CGFloat = 8

        // Arrow points in the rotation direction
        arrowPath.move(to: CGPoint(x: 0, y: arrowLength))
        arrowPath.addLine(to: CGPoint(x: -arrowWidth, y: 0))
        arrowPath.addLine(to: CGPoint(x: arrowWidth, y: 0))
        arrowPath.closeSubpath()

        let arrow = SKShapeNode(path: arrowPath)
        arrow.position = position
        arrow.fillColor = .white
        arrow.strokeColor = .black
        arrow.lineWidth = 1

        // Rotate arrow based on rotation value (0-5 maps to 60-degree increments)
        // Direction 0 = East, 1 = Northeast, etc.
        let angles: [CGFloat] = [0, CGFloat.pi / 3, 2 * CGFloat.pi / 3, CGFloat.pi, -2 * CGFloat.pi / 3, -CGFloat.pi / 3]
        arrow.zRotation = angles[rotation % 6] - CGFloat.pi / 2  // Adjust for arrow pointing up

        return arrow
    }

    /// Cycles to the next rotation (0-5)
    func cycleRotationPreview() {
        guard isInRotationPreviewMode else { return }

        rotationPreviewRotation = (rotationPreviewRotation + 1) % 6
        updateRotationPreview()

        let directions = ["East", "Southeast", "Southwest", "West", "Northwest", "Northeast"]
        print("🔄 Rotation changed to \(directions[rotationPreviewRotation]) (\(rotationPreviewRotation))")
    }

    /// Confirms the current rotation and executes the build
    func confirmRotationPreview() -> Bool {
        guard isInRotationPreviewMode,
              let anchor = rotationPreviewAnchor,
              let buildingType = rotationPreviewType else {
            return false
        }

        // Validate all tiles are clear (use single-tile check, not multi-tile recalculation)
        let occupiedCoords = buildingType.getOccupiedCoordinates(anchor: anchor, rotation: rotationPreviewRotation)
        let allValid = occupiedCoords.allSatisfy { coord in
            hexMap.canPlaceBuildingOnTile(at: coord)
        }

        guard allValid else {
            print("❌ Cannot build - some tiles are blocked")
            gameDelegate?.gameScene(self, showAlertWithTitle: "Cannot Build", message: "Some tiles in this rotation are blocked. Rotate to find a valid position.")
            return false
        }

        // Call the confirmation callback
        onRotationConfirmed?(anchor, rotationPreviewRotation)

        // Exit preview mode
        exitRotationPreviewMode()

        return true
    }

    /// Exits rotation preview mode and cleans up
    func exitRotationPreviewMode() {
        isInRotationPreviewMode = false
        rotationPreviewAnchor = nil
        rotationPreviewType = nil
        rotationPreviewRotation = 0
        onRotationConfirmed = nil

        clearRotationPreviewHighlights()

        // Notify delegate to hide UI
        gameDelegate?.gameSceneDidExitRotationPreview(self)

        print("🔄 Exited rotation preview mode")
    }

    /// Clears all rotation preview highlight nodes
    private func clearRotationPreviewHighlights() {
        for highlight in rotationPreviewHighlights {
            highlight.removeFromParent()
        }
        rotationPreviewHighlights.removeAll()
    }

    /// Returns whether the current rotation preview is valid for building
    func isCurrentRotationValid() -> Bool {
        guard let anchor = rotationPreviewAnchor,
              let buildingType = rotationPreviewType else {
            return false
        }

        let occupiedCoords = buildingType.getOccupiedCoordinates(anchor: anchor, rotation: rotationPreviewRotation)
        return occupiedCoords.allSatisfy { coord in
            hexMap.canPlaceBuildingOnTile(at: coord)
        }
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
        
        print("Selected tile at q:\(tile.coordinate.q), r:\(tile.coordinate.r)")
        
        gameDelegate?.gameScene(self, didRequestMenuForTile: tile.coordinate)
    }
    
    func deselectAll() {
        selectedTile?.isSelected = false
        selectedTile = nil
    }
    
    func initiateMove(to destination: HexCoordinate) {
        print("🔍 initiateMove called")
        print("   Destination: (\(destination.q), \(destination.r))")

        let availableEntities = hexMap.entities.filter { entity in
            // Must not be currently moving
            guard !entity.isMoving else { return false }

            // Must be owned by player
            guard entity.entity.owner?.id == player?.id else { return false }

            // If it's a villager group, must be idle
            if let villagers = entity.entity as? VillagerGroup {
                return villagers.currentTask == .idle
            }

            // If it's an army, must not be in combat
            if let army = entity.armyReference {
                guard !CombatSystem.shared.isInCombat(army) else { return false }
            }

            return true
        }
        print("   Available player entities: \(availableEntities.count)")
        
        guard !availableEntities.isEmpty else {
            print("❌ No entities available to move")
            gameDelegate?.gameScene(self, showAlertWithTitle: "Cannot Move", message:"You don't have any units available to move.")
            return
        }
        
        // ✅ Use the dedicated move menu that doesn't open entity action menus
        print("✅ Calling showMoveSelectionMenu...")
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
        print("⚔️ COMBAT STARTED!")
        
        // Calculate combat
        let record = CombatSystem.shared.calculateCombat(
            attacker: attacker,
            defender: target,
            defenderCoordinate: location
        )
        
        // Show combat timer
        gameDelegate?.gameScene(self, didStartCombat: record) { [weak self] in
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
                building.clearTileOverlays()  // Clean up multi-tile overlays
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
    
    func initializeFogOfWar(fullyVisible: Bool = false) {
        guard let player = player else {
            print("❌ Cannot initialize fog: No player")
            return
        }

        guard !allGamePlayers.isEmpty else {
            print("❌ Cannot initialize fog: No players in allGamePlayers")
            return
        }

        print("👁️ Initializing fog of war... (fullyVisible: \(fullyVisible))")

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
            print("👁️ Full visibility mode - revealing entire map")
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
            print("❌ Error: Cannot merge - not villager groups")
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
        
        print("✅ Merged villagers: Group 1 now has \(villagers1.villagerCount), Group 2 now has \(villagers2.villagerCount)")
    }
    
    func villagerArrivedForHunt(villagerGroup: VillagerGroup, target: ResourcePointNode, entityNode: EntityNode) {
        print("🏹 GameScene: Villagers arrived for hunt at (\(target.coordinate.q), \(target.coordinate.r))")
        
        // Verify target still exists and is valid
        guard target.parent != nil,
              target.resourceType.isHuntable,
              target.currentHealth > 0 else {
            print("⚠️ Hunt target no longer valid")
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

            // Update collection rate for the player
            if let farmOwner = building.owner {
                let rateContribution = 0.2 * Double(villagerGroup.villagerCount)
                farmOwner.increaseCollectionRate(.food, amount: rateContribution)
            }

            print("🌾 Farm completed - \(villagerGroup.name) now gathering from farmland at (\(coordinate.q), \(coordinate.r))")
        } else {
            print("🌾 Created farmland at (\(coordinate.q), \(coordinate.r))")
        }
    }

    @objc func handleBuildingCompleted(_ notification: Notification) {
        guard let building = notification.object as? BuildingNode else { return }

        // Recalculate adjacency bonuses for nearby buildings
        AdjacencyBonusManager.shared.recalculateAffectedBuildings(near: building.coordinate)
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
            print("✅ Villagers arrived - starting upgrade of \(building.buildingType.displayName) to Lv.\(building.level + 1)")
        }
    }

    // MARK: - Reinforcement Management

    /// Spawns a reinforcement node and starts its movement to the target army
    func spawnReinforcementNode(
        reinforcement: ReinforcementGroup,
        path: [HexCoordinate],
        completion: @escaping (Bool) -> Void
    ) {
        let node = ReinforcementNode(reinforcement: reinforcement, currentPlayer: player)
        let startPos = HexMap.hexToPixel(q: reinforcement.coordinate.q, r: reinforcement.coordinate.r)
        node.position = startPos

        reinforcementNodes.append(node)
        reinforcementsNode?.addChild(node)

        // Register pending reinforcement on the target army
        if let targetArmy = reinforcement.targetArmy {
            let travelTime = node.calculateTravelTime(path: path, hexMap: hexMap)
            let pendingReinforcement = PendingReinforcement(
                reinforcementID: reinforcement.id,
                units: reinforcement.unitComposition,
                estimatedArrival: Date().timeIntervalSince1970 + travelTime,
                source: reinforcement.sourceCoordinate
            )
            targetArmy.addPendingReinforcement(pendingReinforcement)
        }

        // Set up interception check callback
        node.onTileEntered = { [weak self, weak node] coord in
            guard let self = self, let node = node else { return true }
            return self.checkReinforcementInterception(node, at: coord)
        }

        // Start movement
        node.moveTo(path: path, hexMap: hexMap) { [weak self] in
            self?.handleReinforcementArrival(node, success: true)
            completion(true)
        }

        print("🚶 Spawned reinforcement with \(reinforcement.getTotalUnits()) units")
    }

    /// Handles reinforcement arrival at the target army
    func handleReinforcementArrival(_ node: ReinforcementNode, success: Bool) {
        let reinforcement = node.reinforcement

        if success, let targetArmy = reinforcement.targetArmy {
            // Add units to army
            targetArmy.receiveReinforcement(reinforcement.unitComposition)

            // Remove pending entry
            targetArmy.removePendingReinforcement(id: reinforcement.id)

            // Notify UI
            showAlert?("Reinforcements Arrived", "\(reinforcement.getTotalUnits()) units joined \(targetArmy.name)")
        }

        // Cleanup node
        node.cleanup()
        reinforcementNodes.removeAll { $0 === node }
    }

    /// Handles reinforcement return to source building (when cancelled or army destroyed)
    func returnReinforcementToSource(_ node: ReinforcementNode) {
        let reinforcement = node.reinforcement

        // Find path back to source
        guard let path = hexMap.findPath(from: reinforcement.coordinate, to: reinforcement.sourceCoordinate) else {
            print("❌ No path back to source for reinforcement")
            // Just add units back to building garrison directly
            if let building = reinforcement.sourceBuilding {
                for (unitType, count) in reinforcement.unitComposition {
                    building.addToGarrison(unitType: unitType, quantity: count)
                }
            }
            node.cleanup()
            reinforcementNodes.removeAll { $0 === node }
            return
        }

        reinforcement.isCancelled = true

        // Remove from army's pending list
        if let targetArmy = reinforcement.targetArmy {
            targetArmy.removePendingReinforcement(id: reinforcement.id)
        }

        // Move back to source
        node.moveTo(path: path, hexMap: hexMap) { [weak self] in
            // Add units back to building garrison
            if let building = reinforcement.sourceBuilding {
                for (unitType, count) in reinforcement.unitComposition {
                    building.addToGarrison(unitType: unitType, quantity: count)
                }
                print("✅ Reinforcements returned to \(building.buildingType.displayName)")
            }

            node.cleanup()
            self?.reinforcementNodes.removeAll { $0 === node }
        }
    }

    /// Gets the reinforcement node for a given reinforcement ID
    func getReinforcementNode(id: UUID) -> ReinforcementNode? {
        return reinforcementNodes.first { $0.reinforcement.id == id }
    }

    /// Cancels a reinforcement and returns it to source
    func cancelReinforcement(id: UUID) {
        guard let node = getReinforcementNode(id: id) else {
            print("❌ Reinforcement not found: \(id)")
            return
        }

        // Stop current movement
        node.removeAllActions()
        node.isMoving = false

        // Return to source
        returnReinforcementToSource(node)
    }

    /// Handles when an army is destroyed while reinforcements are en route
    func handleArmyDestroyed(_ army: Army) {
        // Find all reinforcements targeting this army
        let targetingNodes = reinforcementNodes.filter { $0.reinforcement.targetArmyID == army.id }

        for node in targetingNodes {
            print("⚠️ Army destroyed - returning reinforcement to source")
            returnReinforcementToSource(node)
        }
    }

    /// Checks if reinforcements are intercepted by enemy army at this coordinate
    /// Returns true to continue movement, false to stop (combat/interception occurred)
    func checkReinforcementInterception(_ node: ReinforcementNode, at coord: HexCoordinate) -> Bool {
        let reinforcement = node.reinforcement

        // Check for enemy armies at this tile
        for entityNode in hexMap.entities {
            guard let army = entityNode.entity as? Army else { continue }

            // Skip if same owner
            guard army.owner?.id != reinforcement.owner?.id else { continue }

            // Check if on same tile
            guard army.coordinate == coord else { continue }

            // Check diplomacy - only intercept if enemy
            let diplomacy = reinforcement.owner?.getDiplomacyStatus(with: army.owner) ?? .neutral
            guard diplomacy == .enemy else { continue }

            // Interception triggered!
            print("⚔️ Reinforcements intercepted by \(army.name) at (\(coord.q), \(coord.r))!")

            // Stop reinforcement movement
            node.removeAllActions()
            node.isMoving = false

            // Combat at reduced effectiveness (no commander bonus)
            handleReinforcementCombat(node, interceptingArmy: army)

            return false  // Stop movement
        }

        return true  // Continue movement
    }

    /// Handles combat when reinforcements are intercepted
    func handleReinforcementCombat(_ node: ReinforcementNode, interceptingArmy: Army) {
        let reinforcement = node.reinforcement

        // Calculate reinforcement combat strength (no commander bonus)
        var reinforcementStrength = 0.0
        for (unitType, count) in reinforcement.unitComposition {
            reinforcementStrength += unitType.attackPower * Double(count)
        }

        // Get army strength (with commander bonus if present)
        let armyStrength = interceptingArmy.getModifiedStrength()

        // Simple combat resolution - side with higher strength wins
        // Reinforcements fight at 75% effectiveness due to no commander
        let effectiveReinforcementStrength = reinforcementStrength * 0.75

        if effectiveReinforcementStrength > armyStrength {
            // Reinforcements win but take losses
            let lossRatio = armyStrength / effectiveReinforcementStrength
            applyReinforcementLosses(reinforcement, lossRatio: lossRatio)

            // Army is destroyed
            print("✅ Reinforcements defeated intercepting army (took \(Int(lossRatio * 100))% losses)")
            showAlert?("Interception Repelled", "Reinforcements defeated enemy but took losses")

            // Continue to destination (will need to restart movement)
            if let targetCoord = reinforcement.getTargetCoordinate(),
               let path = hexMap.findPath(from: reinforcement.coordinate, to: targetCoord) {
                node.moveTo(path: path, hexMap: hexMap) { [weak self] in
                    self?.handleReinforcementArrival(node, success: true)
                }
            }
        } else {
            // Army wins - reinforcements are destroyed
            print("❌ Reinforcements destroyed by intercepting army")
            showAlert?("Reinforcements Lost", "\(reinforcement.getTotalUnits()) units lost to enemy interception")

            // Remove pending from target army
            if let targetArmy = reinforcement.targetArmy {
                targetArmy.removePendingReinforcement(id: reinforcement.id)
            }

            // Cleanup
            node.cleanup()
            reinforcementNodes.removeAll { $0 === node }

            // Apply some losses to the intercepting army
            let armyLossRatio = effectiveReinforcementStrength / armyStrength * 0.5
            // Note: Would need to implement army loss application
        }
    }

    /// Applies losses to reinforcement group based on combat
    private func applyReinforcementLosses(_ reinforcement: ReinforcementGroup, lossRatio: Double) {
        var newComposition: [MilitaryUnitType: Int] = [:]
        for (unitType, count) in reinforcement.unitComposition {
            let survivingCount = Int(Double(count) * (1.0 - lossRatio))
            if survivingCount > 0 {
                newComposition[unitType] = survivingCount
            }
        }
        // Note: Would need to add a method to update reinforcement composition
        // For now, losses are tracked conceptually
    }
}
