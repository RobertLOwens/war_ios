// ============================================================================
// FILE: Grow2 Shared/Data/UnitUpgradeType.swift
// PURPOSE: Per-unit-type upgrade definitions (blacksmith-style upgrades)
// ============================================================================

import Foundation

// MARK: - Unit Upgrade Bonus Data

/// Flat bonuses granted by a unit upgrade tier
struct UnitUpgradeBonusData: Codable {
    let attackBonus: Double
    let armorBonus: Double
    let hpBonus: Double
}

// MARK: - Unit Upgrade Type

/// 27 upgrade types: 9 unit types x 3 tiers
/// Each tier provides cumulative flat bonuses to attack, armor, and HP
enum UnitUpgradeType: String, CaseIterable {

    // Swordsman
    case swordsmanTier1 = "swordsman_t1"
    case swordsmanTier2 = "swordsman_t2"
    case swordsmanTier3 = "swordsman_t3"

    // Archer
    case archerTier1 = "archer_t1"
    case archerTier2 = "archer_t2"
    case archerTier3 = "archer_t3"

    // Crossbow
    case crossbowTier1 = "crossbow_t1"
    case crossbowTier2 = "crossbow_t2"
    case crossbowTier3 = "crossbow_t3"

    // Pikeman
    case pikemanTier1 = "pikeman_t1"
    case pikemanTier2 = "pikeman_t2"
    case pikemanTier3 = "pikeman_t3"

    // Scout
    case scoutTier1 = "scout_t1"
    case scoutTier2 = "scout_t2"
    case scoutTier3 = "scout_t3"

    // Knight
    case knightTier1 = "knight_t1"
    case knightTier2 = "knight_t2"
    case knightTier3 = "knight_t3"

    // Heavy Cavalry
    case heavyCavalryTier1 = "heavyCavalry_t1"
    case heavyCavalryTier2 = "heavyCavalry_t2"
    case heavyCavalryTier3 = "heavyCavalry_t3"

    // Mangonel
    case mangonelTier1 = "mangonel_t1"
    case mangonelTier2 = "mangonel_t2"
    case mangonelTier3 = "mangonel_t3"

    // Trebuchet
    case trebuchetTier1 = "trebuchet_t1"
    case trebuchetTier2 = "trebuchet_t2"
    case trebuchetTier3 = "trebuchet_t3"

    // MARK: - Properties

    var unitType: MilitaryUnitTypeData {
        switch self {
        case .swordsmanTier1, .swordsmanTier2, .swordsmanTier3: return .swordsman
        case .archerTier1, .archerTier2, .archerTier3: return .archer
        case .crossbowTier1, .crossbowTier2, .crossbowTier3: return .crossbow
        case .pikemanTier1, .pikemanTier2, .pikemanTier3: return .pikeman
        case .scoutTier1, .scoutTier2, .scoutTier3: return .scout
        case .knightTier1, .knightTier2, .knightTier3: return .knight
        case .heavyCavalryTier1, .heavyCavalryTier2, .heavyCavalryTier3: return .heavyCavalry
        case .mangonelTier1, .mangonelTier2, .mangonelTier3: return .mangonel
        case .trebuchetTier1, .trebuchetTier2, .trebuchetTier3: return .trebuchet
        }
    }

    var tier: Int {
        switch self {
        case .swordsmanTier1, .archerTier1, .crossbowTier1, .pikemanTier1,
             .scoutTier1, .knightTier1, .heavyCavalryTier1, .mangonelTier1, .trebuchetTier1:
            return 1
        case .swordsmanTier2, .archerTier2, .crossbowTier2, .pikemanTier2,
             .scoutTier2, .knightTier2, .heavyCavalryTier2, .mangonelTier2, .trebuchetTier2:
            return 2
        case .swordsmanTier3, .archerTier3, .crossbowTier3, .pikemanTier3,
             .scoutTier3, .knightTier3, .heavyCavalryTier3, .mangonelTier3, .trebuchetTier3:
            return 3
        }
    }

    var requiredBuildingLevel: Int {
        switch tier {
        case 1: return GameConfig.UnitUpgrade.tier1BuildingLevel
        case 2: return GameConfig.UnitUpgrade.tier2BuildingLevel
        case 3: return GameConfig.UnitUpgrade.tier3BuildingLevel
        default: return 1
        }
    }

    var requiredBuildingType: BuildingType {
        return unitType.trainingBuilding
    }

    var displayName: String {
        return "\(unitType.displayName) Upgrade \(tier)"
    }

