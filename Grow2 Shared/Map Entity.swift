// ============================================================================
// FILE: Map Entity.swift
// LOCATION: Replace the entire file with this corrected version
// ============================================================================

import Foundation
import SpriteKit
import UIKit

// MARK: - MapEntity

class MapEntity {
    let id: UUID
    var name: String
    let entityType: EntityType
    weak var owner: Player?
    
    // ✅ FIXED: Removed units parameter
    init(id: UUID = UUID(), name: String, entityType: EntityType) {
        self.id = id
        self.name = name
        self.entityType = entityType
    }
}

// MARK: - Pending Reinforcement

/// Represents reinforcements that are marching to join this army
struct PendingReinforcement: Codable {
    let reinforcementID: UUID
    let unitComposition: [String: Int]  // MilitaryUnitType.rawValue: count
    let estimatedArrivalTime: TimeInterval
    let sourceCoordinate: HexCoordinate

    init(reinforcementID: UUID, units: [MilitaryUnitType: Int], estimatedArrival: TimeInterval, source: HexCoordinate) {
        self.reinforcementID = reinforcementID
        self.unitComposition = Dictionary(uniqueKeysWithValues: units.map { ($0.key.rawValue, $0.value) })
        self.estimatedArrivalTime = estimatedArrival
        self.sourceCoordinate = source
    }

    /// Gets the unit composition as MilitaryUnitType dictionary
    func getUnits() -> [MilitaryUnitType: Int] {
        var result: [MilitaryUnitType: Int] = [:]
        for (key, value) in unitComposition {
            if let unitType = MilitaryUnitType(rawValue: key) {
                result[unitType] = value
            }
        }
        return result
    }

    /// Gets total unit count
    func getTotalUnits() -> Int {
        return unitComposition.values.reduce(0, +)
    }
}

// MARK: - Army
class Army: MapEntity {
    var coordinate: HexCoordinate
    var commander: Commander?  // ✅ CHANGED: Made optional for now (until commander system fully implemented)

    private(set) var militaryComposition: [MilitaryUnitType: Int] = [:]

    /// Reinforcements currently marching to this army
    private(set) var pendingReinforcements: [PendingReinforcement] = []

    /// Whether this army has reinforcements en route
    var isAwaitingReinforcements: Bool {
        return !pendingReinforcements.isEmpty
    }

    // MARK: - Home Base System

    /// Reference to this army's home base building (City Center, Wooden Fort, or Castle)
    var homeBaseID: UUID?

    /// Whether this army is currently retreating (grants 10% speed bonus)
    var isRetreating: Bool = false

    /// Building types that can serve as a home base
    static let validHomeBaseTypes: Set<BuildingType> = [.cityCenter, .woodenFort, .castle]

    /// Check if a building type can be used as a home base
    static func canBeHomeBase(_ buildingType: BuildingType) -> Bool {
        return validHomeBaseTypes.contains(buildingType)
    }

    /// Updates the army's home base
    func setHomeBase(_ buildingID: UUID?) {
        homeBaseID = buildingID
        if let id = buildingID {
            print("🏠 Army \(name) home base set to building \(id)")
        } else {
            print("🏠 Army \(name) home base cleared")
        }
    }

    init(id: UUID = UUID(), name: String = "Army", coordinate: HexCoordinate, commander: Commander? = nil, owner: Player? = nil) {
        self.coordinate = coordinate
        self.commander = commander
        super.init(id: id, name: name, entityType: .army)
        self.owner = owner
    }

    // MARK: - Pending Reinforcement Management

    /// Adds a pending reinforcement to track
    func addPendingReinforcement(_ reinforcement: PendingReinforcement) {
        pendingReinforcements.append(reinforcement)
        print("🚶 Army \(name) now awaiting \(reinforcement.getTotalUnits()) reinforcements")
    }

    /// Removes a pending reinforcement by ID
    func removePendingReinforcement(id: UUID) {
        pendingReinforcements.removeAll { $0.reinforcementID == id }
    }

    /// Receives arriving reinforcements and adds them to the army
    func receiveReinforcement(_ units: [MilitaryUnitType: Int]) {
        for (unitType, count) in units {
            addMilitaryUnits(unitType, count: count)
        }
        let total = units.values.reduce(0, +)
        print("✅ Army \(name) received \(total) reinforcement units!")
    }

    /// Gets total pending reinforcement units
    func getTotalPendingUnits() -> Int {
        return pendingReinforcements.reduce(0) { $0 + $1.getTotalUnits() }
    }
    func addMilitaryUnits(_ unitType: MilitaryUnitType, count: Int) {
        militaryComposition[unitType, default: 0] += count
    }
    
    func setCommander(_ newCommander: Commander?) {
        // Clear old commander's reference
        if let oldCommander = commander {
            oldCommander.assignedArmy = nil
        }
        
        // Set new commander
        commander = newCommander
        
        // Update new commander's reference
        if let newCommander = newCommander {
            // Remove from their old army if any
            if let oldArmy = newCommander.assignedArmy, oldArmy.id != self.id {
                oldArmy.commander = nil
            }
            newCommander.assignedArmy = self
        }
    }
    
