import Foundation

// MARK: - Damage Type

enum DamageType: String, CaseIterable, Codable {
    case melee, pierce, bludgeon
}

// MARK: - Unit Category

enum UnitCategory: String, Codable {
    case infantry, ranged, cavalry, siege
}

// MARK: - Unit Combat Stats

struct UnitCombatStats: Codable {
    var meleeDamage: Double = 0
    var pierceDamage: Double = 0
    var bludgeonDamage: Double = 0
    var meleeArmor: Double = 0
    var pierceArmor: Double = 0
    var bludgeonArmor: Double = 0
    var bonusVsCavalry: Double = 0
    var bonusVsBuildings: Double = 0

    /// Combines stats from multiple units (for army aggregation)
    static func aggregate(_ stats: [UnitCombatStats]) -> UnitCombatStats {
        var result = UnitCombatStats()
        for stat in stats {
            result.meleeDamage += stat.meleeDamage
            result.pierceDamage += stat.pierceDamage
            result.bludgeonDamage += stat.bludgeonDamage
            result.meleeArmor += stat.meleeArmor
            result.pierceArmor += stat.pierceArmor
            result.bludgeonArmor += stat.bludgeonArmor
            result.bonusVsCavalry += stat.bonusVsCavalry
            result.bonusVsBuildings += stat.bonusVsBuildings
        }
        return result
    }
}

struct VillagerTrainingEntry: Codable {
    let id: UUID
    let quantity: Int
    let startTime: TimeInterval
    var progress: Double = 0.0
    
    static let trainingTimePerVillager: TimeInterval = 10.0
    
    init(quantity: Int, startTime: TimeInterval) {
        self.id = UUID()
        self.quantity = quantity
        self.startTime = startTime
    }
    
    func getProgress(currentTime: TimeInterval) -> Double {
        let elapsed = currentTime - startTime
        let totalTime = VillagerTrainingEntry.trainingTimePerVillager * Double(quantity)
        return min(1.0, elapsed / totalTime)
    }
}


// MARK: - Military Unit Type

enum TrainableUnitType: Codable {
    case military(MilitaryUnitType)
    case villager
    
    var displayName: String {
        switch self {
        case .military(let type):
            return type.displayName
        case .villager:
            return "Villager"
        }
    }
    
    var icon: String {
        switch self {
        case .military(let type):
            return type.icon
        case .villager:
            return "👷"
        }
    }
    
    var trainingCost: [ResourceType: Int] {
        switch self {
        case .military(let type):
            return type.trainingCost
        case .villager:
            return [.food: 50]
        }
    }
    
    var trainingTime: TimeInterval {
        switch self {
        case .military(let type):
            return type.trainingTime
        case .villager:
            return 15.0
        }
    }
    
    var description: String {
        switch self {
        case .military(let type):
            return type.description
        case .villager:
            return "Gathers resources and constructs buildings"
        }
    }
}

enum MilitaryUnitType: String, CaseIterable, Codable {
    case swordsman = "Swordsman"
    case pikeman = "Pikeman"
    case archer = "Archer"
    case crossbow = "Crossbow"
    case scout = "Scout"
    case knight = "Knight"
    case mangonel = "Mangonel"
    case trebuchet = "Trebuchet"

    var displayName: String {
        return rawValue
    }

    var icon: String {
        switch self {
        case .swordsman: return "🗡️"
        case .pikeman: return "🔱"
        case .archer: return "🏹"
        case .crossbow: return "🎯"
        case .scout: return "🐎"
        case .knight: return "🐴"
        case .mangonel: return "⚙️"
        case .trebuchet: return "🪨"
        }
    }

    var category: UnitCategory {
        switch self {
        case .swordsman, .pikeman:
            return .infantry
        case .archer, .crossbow:
            return .ranged
        case .scout, .knight:
            return .cavalry
        case .mangonel, .trebuchet:
            return .siege
        }
    }

    var trainingBuilding: BuildingType {
        switch self {
        case .swordsman, .pikeman:
            return .barracks
        case .archer, .crossbow:
            return .archeryRange
        case .scout, .knight:
            return .stable
        case .mangonel, .trebuchet:
            return .siegeWorkshop
        }
    }

    var trainingCost: [ResourceType: Int] {
        switch self {
        case .swordsman:
            return [.food: 50, .ore: 25]
        case .pikeman:
            return [.food: 45, .ore: 20, .wood: 30]
        case .archer:
            return [.food: 40, .ore: 15, .wood: 35]
        case .crossbow:
            return [.food: 45, .ore: 25, .wood: 40]
        case .scout:
            return [.food: 60, .ore: 20]
        case .knight:
            return [.food: 80, .ore: 40, .wood: 40]
        case .mangonel:
            return [.food: 60, .ore: 80, .wood: 180]
        case .trebuchet:
            return [.food: 80, .ore: 100, .wood: 250]
        }
    }

    var trainingTime: TimeInterval {
        switch self {
        case .swordsman: return 15.0
        case .pikeman: return 20.0
        case .archer: return 22.0
        case .crossbow: return 28.0
        case .scout: return 18.0
        case .knight: return 35.0
        case .mangonel: return 45.0
        case .trebuchet: return 60.0
        }
    }

