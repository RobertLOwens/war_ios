// ============================================================================
// FILE: Grow2 Shared/Engine/SystemAdapters.swift
// PURPOSE: Adapters that bridge existing systems with the new engine architecture
// NOTE: With unified types (via TypeAliases.swift), conversion is now simplified
// ============================================================================

import Foundation

// MARK: - Combat Data Adapter

/// Bridges visual Army/BuildingNode objects with CombatEngine data types
class CombatDataAdapter {

    // MARK: - References
    weak var combatEngine: CombatEngine?
    weak var gameState: GameState?

    // MARK: - Initialization

    init(combatEngine: CombatEngine, gameState: GameState) {
        self.combatEngine = combatEngine
        self.gameState = gameState
    }

    // MARK: - Data Conversion

    /// Convert an Army (visual) to ArmyData (pure data)
    func convertToArmyData(_ army: Army) -> ArmyData {
        let armyData = ArmyData(
            id: army.id,
            name: army.name,
            coordinate: army.coordinate,
            ownerID: army.owner?.id
        )

        // Types are now unified, copy directly
        for (unitType, count) in army.militaryComposition {
            armyData.addMilitaryUnits(unitType, count: count)
        }

        armyData.isRetreating = army.isRetreating
        armyData.homeBaseID = army.homeBaseID
        armyData.commanderID = army.commander?.id

        return armyData
    }

    /// Convert ArmyData (pure data) back to update an Army (visual)
    func updateArmy(_ army: Army, from armyData: ArmyData) {
        // Clear existing composition
        for unitType in MilitaryUnitType.allCases {
            let current = army.getMilitaryUnitCount(ofType: unitType)
            if current > 0 {
                _ = army.removeMilitaryUnits(unitType, count: current)
            }
        }

        // Types are now unified, copy directly
        for (unitType, count) in armyData.militaryComposition {
            army.addMilitaryUnits(unitType, count: count)
        }

        army.isRetreating = armyData.isRetreating
        army.coordinate = armyData.coordinate
    }

    /// Convert BuildingData to visual building data updates
    func updateBuilding(_ building: BuildingNode, from buildingData: BuildingData) {
        building.data.health = buildingData.health
        building.data.state = buildingData.state
        building.data.garrison = buildingData.garrison
        building.data.villagerGarrison = buildingData.villagerGarrison
        building.updateAppearance()
    }

    // MARK: - Combat Synchronization

    /// Sync combat results from engine to visual layer
    func syncCombatResult(_ result: CombatResultData, attackerNode: EntityNode?, defenderNode: EntityNode?) {
        // Update visual nodes to reflect casualties
        attackerNode?.updateTexture()
        defenderNode?.updateTexture()
    }
}

// MARK: - Resource System Adapter

/// Adapter for converting between visual ResourcePointNode and data ResourcePointData
class ResourceSystemAdapter {

    // MARK: - References
    weak var resourceEngine: ResourceEngine?
    weak var gameState: GameState?

    // MARK: - Initialization

    init(resourceEngine: ResourceEngine, gameState: GameState) {
        self.resourceEngine = resourceEngine
        self.gameState = gameState
    }

    // MARK: - Data Conversion

    /// Convert ResourcePointNode (visual) to ResourcePointData (pure data)
    func convertToResourcePointData(_ node: ResourcePointNode) -> ResourcePointData {
        // Types are now unified, use directly
        // Use the node's existing ID to maintain consistency with gathering assignments
        let data = ResourcePointData(
            id: node.id,
            coordinate: node.coordinate,
            resourceType: node.resourceType
        )
        data.setRemainingAmount(node.remainingAmount)
        data.setCurrentHealth(node.currentHealth)

        // Copy villager assignments
        for group in node.assignedVillagerGroups {
            _ = data.assignVillagerGroup(group.id, villagerCount: group.villagerCount)
        }

        return data
    }

    /// Update ResourcePointNode from ResourcePointData
    func updateResourceNode(_ node: ResourcePointNode, from data: ResourcePointData) {
        node.setRemainingAmount(data.remainingAmount)
        node.setCurrentHealth(data.currentHealth)
        node.updateLabel()
    }

    /// Convert VillagerGroup (visual) to VillagerGroupData (pure data)
    func convertToVillagerGroupData(_ group: VillagerGroup) -> VillagerGroupData {
        let data = VillagerGroupData(
            id: group.id,
            name: group.name,
            coordinate: group.coordinate,
            villagerCount: group.villagerCount,
            ownerID: group.owner?.id
        )

        // Convert visual task to data task
        data.currentTask = group.currentTask.toTaskData()
        data.taskTargetCoordinate = group.taskTarget

        // Set assignedResourcePointID for gathering tasks (ResourceEngine needs this)
        if case .gatheringResource(let resourcePoint) = group.currentTask {
            data.assignedResourcePointID = resourcePoint.id
            data.taskTargetID = resourcePoint.id
        } else if case .hunting(let resourcePoint) = group.currentTask {
            data.taskTargetID = resourcePoint.id
        }

        return data
    }

    /// Update VillagerGroup from VillagerGroupData
    func updateVillagerGroup(_ group: VillagerGroup, from data: VillagerGroupData) {
        // Update villager count
        let currentCount = group.villagerCount
        if currentCount > data.villagerCount {
            _ = group.removeVillagers(count: currentCount - data.villagerCount)
        } else if currentCount < data.villagerCount {
            group.addVillagers(count: data.villagerCount - currentCount)
        }

        group.coordinate = data.coordinate
    }
}

// MARK: - Player State Adapter

/// Bridges Player (visual) with PlayerState (pure data)
/// Note: Player now holds a PlayerState directly, so this adapter is simpler.
/// The main role is to sync entity ownership IDs from the visual layer to the data layer.
class PlayerStateAdapter {

