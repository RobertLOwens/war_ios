// ============================================================================
// FILE: Commander.swift
// PURPOSE: Visual layer for commanders - delegates state to CommanderData
// ============================================================================

import Foundation
import UIKit

// MARK: - Commander

class Commander {
    // MARK: - Data Layer (Single Source of Truth)
    let data: CommanderData

    // MARK: - Visual Layer Only
    weak var owner: Player?
    weak var assignedArmy: Army?

    // Portrait color for visual identification (converts from data's hex)
    var portraitColor: UIColor {
        get { UIColor(hex: data.portraitColorHex) ?? .blue }
        set { data.portraitColorHex = newValue.toHexString() }
    }

    // MARK: - Delegated Properties

    var id: UUID { data.id }
    var name: String {
        get { data.name }
        set { data.name = newValue }
    }

    var rank: CommanderRank {
        get { data.rank }
        set { data.rank = newValue }
    }

    var specialty: CommanderSpecialty {
        get { data.specialty }
        set { data.specialty = newValue }
    }

    var experience: Int {
        get { data.experience }
    }

    var level: Int {
        get { data.level }
    }

    var leadership: Int {
        return data.leadership
    }

    var tactics: Int {
        return data.tactics
    }

    var stamina: Double {
        return data.stamina
    }

    var staminaPercentage: Double {
        return data.staminaPercentage
    }

    var lastStaminaUpdateTime: TimeInterval {
        get { data.lastStaminaUpdateTime }
        set { data.lastStaminaUpdateTime = newValue }
    }

    var isAssigned: Bool {
        return assignedArmy != nil
    }

    // MARK: - Static Constants
    static var maxStamina: Double { CommanderData.maxStamina }
    static var staminaCostPerCommand: Double { CommanderData.staminaCostPerCommand }
    static var staminaRegenPerSecond: Double { CommanderData.staminaRegenPerSecond }

    // MARK: - Initialization

    init(id: UUID = UUID(), name: String, rank: CommanderRank = .recruit, specialty: CommanderSpecialty,
         baseLeadership: Int = 10, baseTactics: Int = 10, portraitColor: UIColor = .blue, owner: Player? = nil, data: CommanderData? = nil) {
        // Use provided data or create new
        if let existingData = data {
            self.data = existingData
        } else {
            self.data = CommanderData(
                id: id,
                name: name,
                specialty: specialty,
                baseLeadership: baseLeadership,
                baseTactics: baseTactics,
                ownerID: owner?.id
            )
            self.data.rank = rank
            self.data.portraitColorHex = portraitColor.toHexString()
        }
        self.owner = owner
    }

    // MARK: - Stamina Management

    func hasEnoughStamina(cost: Double = CommanderData.staminaCostPerCommand) -> Bool {
        return data.hasEnoughStamina(cost: cost)
    }

    @discardableResult
    func consumeStamina(cost: Double = CommanderData.staminaCostPerCommand) -> Bool {
        let result = data.consumeStamina(cost: cost)
        if !result {
            debugLog("⚡ \(name) doesn't have enough stamina! (\(Int(stamina))/\(Int(CommanderData.maxStamina)))")
        } else {
            debugLog("⚡ \(name) used \(Int(cost)) stamina. Remaining: \(Int(stamina))/\(Int(CommanderData.maxStamina))")
        }
        return result
    }

    func regenerateStamina(currentTime: TimeInterval) {
        let oldStamina = stamina
        data.regenerateStamina(currentTime: currentTime)

        // Only log when stamina actually increased by a meaningful amount
        if Int(stamina) > Int(oldStamina) {
            debugLog("⚡ \(name) regenerated stamina: \(Int(stamina))/\(Int(CommanderData.maxStamina))")
        }
    }

    func setStamina(_ value: Double, lastUpdateTime: TimeInterval) {
        data.setStamina(value, lastUpdateTime: lastUpdateTime)
    }

    // MARK: - Experience and Leveling

    func addExperience(_ amount: Int) {
        let oldLevel = level
        let oldRank = rank
        data.addExperience(amount)

        if level > oldLevel {
            debugLog("🎉 \(name) leveled up to Level \(level)!")
        }
        if rank != oldRank {
            debugLog("⭐ \(name) promoted to \(rank.displayName)!")
        }
    }

    // MARK: - Combat Bonuses

    func getAttackBonus(for unitType: MilitaryUnitType) -> Double {
        return data.getAttackBonus(for: unitType.category)
    }

    func getAttackBonus(for category: UnitCategory) -> Double {
        return data.getAttackBonus(for: category)
    }

    func getDefenseBonus() -> Double {
        return data.getDefenseBonus()
    }

    func getSpeedBonus() -> Double {
        return data.getSpeedBonus()
    }

    // MARK: - Description

    func getDescription() -> String {
        var desc = "\(rank.icon) \(name)\n"
        desc += "Rank: \(rank.displayName)\n"
        desc += "Specialty: \(specialty.icon) \(specialty.displayName)\n"
        desc += "Level: \(level) (XP: \(experience)/\(level * 100))\n"
        desc += "Leadership: \(leadership)\n"
        desc += "Tactics: \(tactics)\n"
        desc += "Stamina: \(Int(stamina))/\(Int(CommanderData.maxStamina)) ⚡\n"
        desc += "Max Army Size: \(rank.maxArmySize)\n"
        desc += "\n\(specialty.description)"
        return desc
    }

    func getShortDescription() -> String {
        return "\(rank.icon) \(name) (Lvl \(level) \(specialty.icon))"
    }

    // MARK: - Factory Methods

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
            existingCommander.data.assignedArmyID = nil
        }

        // Make the assignment
        assignedArmy = army
        army.commander = self
        data.assignedArmyID = army.id
        army.data.commanderID = self.id

        debugLog("✅ \(name) assigned to \(army.name)")
    }

    func removeFromArmy() {
        if let army = assignedArmy {
            army.commander = nil
            army.data.commanderID = nil
            assignedArmy = nil
            data.assignedArmyID = nil
            debugLog("✅ \(name) removed from army")
        }
    }

    func getBaseLeadership() -> Int {
        return data.baseLeadership
    }

    func getBaseTactics() -> Int {
        return data.baseTactics
    }
}
