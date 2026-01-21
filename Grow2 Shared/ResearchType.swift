// ============================================================================
// FILE: ResearchType.swift
// LOCATION: Grow2 Shared/ResearchType.swift (new file)
// ============================================================================

import Foundation

// MARK: - Research Category

enum ResearchCategory: String, CaseIterable, Codable {
    case economic = "Economic"
    case military = "Military"

    var displayName: String {
        return rawValue
    }

    var icon: String {
        switch self {
        case .economic: return "💰"
        case .military: return "⚔️"
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
    case marketRate              // Better market exchange rates
    case villagerMarchSpeed      // Villager movement speed
    case tradeSpeed              // Trade cart/route speed
    case roadSpeed               // Speed bonus from roads
    case foodConsumption         // Reduced food consumption per villager
    case farmGatheringRate       // Farm gathering rate
    case miningCampGatheringRate // Mining camp gathering rate
    case lumberCampGatheringRate // Lumber camp gathering rate

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
        case .marketRate: return "Market Rates"
        case .villagerMarchSpeed: return "Villager Speed"
        case .tradeSpeed: return "Trade Speed"
        case .roadSpeed: return "Road Speed"
        case .foodConsumption: return "Food Consumption"
        case .farmGatheringRate: return "Farm Gathering"
        case .miningCampGatheringRate: return "Mining Camp Gathering"
        case .lumberCampGatheringRate: return "Lumber Camp Gathering"
        }
    }
}

// MARK: - Research Bonus

struct ResearchBonus: Codable {
    let type: ResearchBonusType
    let value: Double  // Percentage bonus (0.05 = 5%), or flat value for populationCapacity

    var displayString: String {
        // Handle flat bonuses (like population capacity)
        if type == .populationCapacity {
            let flatValue = Int(value)
            return "+\(flatValue) \(type.displayName)"
        }

        // Handle percentage bonuses
        let percentage = Int(value * 100)
        if percentage < 0 {
            return "\(percentage)% \(type.displayName)"  // Negative already has minus sign
        }
        return "+\(percentage)% \(type.displayName)"
    }
}

// MARK: - Research Type

enum ResearchType: String, CaseIterable, Codable {
    // ========================================
    // ECONOMIC BRANCH
    // ========================================

    // --- Gathering: Farm ---
    case farmGatheringI = "farm_gathering_1"
    case farmGatheringII = "farm_gathering_2"
    case farmGatheringIII = "farm_gathering_3"

    // --- Gathering: Mining Camp ---
    case miningCampGatheringI = "mining_camp_gathering_1"
    case miningCampGatheringII = "mining_camp_gathering_2"
    case miningCampGatheringIII = "mining_camp_gathering_3"

    // --- Gathering: Lumber Camp ---
    case lumberCampGatheringI = "lumber_camp_gathering_1"
    case lumberCampGatheringII = "lumber_camp_gathering_2"
    case lumberCampGatheringIII = "lumber_camp_gathering_3"

    // --- Market ---
    case betterMarketRatesI = "better_market_rates_1"
    case betterMarketRatesII = "better_market_rates_2"
    case betterMarketRatesIII = "better_market_rates_3"

    // --- Villager Speed ---
    case villagerSpeedI = "villager_speed_1"
    case villagerSpeedII = "villager_speed_2"
    case villagerSpeedIII = "villager_speed_3"

    // --- Trade Speed ---
    case tradeSpeedI = "trade_speed_1"
    case tradeSpeedII = "trade_speed_2"
    case tradeSpeedIII = "trade_speed_3"

    // --- Roads ---
    case improvedRoadsI = "improved_roads_1"
    case improvedRoadsII = "improved_roads_2"
    case improvedRoadsIII = "improved_roads_3"

    // --- Population Capacity ---
    case populationCapacityI = "population_capacity_1"
    case populationCapacityII = "population_capacity_2"
    case populationCapacityIII = "population_capacity_3"

    // --- Food Consumption ---
    case efficientRationsI = "efficient_rations_1"
    case efficientRationsII = "efficient_rations_2"
    case efficientRationsIII = "efficient_rations_3"

    // --- Building Speed ---
    case buildingSpeedI = "building_speed_1"
    case buildingSpeedII = "building_speed_2"
    case buildingSpeedIII = "building_speed_3"

    // ========================================
    // MILITARY BRANCH (Empty for now)
    // ========================================
    // Future military research will go here

