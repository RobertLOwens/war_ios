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

    // Military bonuses
    case militaryMarchSpeed      // Army movement speed
    case militaryRetreatSpeed    // Retreat movement speed
    case infantryMeleeAttack     // Infantry melee damage
    case cavalryMeleeAttack      // Cavalry melee damage
    case infantryMeleeArmor      // Infantry melee armor
    case cavalryMeleeArmor       // Cavalry melee armor
    case archerMeleeArmor        // Archer/ranged melee armor
    case piercingDamage          // Archers + garrison pierce damage
    case infantryPierceArmor     // Infantry pierce armor
    case cavalryPierceArmor      // Cavalry pierce armor
    case archerPierceArmor       // Archer/ranged pierce armor
    case siegeBludgeonDamage     // Siege bludgeon damage
    case buildingBludgeonArmor   // Building bludgeon armor
    case militaryTrainingSpeed   // Military unit training speed
    case militaryFoodConsumption // Military food consumption (negative = reduction)
    case buildingHP              // Building max HP

    var isFlatBonus: Bool {
        switch self {
        case .populationCapacity,
             .infantryMeleeAttack, .cavalryMeleeAttack, .piercingDamage, .siegeBludgeonDamage,
             .infantryMeleeArmor, .cavalryMeleeArmor, .archerMeleeArmor,
             .infantryPierceArmor, .cavalryPierceArmor, .archerPierceArmor,
             .buildingBludgeonArmor:
            return true
        default:
            return false
        }
    }

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
        case .militaryMarchSpeed: return "March Speed"
        case .militaryRetreatSpeed: return "Retreat Speed"
        case .infantryMeleeAttack: return "Infantry Melee Attack"
        case .cavalryMeleeAttack: return "Cavalry Melee Attack"
        case .infantryMeleeArmor: return "Infantry Melee Armor"
        case .cavalryMeleeArmor: return "Cavalry Melee Armor"
        case .archerMeleeArmor: return "Archer Melee Armor"
        case .piercingDamage: return "Piercing Damage"
        case .infantryPierceArmor: return "Infantry Pierce Armor"
        case .cavalryPierceArmor: return "Cavalry Pierce Armor"
        case .archerPierceArmor: return "Archer Pierce Armor"
        case .siegeBludgeonDamage: return "Siege Bludgeon Damage"
        case .buildingBludgeonArmor: return "Building Bludgeon Armor"
        case .militaryTrainingSpeed: return "Military Training Speed"
        case .militaryFoodConsumption: return "Military Food Consumption"
        case .buildingHP: return "Building HP"
        }
    }
}

// MARK: - Research Bonus

struct ResearchBonus: Codable {
    let type: ResearchBonusType
    let value: Double  // Percentage bonus (0.05 = 5%), or flat value for populationCapacity

    var displayString: String {
        // Handle flat bonuses (damage, armor, population capacity)
        if type.isFlatBonus {
            let flatValue = Int(value)
            return flatValue >= 0 ? "+\(flatValue) \(type.displayName)" : "\(flatValue) \(type.displayName)"
        }

        // Handle percentage bonuses
        let percentage = Int(value * 100)
        if percentage < 0 {
            return "\(percentage)% \(type.displayName)"  // Negative already has minus sign
        }
        return "+\(percentage)% \(type.displayName)"
    }
}

// MARK: - Research Branch

enum ResearchBranch: String, CaseIterable {
    case gathering
    case commerce
    case infrastructure
    case logistics
    case meleeEquipment
    case rangedEquipment
    case siegeFortification

    var displayName: String {
        switch self {
        case .gathering: return "Gathering"
        case .commerce: return "Commerce"
        case .infrastructure: return "Infrastructure"
        case .logistics: return "Logistics"
        case .meleeEquipment: return "Melee Equipment"
        case .rangedEquipment: return "Ranged Equipment"
        case .siegeFortification: return "Siege & Fortification"
        }
    }

    var icon: String {
        switch self {
        case .gathering: return "🌾"
        case .commerce: return "💱"
        case .infrastructure: return "🏗️"
        case .logistics: return "🚶"
        case .meleeEquipment: return "🗡️"
        case .rangedEquipment: return "🏹"
        case .siegeFortification: return "🏰"
        }
    }

    var category: ResearchCategory {
        switch self {
        case .gathering, .commerce, .infrastructure:
            return .economic
        case .logistics, .meleeEquipment, .rangedEquipment, .siegeFortification:
            return .military
        }
    }

    /// Building type that gates Tier II+ research in this branch (nil = ungated)
    var gateBuildingType: BuildingType? {
        switch self {
        case .gathering, .logistics: return nil
        case .commerce: return .library
        case .infrastructure: return .university
        case .meleeEquipment, .rangedEquipment, .siegeFortification: return .blacksmith
        }
    }

