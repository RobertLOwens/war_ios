// ============================================================================
// FILE: Grow2 Shared/MilitaryUnit.swift
// PURPOSE: Military unit related types
// NOTE: This file now serves as backward-compatibility layer
// ============================================================================

import Foundation

// MARK: - Type Aliases for Backward Compatibility

/// Alias for backward compatibility - use MilitaryUnitTypeData directly in new code
typealias MilitaryUnitType = MilitaryUnitTypeData

/// Alias for backward compatibility - use UnitCategoryData directly in new code
typealias UnitCategory = UnitCategoryData

/// Alias for backward compatibility - use UnitCombatStatsData directly in new code
typealias UnitCombatStats = UnitCombatStatsData

/// Alias for backward compatibility - use TrainingQueueEntryData directly in new code
typealias TrainingQueueEntry = TrainingQueueEntryData

/// Alias for backward compatibility - use VillagerTrainingEntryData directly in new code
typealias VillagerTrainingEntry = VillagerTrainingEntryData

// MARK: - Damage Type

/// Damage types for combat calculations
enum DamageType: String, CaseIterable, Codable {
    case melee, pierce, bludgeon
}

// MARK: - Trainable Unit Type

/// Unified type for both military units and villagers in training queues
enum TrainableUnitType: Codable {
    case military(MilitaryUnitTypeData)
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

    var trainingCost: [ResourceTypeData: Int] {
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

    var popSpace: Int {
        switch self {
        case .military(let type):
            return type.popSpace
        case .villager:
            return 1
        }
    }
}

// MARK: - Research Manager Integration

extension TrainingQueueEntryData {
    /// Get progress with research bonus applied
    func getProgress(currentTime: TimeInterval) -> Double {
        let trainingSpeedMultiplier = ResearchManager.shared.getMilitaryTrainingSpeedMultiplier()
        return getProgress(currentTime: currentTime, trainingSpeedMultiplier: trainingSpeedMultiplier)
    }
}