    // MARK: - Display Name
    var displayName: String {
        switch self {
        // Farm Gathering
        case .farmGatheringI: return "Farm Efficiency I"
        case .farmGatheringII: return "Farm Efficiency II"
        case .farmGatheringIII: return "Farm Efficiency III"
        // Mining Camp
        case .miningCampGatheringI: return "Mining Efficiency I"
        case .miningCampGatheringII: return "Mining Efficiency II"
        case .miningCampGatheringIII: return "Mining Efficiency III"
        // Lumber Camp
        case .lumberCampGatheringI: return "Lumber Efficiency I"
        case .lumberCampGatheringII: return "Lumber Efficiency II"
        case .lumberCampGatheringIII: return "Lumber Efficiency III"
        // Market Rates
        case .betterMarketRatesI: return "Better Market Rates I"
        case .betterMarketRatesII: return "Better Market Rates II"
        case .betterMarketRatesIII: return "Better Market Rates III"
        // Villager Speed
        case .villagerSpeedI: return "Swift Villagers I"
        case .villagerSpeedII: return "Swift Villagers II"
        case .villagerSpeedIII: return "Swift Villagers III"
        // Trade Speed
        case .tradeSpeedI: return "Trade Routes I"
        case .tradeSpeedII: return "Trade Routes II"
        case .tradeSpeedIII: return "Trade Routes III"
        // Roads
        case .improvedRoadsI: return "Improved Roads I"
        case .improvedRoadsII: return "Improved Roads II"
        case .improvedRoadsIII: return "Improved Roads III"
        // Population
        case .populationCapacityI: return "Urban Planning I"
        case .populationCapacityII: return "Urban Planning II"
        case .populationCapacityIII: return "Urban Planning III"
        // Food Consumption
        case .efficientRationsI: return "Efficient Rations I"
        case .efficientRationsII: return "Efficient Rations II"
        case .efficientRationsIII: return "Efficient Rations III"
        // Building Speed
        case .buildingSpeedI: return "Construction I"
        case .buildingSpeedII: return "Construction II"
        case .buildingSpeedIII: return "Construction III"
        }
    }

    // MARK: - Icon
    var icon: String {
        switch self {
        case .farmGatheringI, .farmGatheringII, .farmGatheringIII: return "🌾"
        case .miningCampGatheringI, .miningCampGatheringII, .miningCampGatheringIII: return "⛏️"
        case .lumberCampGatheringI, .lumberCampGatheringII, .lumberCampGatheringIII: return "🪓"
        case .betterMarketRatesI, .betterMarketRatesII, .betterMarketRatesIII: return "💱"
        case .villagerSpeedI, .villagerSpeedII, .villagerSpeedIII: return "🏃"
        case .tradeSpeedI, .tradeSpeedII, .tradeSpeedIII: return "🛒"
        case .improvedRoadsI, .improvedRoadsII, .improvedRoadsIII: return "🛤️"
        case .populationCapacityI, .populationCapacityII, .populationCapacityIII: return "🏘️"
        case .efficientRationsI, .efficientRationsII, .efficientRationsIII: return "🍽️"
        case .buildingSpeedI, .buildingSpeedII, .buildingSpeedIII: return "🏗️"
        }
    }

    // MARK: - Description
    var description: String {
        switch self {
        case .farmGatheringI: return "Improve farming techniques to increase food yield from farms."
        case .farmGatheringII: return "Advanced farming methods further increase farm efficiency."
        case .farmGatheringIII: return "Master farming techniques for maximum farm output."
        case .miningCampGatheringI: return "Better mining tools increase stone and ore yield."
        case .miningCampGatheringII: return "Advanced mining techniques improve extraction rates."
        case .miningCampGatheringIII: return "Master mining operations for peak efficiency."
        case .lumberCampGatheringI: return "Sharpen axes and improve logging techniques."
        case .lumberCampGatheringII: return "Advanced woodcutting methods increase lumber yield."
        case .lumberCampGatheringIII: return "Master lumberjack skills for maximum wood production."
        case .betterMarketRatesI: return "Negotiate better trade deals at the market."
        case .betterMarketRatesII: return "Establish trade networks for improved rates."
        case .betterMarketRatesIII: return "Dominate local markets with the best exchange rates."
        case .villagerSpeedI: return "Train villagers to move faster between tasks."
        case .villagerSpeedII: return "Improved stamina allows villagers to maintain pace."
        case .villagerSpeedIII: return "Elite training makes villagers swift and efficient."
        case .tradeSpeedI: return "Optimize trade routes for faster delivery."
        case .tradeSpeedII: return "Better carts and paths speed up trade."
        case .tradeSpeedIII: return "Master logistics for lightning-fast trades."
        case .improvedRoadsI: return "Pave roads for smoother, faster travel."
        case .improvedRoadsII: return "Advanced road construction improves travel speed."
        case .improvedRoadsIII: return "Build highways for maximum movement speed."
        case .populationCapacityI: return "Better housing designs increase neighborhood capacity."
        case .populationCapacityII: return "Urban planning allows denser populations."
        case .populationCapacityIII: return "Master architecture maximizes living space."
        case .efficientRationsI: return "Better food storage reduces spoilage and consumption."
        case .efficientRationsII: return "Improved nutrition means villagers eat less."
        case .efficientRationsIII: return "Optimal meal planning minimizes food requirements."
        case .buildingSpeedI: return "Improve construction techniques for faster building."
        case .buildingSpeedII: return "Advanced tools speed up construction."
        case .buildingSpeedIII: return "Master builders construct at incredible speed."
        }
    }

