// ============================================================================
// FILE: Grow2 Shared/Data/VillagerGroupData.swift
// PURPOSE: Pure data model for villager groups - no SpriteKit dependencies
// ============================================================================

import Foundation

// MARK: - Villager Task Data

/// Pure data representation of villager tasks
enum VillagerTaskData: Codable, Equatable {
    case idle
    case building(buildingID: UUID)
    case gathering(resourceType: ResourceTypeData)
    case gatheringResource(resourcePointID: UUID)
    case hunting(resourcePointID: UUID)
    case repairing(buildingID: UUID)
    case moving(targetCoordinate: HexCoordinate)
    case upgrading(buildingID: UUID)
    case demolishing(buildingID: UUID)

    var displayName: String {
        switch self {
        case .idle:
            return "Idle"
        case .building:
            return "Building"
        case .gathering(let resource):
            return "Gathering \(resource.displayName)"
        case .gatheringResource:
            return "Gathering"
        case .hunting:
            return "Hunting"
        case .repairing:
            return "Repairing"
        case .moving(let coord):
            return "Moving to (\(coord.q), \(coord.r))"
        case .upgrading:
            return "Upgrading"
        case .demolishing:
            return "Demolishing"
        }
    }

    var isIdle: Bool {
        if case .idle = self { return true }
        return false
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case type
        case buildingID
        case resourceType
        case resourcePointID
        case targetCoordinate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "idle":
            self = .idle
        case "building":
            let buildingID = try container.decode(UUID.self, forKey: .buildingID)
            self = .building(buildingID: buildingID)
        case "gathering":
            let resourceType = try container.decode(ResourceTypeData.self, forKey: .resourceType)
            self = .gathering(resourceType: resourceType)
        case "gatheringResource":
            let resourcePointID = try container.decode(UUID.self, forKey: .resourcePointID)
            self = .gatheringResource(resourcePointID: resourcePointID)
        case "hunting":
            let resourcePointID = try container.decode(UUID.self, forKey: .resourcePointID)
            self = .hunting(resourcePointID: resourcePointID)
        case "repairing":
            let buildingID = try container.decode(UUID.self, forKey: .buildingID)
            self = .repairing(buildingID: buildingID)
        case "moving":
            let coord = try container.decode(HexCoordinate.self, forKey: .targetCoordinate)
            self = .moving(targetCoordinate: coord)
        case "upgrading":
            let buildingID = try container.decode(UUID.self, forKey: .buildingID)
            self = .upgrading(buildingID: buildingID)
        case "demolishing":
            let buildingID = try container.decode(UUID.self, forKey: .buildingID)
            self = .demolishing(buildingID: buildingID)
        default:
            self = .idle
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .idle:
            try container.encode("idle", forKey: .type)
        case .building(let buildingID):
            try container.encode("building", forKey: .type)
            try container.encode(buildingID, forKey: .buildingID)
        case .gathering(let resourceType):
            try container.encode("gathering", forKey: .type)
            try container.encode(resourceType, forKey: .resourceType)
        case .gatheringResource(let resourcePointID):
            try container.encode("gatheringResource", forKey: .type)
            try container.encode(resourcePointID, forKey: .resourcePointID)
        case .hunting(let resourcePointID):
            try container.encode("hunting", forKey: .type)
            try container.encode(resourcePointID, forKey: .resourcePointID)
        case .repairing(let buildingID):
            try container.encode("repairing", forKey: .type)
            try container.encode(buildingID, forKey: .buildingID)
        case .moving(let coord):
            try container.encode("moving", forKey: .type)
            try container.encode(coord, forKey: .targetCoordinate)
        case .upgrading(let buildingID):
            try container.encode("upgrading", forKey: .type)
            try container.encode(buildingID, forKey: .buildingID)
        case .demolishing(let buildingID):
            try container.encode("demolishing", forKey: .type)
            try container.encode(buildingID, forKey: .buildingID)
        }
    }
}

// MARK: - Villager Group Data

/// Pure data representation of a villager group
class VillagerGroupData: Codable {
    let id: UUID
    var name: String
    var ownerID: UUID?
    var coordinate: HexCoordinate

    private(set) var villagerCount: Int = 0

    var currentTask: VillagerTaskData = .idle
    var taskTargetCoordinate: HexCoordinate?
    var taskTargetID: UUID?  // Building or resource point ID

    // Movement
    var currentPath: [HexCoordinate]?
    var pathIndex: Int = 0
    var movementProgress: Double = 0.0

    // Gathering state
    var gatheringAccumulator: Double = 0.0
    var assignedResourcePointID: UUID?

    init(id: UUID = UUID(), name: String = "Villagers", coordinate: HexCoordinate, villagerCount: Int = 0, ownerID: UUID? = nil) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.villagerCount = max(0, villagerCount)
        self.ownerID = ownerID
    }

    // MARK: - Villager Management

    func addVillagers(count: Int) {
        villagerCount += count
    }

    func removeVillagers(count: Int) -> Int {
        let toRemove = min(villagerCount, count)
        villagerCount -= toRemove
        return toRemove
    }

    func setVillagerCount(_ count: Int) {
        villagerCount = max(0, count)
    }

    func hasVillagers() -> Bool {
        return villagerCount > 0
    }

    func isEmpty() -> Bool {
        return villagerCount == 0
    }

    // MARK: - Task Management

    func assignTask(_ task: VillagerTaskData, targetCoordinate: HexCoordinate? = nil, targetID: UUID? = nil) {
        currentTask = task
        taskTargetCoordinate = targetCoordinate
        taskTargetID = targetID
    }

    func clearTask() {
        currentTask = .idle
        taskTargetCoordinate = nil
        taskTargetID = nil
        gatheringAccumulator = 0.0
    }

    func isGathering() -> Bool {
        switch currentTask {
        case .gathering, .gatheringResource:
            return true
        default:
            return false
        }
    }

    func isHunting() -> Bool {
        if case .hunting = currentTask {
            return true
        }
        return false
    }

    func isBuilding() -> Bool {
        if case .building = currentTask {
            return true
        }
        return false
    }

    // MARK: - Movement

    func setPath(_ path: [HexCoordinate]) {
        currentPath = path
        pathIndex = 0
        movementProgress = 0.0
    }

    func clearPath() {
        currentPath = nil
        pathIndex = 0
        movementProgress = 0.0
    }

    func hasPath() -> Bool {
        guard let path = currentPath else { return false }
        return pathIndex < path.count
    }

    // MARK: - Merging

    func merge(with otherGroup: VillagerGroupData) {
        addVillagers(count: otherGroup.villagerCount)
    }

    // MARK: - Splitting

    func split(count: Int, newID: UUID = UUID(), newName: String? = nil) -> VillagerGroupData? {
        guard count > 0 && count < villagerCount else {
            return nil
        }

        let newGroup = VillagerGroupData(
            id: newID,
            name: newName ?? "\(name) (Split)",
            coordinate: coordinate,
            villagerCount: count,
            ownerID: ownerID
        )

        removeVillagers(count: count)

        return newGroup
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, name, ownerID, coordinate
        case villagerCount
        case currentTask, taskTargetCoordinate, taskTargetID
        case currentPath, pathIndex, movementProgress
        case gatheringAccumulator, assignedResourcePointID
    }
}

// MARK: - Villager Group Data Extensions

extension VillagerGroupData {
    func getDescription() -> String {
        guard hasVillagers() else { return "\(name) (Empty)" }

        let taskDesc = currentTask.isIdle ? "Idle" : "Working: \(currentTask.displayName)"
        return "\(name) (\(villagerCount) villagers)\n\(taskDesc)"
    }
}