    var icon: String {
        return unitType.icon
    }

    var upgradeDescription: String {
        let b = bonuses
        return "+\(String(format: "%.1f", b.attackBonus)) ATK, +\(String(format: "%.1f", b.armorBonus)) ARM, +\(String(format: "%.0f", b.hpBonus)) HP"
    }

    var upgradeTime: TimeInterval {
        switch tier {
        case 1: return GameConfig.UnitUpgrade.tier1Time
        case 2: return GameConfig.UnitUpgrade.tier2Time
        case 3: return GameConfig.UnitUpgrade.tier3Time
        default: return 20.0
        }
    }

    var cost: [ResourceTypeData: Int] {
        let trainingCost = unitType.trainingCost
        let multiplier: Double
        switch tier {
        case 1: multiplier = GameConfig.UnitUpgrade.tier1CostMultiplier
        case 2: multiplier = GameConfig.UnitUpgrade.tier2CostMultiplier
        case 3: multiplier = GameConfig.UnitUpgrade.tier3CostMultiplier
        default: multiplier = 2.0
        }
        var result: [ResourceTypeData: Int] = [:]
        for (resource, amount) in trainingCost {
            result[resource] = Int(Double(amount) * multiplier)
        }
        return result
    }

    var bonuses: UnitUpgradeBonusData {
        switch tier {
        case 1: return UnitUpgradeBonusData(
            attackBonus: GameConfig.UnitUpgrade.tier1AttackBonus,
            armorBonus: GameConfig.UnitUpgrade.tier1ArmorBonus,
            hpBonus: GameConfig.UnitUpgrade.tier1HPBonus)
        case 2: return UnitUpgradeBonusData(
            attackBonus: GameConfig.UnitUpgrade.tier2AttackBonus,
            armorBonus: GameConfig.UnitUpgrade.tier2ArmorBonus,
            hpBonus: GameConfig.UnitUpgrade.tier2HPBonus)
        case 3: return UnitUpgradeBonusData(
            attackBonus: GameConfig.UnitUpgrade.tier3AttackBonus,
            armorBonus: GameConfig.UnitUpgrade.tier3ArmorBonus,
            hpBonus: GameConfig.UnitUpgrade.tier3HPBonus)
        default: return UnitUpgradeBonusData(attackBonus: 0, armorBonus: 0, hpBonus: 0)
        }
    }

    var prerequisite: UnitUpgradeType? {
        switch tier {
        case 1: return nil
        case 2:
            return UnitUpgradeType.allCases.first { $0.unitType == self.unitType && $0.tier == 1 }
        case 3:
            return UnitUpgradeType.allCases.first { $0.unitType == self.unitType && $0.tier == 2 }
        default: return nil
        }
    }

    // MARK: - Static Helpers

    /// Returns all upgrade types available from a specific building type
    static func upgradesForBuilding(_ buildingType: BuildingType) -> [UnitUpgradeType] {
        return allCases.filter { $0.requiredBuildingType == buildingType }
    }

    /// Returns all upgrade tiers for a specific unit type
    static func upgradesForUnit(_ unitType: MilitaryUnitTypeData) -> [UnitUpgradeType] {
        return allCases.filter { $0.unitType == unitType }
    }

    /// Returns the current completed tier for a unit type given completed upgrades
    static func currentTier(for unitType: MilitaryUnitTypeData, completedUpgrades: Set<String>) -> Int {
        let upgrades = upgradesForUnit(unitType).sorted { $0.tier < $1.tier }
        var highestTier = 0
        for upgrade in upgrades {
            if completedUpgrades.contains(upgrade.rawValue) {
                highestTier = upgrade.tier
            } else {
                break
            }
        }
        return highestTier
    }

    /// Returns the cumulative bonuses for a unit type based on completed upgrades
    static func cumulativeBonuses(for unitType: MilitaryUnitTypeData, completedUpgrades: Set<String>) -> UnitUpgradeBonusData {
        var totalAttack = 0.0
        var totalArmor = 0.0
        var totalHP = 0.0

        for upgrade in upgradesForUnit(unitType) {
            if completedUpgrades.contains(upgrade.rawValue) {
                let b = upgrade.bonuses
                totalAttack += b.attackBonus
                totalArmor += b.armorBonus
                totalHP += b.hpBonus
            }
        }

        return UnitUpgradeBonusData(attackBonus: totalAttack, armorBonus: totalArmor, hpBonus: totalHP)
    }
}