    // MARK: - Category
    var category: ResearchCategory {
        // All current research is economic
        return .economic
    }

    // MARK: - Research Time (in seconds)
    var researchTime: TimeInterval {
        switch self {
        // Tier I - 30 seconds
        case .farmGatheringI, .miningCampGatheringI, .lumberCampGatheringI,
             .betterMarketRatesI, .villagerSpeedI, .tradeSpeedI,
             .improvedRoadsI, .populationCapacityI, .efficientRationsI, .buildingSpeedI:
            return 30.0
        // Tier II - 60 seconds
        case .farmGatheringII, .miningCampGatheringII, .lumberCampGatheringII,
             .betterMarketRatesII, .villagerSpeedII, .tradeSpeedII,
             .improvedRoadsII, .populationCapacityII, .efficientRationsII, .buildingSpeedII:
            return 60.0
        // Tier III - 120 seconds
        case .farmGatheringIII, .miningCampGatheringIII, .lumberCampGatheringIII,
             .betterMarketRatesIII, .villagerSpeedIII, .tradeSpeedIII,
             .improvedRoadsIII, .populationCapacityIII, .efficientRationsIII, .buildingSpeedIII:
            return 120.0
        }
    }

    // MARK: - Resource Costs
    var cost: [ResourceType: Int] {
        switch self {
        // Tier I costs
        case .farmGatheringI: return [.wood: 50, .food: 30]
        case .miningCampGatheringI: return [.wood: 50, .food: 30]
        case .lumberCampGatheringI: return [.stone: 40, .food: 30]
        case .betterMarketRatesI: return [.wood: 40, .stone: 40, .food: 20]
        case .villagerSpeedI: return [.food: 60, .wood: 20]
        case .tradeSpeedI: return [.wood: 50, .stone: 30]
        case .improvedRoadsI: return [.stone: 60, .wood: 30]
        case .populationCapacityI: return [.wood: 50, .stone: 30]
        case .efficientRationsI: return [.food: 80, .wood: 20]
        case .buildingSpeedI: return [.wood: 40, .stone: 40]

        // Tier II costs
        case .farmGatheringII: return [.wood: 100, .food: 60, .stone: 30]
        case .miningCampGatheringII: return [.wood: 100, .food: 60, .stone: 30]
        case .lumberCampGatheringII: return [.stone: 80, .food: 60, .wood: 30]
        case .betterMarketRatesII: return [.wood: 80, .stone: 80, .food: 40]
        case .villagerSpeedII: return [.food: 120, .wood: 40, .stone: 20]
        case .tradeSpeedII: return [.wood: 100, .stone: 60, .food: 30]
        case .improvedRoadsII: return [.stone: 120, .wood: 60, .food: 30]
        case .populationCapacityII: return [.wood: 100, .stone: 60, .food: 30]
        case .efficientRationsII: return [.food: 160, .wood: 40, .stone: 20]
        case .buildingSpeedII: return [.wood: 80, .stone: 80, .food: 30]

        // Tier III costs
        case .farmGatheringIII: return [.wood: 200, .food: 120, .stone: 60, .ore: 30]
        case .miningCampGatheringIII: return [.wood: 200, .food: 120, .stone: 60, .ore: 30]
        case .lumberCampGatheringIII: return [.stone: 160, .food: 120, .wood: 60, .ore: 30]
        case .betterMarketRatesIII: return [.wood: 160, .stone: 160, .food: 80, .ore: 40]
        case .villagerSpeedIII: return [.food: 240, .wood: 80, .stone: 40, .ore: 20]
        case .tradeSpeedIII: return [.wood: 200, .stone: 120, .food: 60, .ore: 30]
        case .improvedRoadsIII: return [.stone: 240, .wood: 120, .food: 60, .ore: 40]
        case .populationCapacityIII: return [.wood: 200, .stone: 120, .food: 60, .ore: 30]
        case .efficientRationsIII: return [.food: 320, .wood: 80, .stone: 40, .ore: 20]
        case .buildingSpeedIII: return [.wood: 160, .stone: 160, .food: 60, .ore: 40]
        }
    }

