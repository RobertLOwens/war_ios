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
    }

    // MARK: - Construction

    enum Construction {
        static let progressChangeThreshold: Double = 0.01  // Min progress to emit event
    }

    // MARK: - Training

    enum Training {
        static let villagerTrainingTime: TimeInterval = 10.0  // Seconds per villager
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
            .wall: 1,
            .gate: 2,
            .road: 1
        ]
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
