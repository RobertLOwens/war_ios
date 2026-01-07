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

// MARK: - Army
class Army: MapEntity {
    var coordinate: HexCoordinate
    var commander: Commander?  // ✅ CHANGED: Made optional for now (until commander system fully implemented)
    
    private(set) var militaryComposition: [MilitaryUnitType: Int] = [:]

    // ✅ UPDATED: Commander is optional
    init(name: String = "Army", coordinate: HexCoordinate, commander: Commander? = nil, owner: Player? = nil) {
        self.coordinate = coordinate
        self.commander = commander
        super.init(id: UUID(), name: name, entityType: .army)  // ✅ No units parameter
        self.owner = owner
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
    
    // ✅ UPDATED: Handle optional commander
    func getModifiedStrength() -> Double {
        var strength = getTotalStrength()
        if let commander = commander {
            let bonus = commander.rank.leadershipBonus
            return Double(Double(strength) * (1.0 + bonus))
        }
        return strength
    }
    
    // ✅ UPDATED: Handle optional commander
    func getModifiedDefense() -> Double {
        var defense = getTotalDefense()
        if let commander = commander {
            let bonus = commander.getDefenseBonus()
            return Double(Double(defense) * (1.0 + bonus))
        }
        return defense
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
    
    func getTotalStrength() -> Double {
        var strength = 0.0
         
         // New military unit system
         for (unitType, count) in militaryComposition {
         strength += unitType.attackPower * Double(count)
         }
         
         return strength
     }
    
    func getTotalDefense() -> Double {
         var defense = 0.0
        
         // New military unit system
         for (unitType, count) in militaryComposition {
             defense += unitType.defensePower * Double(count)
         }
         
         return defense
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
    case gatheringResource(ResourcePointNode) // ✅ NEW: Gathering from specific resource point
    case repairing(BuildingNode)
    case moving(HexCoordinate)
    
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
        case .repairing(let building):
            return "Repairing \(building.buildingType.displayName)"
        case .moving(let coord):
            return "Moving to (\(coord.q), \(coord.r))"
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
        case (.repairing(let lhsBuilding), .repairing(let rhsBuilding)):
            return lhsBuilding === rhsBuilding
        case (.moving(let lhsCoord), .moving(let rhsCoord)):
            return lhsCoord == rhsCoord
        default:
            return false
        }
    }
}