    func removeMilitaryUnits(_ unitType: MilitaryUnitType, count: Int) -> Int {
        let current = militaryComposition[unitType] ?? 0
        let toRemove = min(current, count)
        
        if toRemove > 0 {
            let remaining = current - toRemove
            if remaining > 0 {
                militaryComposition[unitType] = remaining
            } else {
                militaryComposition.removeValue(forKey: unitType)
            }
        }
        
        return toRemove
    }
    
    // ✅ UPDATED: Handle optional commander
    func getMaxArmySize() -> Int {
        return commander?.rank.maxArmySize ?? 200  // Default 200 if no commander
    }
        
    func isAtCapacity() -> Bool {
        return getTotalUnits() >= getMaxArmySize()
    }
    
    func getTotalUnits() -> Int {
        return getTotalMilitaryUnits()
    }
    
    // ✅ UPDATED: Handle optional commander with category-based specialty bonuses using combatStats
    func getModifiedStrength() -> Double {
        let aggregatedStats = getAggregatedCombatStats()
        let baseStrength = aggregatedStats.meleeDamage + aggregatedStats.pierceDamage + aggregatedStats.bludgeonDamage

        guard let commander = commander else {
            return baseStrength
        }

        var totalStrength = 0.0

        // Apply specialty bonuses per unit category
        for (unitType, count) in militaryComposition {
            let stats = unitType.combatStats
            let unitDamage = stats.meleeDamage + stats.pierceDamage + stats.bludgeonDamage
            let baseDamage = unitDamage * Double(count)
            let categoryBonus = commander.getAttackBonus(for: unitType.category)
            totalStrength += baseDamage * (1.0 + categoryBonus)
        }

        return totalStrength
    }

    // ✅ UPDATED: Handle optional commander with category-based specialty bonuses using combatStats
    func getModifiedDefense() -> Double {
        let aggregatedStats = getAggregatedCombatStats()
        let baseDefense = aggregatedStats.averageArmor * Double(getTotalUnits())

        guard let commander = commander else {
            return baseDefense
        }

        var totalDefense = 0.0
        let defenseBonus = commander.getDefenseBonus()

        // Apply defense bonuses per unit
        for (unitType, count) in militaryComposition {
            let stats = unitType.combatStats
            let unitArmor = (stats.meleeArmor + stats.pierceArmor + stats.bludgeonArmor) / 3.0
            let baseArmor = unitArmor * Double(count)
            totalDefense += baseArmor * (1.0 + defenseBonus)
        }

        return totalDefense
    }

    
    // ✅ UPDATED: Handle optional commander
    func getDescription() -> String {
         let totalUnits = getTotalMilitaryUnits()
         
         guard totalUnits > 0 else { return "\(name) (Empty)" }
         
         var desc = "\(name) (\(totalUnits)/\(getMaxArmySize()) units)\n"
         
         if let commander = commander {
             desc += "\(commander.getShortDescription())\n"
         } else {
             desc += "⚠️ No Commander\n"
         }
         
         for (unitType, count) in militaryComposition.sorted(by: { $0.key.displayName < $1.key.displayName }) {
             desc += "\n  • \(count)x \(unitType.icon) \(unitType.displayName)"
         }
         
         return desc
     }
    
    func getMilitaryUnitCount(ofType type: MilitaryUnitType) -> Int {
        return militaryComposition[type] ?? 0
    }
    
    func getTotalMilitaryUnits() -> Int {
        return militaryComposition.values.reduce(0, +)
    }
    
    func hasMilitaryUnits() -> Bool {
        return getTotalMilitaryUnits() > 0
    }
    
    // MARK: - Combat Stats

    /// Aggregates combat stats for all units in this army
    func getAggregatedCombatStats() -> UnitCombatStats {
        var allStats: [UnitCombatStats] = []

        for (unitType, count) in militaryComposition {
            for _ in 0..<count {
                allStats.append(unitType.combatStats)
            }
        }

        return UnitCombatStats.aggregate(allStats)
    }

    /// Gets the primary unit category of this army (based on majority unit count)
    func getPrimaryCategory() -> UnitCategory? {
        var categoryCounts: [UnitCategory: Int] = [:]

        for (unitType, count) in militaryComposition {
            categoryCounts[unitType.category, default: 0] += count
        }

        return categoryCounts.max(by: { $0.value < $1.value })?.key
    }

    /// Gets count of units in a specific category
    func getUnitCountByCategory(_ category: UnitCategory) -> Int {
        var count = 0
        for (unitType, unitCount) in militaryComposition {
            if unitType.category == category {
                count += unitCount
            }
        }
        return count
    }

    /// Total damage output of the army (sum of all damage types across all units)
    func getTotalStrength() -> Double {
        let stats = getAggregatedCombatStats()
        return stats.meleeDamage + stats.pierceDamage + stats.bludgeonDamage
    }

