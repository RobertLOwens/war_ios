// ============================================================================
// FILE: Grow2 Shared/Data/ResourcePointData.swift
// PURPOSE: Pure data model for resource points - no SpriteKit dependencies
// ============================================================================

import Foundation

// MARK: - Type Alias for Backward Compatibility

/// Alias for backward compatibility - use ResourcePointTypeData directly in new code
typealias ResourcePointType = ResourcePointTypeData

// MARK: - Resource Point Type Data

/// Pure data representation of resource point types
enum ResourcePointTypeData: String, Codable, CaseIterable {
    case trees
    case forage
    case oreMine
    case stoneQuarry
    case deer
    case wildBoar
    case deerCarcass
    case boarCarcass
    case farmland

    var displayName: String {
        switch self {
        case .trees: return "Trees"
        case .forage: return "Forage"
        case .oreMine: return "Ore Mine"
        case .stoneQuarry: return "Stone Quarry"
        case .deer: return "Deer"
        case .wildBoar: return "Wild Boar"
        case .deerCarcass: return "Deer Carcass"
        case .boarCarcass: return "Boar Carcass"
        case .farmland: return "Farmland"
        }
    }

    var icon: String {
        switch self {
        case .trees: return "🌲"
        case .forage: return "🍄"
        case .oreMine: return "⛏️"
        case .stoneQuarry: return "🪨"
        case .deer: return "🦌"
        case .wildBoar: return "🐗"
        case .deerCarcass: return "🥩"
        case .boarCarcass: return "🥩"
        case .farmland: return "🌾"
        }
    }

    var resourceYield: ResourceTypeData {
        switch self {
        case .trees: return .wood
        case .forage: return .food
        case .oreMine: return .ore
        case .stoneQuarry: return .stone
        case .deer, .wildBoar, .deerCarcass, .boarCarcass, .farmland: return .food
        }
    }

    var initialAmount: Int {
        switch self {
        case .trees: return 100
        case .forage: return 3000
        case .oreMine: return 8000
        case .stoneQuarry: return 6000
        case .deer: return 2000
        case .wildBoar: return 1500
        case .deerCarcass: return 2000
        case .boarCarcass: return 1500
        case .farmland: return 999999
        }
    }

    var baseGatherRate: Double {
        switch self {
        case .trees: return 0.5
        case .forage: return 0.5
        case .oreMine: return 0.5
        case .stoneQuarry: return 0.5
        case .deer: return 0.0  // Can't gather live animals
        case .wildBoar: return 0.0
        case .deerCarcass: return 0.5
        case .boarCarcass: return 0.5
        case .farmland: return 0.1
        }
    }

    var requiresCamp: Bool {
        switch self {
        case .trees, .oreMine, .stoneQuarry: return true
        case .forage, .deer, .wildBoar, .deerCarcass, .boarCarcass, .farmland: return false
        }
    }

    var requiredCampType: String? {
        switch self {
        case .trees: return "Lumber Camp"
        case .oreMine, .stoneQuarry: return "Mining Camp"
        default: return nil
        }
    }

    var isHuntable: Bool {
        switch self {
        case .deer, .wildBoar: return true
        default: return false
        }
    }

    var isCarcass: Bool {
        switch self {
        case .deerCarcass, .boarCarcass: return true
        default: return false
        }
    }

    var isGatherable: Bool {
        switch self {
        case .deer, .wildBoar: return false  // Must hunt first
        default: return true
        }
    }

    /// Required terrain for spawning
    var requiredTerrain: TerrainData? {
        switch self {
        case .forage: return .plains
        case .oreMine, .stoneQuarry: return .mountain
        case .trees, .deer, .wildBoar, .boarCarcass, .deerCarcass, .farmland: return nil
        }
    }

    // Combat stats for huntable animals
    var attackPower: Double {
        switch self {
        case .deer: return 2
        case .wildBoar: return 8
        default: return 0
        }
    }

    var defensePower: Double {
        switch self {
        case .deer: return 3
        case .wildBoar: return 5
        default: return 0
        }
    }

    var maxHealth: Double {
        switch self {
        case .deer: return 30
        case .wildBoar: return 50
        default: return 0
        }
    }

    /// Alias for backward compatibility with legacy code
    var health: Double { return maxHealth }

    var carcassType: ResourcePointTypeData? {
        switch self {
        case .deer: return .deerCarcass
        case .wildBoar: return .boarCarcass
        default: return nil
        }
    }
}

// MARK: - Resource Point Data

/// Pure data representation of a resource point on the map
class ResourcePointData: Codable {
    let id: UUID
    let resourceType: ResourcePointTypeData
    var coordinate: HexCoordinate

