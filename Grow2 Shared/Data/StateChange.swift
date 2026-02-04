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

    // MARK: - Resource Changes
    case resourcesChanged(playerID: UUID, resourceType: String, oldAmount: Int, newAmount: Int)
    case resourcesGathered(playerID: UUID, resourceType: String, amount: Int, sourceCoordinate: HexCoordinate)
    case resourcePointAmountChanged(coordinate: HexCoordinate, oldAmount: Int, newAmount: Int)
    case resourcePointDepleted(coordinate: HexCoordinate, resourceType: String)
    case resourcePointCreated(coordinate: HexCoordinate, resourceType: String, amount: Int)
    case collectionRateChanged(playerID: UUID, resourceType: String, oldRate: Double, newRate: Double)

    // MARK: - Reinforcement Changes
    case reinforcementDispatched(reinforcementID: UUID, sourceCoordinate: HexCoordinate, targetArmyID: UUID, units: [String: Int])
    case reinforcementProgress(reinforcementID: UUID, currentCoordinate: HexCoordinate, progress: Double)
    case reinforcementArrived(reinforcementID: UUID, targetArmyID: UUID)
    case reinforcementCancelled(reinforcementID: UUID)

    // MARK: - Player Changes
    case playerResourcesUpdated(playerID: UUID, resources: [String: Int])
    case playerVisionUpdated(playerID: UUID, visibleCoordinates: [HexCoordinate], exploredCoordinates: [HexCoordinate])
    case diplomacyChanged(playerID: UUID, otherPlayerID: UUID, newStatus: String)

    // MARK: - Map Changes
    case terrainChanged(coordinate: HexCoordinate, newTerrain: String)
    case fogOfWarUpdated(playerID: UUID, coordinate: HexCoordinate, visibility: String)

    // MARK: - Commander Changes
    case commanderRecruited(commanderID: UUID, ownerID: UUID, buildingID: UUID)
    case commanderAssigned(commanderID: UUID, armyID: UUID)
    case commanderUnassigned(commanderID: UUID, armyID: UUID)
    case commanderLevelUp(commanderID: UUID, newLevel: Int)

    // MARK: - Hunting Changes
    case animalDamaged(coordinate: HexCoordinate, currentHealth: Double)
    case animalKilled(coordinate: HexCoordinate, resourceType: String)
    case carcassCreated(coordinate: HexCoordinate, resourceType: String, amount: Int)

    // MARK: - Game State Changes
    case gameTick(currentTime: TimeInterval)
    case gameOver(reason: String, winnerID: UUID?)
}

// MARK: - Combat Result Data

struct CombatResultData: Codable {
    let winnerID: UUID?
    let loserID: UUID?
    let attackerCasualties: [String: Int]
    let defenderCasualties: [String: Int]
    let combatDuration: TimeInterval

    init(winnerID: UUID? = nil, loserID: UUID? = nil, attackerCasualties: [String: Int] = [:], defenderCasualties: [String: Int] = [:], combatDuration: TimeInterval = 0) {
        self.winnerID = winnerID
        self.loserID = loserID
        self.attackerCasualties = attackerCasualties
        self.defenderCasualties = defenderCasualties
        self.combatDuration = combatDuration
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
