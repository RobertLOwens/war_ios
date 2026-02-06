// ============================================================================
// FILE: Grow2 Shared/Visual/NodeFactory.swift
// PURPOSE: Creates SpriteKit nodes from pure data models
// ============================================================================

import Foundation
import SpriteKit

// MARK: - Node Factory

/// Factory for creating SpriteKit nodes from pure data models
class NodeFactory {

    // MARK: - References
    private weak var hexMap: HexMap?

    // MARK: - Setup

    func setup(hexMap: HexMap) {
        self.hexMap = hexMap
    }

    // MARK: - Building Nodes

    /// Create a BuildingNode from BuildingData
    func createBuildingNode(from data: BuildingData) -> BuildingNode {
        // Create the building node using existing BuildingNode initializer
        let buildingNode = BuildingNode(
            coordinate: data.coordinate,
            buildingType: data.buildingType,
            owner: nil,  // Owner will be set later via player lookup
            rotation: data.rotation
        )

        // Sync the data
        syncBuildingNode(buildingNode, with: data)

        return buildingNode
    }

    /// Sync a BuildingNode with BuildingData
    func syncBuildingNode(_ node: BuildingNode, with data: BuildingData) {
        // The BuildingNode already has its own BuildingData
        // We need to copy the state from the input data to the node's data
        node.data.state = data.state
        node.data.level = data.level
        node.data.health = data.health
        node.data.maxHealth = data.maxHealth
        node.data.constructionProgress = data.constructionProgress
        node.data.constructionStartTime = data.constructionStartTime
        node.data.buildersAssigned = data.buildersAssigned
        node.data.upgradeProgress = data.upgradeProgress
        node.data.upgradeStartTime = data.upgradeStartTime
        node.data.demolitionProgress = data.demolitionProgress
        node.data.demolitionStartTime = data.demolitionStartTime
        node.data.demolishersAssigned = data.demolishersAssigned
        node.data.garrison = data.garrison
        node.data.villagerGarrison = data.villagerGarrison
        node.data.trainingQueue = data.trainingQueue
        node.data.villagerTrainingQueue = data.villagerTrainingQueue

        node.updateAppearance()
    }

    // MARK: - Entity Nodes (Army)

    /// Create an EntityNode from ArmyData
    func createEntityNode(from armyData: ArmyData) -> EntityNode {
        // Create the Army object, passing existing data to preserve ownerID
        let army = Army(
            id: armyData.id,
            name: armyData.name,
            coordinate: armyData.coordinate,
            commander: nil,
            owner: nil,
            data: armyData
        )

        // Create the entity node with correct initializer
        let entityNode = EntityNode(
            coordinate: armyData.coordinate,
            entityType: .army,
            entity: army,
            currentPlayer: nil
        )

        return entityNode
    }

    /// Sync an EntityNode (army) with ArmyData
    func syncEntityNode(_ node: EntityNode, with armyData: ArmyData) {
        guard let army = node.armyReference else { return }

        // Clear existing composition
        for unitType in MilitaryUnitType.allCases {
            let current = army.getMilitaryUnitCount(ofType: unitType)
            if current > 0 {
                _ = army.removeMilitaryUnits(unitType, count: current)
            }
        }

        // Copy new composition
        for (unitTypeData, count) in armyData.militaryComposition {
            if let unitType = MilitaryUnitType(rawValue: unitTypeData.rawValue) {
                army.addMilitaryUnits(unitType, count: count)
            }
        }

        army.isRetreating = armyData.isRetreating
        army.homeBaseID = armyData.homeBaseID

        // Update coordinate
        node.coordinate = armyData.coordinate

        node.updateTexture()
    }

    // MARK: - Entity Nodes (Villager Group)

    /// Create an EntityNode from VillagerGroupData
    func createEntityNode(from groupData: VillagerGroupData) -> EntityNode {
        // Create the VillagerGroup object, passing existing data to preserve ownerID
        let villagerGroup = VillagerGroup(
            name: groupData.name,
            coordinate: groupData.coordinate,
            villagerCount: groupData.villagerCount,
            owner: nil,
            data: groupData
        )

        // Create the entity node with correct initializer
        let entityNode = EntityNode(
            coordinate: groupData.coordinate,
            entityType: .villagerGroup,
            entity: villagerGroup,
            currentPlayer: nil
        )

        return entityNode
    }

    /// Sync an EntityNode (villager group) with VillagerGroupData
    func syncEntityNode(_ node: EntityNode, with groupData: VillagerGroupData) {
        guard let villagerGroup = node.villagerReference else { return }

        // Update villager count
        let currentCount = villagerGroup.villagerCount
        if currentCount > groupData.villagerCount {
            _ = villagerGroup.removeVillagers(count: currentCount - groupData.villagerCount)
        } else if currentCount < groupData.villagerCount {
            villagerGroup.addVillagers(count: groupData.villagerCount - currentCount)
        }

        // Update coordinate
        villagerGroup.coordinate = groupData.coordinate
        node.coordinate = groupData.coordinate

        node.updateTexture()
    }

    // MARK: - Resource Point Nodes

    /// Create a ResourcePointNode from ResourcePointData
    func createResourcePointNode(from data: ResourcePointData) -> ResourcePointNode {
        // Convert data type to existing type
        guard let resourceType = ResourcePointType(rawValue: data.resourceType.rawValue) else {
            // Fallback to trees if unknown
            let node = ResourcePointNode(coordinate: data.coordinate, resourceType: .trees)
            return node
        }

        let node = ResourcePointNode(coordinate: data.coordinate, resourceType: resourceType)
        node.setRemainingAmount(data.remainingAmount)
        node.setCurrentHealth(data.currentHealth)

        return node
    }

    /// Sync a ResourcePointNode with ResourcePointData
    func syncResourcePointNode(_ node: ResourcePointNode, with data: ResourcePointData) {
        node.setRemainingAmount(data.remainingAmount)
        node.setCurrentHealth(data.currentHealth)
        node.updateLabel()
    }

    // MARK: - Hex Tile Nodes

    /// Create a HexTileNode from TileData
    func createTileNode(from tileData: TileData) -> HexTileNode {
        // Convert data terrain to existing terrain type
        let terrain = TerrainType(rawValue: tileData.terrain.rawValue) ?? .plains

        let node = HexTileNode(
            coordinate: tileData.coordinate,
            terrain: terrain,
            elevation: tileData.elevation
        )

        return node
    }

    // MARK: - Fog Overlay Nodes

    /// Create a FogOverlayNode
    func createFogOverlayNode(at coordinate: HexCoordinate) -> FogOverlayNode {
        let node = FogOverlayNode(coordinate: coordinate)
        return node
    }

    // MARK: - Helper Methods

    /// Convert a position to hex coordinate
    func pixelToHex(point: CGPoint) -> HexCoordinate {
        return HexMap.pixelToHex(point: point)
    }

    /// Convert a hex coordinate to position
    func hexToPixel(coordinate: HexCoordinate) -> CGPoint {
        return HexMap.hexToPixel(q: coordinate.q, r: coordinate.r)
    }
}
