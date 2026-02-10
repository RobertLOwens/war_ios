// ============================================================================
// FILE: Grow2 Shared/Engine/GameConfig.swift
// PURPOSE: Centralized game configuration constants for easy tuning
// ============================================================================

import Foundation

/// Centralized configuration for all game constants.
/// Edit values here to tune game balance without hunting through engine files.
enum GameConfig {

    // MARK: - Engine Update Intervals

    enum EngineIntervals {
        static let tick: TimeInterval = 0.1              // 10 ticks per second
        static let visionUpdate: TimeInterval = 0.25     // 4x per second
        static let buildingUpdate: TimeInterval = 0.5    // 2x per second
        static let trainingUpdate: TimeInterval = 1.0    // 1x per second
        static let combatUpdate: TimeInterval = 1.0      // 1x per second
        static let resourceUpdate: TimeInterval = 0.5    // 2x per second
        static let movementUpdate: TimeInterval = 0.1    // 10x per second
        static let aiUpdate: TimeInterval = 0.5          // AI decisions 2x per second
    }

    // MARK: - Movement

    enum Movement {
        static let baseSpeed: Double = 0.75                    // Hexes per second on roads
        static let terrainSpeedMultiplier: Double = 0.33       // Off-road speed penalty
        static let retreatSpeedBonus: Double = 1.1             // 10% faster when retreating
        static let villagerSpeedMultiplier: Double = 0.8       // Villagers move at 80%
        static let reinforcementSpeedMultiplier: Double = 0.7  // Reinforcements at 70%
    }

    // MARK: - Combat

    enum Combat {
        static let buildingPhaseInterval: TimeInterval = 1.0  // Damage tick vs buildings
        static let siegeBuildingBonusMultiplier: Double = 1.5  // Siege bonus vs buildings
        static let cavalryChargeBonus: Double = 0.2            // +20% cavalry charge damage
        static let infantryChargeBonus: Double = 0.1           // +10% infantry charge damage
    }

    // MARK: - Resource Gathering

    enum Resources {
        static let baseGatherRatePerVillager: Double = 0.2  // Resources/sec/villager
        static let adjacencyBonusPercent: Double = 0.25     // 25% adjacency bonus
        static let campLevelBonusPerLevel: Double = 0.10    // +10% gather rate per building level above 1
        static let farmWoodConsumptionRate: Double = 0.1    // Wood consumed per second per active farm gathering
    }

    // MARK: - Terrain

    enum Terrain {
        /// Cost multiplier for building/upgrading on mountain tiles (+25%)
        static let mountainBuildingCostMultiplier: Double = 1.25
    }

    // MARK: - Construction

    enum Construction {
        static let progressChangeThreshold: Double = 0.01  // Min progress to emit event
        static let diminishingFactor: Double = 0.8

        /// Calculates effective builder count with diminishing returns.
        /// 0 builders = 0 (stalled), 1 = 1.0x, 2 = 1.8x, 3 = 2.44x, etc.
        static func effectiveBuilders(count: Int) -> Double {
            guard count > 0 else { return 0.0 }
            // Geometric series: (1 - factor^count) / (1 - factor)
            return (1.0 - pow(diminishingFactor, Double(count))) / (1.0 - diminishingFactor)
        }
    }

    // MARK: - Training

    enum Training {
        static let villagerTrainingTime: TimeInterval = 10.0  // Seconds per villager
        static let buildingLevelSpeedBonusPerLevel: Double = 0.10  // +10% training speed per building level above 1
    }

    // MARK: - Vision

    enum Vision {
        static let baseUnitRange: Int = 3
        static let baseVillagerRange: Int = 2
        static let buildingRanges: [BuildingType: Int] = [
            .cityCenter: 5,
            .tower: 6,
            .castle: 5,
            .woodenFort: 4,
            .barracks: 3,
            .archeryRange: 3,
            .stable: 3,
            .siegeWorkshop: 3,
            .lumberCamp: 2,
            .miningCamp: 2,
            .farm: 1,
            .mill: 2,
            .warehouse: 2,
            .blacksmith: 2,
            .market: 2,
            .neighborhood: 2,
            .university: 3,
            .library: 3,
            .wall: 1,
            .gate: 2,
            .road: 1
        ]
    }

