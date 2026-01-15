// ============================================================================
// FILE: ResearchType.swift
// LOCATION: Grow2 Shared/ResearchType.swift (new file)
// ============================================================================

import Foundation

// MARK: - Research Category

enum ResearchCategory: String, CaseIterable {
    case economy = "Economy"
    case military = "Military"
    case building = "Building"
    case technology = "Technology"
    
    var displayName: String {
        return rawValue
    }
    
    var icon: String {
        switch self {
        case .economy: return "💰"
        case .military: return "⚔️"
        case .building: return "🏗️"
        case .technology: return "🔬"
        }
    }
}

// MARK: - Research Bonus Type
enum ResearchBonusType: String, Codable {
    case woodGatheringRate       // Multiplier for wood gathering
    case foodGatheringRate       // Multiplier for food gathering
    case stoneGatheringRate      // Multiplier for stone gathering
    case oreGatheringRate        // Multiplier for ore gathering
    case buildingSpeed           // Multiplier for construction speed
    case trainingSpeed           // Multiplier for unit training speed
    case unitAttack              // Multiplier for military unit attack
    case unitDefense             // Multiplier for military unit defense
    case populationCapacity      // Flat bonus to population capacity
    case villagerCarryCapacity   // Multiplier for villager efficiency
    
    var displayName: String {
        switch self {
        case .woodGatheringRate: return "Wood Gathering"
        case .foodGatheringRate: return "Food Gathering"
        case .stoneGatheringRate: return "Stone Gathering"
        case .oreGatheringRate: return "Ore Gathering"
        case .buildingSpeed: return "Building Speed"
        case .trainingSpeed: return "Training Speed"
        case .unitAttack: return "Unit Attack"
        case .unitDefense: return "Unit Defense"
        case .populationCapacity: return "Population Capacity"
        case .villagerCarryCapacity: return "Villager Efficiency"
        }
    }
}

// MARK: - Research Bonus

struct ResearchBonus: Codable {
    let type: ResearchBonusType
    let value: Double  // Percentage bonus (0.05 = 5%)
    
    var displayString: String {
        let percentage = Int(value * 100)
        return "+\(percentage)% \(type.displayName)"
    }
}

// MARK: - Research Type

enum ResearchType: String, CaseIterable, Codable {
    // Economy - Tier 1
    case axeSharpening = "axe_sharpening"
    
    // Future research (placeholders for the tree structure)
    // case improvedAxes = "improved_axes"         // Requires axeSharpening
    // case lumberMill = "lumber_mill"             // Requires improvedAxes
    // case betterHoes = "better_hoes"             // Food gathering
    // case stoneMasonry = "stone_masonry"         // Stone gathering
    // case ironPickaxes = "iron_pickaxes"         // Ore gathering
    
    var displayName: String {
        switch self {
        case .axeSharpening: return "Axe Sharpening"
        }
    }
    
    var icon: String {
        switch self {
        case .axeSharpening: return "🪓"
        }
    }
    
    var description: String {
        switch self {
        case .axeSharpening: 
            return "Sharpen your villagers' axes to improve wood gathering efficiency."
        }
    }
    
    var category: ResearchCategory {
        switch self {
        case .axeSharpening: return .economy
        }
    }
    
    // Research time in seconds
    var researchTime: TimeInterval {
        switch self {
        case .axeSharpening: return 30.0  // 30 seconds
        }
    }
    
    // Resource costs
    var cost: [ResourceType: Int] {
        switch self {
        case .axeSharpening: 
            return [
                .wood: 50,
                .stone: 30,
                .food: 20
            ]
        }
    }
    
    // Bonuses granted when research is completed
    var bonuses: [ResearchBonus] {
        switch self {
        case .axeSharpening:
            return [ResearchBonus(type: .woodGatheringRate, value: 0.05)]  // +5% wood gathering
        }
    }
    
    // Prerequisites - other research that must be completed first
    var prerequisites: [ResearchType] {
        switch self {
        case .axeSharpening: return []  // No prerequisites
        }
    }
    
    // Building requirement - building type and level required
    var buildingRequirement: (buildingType: BuildingType, level: Int)? {
        switch self {
        case .axeSharpening: return nil  // No building requirement for now
        }
    }
    
    // Tier in the research tree (for UI layout)
    var tier: Int {
        switch self {
        case .axeSharpening: return 1
        }
    }
    
    // Format cost as string for display
    var costString: String {
        cost.map { "\($0.key.icon)\($0.value)" }.joined(separator: " ")
    }
    
    // Format time as string for display
    var timeString: String {
        let minutes = Int(researchTime) / 60
        let seconds = Int(researchTime) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    // Format bonuses as string for display
    var bonusString: String {
        bonuses.map { $0.displayString }.joined(separator: "\n")
    }
}

// MARK: - Active Research Entry

struct ActiveResearch: Codable {
    let researchType: ResearchType
    let startTime: TimeInterval
    
    init(researchType: ResearchType) {
        self.researchType = researchType
        self.startTime = Date().timeIntervalSince1970
    }
    
    init(researchType: ResearchType, startTime: TimeInterval) {
        self.researchType = researchType
        self.startTime = startTime
    }
    
    func getProgress(currentTime: TimeInterval = Date().timeIntervalSince1970) -> Double {
        let elapsed = currentTime - startTime
        return min(1.0, max(0.0, elapsed / researchType.researchTime))
    }
    
    func getRemainingTime(currentTime: TimeInterval = Date().timeIntervalSince1970) -> TimeInterval {
        let elapsed = currentTime - startTime
        return max(0, researchType.researchTime - elapsed)
    }
    
    func isComplete(currentTime: TimeInterval = Date().timeIntervalSince1970) -> Bool {
        return getProgress(currentTime: currentTime) >= 1.0
    }
}
