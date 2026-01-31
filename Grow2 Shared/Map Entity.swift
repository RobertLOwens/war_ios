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
    // MARK: - Data Layer (Single Source of Truth)
    let data: ArmyData

    // MARK: - Visual Layer Only
    var commander: Commander?  // Visual reference (data.commanderID holds the ID)

    // MARK: - Delegated Properties
    var coordinate: HexCoordinate {
        get { data.coordinate }
        set { data.coordinate = newValue }
    }

    var militaryComposition: [MilitaryUnitType: Int] {
        get {
            // Convert from Data types to Visual types (they're aliased, so direct cast works)
            var result: [MilitaryUnitType: Int] = [:]
            for (unitType, count) in data.militaryComposition {
                result[unitType] = count
            }
            return result
        }
    }

    var homeBaseID: UUID? {
        get { data.homeBaseID }
        set { data.homeBaseID = newValue }
    }

    var isRetreating: Bool {
        get { data.isRetreating }
        set { data.isRetreating = newValue }
    }

    var isAwaitingReinforcements: Bool {
        return data.isAwaitingReinforcements
    }

    /// Pending reinforcements (converted from data layer)
    var pendingReinforcements: [PendingReinforcement] {
        return data.pendingReinforcements.map { dataReinforcement in
            var units: [MilitaryUnitType: Int] = [:]
            for (unitType, count) in dataReinforcement.unitComposition {
                units[unitType] = count
            }
            return PendingReinforcement(
                reinforcementID: dataReinforcement.reinforcementID,
                units: units,
                estimatedArrival: dataReinforcement.estimatedArrivalTime,
                source: dataReinforcement.sourceCoordinate
            )
        }
    }

    // MARK: - Static Properties
    static let validHomeBaseTypes: Set<BuildingType> = [.cityCenter, .woodenFort, .castle]

    static func canBeHomeBase(_ buildingType: BuildingType) -> Bool {
        return validHomeBaseTypes.contains(buildingType)
    }

    // MARK: - Initialization

    init(id: UUID = UUID(), name: String = "Army", coordinate: HexCoordinate, commander: Commander? = nil, owner: Player? = nil, data: ArmyData? = nil) {
        // Use provided data or create new
        if let existingData = data {
            self.data = existingData
        } else {
            self.data = ArmyData(id: id, name: name, coordinate: coordinate, ownerID: owner?.id)
        }
        self.commander = commander
        super.init(id: self.data.id, name: self.data.name, entityType: .army)
        self.owner = owner

        // Sync commander ID to data
        if let cmd = commander {
            self.data.commanderID = cmd.id
        }
    }

    /// Updates the army's home base
    func setHomeBase(_ buildingID: UUID?) {
        data.homeBaseID = buildingID
        if let id = buildingID {
            print("🏠 Army \(name) home base set to building \(id)")
        } else {
            print("🏠 Army \(name) home base cleared")
        }
    }

    // MARK: - Pending Reinforcement Management

    /// Adds a pending reinforcement to track
    func addPendingReinforcement(_ reinforcement: PendingReinforcement) {
        // Convert to data type
        var dataUnits: [MilitaryUnitTypeData: Int] = [:]
        for (unitType, count) in reinforcement.getUnits() {
            dataUnits[unitType] = count
        }
        let dataReinforcement = PendingReinforcementData(
            reinforcementID: reinforcement.reinforcementID,
            units: dataUnits,
            estimatedArrival: reinforcement.estimatedArrivalTime,
            source: reinforcement.sourceCoordinate,
            path: []  // Path would need to be provided
        )
        data.addPendingReinforcement(dataReinforcement)
        print("🚶 Army \(name) now awaiting \(reinforcement.getTotalUnits()) reinforcements")
    }

    /// Removes a pending reinforcement by ID
    func removePendingReinforcement(id: UUID) {
        data.removePendingReinforcement(id: id)
    }

    /// Receives arriving reinforcements and adds them to the army
    func receiveReinforcement(_ units: [MilitaryUnitType: Int]) {
        var dataUnits: [MilitaryUnitTypeData: Int] = [:]
        for (unitType, count) in units {
            dataUnits[unitType] = count
        }
        data.receiveReinforcement(dataUnits)
        let total = units.values.reduce(0, +)
        print("✅ Army \(name) received \(total) reinforcement units!")
    }

    /// Gets total pending reinforcement units
    func getTotalPendingUnits() -> Int {
        return data.getTotalPendingUnits()
    }

    func addMilitaryUnits(_ unitType: MilitaryUnitType, count: Int) {
        data.addMilitaryUnits(unitType, count: count)
    }

    func setCommander(_ newCommander: Commander?) {
        // Clear old commander's reference
        if let oldCommander = commander {
            oldCommander.assignedArmy = nil
        }

        // Set new commander
        commander = newCommander
        data.commanderID = newCommander?.id

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
        return data.removeMilitaryUnits(unitType, count: count)
    }
    
    // MARK: - Capacity
    func getMaxArmySize() -> Int {
        return commander?.rank.maxArmySize ?? 200  // Default 200 if no commander
    }

    func isAtCapacity() -> Bool {
        return getTotalUnits() >= getMaxArmySize()
    }

    func getTotalUnits() -> Int {
        return data.getTotalUnits()
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
        return data.getUnitCount(ofType: type)
    }

    func getTotalMilitaryUnits() -> Int {
        return data.getTotalUnits()
    }

    func hasMilitaryUnits() -> Bool {
        return data.hasMilitaryUnits()
    }

    // MARK: - Combat Stats

    /// Aggregates combat stats for all units in this army
    func getAggregatedCombatStats() -> UnitCombatStats {
        // Delegate to data and convert result
        let dataStats = data.getAggregatedCombatStats()
        return UnitCombatStats(
            meleeDamage: dataStats.meleeDamage,
            pierceDamage: dataStats.pierceDamage,
            bludgeonDamage: dataStats.bludgeonDamage,
            meleeArmor: dataStats.meleeArmor,
            pierceArmor: dataStats.pierceArmor,
            bludgeonArmor: dataStats.bludgeonArmor,
            bonusVsInfantry: dataStats.bonusVsInfantry,
            bonusVsCavalry: dataStats.bonusVsCavalry,
            bonusVsRanged: dataStats.bonusVsRanged,
            bonusVsSiege: dataStats.bonusVsSiege,
            bonusVsBuildings: dataStats.bonusVsBuildings
        )
    }

    /// Gets the primary unit category of this army (based on majority unit count)
    func getPrimaryCategory() -> UnitCategory? {
        return data.getPrimaryCategory()
    }

    /// Gets count of units in a specific category
    func getUnitCountByCategory(_ category: UnitCategory) -> Int {
        return data.getUnitCountByCategory(category)
    }

    /// Total damage output of the army (sum of all damage types across all units)
    func getTotalStrength() -> Double {
        let stats = data.getAggregatedCombatStats()
        return stats.meleeDamage + stats.pierceDamage + stats.bludgeonDamage
    }

    /// Average defense of the army (average armor across all units)
    func getTotalDefense() -> Double {
        let stats = data.getAggregatedCombatStats()
        let totalUnits = getTotalUnits()
        guard totalUnits > 0 else { return 0 }
        return (stats.meleeArmor + stats.pierceArmor + stats.bludgeonArmor) / 3.0 * Double(totalUnits)
    }

    /// Total HP of all units in the army
    func getTotalHP() -> Double {
        return data.getTotalHP()
    }

    // MARK: - Merging Armies

    func merge(with otherArmy: Army) {
        data.merge(with: otherArmy.data)
    }

}