    private(set) var remainingAmount: Int
    private(set) var currentHealth: Double

    // Gathering state
    private(set) var assignedVillagerGroupIDs: Set<UUID> = []
    private(set) var totalVillagersGathering: Int = 0

    static let maxVillagersPerTile = 20

    init(id: UUID = UUID(), coordinate: HexCoordinate, resourceType: ResourcePointTypeData) {
        self.id = id
        self.coordinate = coordinate
        self.resourceType = resourceType
        self.remainingAmount = resourceType.initialAmount
        self.currentHealth = resourceType.maxHealth
    }

    // MARK: - Amount Management

    func setRemainingAmount(_ amount: Int) {
        remainingAmount = max(0, amount)
    }

    func gather(amount: Int) -> Int {
        let gathered = min(amount, remainingAmount)
        remainingAmount = max(0, remainingAmount - gathered)
        return gathered
    }

    func isDepleted() -> Bool {
        return remainingAmount <= 0
    }

    // MARK: - Health Management (for huntable animals)

    func setCurrentHealth(_ health: Double) {
        currentHealth = max(0, min(health, resourceType.maxHealth))
    }

    func takeDamage(_ damage: Double) -> Bool {
        guard resourceType.isHuntable else { return false }

        currentHealth = max(0, currentHealth - damage)

        return currentHealth <= 0  // Returns true if killed
    }

    func isAlive() -> Bool {
        return currentHealth > 0
    }

    // MARK: - Villager Assignment

    func assignVillagerGroup(_ groupID: UUID, villagerCount: Int) -> Bool {
        guard canAddVillagers(villagerCount) else { return false }
        guard !assignedVillagerGroupIDs.contains(groupID) else { return false }

        assignedVillagerGroupIDs.insert(groupID)
        totalVillagersGathering += villagerCount

        return true
    }

    func unassignVillagerGroup(_ groupID: UUID, villagerCount: Int) {
        guard assignedVillagerGroupIDs.contains(groupID) else { return }

        assignedVillagerGroupIDs.remove(groupID)
        totalVillagersGathering = max(0, totalVillagersGathering - villagerCount)
    }

    func updateVillagerCount(forGroup groupID: UUID, oldCount: Int, newCount: Int) {
        guard assignedVillagerGroupIDs.contains(groupID) else { return }

        totalVillagersGathering = max(0, totalVillagersGathering - oldCount + newCount)
    }

    func canAddVillagers(_ count: Int) -> Bool {
        return totalVillagersGathering + count <= ResourcePointData.maxVillagersPerTile
    }

    func getRemainingCapacity() -> Int {
        return max(0, ResourcePointData.maxVillagersPerTile - totalVillagersGathering)
    }

    func isBeingGathered() -> Bool {
        return !assignedVillagerGroupIDs.isEmpty
    }

    // MARK: - Gather Rate Calculation

    func getCurrentGatherRate(researchMultiplier: Double = 1.0) -> Double {
        let perVillagerRate = 0.2  // Each villager adds 0.2 per second
        let baseRate = resourceType.baseGatherRate + (Double(totalVillagersGathering) * perVillagerRate)

        return baseRate * researchMultiplier
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, resourceType, coordinate
        case remainingAmount, currentHealth
        case assignedVillagerGroupIDs, totalVillagersGathering
    }
}

// MARK: - Resource Point Data Extensions

extension ResourcePointData {
    func getDescription() -> String {
        var desc = "\(resourceType.displayName)\n"
        desc += "Remaining: \(remainingAmount)/\(resourceType.initialAmount)\n"
        desc += "Yields: \(resourceType.resourceYield.displayName)"

        if resourceType.isHuntable {
            desc += "\n\nHealth: \(Int(currentHealth))/\(Int(resourceType.maxHealth))"
            desc += "\nAttack: \(Int(resourceType.attackPower))"
            desc += "\nDefense: \(Int(resourceType.defensePower))"
        } else if resourceType.isGatherable {
            desc += "\n\nVillagers: \(totalVillagersGathering)/\(ResourcePointData.maxVillagersPerTile)"

            if resourceType.requiresCamp {
                desc += "\nRequires \(resourceType.requiredCampType ?? "Camp") nearby"
            }
        }

        return desc
    }

    /// Creates a carcass data object from this resource point (for when an animal is killed)
    func createCarcassData() -> ResourcePointData? {
        guard let carcassType = resourceType.carcassType else { return nil }

        return ResourcePointData(
            id: UUID(),
            coordinate: coordinate,
            resourceType: carcassType
        )
    }
}
