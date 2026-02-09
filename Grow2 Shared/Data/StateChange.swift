// ============================================================================
// FILE: Grow2 Shared/Data/StateChange.swift
// PURPOSE: Pure data types for state changes - no SpriteKit dependencies
// ============================================================================

import Foundation

// MARK: - State Change

/// Represents a change to the game state that occurred as a result of a command or game tick
/// These changes are used by the visual layer to update the display
enum StateChange: Codable {

    // MARK: - Building Changes
    case buildingPlaced(buildingID: UUID, buildingType: String, coordinate: HexCoordinate, ownerID: UUID, rotation: Int)
    case buildingConstructionStarted(buildingID: UUID)
    case buildingConstructionProgress(buildingID: UUID, progress: Double)
    case buildingCompleted(buildingID: UUID)
    case buildingUpgradeStarted(buildingID: UUID, toLevel: Int)
    case buildingUpgradeProgress(buildingID: UUID, progress: Double)
    case buildingUpgradeCompleted(buildingID: UUID, newLevel: Int)
    case buildingDemolitionStarted(buildingID: UUID)
    case buildingDemolitionProgress(buildingID: UUID, progress: Double)
    case buildingDemolished(buildingID: UUID, coordinate: HexCoordinate)
    case buildingDamaged(buildingID: UUID, currentHealth: Double, maxHealth: Double)
    case buildingRepaired(buildingID: UUID, currentHealth: Double)
    case buildingDestroyed(buildingID: UUID, coordinate: HexCoordinate)

    // MARK: - Unit Changes
    case armyCreated(armyID: UUID, ownerID: UUID, coordinate: HexCoordinate, composition: [String: Int])
    case armyMoved(armyID: UUID, from: HexCoordinate, to: HexCoordinate, path: [HexCoordinate])
    case armyCompositionChanged(armyID: UUID, newComposition: [String: Int])
    case armyDestroyed(armyID: UUID, coordinate: HexCoordinate)
    case armyMerged(sourceArmyID: UUID, targetArmyID: UUID)
    case armyRetreating(armyID: UUID, to: HexCoordinate)
    case armyAutoRetreating(armyID: UUID, path: [HexCoordinate])
    case armyEntrenchmentStarted(armyID: UUID, coordinate: HexCoordinate)
    case armyEntrenchmentProgress(armyID: UUID, progress: Double)
    case armyEntrenched(armyID: UUID, coordinate: HexCoordinate)
    case armyEntrenchmentCancelled(armyID: UUID, coordinate: HexCoordinate)

    case villagerGroupCreated(groupID: UUID, ownerID: UUID, coordinate: HexCoordinate, count: Int)
    case villagerGroupMoved(groupID: UUID, from: HexCoordinate, to: HexCoordinate, path: [HexCoordinate])
    case villagerGroupCountChanged(groupID: UUID, newCount: Int)
    case villagerGroupDestroyed(groupID: UUID, coordinate: HexCoordinate)
    case villagerGroupTaskChanged(groupID: UUID, task: String, targetCoordinate: HexCoordinate?)

    // MARK: - Training Changes
    case trainingStarted(buildingID: UUID, unitType: String, quantity: Int, startTime: TimeInterval)
    case trainingProgress(buildingID: UUID, entryIndex: Int, progress: Double)
    case trainingCompleted(buildingID: UUID, unitType: String, quantity: Int)
    case villagerTrainingStarted(buildingID: UUID, quantity: Int, startTime: TimeInterval)
    case villagerTrainingProgress(buildingID: UUID, entryIndex: Int, progress: Double)
    case villagerTrainingCompleted(buildingID: UUID, quantity: Int)

    // MARK: - Garrison Changes
    case unitsGarrisoned(buildingID: UUID, unitType: String, quantity: Int)
    case unitsUngarrisoned(buildingID: UUID, unitType: String, quantity: Int)
    case villagersGarrisoned(buildingID: UUID, quantity: Int)
    case villagersUngarrisoned(buildingID: UUID, quantity: Int)

    // MARK: - Combat Changes
    case combatStarted(attackerID: UUID, defenderID: UUID, coordinate: HexCoordinate)
    case combatDamageDealt(sourceID: UUID, targetID: UUID, damage: Double, damageType: String)
    case combatPhaseCompleted(attackerID: UUID, defenderID: UUID, phase: Int)
    case combatEnded(attackerID: UUID, defenderID: UUID, result: CombatResultData)
    case garrisonDefenseAttack(buildingID: UUID, targetArmyID: UUID, damage: Double)
    case villagerCasualties(villagerGroupID: UUID, casualties: Int, remaining: Int)

    // MARK: - Stack Combat Changes
    case stackCombatStarted(coordinate: HexCoordinate, attackerArmyIDs: [UUID], defenderArmyIDs: [UUID])
    case stackCombatPairingEnded(coordinate: HexCoordinate, winnerArmyID: UUID?, loserArmyID: UUID?)
    case stackCombatTierAdvanced(coordinate: HexCoordinate, newTier: Int)
    case stackCombatEnded(coordinate: HexCoordinate, result: CombatResultData)
    case armyForcedRetreat(armyID: UUID, from: HexCoordinate, to: HexCoordinate)

