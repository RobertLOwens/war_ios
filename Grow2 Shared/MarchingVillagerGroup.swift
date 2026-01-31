// ============================================================================
// FILE: MarchingVillagerGroup.swift
// PURPOSE: Data model for villagers traveling to join another villager group
// ============================================================================

import Foundation

/// Represents a group of villagers marching from a building to join another villager group
class MarchingVillagerGroup {
    /// Unique identifier
    let id: UUID

    /// Display name
    var name: String

    /// Starting position (building location)
    var sourceCoordinate: HexCoordinate

    /// Current position during march
    var coordinate: HexCoordinate

    /// Target villager group to join
    weak var targetVillagerGroup: VillagerGroup?

    /// The ID of the target villager group (for persistence when reference is weak)
    let targetVillagerGroupID: UUID

    /// The building the villagers came from (for return on cancel)
    weak var sourceBuilding: BuildingNode?

    /// The ID of the source building (for persistence)
    let sourceBuildingID: UUID

    /// The number of villagers being transferred
    private(set) var villagerCount: Int

    /// The planned path to the target group
    var movementPath: [HexCoordinate] = []

    /// Current index in the movement path
    var pathIndex: Int = 0

    /// When the march started
    let startTime: TimeInterval

    /// Whether this march has been cancelled
    var isCancelled: Bool = false

    /// Progress along current path segment (0.0 to 1.0)
    var segmentProgress: Double = 0

    /// Owner player
    weak var owner: Player?

    init(
        id: UUID = UUID(),
        name: String = "Marching Villagers",
        sourceCoordinate: HexCoordinate,
        targetVillagerGroup: VillagerGroup,
        sourceBuilding: BuildingNode,
        villagerCount: Int,
        owner: Player?
    ) {
        self.id = id
        self.name = name
        self.sourceCoordinate = sourceCoordinate
        self.coordinate = sourceCoordinate
        self.targetVillagerGroup = targetVillagerGroup
        self.targetVillagerGroupID = targetVillagerGroup.id
        self.sourceBuilding = sourceBuilding
        self.sourceBuildingID = sourceBuilding.data.id
        self.villagerCount = villagerCount
        self.startTime = Date().timeIntervalSince1970
        self.owner = owner
    }

    /// Internal initializer for save/load (without direct references)
    init(
        id: UUID,
        name: String,
        sourceCoordinate: HexCoordinate,
        targetVillagerGroupID: UUID,
        sourceBuildingID: UUID,
        villagerCount: Int,
        startTime: TimeInterval
    ) {
        self.id = id
        self.name = name
        self.sourceCoordinate = sourceCoordinate
        self.coordinate = sourceCoordinate
        self.targetVillagerGroupID = targetVillagerGroupID
        self.sourceBuildingID = sourceBuildingID
        self.villagerCount = villagerCount
        self.startTime = startTime
    }

    // MARK: - Villager Management

    /// Gets a description of the villagers
    func getDescription() -> String {
        return "\(villagerCount) villagers"
    }

    // MARK: - Movement

    /// Updates the current coordinate
    func updateCoordinate(_ newCoord: HexCoordinate) {
        self.coordinate = newCoord
    }

    /// Gets the target coordinate (villager group's current position)
    func getTargetCoordinate() -> HexCoordinate? {
        return targetVillagerGroup?.coordinate
    }

    /// Checks if the marching group has arrived at the target
    func hasArrived() -> Bool {
        guard let targetCoord = getTargetCoordinate() else { return false }
        return coordinate == targetCoord
    }

    /// Applies losses from enemy interception
    func applyLosses(count: Int) {
        villagerCount = max(0, villagerCount - count)
    }
}

// MARK: - Codable Support for Save/Load

extension MarchingVillagerGroup {
    struct SaveData: Codable {
        let id: String
        let name: String
        let sourceQ: Int
        let sourceR: Int
        let currentQ: Int
        let currentR: Int
        let targetVillagerGroupID: String
        let sourceBuildingID: String
        let villagerCount: Int
        let pathCoordinates: [[Int]]  // Array of [q, r] pairs
        let pathIndex: Int
        let startTime: TimeInterval
        let isCancelled: Bool
        let ownerID: String?
    }

    func toSaveData() -> SaveData {
        let pathCoords = movementPath.map { [$0.q, $0.r] }

        return SaveData(
            id: id.uuidString,
            name: name,
            sourceQ: sourceCoordinate.q,
            sourceR: sourceCoordinate.r,
            currentQ: coordinate.q,
            currentR: coordinate.r,
            targetVillagerGroupID: targetVillagerGroupID.uuidString,
            sourceBuildingID: sourceBuildingID.uuidString,
            villagerCount: villagerCount,
            pathCoordinates: pathCoords,
            pathIndex: pathIndex,
            startTime: startTime,
            isCancelled: isCancelled,
            ownerID: owner?.id.uuidString
        )
    }

    static func fromSaveData(_ data: SaveData) -> MarchingVillagerGroup? {
        guard let id = UUID(uuidString: data.id),
              let targetVillagerGroupID = UUID(uuidString: data.targetVillagerGroupID),
              let sourceBuildingID = UUID(uuidString: data.sourceBuildingID) else {
            return nil
        }

        // Create a minimal marching group - references will be reconnected during load
        let marchingGroup = MarchingVillagerGroup(
            id: id,
            name: data.name,
            sourceCoordinate: HexCoordinate(q: data.sourceQ, r: data.sourceR),
            targetVillagerGroupID: targetVillagerGroupID,
            sourceBuildingID: sourceBuildingID,
            villagerCount: data.villagerCount,
            startTime: data.startTime
        )

        marchingGroup.coordinate = HexCoordinate(q: data.currentQ, r: data.currentR)
        marchingGroup.movementPath = data.pathCoordinates.map { HexCoordinate(q: $0[0], r: $0[1]) }
        marchingGroup.pathIndex = data.pathIndex
        marchingGroup.isCancelled = data.isCancelled

        return marchingGroup
    }
}
