import Foundation
import UIKit

// MARK: - Commander Rank

enum CommanderRank: String, CaseIterable {
    case recruit = "Recruit"
    case sergeant = "Sergeant"
    case captain = "Captain"
    case major = "Major"
    case colonel = "Colonel"
    case general = "General"
    
    var displayName: String {
        return rawValue
    }
    
    var icon: String {
        switch self {
        case .recruit: return "⭐"
        case .sergeant: return "⭐⭐"
        case .captain: return "⭐⭐⭐"
        case .major: return "🎖️"
        case .colonel: return "🎖️🎖️"
        case .general: return "👑"
        }
    }
    
    var maxArmySize: Int {
        switch self {
        case .recruit: return 50
        case .sergeant: return 100
        case .captain: return 150
        case .major: return 200
        case .colonel: return 300
        case .general: return 500
        }
    }
    
    var leadershipBonus: Double {
        switch self {
        case .recruit: return 0.0
        case .sergeant: return 0.05
        case .captain: return 0.10
        case .major: return 0.15
        case .colonel: return 0.20
        case .general: return 0.30
        }
    }
}

// MARK: - Commander Specialty

enum CommanderSpecialty: String, CaseIterable, Codable {
    case infantry = "Infantry"
    case cavalry = "Cavalry"
    case ranged = "Ranged"
    case siege = "Siege"
    case defensive = "Defensive"
    case logistics = "Logistics"
    
    var displayName: String {
        return rawValue
    }
    
    var icon: String {
        switch self {
        case .infantry: return "🗡️"
        case .cavalry: return "🐴"
        case .ranged: return "🏹"
        case .siege: return "🎯"
        case .defensive: return "🛡️"
        case .logistics: return "📦"
        }
    }
    
    var description: String {
        switch self {
        case .infantry: return "Bonus to infantry attack and defense"
        case .cavalry: return "Bonus to cavalry speed and attack"
        case .ranged: return "Bonus to ranged unit damage and range"
        case .siege: return "Bonus to siege weapons and building damage"
        case .defensive: return "Bonus to all unit defense"
        case .logistics: return "Reduced movement time and resource costs"
        }
    }
    
    func getBonus(for unitType: MilitaryUnitType) -> Double {
        return getBonus(for: unitType.category)
    }

    func getBonus(for category: UnitCategory) -> Double {
        switch (self, category) {
        case (.infantry, .infantry):
            return 0.20  // +20% to infantry units
        case (.cavalry, .cavalry):
            return 0.25  // +25% to cavalry units
        case (.ranged, .ranged):
            return 0.20  // +20% to ranged units
        case (.siege, .siege):
            return 0.25  // +25% to siege units
        default:
            return 0.0
        }
    }
}

// MARK: - Commander

class Commander {
    let id: UUID
    var name: String
    var rank: CommanderRank
    var specialty: CommanderSpecialty
    weak var owner: Player?
    weak var assignedArmy: Army?
    
    private(set) var experience: Int = 0
    private(set) var level: Int = 1
    private let baseLeadership: Int
    private let baseTactics: Int
    
    // Stats
    var leadership: Int {
        return baseLeadership + (level - 1) * 2
    }
    
    var tactics: Int {
        return baseTactics + (level - 1) * 2
    }
    
    var isAssigned: Bool {
        return assignedArmy != nil
    }

    // Portrait color for visual identification
    var portraitColor: UIColor
    
    init(id: UUID = UUID(), name: String, rank: CommanderRank = .recruit, specialty: CommanderSpecialty,
         baseLeadership: Int = 10, baseTactics: Int = 10, portraitColor: UIColor = .blue, owner: Player? = nil) {
        self.id = id
        self.name = name
        self.rank = rank
        self.specialty = specialty
        self.baseLeadership = baseLeadership
        self.baseTactics = baseTactics
        self.portraitColor = portraitColor
        self.owner = owner
    }
    
    // MARK: - Experience and Leveling
    
    func addExperience(_ amount: Int) {
        experience += amount
        checkLevelUp()
    }
    
    private func checkLevelUp() {
        let requiredXP = level * 100
        if experience >= requiredXP {
            level += 1
            experience -= requiredXP
            print("🎉 \(name) leveled up to Level \(level)!")
            checkRankPromotion()
        }
    }
    
