// ============================================================================
// FILE: ReinforcementGroup.swift
// PURPOSE: Data model for marching reinforcement units
// ============================================================================

import Foundation

/// Represents a group of units marching from a building to reinforce an army
class ReinforcementGroup: MapEntity {
    /// Starting position (building location)
    var sourceCoordinate: HexCoordinate

    /// Current position during march
    var coordinate: HexCoordinate

    /// Target army to reinforce
    weak var targetArmy: Army?

    /// The ID of the target army (for persistence when army reference is weak)
    let targetArmyID: UUID

    /// The building the units came from (for return on cancel)
    weak var sourceBuilding: BuildingNode?

    /// The ID of the source building (for persistence)
    let sourceBuildingID: UUID

    /// The units being transferred
    private(set) var unitComposition: [MilitaryUnitType: Int]

    /// The planned path to the army
    var movementPath: [HexCoordinate] = []

    /// Current index in the movement path
    var pathIndex: Int = 0

    /// When the march started
    let startTime: TimeInterval

    /// Whether this reinforcement has been cancelled
    var isCancelled: Bool = false

    /// Progress along current path segment (0.0 to 1.0)
    var segmentProgress: Double = 0

    init(
        id: UUID = UUID(),
        name: String = "Reinforcements",
        sourceCoordinate: HexCoordinate,
        targetArmy: Army,
        sourceBuilding: BuildingNode,
        units: [MilitaryUnitType: Int],
        owner: Player?
    ) {
        self.sourceCoordinate = sourceCoordinate
        self.coordinate = sourceCoordinate
        self.targetArmy = targetArmy
        self.targetArmyID = targetArmy.id
        self.sourceBuilding = sourceBuilding
        self.sourceBuildingID = sourceBuilding.data.id
        self.unitComposition = units
        self.startTime = Date().timeIntervalSince1970

        super.init(id: id, name: name, entityType: .reinforcement)
        self.owner = owner
    }

    /// Internal initializer for save/load (without army/building references)
    init(
        id: UUID,
        name: String,
        sourceCoordinate: HexCoordinate,
        targetArmyID: UUID,
        sourceBuildingID: UUID,
        units: [MilitaryUnitType: Int],
        startTime: TimeInterval
    ) {
        self.sourceCoordinate = sourceCoordinate
        self.coordinate = sourceCoordinate
        self.targetArmyID = targetArmyID
        self.sourceBuildingID = sourceBuildingID
        self.unitComposition = units
        self.startTime = startTime

        super.init(id: id, name: name, entityType: .reinforcement)
    }

    // MARK: - Unit Management

    /// Gets the total number of units in this reinforcement group
    func getTotalUnits() -> Int {
        return unitComposition.values.reduce(0, +)
    }

    /// Gets the unit count for a specific type
    func getUnitCount(of type: MilitaryUnitType) -> Int {
        return unitComposition[type] ?? 0
    }

    /// Gets a description of the units
    func getUnitsDescription() -> String {
        return unitComposition
            .filter { $0.value > 0 }
            .map { "\($0.value)x \($0.key.displayName)" }
            .joined(separator: ", ")
    }

    // MARK: - Movement

    /// Updates the current coordinate
    func updateCoordinate(_ newCoord: HexCoordinate) {
        self.coordinate = newCoord
    }

    /// Gets the target coordinate (army's current position)
    func getTargetCoordinate() -> HexCoordinate? {
        return targetArmy?.coordinate
    }

    /// Checks if the reinforcement has arrived at the target
    func hasArrived() -> Bool {
        guard let targetCoord = getTargetCoordinate() else { return false }
        return coordinate == targetCoord
    }
}

// MARK: - Codable Support for Save/Load

extension ReinforcementGroup {
    struct SaveData: Codable {
        let id: String
        let name: String
        let sourceQ: Int
        let sourceR: Int
        let currentQ: Int
        let currentR: Int
        let targetArmyID: String
        let sourceBuildingID: String
        let unitComposition: [String: Int]
        let pathCoordinates: [[Int]]  // Array of [q, r] pairs
        let pathIndex: Int
        let startTime: TimeInterval
        let isCancelled: Bool
        let ownerID: String?
    }

    func toSaveData() -> SaveData {
        let pathCoords = movementPath.map { [$0.q, $0.r] }
        let units = Dictionary(uniqueKeysWithValues: unitComposition.map { ($0.key.rawValue, $0.value) })

        return SaveData(
            id: id.uuidString,
            name: name,
            sourceQ: sourceCoordinate.q,
            sourceR: sourceCoordinate.r,
            currentQ: coordinate.q,
            currentR: coordinate.r,
            targetArmyID: targetArmyID.uuidString,
            sourceBuildingID: sourceBuildingID.uuidString,
            unitComposition: units,
            pathCoordinates: pathCoords,
            pathIndex: pathIndex,
            startTime: startTime,
            isCancelled: isCancelled,
            ownerID: owner?.id.uuidString
        )
    }

    static func fromSaveData(_ data: SaveData) -> ReinforcementGroup? {
        guard let id = UUID(uuidString: data.id),
              let targetArmyID = UUID(uuidString: data.targetArmyID),
              let sourceBuildingID = UUID(uuidString: data.sourceBuildingID) else {
            return nil
        }

        // Reconstruct unit composition
        var units: [MilitaryUnitType: Int] = [:]
        for (key, value) in data.unitComposition {
            if let unitType = MilitaryUnitType(rawValue: key) {
                units[unitType] = value
            }
        }

        // Create a minimal reinforcement group - references will be reconnected during load
        let reinforcement = ReinforcementGroup(
            id: id,
            name: data.name,
            sourceCoordinate: HexCoordinate(q: data.sourceQ, r: data.sourceR),
            targetArmyID: targetArmyID,
            sourceBuildingID: sourceBuildingID,
            units: units,
            startTime: data.startTime
        )

        reinforcement.coordinate = HexCoordinate(q: data.currentQ, r: data.currentR)
        reinforcement.movementPath = data.pathCoordinates.map { HexCoordinate(q: $0[0], r: $0[1]) }
        reinforcement.pathIndex = data.pathIndex
        reinforcement.isCancelled = data.isCancelled

        return reinforcement
    }
}