    /// Average defense of the army (average armor across all units)
    func getTotalDefense() -> Double {
        let stats = getAggregatedCombatStats()
        let totalUnits = getTotalUnits()
        guard totalUnits > 0 else { return 0 }
        return (stats.meleeArmor + stats.pierceArmor + stats.bludgeonArmor) / 3.0 * Double(totalUnits)
    }

    /// Total HP of all units in the army
    func getTotalHP() -> Double {
        var totalHP = 0.0
        for (unitType, count) in militaryComposition {
            totalHP += unitType.hp * Double(count)
        }
        return totalHP
    }
    
    // MARK: - Merging Armies
    
    func merge(with otherArmy: Army) {
        // Merge new military unit system
        for (unitType, count) in otherArmy.militaryComposition {
            addMilitaryUnits(unitType, count: count)
        }
    }

}

// MARK: - VillagerGroup

class VillagerGroup: MapEntity {
    var coordinate: HexCoordinate
    
    private(set) var villagerCount: Int = 0
    
    var currentTask: VillagerTask = .idle
    var taskTarget: HexCoordinate?
    
    init(name: String = "Villagers", coordinate: HexCoordinate, villagerCount: Int = 0, owner: Player? = nil) {
        self.coordinate = coordinate
        self.villagerCount = max(0, villagerCount)
        super.init(id: UUID(), name: name, entityType: .villagerGroup)  // ✅ No units parameter
        self.owner = owner
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
    
    func getUnitCount() -> Int {
        return villagerCount
    }
    
    func hasVillagers() -> Bool {
        return villagerCount > 0
    }
    
    func getDescription() -> String {
        guard hasVillagers() else { return "\(name) (Empty)" }
        
        let taskDesc = currentTask == .idle ? "Idle" : "Working: \(currentTask.displayName)"
        return "\(name) (\(villagerCount) villagers)\n\(taskDesc)"
    }
    
    // MARK: - Task Management
    
    func assignTask(_ task: VillagerTask, target: HexCoordinate? = nil) {
        currentTask = task
        taskTarget = target
    }
    
    func clearTask() {
        currentTask = .idle
        taskTarget = nil
    }
    
    // MARK: - Merging Groups
    
    func merge(with otherGroup: VillagerGroup) {
        addVillagers(count: otherGroup.villagerCount)
    }
    
    // MARK: - Splitting Groups
    
    func split(count: Int, name: String? = nil) -> VillagerGroup? {
        guard count > 0 && count < villagerCount else {
            return nil
        }
        
        let newGroup = VillagerGroup(
            name: name ?? "\(self.name) (Split)",
            coordinate: coordinate,
            villagerCount: count,
            owner: owner
        )
        
        removeVillagers(count: count)
        
        return newGroup
    }
}

enum VillagerTask: Equatable {

    case idle
    case building(BuildingNode)
    case gathering(ResourceType)
    case gatheringResource(ResourcePointNode)
    case hunting(ResourcePointNode)  // ✅ NEW: Hunting an animal
    case repairing(BuildingNode)
    case moving(HexCoordinate)
    case upgrading(BuildingNode)
    case demolishing(BuildingNode)
    
    var displayName: String {
        switch self {
        case .idle:
            return "Idle"
        case .building(let building):
            return "Building \(building.buildingType.displayName)"
        case .gathering(let resource):
            return "Gathering \(resource.displayName)"
        case .gatheringResource(let resourcePoint):
            return "Gathering \(resourcePoint.resourceType.displayName)"
        case .hunting(let resourcePoint):
            return "Hunting \(resourcePoint.resourceType.displayName)"
        case .repairing(let building):
            return "Repairing \(building.buildingType.displayName)"
        case .moving(let coord):
            return "Moving to (\(coord.q), \(coord.r))"
        case .upgrading(let building):
            return "Upgrading \(building.buildingType.displayName)"
        case .demolishing(let building):
            return "Demolishing \(building.buildingType.displayName)"
        }
    }

    static func == (lhs: VillagerTask, rhs: VillagerTask) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.building(let lhsBuilding), .building(let rhsBuilding)):
            return lhsBuilding === rhsBuilding
        case (.gathering(let lhsResource), .gathering(let rhsResource)):
            return lhsResource == rhsResource
        case (.gatheringResource(let lhsResource), .gatheringResource(let rhsResource)):
            return lhsResource === rhsResource
        case (.hunting(let lhsResource), .hunting(let rhsResource)):
            return lhsResource === rhsResource
        case (.repairing(let lhsBuilding), .repairing(let rhsBuilding)):
            return lhsBuilding === rhsBuilding
        case (.moving(let lhsCoord), .moving(let rhsCoord)):
            return lhsCoord == rhsCoord
        case (.upgrading(let lhsBuilding), .upgrading(let rhsBuilding)):
            return lhsBuilding === rhsBuilding
        case (.demolishing(let lhsBuilding), .demolishing(let rhsBuilding)):
            return lhsBuilding === rhsBuilding
        default:
            return false
        }
    }
}