    private func checkRankPromotion() {
        let newRank: CommanderRank?
        
        switch level {
        case 5: newRank = .sergeant
        case 10: newRank = .captain
        case 15: newRank = .major
        case 20: newRank = .colonel
        case 25: newRank = .general
        default: newRank = nil
        }
        
        if let newRank = newRank, newRank.maxArmySize > rank.maxArmySize {
            rank = newRank
            print("⭐ \(name) promoted to \(rank.displayName)!")
        }
    }
    
    // MARK: - Combat Bonuses
    
    func getAttackBonus(for unitType: MilitaryUnitType) -> Double {
        return getAttackBonus(for: unitType.category)
    }

    func getAttackBonus(for category: UnitCategory) -> Double {
        let specialtyBonus = specialty.getBonus(for: category)
        let rankBonus = rank.leadershipBonus
        let levelBonus = Double(level) * 0.01

        return specialtyBonus + rankBonus + levelBonus
    }
    
    func getDefenseBonus() -> Double {
        let rankBonus = rank.leadershipBonus
        let levelBonus = Double(level) * 0.01
        
        if specialty == .defensive {
            return rankBonus + levelBonus + 0.15
        }
        
        return rankBonus + levelBonus
    }
    
    func getSpeedBonus() -> Double {
        if specialty == .logistics {
            return 0.20
        }
        return 0.0
    }
    
    // MARK: - Description
    
    func getDescription() -> String {
        var desc = "\(rank.icon) \(name)\n"
        desc += "Rank: \(rank.displayName)\n"
        desc += "Specialty: \(specialty.icon) \(specialty.displayName)\n"
        desc += "Level: \(level) (XP: \(experience)/\(level * 100))\n"
        desc += "Leadership: \(leadership)\n"
        desc += "Tactics: \(tactics)\n"
        desc += "Max Army Size: \(rank.maxArmySize)\n"
        desc += "\n\(specialty.description)"
        
        return desc
    }
    
    func getShortDescription() -> String {
            return "\(rank.icon) \(name) (Lvl \(level) \(specialty.icon))"
    }
        
    // MARK: - Factory Methods

    /// Returns a random commander name
    static func randomName() -> String {
        let randomNames = [
            "Alexander", "Caesar", "Napoleon", "Hannibal", "Genghis",
            "Joan", "Boudicca", "Cleopatra", "Tomyris", "Zenobia",
            "Sun Tzu", "Khalid", "Saladin", "Richard", "Frederick"
        ]
        return randomNames.randomElement()!
    }

    /// Returns a random portrait color
    static func randomColor() -> UIColor {
        let colors: [UIColor] = [
            .blue, .red, .green, .purple, .orange, .brown, .cyan, .magenta
        ]
        return colors.randomElement()!
    }

    static func createRandom(name: String? = nil, owner: Player? = nil) -> Commander {
        let commanderName = name ?? randomName()
        let specialty = CommanderSpecialty.allCases.randomElement()!
        let baseLeadership = Int.random(in: 8...15)
        let baseTactics = Int.random(in: 8...15)
        let color = randomColor()

        return Commander(
            name: commanderName,
            specialty: specialty,
            baseLeadership: baseLeadership,
            baseTactics: baseTactics,
            portraitColor: color,
            owner: owner
        )
    }
    
    func assignToArmy(_ army: Army) {
        // Remove from current army if assigned
        if let currentArmy = assignedArmy {
            currentArmy.commander = nil
        }
        
        // Remove any existing commander from target army
        if let existingCommander = army.commander {
            existingCommander.assignedArmy = nil
        }
        
        // Make the assignment
        assignedArmy = army
        army.commander = self
        
        print("✅ \(name) assigned to \(army.name)")
    }
    
    /// Removes this commander from their current army
    func removeFromArmy() {
        if let army = assignedArmy {
            army.commander = nil
            assignedArmy = nil
            print("✅ \(name) removed from army")
        }
    }
    
    func getBaseLeadership() -> Int {
        return baseLeadership
    }

    func getBaseTactics() -> Int {
        return baseTactics
    }

}
