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

    // MARK: - Stamina System

    /// Current stamina level
    private(set) var stamina: Double = 100.0

    /// Maximum stamina
    static let maxStamina: Double = 100.0

    /// Stamina cost per movement or attack command
    static let staminaCostPerCommand: Double = 5.0

    /// Stamina regeneration rate (1 per minute = 1/60 per second)
    static let staminaRegenPerSecond: Double = 1.0 / 60.0

    /// Last time stamina was updated (for regeneration calculation)
    var lastStaminaUpdateTime: TimeInterval = 0

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

    /// Current stamina as a percentage (0.0 to 1.0)
    var staminaPercentage: Double {
        return stamina / Commander.maxStamina
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
        self.stamina = Commander.maxStamina
        self.lastStaminaUpdateTime = Date().timeIntervalSince1970
    }
    
    // MARK: - Stamina Management

    /// Checks if the commander has enough stamina for a command
    func hasEnoughStamina(cost: Double = Commander.staminaCostPerCommand) -> Bool {
        return stamina >= cost
    }

    /// Consumes stamina for a command. Returns true if successful, false if not enough stamina.
    @discardableResult
    func consumeStamina(cost: Double = Commander.staminaCostPerCommand) -> Bool {
        guard hasEnoughStamina(cost: cost) else {
            print("⚡ \(name) doesn't have enough stamina! (\(Int(stamina))/\(Int(Commander.maxStamina)))")
            return false
        }

        stamina = max(0, stamina - cost)
        print("⚡ \(name) used \(Int(cost)) stamina. Remaining: \(Int(stamina))/\(Int(Commander.maxStamina))")
        return true
    }

    /// Regenerates stamina based on elapsed time since last update
    func regenerateStamina(currentTime: TimeInterval) {
        guard lastStaminaUpdateTime > 0 else {
            lastStaminaUpdateTime = currentTime
            return
        }

        let elapsed = currentTime - lastStaminaUpdateTime
        let regenAmount = elapsed * Commander.staminaRegenPerSecond

        if stamina < Commander.maxStamina {
            let oldStamina = stamina
            stamina = min(Commander.maxStamina, stamina + regenAmount)

            // Only log when stamina actually increased by a meaningful amount
            if Int(stamina) > Int(oldStamina) {
                print("⚡ \(name) regenerated stamina: \(Int(stamina))/\(Int(Commander.maxStamina))")
            }
        }

        lastStaminaUpdateTime = currentTime
    }

    /// Manually sets stamina (for loading saved games)
    func setStamina(_ value: Double, lastUpdateTime: TimeInterval) {
        stamina = min(Commander.maxStamina, max(0, value))
        lastStaminaUpdateTime = lastUpdateTime
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
        desc += "Stamina: \(Int(stamina))/\(Int(Commander.maxStamina)) ⚡\n"
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
            // Ancient/Classical
            "Alexander", "Caesar", "Hannibal", "Scipio", "Leonidas",
            "Themistocles", "Pyrrhus", "Spartacus", "Marcus Aurelius", "Trajan",
            // Medieval
            "Charlemagne", "Richard", "Saladin", "Genghis", "Tamerlane",
            "El Cid", "William", "Harald", "Vlad", "Baibars",
            // Early Modern
            "Napoleon", "Frederick", "Gustavus", "Cromwell", "Marlborough",
            "Wellington", "Nelson", "Suvorov", "Turenne", "Eugene",
            // Women Warriors
            "Joan", "Boudicca", "Cleopatra", "Tomyris", "Zenobia",
            "Artemisia", "Theodora", "Matilda", "Isabella", "Rani Lakshmibai",
            // Eastern
            "Sun Tzu", "Khalid", "Zhuge Liang", "Yi Sun-sin", "Oda Nobunaga",
            "Tokugawa", "Shaka", "Cao Cao", "Bai Qi", "Takeda"
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