    // MARK: - Bonuses
    var bonuses: [ResearchBonus] {
        switch self {
        // Farm Gathering: +10%, +15%, +20%
        case .farmGatheringI: return [ResearchBonus(type: .farmGatheringRate, value: 0.10)]
        case .farmGatheringII: return [ResearchBonus(type: .farmGatheringRate, value: 0.15)]
        case .farmGatheringIII: return [ResearchBonus(type: .farmGatheringRate, value: 0.20)]

        // Mining Camp: +10%, +15%, +20%
        case .miningCampGatheringI: return [ResearchBonus(type: .miningCampGatheringRate, value: 0.10)]
        case .miningCampGatheringII: return [ResearchBonus(type: .miningCampGatheringRate, value: 0.15)]
        case .miningCampGatheringIII: return [ResearchBonus(type: .miningCampGatheringRate, value: 0.20)]

        // Lumber Camp: +10%, +15%, +20%
        case .lumberCampGatheringI: return [ResearchBonus(type: .lumberCampGatheringRate, value: 0.10)]
        case .lumberCampGatheringII: return [ResearchBonus(type: .lumberCampGatheringRate, value: 0.15)]
        case .lumberCampGatheringIII: return [ResearchBonus(type: .lumberCampGatheringRate, value: 0.20)]

        // Market Rates: +5%, +10%, +15%
        case .betterMarketRatesI: return [ResearchBonus(type: .marketRate, value: 0.05)]
        case .betterMarketRatesII: return [ResearchBonus(type: .marketRate, value: 0.10)]
        case .betterMarketRatesIII: return [ResearchBonus(type: .marketRate, value: 0.15)]

        // Villager Speed: +10%, +15%, +20%
        case .villagerSpeedI: return [ResearchBonus(type: .villagerMarchSpeed, value: 0.10)]
        case .villagerSpeedII: return [ResearchBonus(type: .villagerMarchSpeed, value: 0.15)]
        case .villagerSpeedIII: return [ResearchBonus(type: .villagerMarchSpeed, value: 0.20)]

        // Trade Speed: +10%, +15%, +20%
        case .tradeSpeedI: return [ResearchBonus(type: .tradeSpeed, value: 0.10)]
        case .tradeSpeedII: return [ResearchBonus(type: .tradeSpeed, value: 0.15)]
        case .tradeSpeedIII: return [ResearchBonus(type: .tradeSpeed, value: 0.20)]

        // Roads: +10%, +15%, +20%
        case .improvedRoadsI: return [ResearchBonus(type: .roadSpeed, value: 0.10)]
        case .improvedRoadsII: return [ResearchBonus(type: .roadSpeed, value: 0.15)]
        case .improvedRoadsIII: return [ResearchBonus(type: .roadSpeed, value: 0.20)]

        // Population: +5, +10, +15 (flat bonus)
        case .populationCapacityI: return [ResearchBonus(type: .populationCapacity, value: 5.0)]
        case .populationCapacityII: return [ResearchBonus(type: .populationCapacity, value: 10.0)]
        case .populationCapacityIII: return [ResearchBonus(type: .populationCapacity, value: 15.0)]

        // Food Consumption: -5%, -10%, -15% (negative = reduction)
        case .efficientRationsI: return [ResearchBonus(type: .foodConsumption, value: -0.05)]
        case .efficientRationsII: return [ResearchBonus(type: .foodConsumption, value: -0.10)]
        case .efficientRationsIII: return [ResearchBonus(type: .foodConsumption, value: -0.15)]

        // Building Speed: +10%, +15%, +20%
        case .buildingSpeedI: return [ResearchBonus(type: .buildingSpeed, value: 0.10)]
        case .buildingSpeedII: return [ResearchBonus(type: .buildingSpeed, value: 0.15)]
        case .buildingSpeedIII: return [ResearchBonus(type: .buildingSpeed, value: 0.20)]
        }
    }