    /// Get PlayerState from Player, syncing entity ownership IDs
    static func convertToPlayerState(_ player: Player) -> PlayerState {
        let state = player.state

        // Sync entity ownership IDs from visual layer to data layer
        // Clear and rebuild to ensure consistency
        syncEntityOwnership(player: player, state: state)

        return state
    }

    /// Sync entity ownership IDs from Player's visual objects to PlayerState
    static func syncEntityOwnership(player: Player, state: PlayerState) {
        // Sync building IDs
        for building in player.buildings {
            state.addOwnedBuilding(building.data.id)
        }

        // Sync army IDs
        for army in player.armies {
            state.addOwnedArmy(army.id)
        }

        // Sync villager group IDs
        for group in player.getVillagerGroups() {
            state.addOwnedVillagerGroup(group.id)
        }

        // Sync commander IDs
        for commander in player.commanders {
            state.addOwnedCommander(commander.id)
        }
    }

    /// Update Player from a different PlayerState (e.g., when loading saves)
    /// This replaces Player's internal state with the loaded one
    static func updatePlayer(_ player: Player, from state: PlayerState) {
        // Resources and rates are now managed by player.state
        // If we need to load from a different state, copy the values
        for resourceType in ResourceType.allCases {
            player.state.setResource(resourceType, amount: state.getResource(resourceType))
            player.state.setCollectionRate(resourceType, rate: state.getCollectionRate(resourceType))
        }

        // Copy diplomacy relations
        for (playerID, status) in state.diplomacyRelations {
            player.state.setDiplomacyStatus(with: playerID, status: status)
        }
    }
}

// MARK: - Map Data Adapter

/// Bridges HexMap (visual) with MapData (pure data)
class MapDataAdapter {

    /// Convert HexMap to MapData
    static func convertToMapData(_ hexMap: HexMap) -> MapData {
        let mapData = MapData(width: hexMap.width, height: hexMap.height)

        // Types are now unified, copy directly
        for (coord, tile) in hexMap.tiles {
            let tileData = TileData(
                coordinate: coord,
                terrain: tile.terrain,
                elevation: tile.elevation
            )
            mapData.setTile(tileData)
        }

        return mapData
    }

    /// Sync positions from visual nodes to map data
    static func syncPositions(from hexMap: HexMap, to mapData: MapData) {
        // Sync building positions
        for building in hexMap.buildings {
            mapData.registerBuilding(
                id: building.data.id,
                at: building.coordinate,
                occupiedCoords: building.data.occupiedCoordinates
            )
        }

        // Sync entity positions
        for entity in hexMap.entities {
            if let army = entity.entity as? Army {
                mapData.registerArmy(id: army.id, at: entity.coordinate)
            } else if let villagerGroup = entity.entity as? VillagerGroup {
                mapData.registerVillagerGroup(id: villagerGroup.id, at: entity.coordinate)
            }
        }
    }
}

// MARK: - Full State Sync

/// Utility for syncing between visual and data layers
class GameStateSynchronizer {

    /// Create a full GameState from existing visual objects
    static func createGameState(from hexMap: HexMap, players: [Player], mapWidth: Int, mapHeight: Int) -> GameState {
        let gameState = GameState(mapWidth: mapWidth, mapHeight: mapHeight)

        debugLog("🔧 GameStateSynchronizer: Creating game state from \(players.count) players, \(hexMap.buildings.count) buildings")

        // Convert map tiles - copy terrain data from hexMap to gameState.mapData
        for (coord, tile) in hexMap.tiles {
            let tileData = TileData(
                coordinate: coord,
                terrain: tile.terrain,
                elevation: tile.elevation
            )
            gameState.mapData.setTile(tileData)
        }

        // Add players
        for player in players {
            let playerState = PlayerStateAdapter.convertToPlayerState(player)
            gameState.addPlayer(playerState)
            debugLog("🔧   Added player: \(player.name) (isAI: \(playerState.isAI))")
        }

        // Add buildings
        for building in hexMap.buildings {
            // Extract data into local var to hold strong reference before accessing properties
            let buildingData = building.data
            gameState.addBuilding(buildingData)
            debugLog("🔧   Added building: \(buildingData.buildingType.displayName) owner=\(buildingData.ownerID?.uuidString.prefix(8) ?? "nil") state=\(buildingData.state)")
        }

        // Add resource points (needed for ResourceEngine gathering/depletion)
        let resourceAdapter = ResourceSystemAdapter(resourceEngine: GameEngine.shared.resourceEngine, gameState: gameState)
        for resourcePoint in hexMap.resourcePoints {
            let resourceData = resourceAdapter.convertToResourcePointData(resourcePoint)
            gameState.addResourcePoint(resourceData)
            // Register in map data for coordinate lookup
            gameState.mapData.registerResourcePoint(id: resourceData.id, at: resourcePoint.coordinate)
        }

        // Add entities
        for entity in hexMap.entities {
            if let army = entity.entity as? Army {
                // Use existing data object to maintain reference identity
                gameState.addArmy(army.data)
            } else if let villagerGroup = entity.entity as? VillagerGroup {
                // Use existing data object to maintain reference identity
                gameState.addVillagerGroup(villagerGroup.data)
            }
        }

        // Add commanders
        for player in players {
            for commander in player.commanders {
                gameState.addCommander(commander.data)
                debugLog("🔧   Added commander: \(commander.data.name) for player \(player.name)")
            }
        }

        return gameState
    }

    /// Sync visual layer from GameState changes
    static func applyStateChanges(_ changes: StateChangeBatch, visualLayer: GameVisualLayer) {
        visualLayer.applyChanges(changes)
    }
}