// MARK: - VillagerGroup

class VillagerGroup: MapEntity {
    // MARK: - Data Layer (Single Source of Truth)
    let data: VillagerGroupData

    // MARK: - Visual Layer Only
    /// Visual task representation (holds visual node references)
    /// The data layer holds task as VillagerTaskData (with UUIDs instead of references)
    var currentTask: VillagerTaskVisual = .idle

    // MARK: - Delegated Properties
    var coordinate: HexCoordinate {
        get { data.coordinate }
        set { data.coordinate = newValue }
    }

    var villagerCount: Int {
        get { data.villagerCount }
    }

    var taskTarget: HexCoordinate? {
        get { data.taskTargetCoordinate }
        set { data.taskTargetCoordinate = newValue }
    }

    // MARK: - Initialization

    init(name: String = "Villagers", coordinate: HexCoordinate, villagerCount: Int = 0, owner: Player? = nil, data: VillagerGroupData? = nil) {
        // Use provided data or create new
        if let existingData = data {
            self.data = existingData
        } else {
            self.data = VillagerGroupData(name: name, coordinate: coordinate, villagerCount: villagerCount, ownerID: owner?.id)
        }
        super.init(id: self.data.id, name: self.data.name, entityType: .villagerGroup)
        self.owner = owner
    }