    // MARK: - Prerequisites (other research required first)
    var prerequisites: [ResearchType] {
        switch self {
        // Tier I - no prerequisites
        case .farmGatheringI, .miningCampGatheringI, .lumberCampGatheringI,
             .betterMarketRatesI, .villagerSpeedI, .tradeSpeedI,
             .improvedRoadsI, .populationCapacityI, .efficientRationsI, .buildingSpeedI:
            return []

        // Tier II - requires Tier I of same type
        case .farmGatheringII: return [.farmGatheringI]
        case .miningCampGatheringII: return [.miningCampGatheringI]
        case .lumberCampGatheringII: return [.lumberCampGatheringI]
        case .betterMarketRatesII: return [.betterMarketRatesI]
        case .villagerSpeedII: return [.villagerSpeedI]
        case .tradeSpeedII: return [.tradeSpeedI, .improvedRoadsI]  // Trade needs roads
        case .improvedRoadsII: return [.improvedRoadsI]
        case .populationCapacityII: return [.populationCapacityI]
        case .efficientRationsII: return [.efficientRationsI]
        case .buildingSpeedII: return [.buildingSpeedI]

        // Tier III - requires Tier II of same type
        case .farmGatheringIII: return [.farmGatheringII]
        case .miningCampGatheringIII: return [.miningCampGatheringII]
        case .lumberCampGatheringIII: return [.lumberCampGatheringII]
        case .betterMarketRatesIII: return [.betterMarketRatesII]
        case .villagerSpeedIII: return [.villagerSpeedII]
        case .tradeSpeedIII: return [.tradeSpeedII, .improvedRoadsII]  // Trade needs roads
        case .improvedRoadsIII: return [.improvedRoadsII]
        case .populationCapacityIII: return [.populationCapacityII, .efficientRationsI]  // Need some rations research
        case .efficientRationsIII: return [.efficientRationsII]
        case .buildingSpeedIII: return [.buildingSpeedII]
        }
    }

    // MARK: - City Center Level Requirement
    var cityCenterLevelRequirement: Int {
        switch self {
        // Tier I - City Center level 1
        case .farmGatheringI, .miningCampGatheringI, .lumberCampGatheringI,
             .betterMarketRatesI, .villagerSpeedI, .tradeSpeedI,
             .improvedRoadsI, .populationCapacityI, .efficientRationsI, .buildingSpeedI:
            return 1

        // Tier II - City Center level 2
        case .farmGatheringII, .miningCampGatheringII, .lumberCampGatheringII,
             .betterMarketRatesII, .villagerSpeedII, .tradeSpeedII,
             .improvedRoadsII, .populationCapacityII, .efficientRationsII, .buildingSpeedII:
            return 2

        // Tier III - City Center level 3
        case .farmGatheringIII, .miningCampGatheringIII, .lumberCampGatheringIII,
             .betterMarketRatesIII, .villagerSpeedIII, .tradeSpeedIII,
             .improvedRoadsIII, .populationCapacityIII, .efficientRationsIII, .buildingSpeedIII:
            return 3
        }
    }

    // MARK: - Building Requirement (legacy, kept for compatibility)
    var buildingRequirement: (buildingType: BuildingType, level: Int)? {
        // We now use cityCenterLevelRequirement instead
        return nil
    }

    // MARK: - Tier (for UI layout)
    var tier: Int {
        switch self {
        case .farmGatheringI, .miningCampGatheringI, .lumberCampGatheringI,
             .betterMarketRatesI, .villagerSpeedI, .tradeSpeedI,
             .improvedRoadsI, .populationCapacityI, .efficientRationsI, .buildingSpeedI:
            return 1
        case .farmGatheringII, .miningCampGatheringII, .lumberCampGatheringII,
             .betterMarketRatesII, .villagerSpeedII, .tradeSpeedII,
             .improvedRoadsII, .populationCapacityII, .efficientRationsII, .buildingSpeedII:
            return 2
        case .farmGatheringIII, .miningCampGatheringIII, .lumberCampGatheringIII,
             .betterMarketRatesIII, .villagerSpeedIII, .tradeSpeedIII,
             .improvedRoadsIII, .populationCapacityIII, .efficientRationsIII, .buildingSpeedIII:
            return 3
        }
    }

    // MARK: - Format Helpers

    var costString: String {
        cost.map { "\($0.key.icon)\($0.value)" }.joined(separator: " ")
    }

    var timeString: String {
        let minutes = Int(researchTime) / 60
        let seconds = Int(researchTime) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }

    var bonusString: String {
        bonuses.map { $0.displayString }.joined(separator: "\n")
    }

    var prerequisitesString: String {
        if prerequisites.isEmpty {
            return "None"
        }
        return prerequisites.map { $0.displayName }.joined(separator: ", ")
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