    /// Ordered research lines for tree layout (each inner array = one row of Tier I->II->III)
    var researchLines: [[ResearchType]] {
        switch self {
        case .gathering:
            return [
                [.farmGatheringI, .farmGatheringII, .farmGatheringIII],
                [.miningCampGatheringI, .miningCampGatheringII, .miningCampGatheringIII],
                [.lumberCampGatheringI, .lumberCampGatheringII, .lumberCampGatheringIII]
            ]
        case .commerce:
            return [
                [.betterMarketRatesI, .betterMarketRatesII, .betterMarketRatesIII],
                [.improvedRoadsI, .improvedRoadsII, .improvedRoadsIII],
                [.tradeSpeedI, .tradeSpeedII, .tradeSpeedIII]
            ]
        case .infrastructure:
            return [
                [.villagerSpeedI, .villagerSpeedII, .villagerSpeedIII],
                [.populationCapacityI, .populationCapacityII, .populationCapacityIII],
                [.efficientRationsI, .efficientRationsII, .efficientRationsIII],
                [.buildingSpeedI, .buildingSpeedII, .buildingSpeedIII]
            ]
        case .logistics:
            return [
                [.marchSpeedI, .marchSpeedII, .marchSpeedIII],
                [.retreatSpeedI, .retreatSpeedII, .retreatSpeedIII],
                [.militaryTrainingSpeedI, .militaryTrainingSpeedII, .militaryTrainingSpeedIII],
                [.militaryRationsI, .militaryRationsII, .militaryRationsIII]
            ]
        case .meleeEquipment:
            return [
                [.infantryMeleeAttackI, .infantryMeleeAttackII, .infantryMeleeAttackIII],
                [.cavalryMeleeAttackI, .cavalryMeleeAttackII, .cavalryMeleeAttackIII],
                [.infantryMeleeArmorI, .infantryMeleeArmorII, .infantryMeleeArmorIII],
                [.cavalryMeleeArmorI, .cavalryMeleeArmorII, .cavalryMeleeArmorIII]
            ]
        case .rangedEquipment:
            return [
                [.piercingDamageI, .piercingDamageII, .piercingDamageIII],
                [.archerMeleeArmorI, .archerMeleeArmorII, .archerMeleeArmorIII],
                [.infantryPierceArmorI, .infantryPierceArmorII, .infantryPierceArmorIII],
                [.cavalryPierceArmorI, .cavalryPierceArmorII, .cavalryPierceArmorIII],
                [.archerPierceArmorI, .archerPierceArmorII, .archerPierceArmorIII]
            ]
        case .siegeFortification:
            return [
                [.siegeBludgeonDamageI, .siegeBludgeonDamageII, .siegeBludgeonDamageIII],
                [.buildingBludgeonArmorI, .buildingBludgeonArmorII, .buildingBludgeonArmorIII],
                [.fortifiedBuildingsI, .fortifiedBuildingsII, .fortifiedBuildingsIII]
            ]
        }
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
    // MILITARY BRANCH
    // ========================================

    // --- March Speed ---
    case marchSpeedI = "march_speed_1"
    case marchSpeedII = "march_speed_2"
    case marchSpeedIII = "march_speed_3"

    // --- Retreat Speed ---
    case retreatSpeedI = "retreat_speed_1"
    case retreatSpeedII = "retreat_speed_2"
    case retreatSpeedIII = "retreat_speed_3"

    // --- Infantry Melee Attack ---
    case infantryMeleeAttackI = "infantry_melee_attack_1"
    case infantryMeleeAttackII = "infantry_melee_attack_2"
    case infantryMeleeAttackIII = "infantry_melee_attack_3"

    // --- Cavalry Melee Attack ---
    case cavalryMeleeAttackI = "cavalry_melee_attack_1"
    case cavalryMeleeAttackII = "cavalry_melee_attack_2"
    case cavalryMeleeAttackIII = "cavalry_melee_attack_3"

    // --- Infantry Melee Armor ---
    case infantryMeleeArmorI = "infantry_melee_armor_1"
    case infantryMeleeArmorII = "infantry_melee_armor_2"
    case infantryMeleeArmorIII = "infantry_melee_armor_3"

    // --- Cavalry Melee Armor ---
    case cavalryMeleeArmorI = "cavalry_melee_armor_1"
    case cavalryMeleeArmorII = "cavalry_melee_armor_2"
    case cavalryMeleeArmorIII = "cavalry_melee_armor_3"

    // --- Archer Melee Armor ---
    case archerMeleeArmorI = "archer_melee_armor_1"
    case archerMeleeArmorII = "archer_melee_armor_2"
    case archerMeleeArmorIII = "archer_melee_armor_3"

    // --- Piercing Damage ---
    case piercingDamageI = "piercing_damage_1"
    case piercingDamageII = "piercing_damage_2"
    case piercingDamageIII = "piercing_damage_3"

    // --- Infantry Pierce Armor ---
    case infantryPierceArmorI = "infantry_pierce_armor_1"
    case infantryPierceArmorII = "infantry_pierce_armor_2"
    case infantryPierceArmorIII = "infantry_pierce_armor_3"

    // --- Cavalry Pierce Armor ---
    case cavalryPierceArmorI = "cavalry_pierce_armor_1"
    case cavalryPierceArmorII = "cavalry_pierce_armor_2"
    case cavalryPierceArmorIII = "cavalry_pierce_armor_3"

    // --- Archer Pierce Armor ---
    case archerPierceArmorI = "archer_pierce_armor_1"
    case archerPierceArmorII = "archer_pierce_armor_2"
    case archerPierceArmorIII = "archer_pierce_armor_3"

    // --- Siege Bludgeon Damage ---
    case siegeBludgeonDamageI = "siege_bludgeon_damage_1"
    case siegeBludgeonDamageII = "siege_bludgeon_damage_2"
    case siegeBludgeonDamageIII = "siege_bludgeon_damage_3"

    // --- Building Bludgeon Armor ---
    case buildingBludgeonArmorI = "building_bludgeon_armor_1"
    case buildingBludgeonArmorII = "building_bludgeon_armor_2"
    case buildingBludgeonArmorIII = "building_bludgeon_armor_3"

    // --- Military Training Speed ---
    case militaryTrainingSpeedI = "military_training_speed_1"
    case militaryTrainingSpeedII = "military_training_speed_2"
    case militaryTrainingSpeedIII = "military_training_speed_3"

    // --- Military Rations (Food Consumption) ---
    case militaryRationsI = "military_rations_1"
    case militaryRationsII = "military_rations_2"
    case militaryRationsIII = "military_rations_3"

    // --- Fortified Buildings (Building HP) ---
    case fortifiedBuildingsI = "fortified_buildings_1"
    case fortifiedBuildingsII = "fortified_buildings_2"
    case fortifiedBuildingsIII = "fortified_buildings_3"

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

        // ========================================
        // MILITARY BRANCH
        // ========================================

        // March Speed
        case .marchSpeedI: return "Forced March I"
        case .marchSpeedII: return "Forced March II"
        case .marchSpeedIII: return "Forced March III"
        // Retreat Speed
        case .retreatSpeedI: return "Tactical Retreat I"
        case .retreatSpeedII: return "Tactical Retreat II"
        case .retreatSpeedIII: return "Tactical Retreat III"
        // Infantry Melee Attack
        case .infantryMeleeAttackI: return "Infantry Weapons I"
        case .infantryMeleeAttackII: return "Infantry Weapons II"
        case .infantryMeleeAttackIII: return "Infantry Weapons III"
        // Cavalry Melee Attack
        case .cavalryMeleeAttackI: return "Cavalry Weapons I"
        case .cavalryMeleeAttackII: return "Cavalry Weapons II"
        case .cavalryMeleeAttackIII: return "Cavalry Weapons III"
        // Infantry Melee Armor
        case .infantryMeleeArmorI: return "Infantry Shields I"
        case .infantryMeleeArmorII: return "Infantry Shields II"
        case .infantryMeleeArmorIII: return "Infantry Shields III"
        // Cavalry Melee Armor
        case .cavalryMeleeArmorI: return "Cavalry Barding I"
        case .cavalryMeleeArmorII: return "Cavalry Barding II"
        case .cavalryMeleeArmorIII: return "Cavalry Barding III"
        // Archer Melee Armor
        case .archerMeleeArmorI: return "Archer Padding I"
        case .archerMeleeArmorII: return "Archer Padding II"
        case .archerMeleeArmorIII: return "Archer Padding III"
        // Piercing Damage
        case .piercingDamageI: return "Bodkin Points I"
        case .piercingDamageII: return "Bodkin Points II"
        case .piercingDamageIII: return "Bodkin Points III"
        // Infantry Pierce Armor
        case .infantryPierceArmorI: return "Infantry Mail I"
        case .infantryPierceArmorII: return "Infantry Mail II"
        case .infantryPierceArmorIII: return "Infantry Mail III"
        // Cavalry Pierce Armor
        case .cavalryPierceArmorI: return "Cavalry Mail I"
        case .cavalryPierceArmorII: return "Cavalry Mail II"
        case .cavalryPierceArmorIII: return "Cavalry Mail III"
        // Archer Pierce Armor
        case .archerPierceArmorI: return "Archer Mail I"
        case .archerPierceArmorII: return "Archer Mail II"
        case .archerPierceArmorIII: return "Archer Mail III"
        // Siege Bludgeon Damage
        case .siegeBludgeonDamageI: return "Siege Ammunition I"
        case .siegeBludgeonDamageII: return "Siege Ammunition II"
        case .siegeBludgeonDamageIII: return "Siege Ammunition III"
        // Building Bludgeon Armor
        case .buildingBludgeonArmorI: return "Reinforced Walls I"
        case .buildingBludgeonArmorII: return "Reinforced Walls II"
        case .buildingBludgeonArmorIII: return "Reinforced Walls III"
        // Military Training Speed
        case .militaryTrainingSpeedI: return "Military Drills I"
        case .militaryTrainingSpeedII: return "Military Drills II"
        case .militaryTrainingSpeedIII: return "Military Drills III"
        // Military Rations
        case .militaryRationsI: return "Field Rations I"
        case .militaryRationsII: return "Field Rations II"
        case .militaryRationsIII: return "Field Rations III"
        // Fortified Buildings
        case .fortifiedBuildingsI: return "Fortifications I"
        case .fortifiedBuildingsII: return "Fortifications II"
        case .fortifiedBuildingsIII: return "Fortifications III"
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

        // Military icons
        case .marchSpeedI, .marchSpeedII, .marchSpeedIII: return "🚶"
        case .retreatSpeedI, .retreatSpeedII, .retreatSpeedIII: return "🏃"
        case .infantryMeleeAttackI, .infantryMeleeAttackII, .infantryMeleeAttackIII: return "🗡️"
        case .cavalryMeleeAttackI, .cavalryMeleeAttackII, .cavalryMeleeAttackIII: return "⚔️"
        case .infantryMeleeArmorI, .infantryMeleeArmorII, .infantryMeleeArmorIII: return "🛡️"
        case .cavalryMeleeArmorI, .cavalryMeleeArmorII, .cavalryMeleeArmorIII: return "🐴"
        case .archerMeleeArmorI, .archerMeleeArmorII, .archerMeleeArmorIII: return "🎯"
        case .piercingDamageI, .piercingDamageII, .piercingDamageIII: return "🏹"
        case .infantryPierceArmorI, .infantryPierceArmorII, .infantryPierceArmorIII: return "⛓️"
        case .cavalryPierceArmorI, .cavalryPierceArmorII, .cavalryPierceArmorIII: return "🐎"
        case .archerPierceArmorI, .archerPierceArmorII, .archerPierceArmorIII: return "🦺"
        case .siegeBludgeonDamageI, .siegeBludgeonDamageII, .siegeBludgeonDamageIII: return "🪨"
        case .buildingBludgeonArmorI, .buildingBludgeonArmorII, .buildingBludgeonArmorIII: return "🧱"
        case .militaryTrainingSpeedI, .militaryTrainingSpeedII, .militaryTrainingSpeedIII: return "⚔️"
        case .militaryRationsI, .militaryRationsII, .militaryRationsIII: return "🥘"
        case .fortifiedBuildingsI, .fortifiedBuildingsII, .fortifiedBuildingsIII: return "🏰"
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

        // Military descriptions
        case .marchSpeedI: return "Train armies for faster marching speeds."
        case .marchSpeedII: return "Improved conditioning increases army movement."
        case .marchSpeedIII: return "Elite training enables rapid force deployment."
        case .retreatSpeedI: return "Develop tactical retreat procedures."
        case .retreatSpeedII: return "Organized withdrawal protocols save lives."
        case .retreatSpeedIII: return "Master escape tactics ensure army survival."
        case .infantryMeleeAttackI: return "Sharper swords and better technique for infantry."
        case .infantryMeleeAttackII: return "Advanced weaponry increases infantry damage."
        case .infantryMeleeAttackIII: return "Elite weapons make infantry devastating in melee."
        case .cavalryMeleeAttackI: return "Better lances and sabers for mounted units."
        case .cavalryMeleeAttackII: return "Advanced cavalry weapons deal more damage."
        case .cavalryMeleeAttackIII: return "Elite cavalry weapons crush enemies in charges."
        case .infantryMeleeArmorI: return "Improved shields protect infantry from melee."
        case .infantryMeleeArmorII: return "Reinforced shields block more melee damage."
        case .infantryMeleeArmorIII: return "Elite shields make infantry nearly impervious to melee."
        case .cavalryMeleeArmorI: return "Horse barding protects cavalry from melee."
        case .cavalryMeleeArmorII: return "Improved barding increases cavalry protection."
        case .cavalryMeleeArmorIII: return "Full plate barding for maximum cavalry defense."
        case .archerMeleeArmorI: return "Padded armor helps archers survive melee."
        case .archerMeleeArmorII: return "Improved padding reduces archer casualties."
        case .archerMeleeArmorIII: return "Elite archer padding significantly reduces losses."
        case .piercingDamageI: return "Bodkin arrow points penetrate armor better."
        case .piercingDamageII: return "Advanced arrowheads increase pierce damage."
        case .piercingDamageIII: return "Elite ammunition devastates armored targets."
        case .infantryPierceArmorI: return "Chain mail protects infantry from arrows."
        case .infantryPierceArmorII: return "Improved mail reduces arrow damage."
        case .infantryPierceArmorIII: return "Elite mail makes infantry resistant to arrows."
        case .cavalryPierceArmorI: return "Mail armor protects cavalry from arrows."
        case .cavalryPierceArmorII: return "Improved mail increases cavalry arrow resistance."
        case .cavalryPierceArmorIII: return "Elite mail makes cavalry nearly arrow-proof."
        case .archerPierceArmorI: return "Archer mail protects from counter-fire."
        case .archerPierceArmorII: return "Improved archer mail reduces losses."
        case .archerPierceArmorIII: return "Elite archer mail for maximum protection."
        case .siegeBludgeonDamageI: return "Heavier siege ammunition deals more damage."
        case .siegeBludgeonDamageII: return "Improved projectiles increase siege damage."
        case .siegeBludgeonDamageIII: return "Elite ammunition demolishes structures quickly."
        case .buildingBludgeonArmorI: return "Reinforced structures resist siege damage."
        case .buildingBludgeonArmorII: return "Improved reinforcement increases building toughness."
        case .buildingBludgeonArmorIII: return "Elite fortifications withstand heavy bombardment."
        case .militaryTrainingSpeedI: return "Improved drills speed up unit training."
        case .militaryTrainingSpeedII: return "Advanced training methods increase efficiency."
        case .militaryTrainingSpeedIII: return "Elite instructors rapidly train soldiers."
        case .militaryRationsI: return "Better supply management reduces food consumption."
        case .militaryRationsII: return "Improved logistics lower army upkeep."
        case .militaryRationsIII: return "Elite supply corps minimize food requirements."
        case .fortifiedBuildingsI: return "Reinforce buildings for more hit points."
        case .fortifiedBuildingsII: return "Improved construction increases building durability."
        case .fortifiedBuildingsIII: return "Elite fortification techniques maximize building HP."
        }
    }

    // MARK: - Category
    var category: ResearchCategory {
        switch self {
        // Economic research
        case .farmGatheringI, .farmGatheringII, .farmGatheringIII,
             .miningCampGatheringI, .miningCampGatheringII, .miningCampGatheringIII,
             .lumberCampGatheringI, .lumberCampGatheringII, .lumberCampGatheringIII,
             .betterMarketRatesI, .betterMarketRatesII, .betterMarketRatesIII,
             .villagerSpeedI, .villagerSpeedII, .villagerSpeedIII,
             .tradeSpeedI, .tradeSpeedII, .tradeSpeedIII,
             .improvedRoadsI, .improvedRoadsII, .improvedRoadsIII,
             .populationCapacityI, .populationCapacityII, .populationCapacityIII,
             .efficientRationsI, .efficientRationsII, .efficientRationsIII,
             .buildingSpeedI, .buildingSpeedII, .buildingSpeedIII:
            return .economic

        // Military research
        case .marchSpeedI, .marchSpeedII, .marchSpeedIII,
             .retreatSpeedI, .retreatSpeedII, .retreatSpeedIII,
             .infantryMeleeAttackI, .infantryMeleeAttackII, .infantryMeleeAttackIII,
             .cavalryMeleeAttackI, .cavalryMeleeAttackII, .cavalryMeleeAttackIII,
             .infantryMeleeArmorI, .infantryMeleeArmorII, .infantryMeleeArmorIII,
             .cavalryMeleeArmorI, .cavalryMeleeArmorII, .cavalryMeleeArmorIII,
             .archerMeleeArmorI, .archerMeleeArmorII, .archerMeleeArmorIII,
             .piercingDamageI, .piercingDamageII, .piercingDamageIII,
             .infantryPierceArmorI, .infantryPierceArmorII, .infantryPierceArmorIII,
             .cavalryPierceArmorI, .cavalryPierceArmorII, .cavalryPierceArmorIII,
             .archerPierceArmorI, .archerPierceArmorII, .archerPierceArmorIII,
             .siegeBludgeonDamageI, .siegeBludgeonDamageII, .siegeBludgeonDamageIII,
             .buildingBludgeonArmorI, .buildingBludgeonArmorII, .buildingBludgeonArmorIII,
             .militaryTrainingSpeedI, .militaryTrainingSpeedII, .militaryTrainingSpeedIII,
             .militaryRationsI, .militaryRationsII, .militaryRationsIII,
             .fortifiedBuildingsI, .fortifiedBuildingsII, .fortifiedBuildingsIII:
            return .military
        }
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

        // Military Tier I - 30 seconds
        case .marchSpeedI, .retreatSpeedI,
             .infantryMeleeAttackI, .cavalryMeleeAttackI,
             .infantryMeleeArmorI, .cavalryMeleeArmorI, .archerMeleeArmorI,
             .piercingDamageI,
             .infantryPierceArmorI, .cavalryPierceArmorI, .archerPierceArmorI,
             .siegeBludgeonDamageI, .buildingBludgeonArmorI,
             .militaryTrainingSpeedI, .militaryRationsI, .fortifiedBuildingsI:
            return 30.0

        // Military Tier II - 60 seconds
        case .marchSpeedII, .retreatSpeedII,
             .infantryMeleeAttackII, .cavalryMeleeAttackII,
             .infantryMeleeArmorII, .cavalryMeleeArmorII, .archerMeleeArmorII,
             .piercingDamageII,
             .infantryPierceArmorII, .cavalryPierceArmorII, .archerPierceArmorII,
             .siegeBludgeonDamageII, .buildingBludgeonArmorII,
             .militaryTrainingSpeedII, .militaryRationsII, .fortifiedBuildingsII:
            return 60.0

        // Military Tier III - 120 seconds
        case .marchSpeedIII, .retreatSpeedIII,
             .infantryMeleeAttackIII, .cavalryMeleeAttackIII,
             .infantryMeleeArmorIII, .cavalryMeleeArmorIII, .archerMeleeArmorIII,
             .piercingDamageIII,
             .infantryPierceArmorIII, .cavalryPierceArmorIII, .archerPierceArmorIII,
             .siegeBludgeonDamageIII, .buildingBludgeonArmorIII,
             .militaryTrainingSpeedIII, .militaryRationsIII, .fortifiedBuildingsIII:
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

        // Military Tier I costs - Wood: 75, Food: 50, Stone: 25
        case .marchSpeedI, .retreatSpeedI: return [.wood: 75, .food: 50, .stone: 25]
        case .infantryMeleeAttackI, .infantryMeleeArmorI, .infantryPierceArmorI: return [.wood: 75, .food: 50, .stone: 25]
        case .cavalryMeleeAttackI, .cavalryMeleeArmorI, .cavalryPierceArmorI: return [.wood: 75, .food: 50, .stone: 25]
        case .archerMeleeArmorI, .archerPierceArmorI, .piercingDamageI: return [.wood: 75, .food: 50, .stone: 25]
        case .siegeBludgeonDamageI, .buildingBludgeonArmorI: return [.wood: 75, .food: 50, .stone: 25]
        case .militaryTrainingSpeedI, .militaryRationsI, .fortifiedBuildingsI: return [.wood: 75, .food: 50, .stone: 25]

        // Military Tier II costs - Wood: 150, Food: 100, Stone: 50, Ore: 25
        case .marchSpeedII, .retreatSpeedII: return [.wood: 150, .food: 100, .stone: 50, .ore: 25]
        case .infantryMeleeAttackII, .infantryMeleeArmorII, .infantryPierceArmorII: return [.wood: 150, .food: 100, .stone: 50, .ore: 25]
        case .cavalryMeleeAttackII, .cavalryMeleeArmorII, .cavalryPierceArmorII: return [.wood: 150, .food: 100, .stone: 50, .ore: 25]
        case .archerMeleeArmorII, .archerPierceArmorII, .piercingDamageII: return [.wood: 150, .food: 100, .stone: 50, .ore: 25]
        case .siegeBludgeonDamageII, .buildingBludgeonArmorII: return [.wood: 150, .food: 100, .stone: 50, .ore: 25]
        case .militaryTrainingSpeedII, .militaryRationsII, .fortifiedBuildingsII: return [.wood: 150, .food: 100, .stone: 50, .ore: 25]

        // Military Tier III costs - Wood: 300, Food: 200, Stone: 100, Ore: 50
        case .marchSpeedIII, .retreatSpeedIII: return [.wood: 300, .food: 200, .stone: 100, .ore: 50]
        case .infantryMeleeAttackIII, .infantryMeleeArmorIII, .infantryPierceArmorIII: return [.wood: 300, .food: 200, .stone: 100, .ore: 50]
        case .cavalryMeleeAttackIII, .cavalryMeleeArmorIII, .cavalryPierceArmorIII: return [.wood: 300, .food: 200, .stone: 100, .ore: 50]
        case .archerMeleeArmorIII, .archerPierceArmorIII, .piercingDamageIII: return [.wood: 300, .food: 200, .stone: 100, .ore: 50]
        case .siegeBludgeonDamageIII, .buildingBludgeonArmorIII: return [.wood: 300, .food: 200, .stone: 100, .ore: 50]
        case .militaryTrainingSpeedIII, .militaryRationsIII, .fortifiedBuildingsIII: return [.wood: 300, .food: 200, .stone: 100, .ore: 50]
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

        // ========================================
        // MILITARY BONUSES
        // ========================================

        // March Speed: +5%, +7%, +10% (total +22%)
        case .marchSpeedI: return [ResearchBonus(type: .militaryMarchSpeed, value: 0.05)]
        case .marchSpeedII: return [ResearchBonus(type: .militaryMarchSpeed, value: 0.07)]
        case .marchSpeedIII: return [ResearchBonus(type: .militaryMarchSpeed, value: 0.10)]

        // Retreat Speed: +5%, +7%, +10% (total +22%)
        case .retreatSpeedI: return [ResearchBonus(type: .militaryRetreatSpeed, value: 0.05)]
        case .retreatSpeedII: return [ResearchBonus(type: .militaryRetreatSpeed, value: 0.07)]
        case .retreatSpeedIII: return [ResearchBonus(type: .militaryRetreatSpeed, value: 0.10)]

        // Infantry Melee Attack: +1, +1, +2 (total +4)
        case .infantryMeleeAttackI: return [ResearchBonus(type: .infantryMeleeAttack, value: 1.0)]
        case .infantryMeleeAttackII: return [ResearchBonus(type: .infantryMeleeAttack, value: 1.0)]
        case .infantryMeleeAttackIII: return [ResearchBonus(type: .infantryMeleeAttack, value: 2.0)]

        // Cavalry Melee Attack: +1, +1, +2 (total +4)
        case .cavalryMeleeAttackI: return [ResearchBonus(type: .cavalryMeleeAttack, value: 1.0)]
        case .cavalryMeleeAttackII: return [ResearchBonus(type: .cavalryMeleeAttack, value: 1.0)]
        case .cavalryMeleeAttackIII: return [ResearchBonus(type: .cavalryMeleeAttack, value: 2.0)]

        // Infantry Melee Armor: +1, +1, +2 (total +4)
        case .infantryMeleeArmorI: return [ResearchBonus(type: .infantryMeleeArmor, value: 1.0)]
        case .infantryMeleeArmorII: return [ResearchBonus(type: .infantryMeleeArmor, value: 1.0)]
        case .infantryMeleeArmorIII: return [ResearchBonus(type: .infantryMeleeArmor, value: 2.0)]

        // Cavalry Melee Armor: +1, +1, +2 (total +4)
        case .cavalryMeleeArmorI: return [ResearchBonus(type: .cavalryMeleeArmor, value: 1.0)]
        case .cavalryMeleeArmorII: return [ResearchBonus(type: .cavalryMeleeArmor, value: 1.0)]
        case .cavalryMeleeArmorIII: return [ResearchBonus(type: .cavalryMeleeArmor, value: 2.0)]

        // Archer Melee Armor: +1, +1, +2 (total +4)
        case .archerMeleeArmorI: return [ResearchBonus(type: .archerMeleeArmor, value: 1.0)]
        case .archerMeleeArmorII: return [ResearchBonus(type: .archerMeleeArmor, value: 1.0)]
        case .archerMeleeArmorIII: return [ResearchBonus(type: .archerMeleeArmor, value: 2.0)]

        // Piercing Damage: +1, +1, +2 (total +4)
        case .piercingDamageI: return [ResearchBonus(type: .piercingDamage, value: 1.0)]
        case .piercingDamageII: return [ResearchBonus(type: .piercingDamage, value: 1.0)]
        case .piercingDamageIII: return [ResearchBonus(type: .piercingDamage, value: 2.0)]

        // Infantry Pierce Armor: +1, +1, +2 (total +4)
        case .infantryPierceArmorI: return [ResearchBonus(type: .infantryPierceArmor, value: 1.0)]
        case .infantryPierceArmorII: return [ResearchBonus(type: .infantryPierceArmor, value: 1.0)]
        case .infantryPierceArmorIII: return [ResearchBonus(type: .infantryPierceArmor, value: 2.0)]

        // Cavalry Pierce Armor: +1, +1, +2 (total +4)
        case .cavalryPierceArmorI: return [ResearchBonus(type: .cavalryPierceArmor, value: 1.0)]
        case .cavalryPierceArmorII: return [ResearchBonus(type: .cavalryPierceArmor, value: 1.0)]
        case .cavalryPierceArmorIII: return [ResearchBonus(type: .cavalryPierceArmor, value: 2.0)]

        // Archer Pierce Armor: +1, +1, +2 (total +4)
        case .archerPierceArmorI: return [ResearchBonus(type: .archerPierceArmor, value: 1.0)]
        case .archerPierceArmorII: return [ResearchBonus(type: .archerPierceArmor, value: 1.0)]
        case .archerPierceArmorIII: return [ResearchBonus(type: .archerPierceArmor, value: 2.0)]

        // Siege Bludgeon Damage: +1, +1, +2 (total +4)
        case .siegeBludgeonDamageI: return [ResearchBonus(type: .siegeBludgeonDamage, value: 1.0)]
        case .siegeBludgeonDamageII: return [ResearchBonus(type: .siegeBludgeonDamage, value: 1.0)]
        case .siegeBludgeonDamageIII: return [ResearchBonus(type: .siegeBludgeonDamage, value: 2.0)]

        // Building Bludgeon Armor: +1, +1, +2 (total +4)
        case .buildingBludgeonArmorI: return [ResearchBonus(type: .buildingBludgeonArmor, value: 1.0)]
        case .buildingBludgeonArmorII: return [ResearchBonus(type: .buildingBludgeonArmor, value: 1.0)]
        case .buildingBludgeonArmorIII: return [ResearchBonus(type: .buildingBludgeonArmor, value: 2.0)]

        // Military Training Speed: +10%, +15%, +20% (total +45%)
        case .militaryTrainingSpeedI: return [ResearchBonus(type: .militaryTrainingSpeed, value: 0.10)]
        case .militaryTrainingSpeedII: return [ResearchBonus(type: .militaryTrainingSpeed, value: 0.15)]
        case .militaryTrainingSpeedIII: return [ResearchBonus(type: .militaryTrainingSpeed, value: 0.20)]

        // Military Rations (Food Consumption): -5%, -10%, -15% (total -30%)
        case .militaryRationsI: return [ResearchBonus(type: .militaryFoodConsumption, value: -0.05)]
        case .militaryRationsII: return [ResearchBonus(type: .militaryFoodConsumption, value: -0.10)]
        case .militaryRationsIII: return [ResearchBonus(type: .militaryFoodConsumption, value: -0.15)]

        // Fortified Buildings (Building HP): +10%, +15%, +20% (total +45%)
        case .fortifiedBuildingsI: return [ResearchBonus(type: .buildingHP, value: 0.10)]
        case .fortifiedBuildingsII: return [ResearchBonus(type: .buildingHP, value: 0.15)]
        case .fortifiedBuildingsIII: return [ResearchBonus(type: .buildingHP, value: 0.20)]
        }
    }

    // MARK: - Prerequisites (other research required first)
    var prerequisites: [ResearchType] {
        switch self {
        // Economic Tier I - no prerequisites (except tradeSpeedI)
        case .farmGatheringI, .miningCampGatheringI, .lumberCampGatheringI,
             .betterMarketRatesI, .villagerSpeedI,
             .improvedRoadsI, .populationCapacityI, .efficientRationsI, .buildingSpeedI:
            return []

        // Trade Routes I requires Market Rates I (cross-dep)
        case .tradeSpeedI: return [.betterMarketRatesI]

        // Economic Tier II
        case .farmGatheringII: return [.farmGatheringI]
        case .miningCampGatheringII: return [.miningCampGatheringI]
        case .lumberCampGatheringII: return [.lumberCampGatheringI]
        case .betterMarketRatesII: return [.betterMarketRatesI]
        case .villagerSpeedII: return [.villagerSpeedI]
        case .tradeSpeedII: return [.tradeSpeedI, .improvedRoadsI]  // Trade needs roads
        case .improvedRoadsII: return [.improvedRoadsI]
        case .populationCapacityII: return [.populationCapacityI]
        case .efficientRationsII: return [.efficientRationsI]
        case .buildingSpeedII: return [.buildingSpeedI, .lumberCampGatheringI]  // New: Construction II requires Lumber Efficiency I

        // Economic Tier III
        case .farmGatheringIII: return [.farmGatheringII]
        case .miningCampGatheringIII: return [.miningCampGatheringII]
        case .lumberCampGatheringIII: return [.lumberCampGatheringII]
        case .betterMarketRatesIII: return [.betterMarketRatesII]
        case .villagerSpeedIII: return [.villagerSpeedII, .efficientRationsII]  // New: Villager Speed III requires Rations II
        case .tradeSpeedIII: return [.tradeSpeedII, .improvedRoadsII]  // Trade needs roads
        case .improvedRoadsIII: return [.improvedRoadsII]
        case .populationCapacityIII: return [.populationCapacityII, .efficientRationsI]  // Existing cross-dep
        case .efficientRationsIII: return [.efficientRationsII]
        case .buildingSpeedIII: return [.buildingSpeedII]

        // Military Tier I - no prerequisites
        case .marchSpeedI, .retreatSpeedI,
             .infantryMeleeAttackI, .cavalryMeleeAttackI,
             .infantryMeleeArmorI, .cavalryMeleeArmorI, .archerMeleeArmorI,
             .piercingDamageI,
             .infantryPierceArmorI, .cavalryPierceArmorI, .archerPierceArmorI,
             .siegeBludgeonDamageI, .buildingBludgeonArmorI,
             .militaryTrainingSpeedI, .militaryRationsI, .fortifiedBuildingsI:
            return []

        // Military Tier II - with cross-dependencies
        case .marchSpeedII: return [.marchSpeedI]
        case .retreatSpeedII: return [.retreatSpeedI, .marchSpeedI]  // New: Tactical Retreat II requires March Speed I
        case .infantryMeleeAttackII: return [.infantryMeleeAttackI]
        case .cavalryMeleeAttackII: return [.cavalryMeleeAttackI]
        case .infantryMeleeArmorII: return [.infantryMeleeArmorI, .infantryMeleeAttackI]  // New: Infantry Shields II requires Infantry Weapons I
        case .cavalryMeleeArmorII: return [.cavalryMeleeArmorI, .cavalryMeleeAttackI]  // New: Cavalry Barding II requires Cavalry Weapons I
        case .archerMeleeArmorII: return [.archerMeleeArmorI]
        case .piercingDamageII: return [.piercingDamageI]
        case .infantryPierceArmorII: return [.infantryPierceArmorI, .infantryMeleeArmorI]  // New: Infantry Mail II requires Infantry Shields I
        case .cavalryPierceArmorII: return [.cavalryPierceArmorI, .cavalryMeleeArmorI]  // New: Cavalry Mail II requires Cavalry Barding I
        case .archerPierceArmorII: return [.archerPierceArmorI, .archerMeleeArmorI]  // New: Archer Mail II requires Archer Padding I
        case .siegeBludgeonDamageII: return [.siegeBludgeonDamageI, .fortifiedBuildingsI]  // New: Siege Ammo II requires Fortifications I
        case .buildingBludgeonArmorII: return [.buildingBludgeonArmorI, .fortifiedBuildingsI]  // New: Reinforced Walls II requires Fortifications I
        case .militaryTrainingSpeedII: return [.militaryTrainingSpeedI]
        case .militaryRationsII: return [.militaryRationsI]
        case .fortifiedBuildingsII: return [.fortifiedBuildingsI]

        // Military Tier III - with cross-dependencies
        case .marchSpeedIII: return [.marchSpeedII]
        case .retreatSpeedIII: return [.retreatSpeedII]
        case .infantryMeleeAttackIII: return [.infantryMeleeAttackII]
        case .cavalryMeleeAttackIII: return [.cavalryMeleeAttackII]
        case .infantryMeleeArmorIII: return [.infantryMeleeArmorII]
        case .cavalryMeleeArmorIII: return [.cavalryMeleeArmorII]
        case .archerMeleeArmorIII: return [.archerMeleeArmorII]
        case .piercingDamageIII: return [.piercingDamageII]
        case .infantryPierceArmorIII: return [.infantryPierceArmorII]
        case .cavalryPierceArmorIII: return [.cavalryPierceArmorII]
        case .archerPierceArmorIII: return [.archerPierceArmorII]
        case .siegeBludgeonDamageIII: return [.siegeBludgeonDamageII]
        case .buildingBludgeonArmorIII: return [.buildingBludgeonArmorII]
        case .militaryTrainingSpeedIII: return [.militaryTrainingSpeedII]
        case .militaryRationsIII: return [.militaryRationsII, .militaryTrainingSpeedII]  // New: Field Rations III requires Military Drills II
        case .fortifiedBuildingsIII: return [.fortifiedBuildingsII]
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

        // Military Tier I - City Center level 1
        case .marchSpeedI, .retreatSpeedI,
             .infantryMeleeAttackI, .cavalryMeleeAttackI,
             .infantryMeleeArmorI, .cavalryMeleeArmorI, .archerMeleeArmorI,
             .piercingDamageI,
             .infantryPierceArmorI, .cavalryPierceArmorI, .archerPierceArmorI,
             .siegeBludgeonDamageI, .buildingBludgeonArmorI,
             .militaryTrainingSpeedI, .militaryRationsI, .fortifiedBuildingsI:
            return 1

        // Military Tier II - City Center level 2
        case .marchSpeedII, .retreatSpeedII,
             .infantryMeleeAttackII, .cavalryMeleeAttackII,
             .infantryMeleeArmorII, .cavalryMeleeArmorII, .archerMeleeArmorII,
             .piercingDamageII,
             .infantryPierceArmorII, .cavalryPierceArmorII, .archerPierceArmorII,
             .siegeBludgeonDamageII, .buildingBludgeonArmorII,
             .militaryTrainingSpeedII, .militaryRationsII, .fortifiedBuildingsII:
            return 2

        // Military Tier III - City Center level 3
        case .marchSpeedIII, .retreatSpeedIII,
             .infantryMeleeAttackIII, .cavalryMeleeAttackIII,
             .infantryMeleeArmorIII, .cavalryMeleeArmorIII, .archerMeleeArmorIII,
             .piercingDamageIII,
             .infantryPierceArmorIII, .cavalryPierceArmorIII, .archerPierceArmorIII,
             .siegeBludgeonDamageIII, .buildingBludgeonArmorIII,
             .militaryTrainingSpeedIII, .militaryRationsIII, .fortifiedBuildingsIII:
            return 3
        }
    }

    // MARK: - Building Requirement
    var buildingRequirement: (buildingType: BuildingType, level: Int)? {
        // Gated branches require their gate building for Tier II+
        guard tier >= 2, let gateBuilding = branch.gateBuildingType else {
            return nil
        }
        return (gateBuilding, 1)
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

        // Military Tier 1
        case .marchSpeedI, .retreatSpeedI,
             .infantryMeleeAttackI, .cavalryMeleeAttackI,
             .infantryMeleeArmorI, .cavalryMeleeArmorI, .archerMeleeArmorI,
             .piercingDamageI,
             .infantryPierceArmorI, .cavalryPierceArmorI, .archerPierceArmorI,
             .siegeBludgeonDamageI, .buildingBludgeonArmorI,
             .militaryTrainingSpeedI, .militaryRationsI, .fortifiedBuildingsI:
            return 1

        // Military Tier 2
        case .marchSpeedII, .retreatSpeedII,
             .infantryMeleeAttackII, .cavalryMeleeAttackII,
             .infantryMeleeArmorII, .cavalryMeleeArmorII, .archerMeleeArmorII,
             .piercingDamageII,
             .infantryPierceArmorII, .cavalryPierceArmorII, .archerPierceArmorII,
             .siegeBludgeonDamageII, .buildingBludgeonArmorII,
             .militaryTrainingSpeedII, .militaryRationsII, .fortifiedBuildingsII:
            return 2

        // Military Tier 3
        case .marchSpeedIII, .retreatSpeedIII,
             .infantryMeleeAttackIII, .cavalryMeleeAttackIII,
             .infantryMeleeArmorIII, .cavalryMeleeArmorIII, .archerMeleeArmorIII,
             .piercingDamageIII,
             .infantryPierceArmorIII, .cavalryPierceArmorIII, .archerPierceArmorIII,
             .siegeBludgeonDamageIII, .buildingBludgeonArmorIII,
             .militaryTrainingSpeedIII, .militaryRationsIII, .fortifiedBuildingsIII:
            return 3
        }
    }

    // MARK: - Branch
    var branch: ResearchBranch {
        switch self {
        // Gathering
        case .farmGatheringI, .farmGatheringII, .farmGatheringIII,
             .miningCampGatheringI, .miningCampGatheringII, .miningCampGatheringIII,
             .lumberCampGatheringI, .lumberCampGatheringII, .lumberCampGatheringIII:
            return .gathering
        // Commerce
        case .betterMarketRatesI, .betterMarketRatesII, .betterMarketRatesIII,
             .improvedRoadsI, .improvedRoadsII, .improvedRoadsIII,
             .tradeSpeedI, .tradeSpeedII, .tradeSpeedIII:
            return .commerce
        // Infrastructure
        case .villagerSpeedI, .villagerSpeedII, .villagerSpeedIII,
             .populationCapacityI, .populationCapacityII, .populationCapacityIII,
             .efficientRationsI, .efficientRationsII, .efficientRationsIII,
             .buildingSpeedI, .buildingSpeedII, .buildingSpeedIII:
            return .infrastructure
        // Logistics
        case .marchSpeedI, .marchSpeedII, .marchSpeedIII,
             .retreatSpeedI, .retreatSpeedII, .retreatSpeedIII,
             .militaryTrainingSpeedI, .militaryTrainingSpeedII, .militaryTrainingSpeedIII,
             .militaryRationsI, .militaryRationsII, .militaryRationsIII:
            return .logistics
        // Melee Equipment
        case .infantryMeleeAttackI, .infantryMeleeAttackII, .infantryMeleeAttackIII,
             .cavalryMeleeAttackI, .cavalryMeleeAttackII, .cavalryMeleeAttackIII,
             .infantryMeleeArmorI, .infantryMeleeArmorII, .infantryMeleeArmorIII,
             .cavalryMeleeArmorI, .cavalryMeleeArmorII, .cavalryMeleeArmorIII:
            return .meleeEquipment
        // Ranged Equipment
        case .piercingDamageI, .piercingDamageII, .piercingDamageIII,
             .archerMeleeArmorI, .archerMeleeArmorII, .archerMeleeArmorIII,
             .infantryPierceArmorI, .infantryPierceArmorII, .infantryPierceArmorIII,
             .cavalryPierceArmorI, .cavalryPierceArmorII, .cavalryPierceArmorIII,
             .archerPierceArmorI, .archerPierceArmorII, .archerPierceArmorIII:
            return .rangedEquipment
        // Siege & Fortification
        case .siegeBludgeonDamageI, .siegeBludgeonDamageII, .siegeBludgeonDamageIII,
             .buildingBludgeonArmorI, .buildingBludgeonArmorII, .buildingBludgeonArmorIII,
             .fortifiedBuildingsI, .fortifiedBuildingsII, .fortifiedBuildingsIII:
            return .siegeFortification
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
    
    func getProgress(currentTime: TimeInterval = Date().timeIntervalSince1970, speedMultiplier: Double = 1.0) -> Double {
        let elapsed = currentTime - startTime
        let effectiveTime = researchType.researchTime / max(speedMultiplier, 0.1)
        return min(1.0, max(0.0, elapsed / effectiveTime))
    }

    func getRemainingTime(currentTime: TimeInterval = Date().timeIntervalSince1970, speedMultiplier: Double = 1.0) -> TimeInterval {
        let elapsed = currentTime - startTime
        let effectiveTime = researchType.researchTime / max(speedMultiplier, 0.1)
        return max(0, effectiveTime - elapsed)
    }

    func isComplete(currentTime: TimeInterval = Date().timeIntervalSince1970, speedMultiplier: Double = 1.0) -> Bool {
        return getProgress(currentTime: currentTime, speedMultiplier: speedMultiplier) >= 1.0
    }
}