    // MARK: - Villager Management

    func addVillagers(count: Int) {
        data.addVillagers(count: count)
    }

    func removeVillagers(count: Int) -> Int {
        return data.removeVillagers(count: count)
    }

    func getUnitCount() -> Int {
        return data.villagerCount
    }

    func hasVillagers() -> Bool {
        return data.hasVillagers()
    }

    func getDescription() -> String {
        guard hasVillagers() else { return "\(name) (Empty)" }

        let taskDesc = currentTask == .idle ? "Idle" : "Working: \(currentTask.displayName)"
        return "\(name) (\(villagerCount) villagers)\n\(taskDesc)"
    }

    // MARK: - Task Management

    func assignTask(_ task: VillagerTaskVisual, target: HexCoordinate? = nil) {
        currentTask = task
        data.taskTargetCoordinate = target

        // Also update data layer task
        data.currentTask = task.toTaskData()
    }

    func clearTask() {
        currentTask = .idle
        data.clearTask()
    }

    // MARK: - Merging Groups

    func merge(with otherGroup: VillagerGroup) {
        data.merge(with: otherGroup.data)
    }

    // MARK: - Splitting Groups

    func split(count: Int, name: String? = nil) -> VillagerGroup? {
        guard let newData = data.split(count: count, newName: name ?? "\(self.name) (Split)") else {
            return nil
        }

        let newGroup = VillagerGroup(
            name: newData.name,
            coordinate: newData.coordinate,
            villagerCount: newData.villagerCount,
            owner: owner,
            data: newData
        )

        return newGroup
    }
}

/// Visual layer villager task enum with associated visual types (BuildingNode, ResourcePointNode)
/// For data layer, use VillagerTaskData instead which uses UUIDs
enum VillagerTaskVisual: Equatable {

    case idle
    case building(BuildingNode)
    case gathering(ResourceType)
    case gatheringResource(ResourcePointNode)
    case hunting(ResourcePointNode)
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

    /// Convert to data layer task (loses visual references, uses IDs instead)
    func toTaskData() -> VillagerTaskData {
        switch self {
        case .idle:
            return .idle
        case .building(let building):
            return .building(buildingID: building.data.id)
        case .gathering(let resourceType):
            return .gathering(resourceType: resourceType)
        case .gatheringResource:
            // Would need resource point ID, return idle for now
            return .idle
        case .hunting:
            // Would need resource point ID, return idle for now
            return .idle
        case .repairing(let building):
            return .repairing(buildingID: building.data.id)
        case .moving(let coord):
            return .moving(targetCoordinate: coord)
        case .upgrading(let building):
            return .upgrading(buildingID: building.data.id)
        case .demolishing(let building):
            return .demolishing(buildingID: building.data.id)
        }
    }

    static func == (lhs: VillagerTaskVisual, rhs: VillagerTaskVisual) -> Bool {
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