    /// Combat stats for the new damage/armor system
    var combatStats: UnitCombatStats {
        switch self {
        case .swordsman:
            return UnitCombatStats(
                meleeDamage: 12, pierceDamage: 0, bludgeonDamage: 0,
                meleeArmor: 10, pierceArmor: 6, bludgeonArmor: 5,
                bonusVsCavalry: 0, bonusVsBuildings: 0
            )
        case .pikeman:
            return UnitCombatStats(
                meleeDamage: 6, pierceDamage: 0, bludgeonDamage: 0,
                meleeArmor: 4, pierceArmor: 3, bludgeonArmor: 3,
                bonusVsCavalry: 15, bonusVsBuildings: 0
            )
        case .archer:
            return UnitCombatStats(
                meleeDamage: 0, pierceDamage: 12, bludgeonDamage: 0,
                meleeArmor: 3, pierceArmor: 3, bludgeonArmor: 0,
                bonusVsCavalry: 0, bonusVsBuildings: 0
            )
        case .crossbow:
            return UnitCombatStats(
                meleeDamage: 0, pierceDamage: 14, bludgeonDamage: 0,
                meleeArmor: 3, pierceArmor: 7, bludgeonArmor: 0,
                bonusVsCavalry: 0, bonusVsBuildings: 0
            )
        case .scout:
            return UnitCombatStats(
                meleeDamage: 6, pierceDamage: 0, bludgeonDamage: 0,
                meleeArmor: 3, pierceArmor: 6, bludgeonArmor: 0,
                bonusVsCavalry: 0, bonusVsBuildings: 0
            )
        case .knight:
            return UnitCombatStats(
                meleeDamage: 14, pierceDamage: 0, bludgeonDamage: 0,
                meleeArmor: 8, pierceArmor: 5, bludgeonArmor: 4,
                bonusVsCavalry: 0, bonusVsBuildings: 0
            )
        case .mangonel:
            return UnitCombatStats(
                meleeDamage: 0, pierceDamage: 0, bludgeonDamage: 18,
                meleeArmor: 6, pierceArmor: 10, bludgeonArmor: 6,
                bonusVsCavalry: 0, bonusVsBuildings: 20
            )
        case .trebuchet:
            return UnitCombatStats(
                meleeDamage: 0, pierceDamage: 0, bludgeonDamage: 25,
                meleeArmor: 5, pierceArmor: 12, bludgeonArmor: 5,
                bonusVsCavalry: 0, bonusVsBuildings: 35
            )
        }
    }

    /// Hit points for this unit type
    var hp: Double {
        switch self {
        case .swordsman:  return 120  // Tanky infantry
        case .pikeman:    return 100  // Standard infantry
        case .archer:     return 70   // Fragile ranged
        case .crossbow:   return 85   // Armored ranged
        case .scout:      return 80   // Light cavalry
        case .knight:     return 140  // Heavy cavalry
        case .mangonel:   return 150  // Siege - tanky but slow
        case .trebuchet:  return 180  // Heavy siege
        }
    }

    /// Legacy attack power (sum of all damage types for backward compatibility)
    var attackPower: Double {
        let stats = combatStats
        return stats.meleeDamage + stats.pierceDamage + stats.bludgeonDamage
    }

    /// Legacy defense power (average of armor types for backward compatibility)
    var defensePower: Double {
        let stats = combatStats
        return (stats.meleeArmor + stats.pierceArmor + stats.bludgeonArmor) / 3.0
    }

    var moveSpeed: TimeInterval {
        switch self {
        case .swordsman: return 0.35
        case .pikeman: return 0.40
        case .archer: return 0.35
        case .crossbow: return 0.38
        case .scout: return 0.22  // Fast cavalry
        case .knight: return 0.25
        case .mangonel: return 0.50  // Slow siege
        case .trebuchet: return 0.60  // Very slow siege
        }
    }

    /// Attack speed - time between attacks in seconds (lower = faster)
    var attackSpeed: TimeInterval {
        switch self {
        case .swordsman: return 1.0    // Standard melee
        case .pikeman: return 1.2      // Slower heavy weapon
        case .archer: return 0.8       // Fast ranged
        case .crossbow: return 1.5     // Slow reload
        case .scout: return 0.7        // Fast light cavalry
        case .knight: return 1.1       // Heavy cavalry
        case .mangonel: return 2.5     // Slow siege
        case .trebuchet: return 4.0    // Very slow siege
        }
    }

    var description: String {
        switch self {
        case .swordsman:
            return "Balanced melee infantry unit with good armor"
        case .pikeman:
            return "Anti-cavalry infantry with bonus damage vs mounted units"
        case .archer:
            return "Ranged unit with pierce damage"
        case .crossbow:
            return "Heavy ranged unit with high pierce damage and armor"
        case .scout:
            return "Fast light cavalry for reconnaissance"
        case .knight:
            return "Powerful mounted unit with high melee damage"
        case .mangonel:
            return "Siege weapon with bludgeon damage, effective vs buildings"
        case .trebuchet:
            return "Long-range siege weapon, devastating vs buildings"
        }
    }
}

// MARK: - Training Queue Entry

struct TrainingQueueEntry: Codable {
    let id: UUID
    let unitType: MilitaryUnitType
    let quantity: Int
    let startTime: TimeInterval
    var progress: Double = 0.0
    
    init(unitType: MilitaryUnitType, quantity: Int, startTime: TimeInterval) {
        self.id = UUID()
        self.unitType = unitType
        self.quantity = quantity
        self.startTime = startTime
    }
    
    func getProgress(currentTime: TimeInterval) -> Double {
        let elapsed = currentTime - startTime
        let totalTime = unitType.trainingTime * Double(quantity)
        return min(1.0, elapsed / totalTime)
    }
}