    // MARK: - Resource Changes
    case resourcesChanged(playerID: UUID, resourceType: String, oldAmount: Int, newAmount: Int)
    case resourcesGathered(playerID: UUID, resourceType: String, amount: Int, sourceCoordinate: HexCoordinate)
    case resourcePointAmountChanged(coordinate: HexCoordinate, oldAmount: Int, newAmount: Int)
    case resourcePointDepleted(coordinate: HexCoordinate, resourceType: String)
    case resourcePointCreated(coordinate: HexCoordinate, resourceType: String, amount: Int)
    case collectionRateChanged(playerID: UUID, resourceType: String, oldRate: Double, newRate: Double)

    // MARK: - Player Changes
    case playerResourcesUpdated(playerID: UUID, resources: [String: Int])
    case playerVisionUpdated(playerID: UUID, visibleCoordinates: [HexCoordinate], exploredCoordinates: [HexCoordinate])
    case diplomacyChanged(playerID: UUID, otherPlayerID: UUID, newStatus: String)

    // MARK: - Map Changes
    case fogOfWarUpdated(playerID: UUID, coordinate: HexCoordinate, visibility: String)

    // MARK: - Research Changes
    case researchStarted(playerID: UUID, researchType: String, startTime: TimeInterval)
    case researchProgress(playerID: UUID, researchType: String, progress: Double)
    case researchCompleted(playerID: UUID, researchType: String)

    // MARK: - Unit Upgrade Changes
    case unitUpgradeStarted(playerID: UUID, unitType: String, tier: Int, buildingID: UUID, startTime: TimeInterval)
    case unitUpgradeProgress(playerID: UUID, unitType: String, progress: Double)
    case unitUpgradeCompleted(playerID: UUID, unitType: String, tier: Int)

    // MARK: - Game State Changes
    case gameTick(currentTime: TimeInterval)
    case gameOver(reason: String, winnerID: UUID?)
}

// MARK: - Building Damage Record

/// Records damage dealt to a building during combat
struct BuildingDamageRecord: Codable {
    let buildingID: UUID
    let buildingType: String
    let damageDealt: Double
    let healthBefore: Double
    let healthAfter: Double
    let wasDestroyed: Bool

    init(buildingID: UUID, buildingType: String, damageDealt: Double, healthBefore: Double, healthAfter: Double, wasDestroyed: Bool) {
        self.buildingID = buildingID
        self.buildingType = buildingType
        self.damageDealt = damageDealt
        self.healthBefore = healthBefore
        self.healthAfter = healthAfter
        self.wasDestroyed = wasDestroyed
    }
}

// MARK: - Combat Result Data

struct CombatResultData: Codable {
    let winnerID: UUID?
    let loserID: UUID?
    let attackerCasualties: [String: Int]
    let defenderCasualties: [String: Int]
    let combatDuration: TimeInterval
    let buildingDamage: BuildingDamageRecord?

    init(winnerID: UUID? = nil, loserID: UUID? = nil, attackerCasualties: [String: Int] = [:], defenderCasualties: [String: Int] = [:], combatDuration: TimeInterval = 0, buildingDamage: BuildingDamageRecord? = nil) {
        self.winnerID = winnerID
        self.loserID = loserID
        self.attackerCasualties = attackerCasualties
        self.defenderCasualties = defenderCasualties
        self.combatDuration = combatDuration
        self.buildingDamage = buildingDamage
    }
}

// MARK: - State Change Batch

/// A batch of state changes that occurred together (e.g., from one game tick or command)
struct StateChangeBatch: Codable {
    let timestamp: TimeInterval
    let changes: [StateChange]
    let sourceCommandID: UUID?

    init(timestamp: TimeInterval, changes: [StateChange], sourceCommandID: UUID? = nil) {
        self.timestamp = timestamp
        self.changes = changes
        self.sourceCommandID = sourceCommandID
    }
}

// MARK: - State Change Builder

/// Helper class for accumulating state changes during command execution or game tick
class StateChangeBuilder {
    private var changes: [StateChange] = []
    private let startTime: TimeInterval
    private let sourceCommandID: UUID?

    init(currentTime: TimeInterval, sourceCommandID: UUID? = nil) {
        self.startTime = currentTime
        self.sourceCommandID = sourceCommandID
    }

    func add(_ change: StateChange) {
        changes.append(change)
    }

    func addAll(_ newChanges: [StateChange]) {
        changes.append(contentsOf: newChanges)
    }

    func build() -> StateChangeBatch {
        return StateChangeBatch(
            timestamp: startTime,
            changes: changes,
            sourceCommandID: sourceCommandID
        )
    }

    var isEmpty: Bool {
        return changes.isEmpty
    }

    var count: Int {
        return changes.count
    }
}
