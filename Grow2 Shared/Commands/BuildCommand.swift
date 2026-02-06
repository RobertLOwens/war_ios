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
    let rotation: Int

    static var commandType: CommandType { .build }

    init(playerID: UUID, buildingType: BuildingType, coordinate: HexCoordinate, builderEntityID: UUID? = nil, rotation: Int = 0) {
        self.id = UUID()
        self.timestamp = Date().timeIntervalSince1970
        self.playerID = playerID
        self.buildingType = buildingType
        self.coordinate = coordinate
        self.builderEntityID = builderEntityID
        self.rotation = rotation
    }
    
    func validate(in context: CommandContext) -> CommandResult {
        guard let player = context.getPlayer(by: playerID) else {
            return .failure(reason: "Player not found")
        }

        // Get all tiles this building would occupy
        let occupiedCoords = buildingType.getOccupiedCoordinates(anchor: coordinate, rotation: rotation)

        // Check all tiles are valid
        for coord in occupiedCoords {
            guard let tile = context.hexMap.getTile(at: coord) else {
                return .failure(reason: "Invalid location")
            }

            // Check terrain allows building
            guard tile.terrain != .water else {
                return .failure(reason: "Cannot build on water")
            }

            // Check no building already exists (roads can be built where there's already a road)
            if let existingBuilding = context.getBuilding(at: coord) {
                // Allow replacing roads with other buildings, or building roads where there's a road
                if existingBuilding.buildingType.isRoad && !buildingType.isRoad {
                    // OK - building over a road with a real building
                } else if buildingType.isRoad && existingBuilding.buildingType.isRoad {
                    return .failure(reason: "A road already exists here")
                } else {
                    return .failure(reason: "A building already exists here")
                }
            }
        }

        // Check City Center level requirement
        let ccLevel = player.getCityCenterLevel()
        if buildingType.requiredCityCenterLevel > ccLevel {
            return .failure(reason: "Requires City Center Level \(buildingType.requiredCityCenterLevel)")
        }

        // Check resources (with terrain cost multiplier for mountains)
        let costMultiplier = getTerrainCostMultiplier(for: occupiedCoords, in: context.hexMap)

        for (resourceType, baseAmount) in buildingType.buildCost {
            let adjustedAmount = Int(ceil(Double(baseAmount) * costMultiplier))
            if !player.hasResource(resourceType, amount: adjustedAmount) {
                let current = player.getResource(resourceType)
                return .failure(reason: "Need \(adjustedAmount) \(resourceType.displayName), have \(current)")
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

        // Remove existing roads if building over them (check all occupied tiles)
        let occupiedCoords = buildingType.getOccupiedCoordinates(anchor: coordinate, rotation: rotation)
        for coord in occupiedCoords {
            if let existingBuilding = context.getBuilding(at: coord), existingBuilding.buildingType.isRoad {
                context.hexMap.removeBuilding(existingBuilding)
                player.removeBuilding(existingBuilding)
                existingBuilding.clearTileOverlays()  // Clean up multi-tile overlays
                existingBuilding.removeFromParent()
            }
        }

        // Deduct resources (with terrain cost multiplier for mountains)
        let costMultiplier = getTerrainCostMultiplier(for: occupiedCoords, in: context.hexMap)

        for (resourceType, baseAmount) in buildingType.buildCost {
            let adjustedAmount = Int(ceil(Double(baseAmount) * costMultiplier))
            player.removeResource(resourceType, amount: adjustedAmount)
        }

        // Create building
        let building = BuildingNode(coordinate: coordinate, buildingType: buildingType, owner: player, rotation: rotation)
        building.position = HexMap.hexToPixel(q: coordinate.q, r: coordinate.r)

        // Check if builder is already at the location
        var builderAtLocation = false

        // Assign builder if provided
        if let builderID = builderEntityID,
           let builderEntity = context.getEntity(by: builderID),
           let villagers = builderEntity.entity as? VillagerGroup {
            building.builderEntity = builderEntity
            villagers.assignTask(.building(building), target: coordinate)

            // Check if villager is already at the build site (must be ON the tile, not adjacent)
            let distance = builderEntity.coordinate.distance(to: coordinate)
            if distance == 0 {
                builderAtLocation = true
                builderEntity.isMoving = false
            } else {
                // Need to move to the location - construction starts when they arrive
                builderEntity.isMoving = true

                // Move the entity to the build site
                if let path = context.hexMap.findPath(from: builderEntity.coordinate, to: coordinate, for: builderEntity.entity.owner) {
                    builderEntity.moveTo(path: path) {
                        // When movement completes, start construction
                        if building.state == .planning {
                            building.startConstruction()
                            debugLog("🏗️ Builder arrived, starting construction of \(building.buildingType.displayName)")
                        }
                    }
                } else {
                    // Can't find path, start construction anyway (villager might be blocked)
                    builderAtLocation = true
                }
            }
        } else {
            // No builder assigned, start construction immediately
            builderAtLocation = true
        }

        // Only start construction if builder is at location or no builder needed
        if builderAtLocation {
            building.startConstruction()
        } else {
            // Set to planning state - construction will start when builder arrives
            building.data.state = .planning
            debugLog("🏗️ Waiting for builder to arrive at \(buildingType.displayName)")
        }

        let position = HexMap.hexToPixel(q: coordinate.q, r: coordinate.r)
        building.position = position
        // Roads should be below other buildings; non-roads keep isometric z from init
        if buildingType.isRoad {
            building.zPosition = HexTileNode.isometricZPosition(q: coordinate.q, r: coordinate.r, baseLayer: 50)
        }
        context.gameScene?.buildingsNode.addChild(building)

        // Register in visual layer so state change handlers work
        context.gameScene?.visualLayer?.registerBuildingNode(id: building.data.id, node: building)

        // Setup construction progress bar
        if building.state == .constructing {
            building.setupConstructionBar()
        }

        // Create per-tile visual overlays for multi-tile buildings
        if let scene = context.gameScene, buildingType.hexSize > 1 {
            building.createTileOverlays(in: scene)
        }

        // Add to map and player
        context.hexMap.addBuilding(building)
        player.addBuilding(building)

        // Sync to engine's game state for ResourceEngine camp coverage checks
        if let gameState = GameEngine.shared.gameState {
            gameState.addBuilding(building.data)
        }

        // Remove resources on all occupied tiles (except for camps and roads)
        if buildingType != .miningCamp && buildingType != .lumberCamp && !buildingType.isRoad {
            let occupiedCoords = buildingType.getOccupiedCoordinates(anchor: coordinate, rotation: rotation)
            for coord in occupiedCoords {
                if let resource = context.hexMap.getResourcePoint(at: coord) {
                    context.hexMap.removeResourcePoint(resource)
                    resource.removeFromParent()
                }
            }
        }

        context.onResourcesChanged?()

        debugLog("🏗️ Started building \(buildingType.displayName) at (\(coordinate.q), \(coordinate.r))")

        return .success
    }

    private func getTerrainCostMultiplier(for coordinates: [HexCoordinate], in hexMap: HexMap) -> Double {
        let hasAnyMountainTile = coordinates.contains { coord in
            hexMap.getTile(at: coord)?.terrain == .mountain
        }
        return hasAnyMountainTile ? 1.25 : 1.0
    }
}