    // MARK: - Library

    enum Library {
        /// Research speed bonus per Library level (+10% per level, level 5 = +50%)
        static let researchSpeedBonusPerLevel: Double = 0.10
    }

    // MARK: - Defense

    enum Defense {
        /// HP bonus per building level above 1 for defensive buildings (tower, fort, castle)
        static let hpBonusPerLevel: Double = 0.20
        /// Castle: base army home base capacity
        static let castleBaseArmyCapacity: Int = 3
        /// Castle: additional army capacity per level above 1
        static let castleArmyCapacityPerLevel: Int = 1
        /// Wooden Fort: base army home base capacity
        static let fortBaseArmyCapacity: Int = 1
        /// Wooden Fort: additional army capacity per level above 1
        static let fortArmyCapacityPerLevel: Int = 1
    }

    // MARK: - Garrison Defense

    enum GarrisonDefense {
        static let archerDamage: Double = 12.0
        static let crossbowDamage: Double = 14.0
        static let mangonelDamage: Double = 18.0
        static let trebuchetDamage: Double = 25.0
    }

    // MARK: - Commander Stat Scaling

    enum Commander {
        static let leadershipToArmySizeBase: Int = 20
        static let leadershipToArmySizePerPoint: Int = 2
        static let tacticsTerrainScaling: Double = 0.01
        static let logisticsSpeedScaling: Double = 0.005
        static let rationingReductionScaling: Double = 0.005
        static let rationingReductionCap: Double = 0.5
        static let enduranceRegenScaling: Double = 0.02
    }

    // MARK: - Entrenchment

    enum Entrenchment {
        static let buildTime: TimeInterval = 10.0
        static let woodCost: Int = 100
        static let defenseBonus: Double = 0.10
        static let checkInterval: TimeInterval = 0.5
    }

    // MARK: - Entity Stacking

    enum Stacking {
        static let maxEntitiesPerTile: Int = 5
    }

    // MARK: - Stack Combat

    enum StackCombat {
        /// DPS reduction per additional front when entrenched army fights in multiple combats
        static let stretchingPenaltyPerFront: Double = 0.15
        /// Delay between chain combat engagements within a stack
        static let chainCombatDelay: TimeInterval = 0.5
    }

    // MARK: - Unit Upgrades

    enum UnitUpgrade {
        static let tier1BuildingLevel: Int = 2
        static let tier2BuildingLevel: Int = 3
        static let tier3BuildingLevel: Int = 5

        static let tier1Time: TimeInterval = 20.0
        static let tier2Time: TimeInterval = 40.0
        static let tier3Time: TimeInterval = 80.0

        static let tier1AttackBonus: Double = 0.5
        static let tier2AttackBonus: Double = 1.0
        static let tier3AttackBonus: Double = 1.5

        static let tier1ArmorBonus: Double = 0.5
        static let tier2ArmorBonus: Double = 1.0
        static let tier3ArmorBonus: Double = 1.5

        static let tier1HPBonus: Double = 5.0
        static let tier2HPBonus: Double = 10.0
        static let tier3HPBonus: Double = 15.0

        static let tier1CostMultiplier: Double = 2.0
        static let tier2CostMultiplier: Double = 4.0
        static let tier3CostMultiplier: Double = 8.0

        static let checkInterval: TimeInterval = 1.0
    }

    // MARK: - AI Decision Intervals

    enum AI {
        enum Intervals {
            static let economicBuild: TimeInterval = 2.0
            static let militaryTrain: TimeInterval = 3.0
            static let scout: TimeInterval = 30.0
            static let campBuild: TimeInterval = 5.0
            static let defenseBuild: TimeInterval = 10.0
            static let garrisonCheck: TimeInterval = 5.0
            static let researchCheck: TimeInterval = 5.0
            static let enemyAnalysis: TimeInterval = 10.0
            static let unitUpgradeCheck: TimeInterval = 10.0
            static let entrenchCheck: TimeInterval = 8.0
        }

        enum Limits {
            static let maxCampsPerType: Int = 3
            static let maxTowersPerAI: Int = 4
            static let maxFortsPerAI: Int = 2
            static let scoutRange: Int = 12
        }

        enum Thresholds {
            static let minThreatForDefenseBuilding: Double = 15.0
        }
    }
}
