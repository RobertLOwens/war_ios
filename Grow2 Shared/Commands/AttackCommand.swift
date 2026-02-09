// ============================================================================
// FILE: Grow2 Shared/Commands/AttackCommand.swift
// PURPOSE: Command to initiate combat
// ============================================================================

import Foundation

struct AttackCommand: GameCommand {
    let id: UUID
    let timestamp: TimeInterval
    let playerID: UUID
    
    let attackerEntityID: UUID
    let targetCoordinate: HexCoordinate
    let targetEntityID: UUID?  // When set, looks up entity by ID for current position (avoids stale coordinate)

    static var commandType: CommandType { .attack }

    init(playerID: UUID, attackerEntityID: UUID, targetCoordinate: HexCoordinate, targetEntityID: UUID? = nil) {
        self.id = UUID()
        self.timestamp = Date().timeIntervalSince1970
        self.playerID = playerID
        self.attackerEntityID = attackerEntityID
        self.targetCoordinate = targetCoordinate
        self.targetEntityID = targetEntityID
    }
    
    func validate(in context: CommandContext) -> CommandResult {
        guard let attacker = context.getEntity(by: attackerEntityID) else {
            return .failure(reason: "Attacker not found")
        }

        guard attacker.entity.owner?.id == playerID else {
            return .failure(reason: "You don't own this unit")
        }

        guard attacker.entityType == .army else {
            return .failure(reason: "Only armies can attack")
        }

        // Check if army is already in combat
        if GameEngine.shared.combatEngine.isInCombat(armyID: attackerEntityID) {
            return .failure(reason: "Army is currently in combat")
        }

        // Check commander stamina
        if let army = attacker.entity as? Army, let commander = army.commander {
            if !commander.hasEnoughStamina() {
                return .failure(reason: "Commander \(commander.name) is too exhausted! (Stamina: \(Int(commander.stamina))/\(Int(Commander.maxStamina)))")
            }
        }

        let player = context.getPlayer(by: playerID)

        // If targeting a specific entity by ID, look up its current position
        if let entityID = targetEntityID,
           let targetEntity = context.hexMap.entities.first(where: { $0.entity.id == entityID }) {
            let diplomacy = player?.getDiplomacyStatus(with: targetEntity.entity.owner) ?? .neutral
            guard diplomacy == .enemy else {
                return .failure(reason: "Target is not an enemy")
            }
            // Check if target army is entrenched — must attack adjacent tile instead
            if let gameState = GameEngine.shared.gameState,
               let armyData = gameState.getArmy(id: entityID),
               armyData.isEntrenched {
                return .failure(reason: "Target is entrenched - attack an adjacent tile instead")
            }
            return .success
        }

        // Check if the target tile has any entrenched armies — must attack from adjacent tile instead
        if let gameState = GameEngine.shared.gameState {
            let armiesAtTarget = gameState.getArmies(at: targetCoordinate)
            let hasEntrenchedDefender = armiesAtTarget.contains { army in
                army.isEntrenched && army.ownerID != playerID
            }
            if hasEntrenchedDefender {
                return .failure(reason: "Target is entrenched - attack from an adjacent tile")
            }
        }

        // Check if target is a building FIRST
        // This ensures clicking any tile of a multi-tile building initiates building combat
        // Any defending army on the building will participate in defense
        if let targetBuilding = context.hexMap.getBuilding(at: targetCoordinate) {
            // Check diplomacy - must be enemy building
            let diplomacy = player?.getDiplomacyStatus(with: targetBuilding.owner) ?? .neutral
            guard diplomacy == .enemy else {
                return .failure(reason: "Target building is not an enemy")
            }

            // Check if building is protected by a defensive structure
            if let gameState = GameEngine.shared.gameState {
                let protectors = gameState.getProtectingBuildings(for: targetBuilding.data.id)
                if !protectors.isEmpty {
                    // Get the name of the first protector for the error message
                    let protectorName = protectors[0].buildingType.displayName
                    if protectors.count == 1 {
                        return .failure(reason: "Protected by \(protectorName) - destroy it first")
                    } else {
                        return .failure(reason: "Protected by \(protectorName) and \(protectors.count - 1) other(s) - destroy them first")
                    }
                }
            }

            // Note: Defending armies will participate in building defense (handled in execute)
            // No longer blocking attack when defenders are present
            return .success
        }

        // Check if target is an entity (army or villagers) NOT on a building
        if let target = context.hexMap.getEntity(at: targetCoordinate) {
            let diplomacy = player?.getDiplomacyStatus(with: target.entity.owner) ?? .neutral
            guard diplomacy == .enemy else {
                return .failure(reason: "Target is not an enemy")
            }
            return .success
        }

        // Check if target is an entrenchment zone tile (cross-tile entrenched enemies covering this coordinate)
        if let gameState = GameEngine.shared.gameState {
            let crossTileEntrenched = gameState.getEntrenchedArmiesCovering(coordinate: targetCoordinate)
                .filter { $0.ownerID != playerID }
            if !crossTileEntrenched.isEmpty {
                return .success
            }
        }

        return .failure(reason: "No target at this location")
    }
    
    func execute(in context: CommandContext) -> CommandResult {
        guard let attacker = context.getEntity(by: attackerEntityID),
              let attackerArmy = attacker.entity as? Army else {
            return .failure(reason: "Attacker not found")
        }

        // Consume commander stamina for attack command
        if let commander = attackerArmy.commander {
            commander.consumeStamina()
        }

        // Clear entrenchment when attacking
        if attackerArmy.isEntrenching || attackerArmy.isEntrenched {
            attackerArmy.clearEntrenchment()
            debugLog("🪖 Army \(attackerArmy.name) entrenchment cancelled due to attack command")
        }

        // Store reference for use in completion handler
        let hexMap = context.hexMap

        // If targeting a specific entity by ID, use its current position
        if let entityID = targetEntityID,
           let target = context.hexMap.entities.first(where: { $0.entity.id == entityID }) {
            let currentCoordinate = target.coordinate

            if let defenderArmy = target.entity as? Army {
                if let path = hexMap.findPath(from: attacker.coordinate, to: currentCoordinate, for: attacker.entity.owner, allowImpassableDestination: true) {
                    debugLog("⚔️ \(attackerArmy.name) attacking army at (\(currentCoordinate.q), \(currentCoordinate.r)) [tracked by ID] - path: \(path.count) steps")

                    let attackerID = attackerArmy.id
                    let attackerOwnerID = playerID
                    let targetCoord = currentCoordinate

                    attacker.moveTo(path: path) {
                        debugLog("⚔️ \(attackerArmy.name) arrived - initiating combat!")
                        let combatTime = GameEngine.shared.gameState?.currentTime ?? 0
                        guard let gameState = GameEngine.shared.gameState else { return }

                        // Build defensive stack to check for multi-army defense
                        let defensiveStack = DefensiveStack.build(at: targetCoord, state: gameState, attackerOwnerID: attackerOwnerID)

                        if defensiveStack.armyEntries.count > 1 || defensiveStack.hasEntrenchedDefenders {
                            // Multiple defenders or entrenched defenders — use stack combat
                            var attackerIDs = [attackerID]
                            let friendlyArmies = gameState.getArmies(at: targetCoord)
                                .filter { $0.ownerID == attackerOwnerID && !$0.isInCombat && $0.id != attackerID }
                            attackerIDs.append(contentsOf: friendlyArmies.map { $0.id })

                            _ = GameEngine.shared.combatEngine.startStackCombat(
                                attackerArmyIDs: attackerIDs,
                                at: targetCoord,
                                currentTime: combatTime
                            )
                        } else {
                            // Simple 1v1 combat
                            _ = GameEngine.shared.combatEngine.startCombat(
                                attackerArmyID: attackerID,
                                defenderArmyID: defenderArmy.id,
                                currentTime: combatTime
                            )
                        }
                    }
                    return .success
                } else {
                    return .failure(reason: "No path to target")
                }
            } else if let defenderVillagers = target.entity as? VillagerGroup {
                if let path = hexMap.findPath(from: attacker.coordinate, to: currentCoordinate, for: attacker.entity.owner, allowImpassableDestination: true) {
                    debugLog("⚔️ \(attackerArmy.name) attacking villagers at (\(currentCoordinate.q), \(currentCoordinate.r)) [tracked by ID] - path: \(path.count) steps")
                    attacker.moveTo(path: path) {
                        debugLog("⚔️ \(attackerArmy.name) arrived - attacking villagers!")
                        let combatTime = GameEngine.shared.gameState?.currentTime ?? 0
                        _ = GameEngine.shared.combatEngine.startVillagerCombat(
                            attackerArmyID: attackerArmy.id,
                            defenderVillagerGroupID: defenderVillagers.data.id,
                            currentTime: combatTime
                        )
                    }
                    return .success
                } else {
                    return .failure(reason: "No path to target")
                }
            }
            return .failure(reason: "No valid target found")
        }

        // Check for building target FIRST
        // This ensures clicking any tile of a multi-tile building initiates building combat
        if let targetBuilding = context.hexMap.getBuilding(at: targetCoordinate) {
            let buildingID = targetBuilding.data.id
            let buildingName = targetBuilding.data.buildingType.displayName

            // For multi-tile buildings, use the anchor coordinate as the destination
            // This ensures the path doesn't need to go through other tiles of the same building
            let destinationCoordinate = targetBuilding.coordinate

            // Path to building and initiate combat on arrival
            // Use allowImpassableDestination to path onto enemy defensive buildings
            // Pass targetBuilding to allow pathing through all tiles of multi-tile buildings
            if let path = hexMap.findPath(from: attacker.coordinate, to: destinationCoordinate, for: attacker.entity.owner, allowImpassableDestination: true, targetBuilding: targetBuilding) {
                debugLog("⚔️ \(attackerArmy.name) attacking \(buildingName) at (\(destinationCoordinate.q), \(destinationCoordinate.r)) - path: \(path.count) steps")

                // Capture attacker origin for gathering co-located armies
                let attackerOrigin = attacker.coordinate
                let attackerID = attackerArmy.id
                let attackerOwnerID = playerID

                attacker.moveTo(path: path) {
                    debugLog("⚔️ \(attackerArmy.name) arrived - attacking \(buildingName)!")
                    let combatTime = GameEngine.shared.gameState?.currentTime ?? 0
                    guard let gameState = GameEngine.shared.gameState else { return }

                    // Build defensive stack at the target
                    let defensiveStack = DefensiveStack.build(at: destinationCoordinate, state: gameState, attackerOwnerID: attackerOwnerID)

                    if !defensiveStack.armyEntries.isEmpty {
                        // Defenders present — use stack combat
                        // Gather all friendly armies at attacker's current position
                        let friendlyArmies = gameState.getArmies(at: destinationCoordinate)
                            .filter { $0.ownerID == attackerOwnerID && !$0.isInCombat }
                        var attackerIDs = [attackerID]
                        for ally in friendlyArmies where ally.id != attackerID {
                            attackerIDs.append(ally.id)
                        }

                        debugLog("🛡️ \(defensiveStack.armyEntries.count) defender(s) present — initiating stack combat!")
                        _ = GameEngine.shared.combatEngine.startStackCombat(
                            attackerArmyIDs: attackerIDs,
                            at: destinationCoordinate,
                            currentTime: combatTime
                        )
                    } else if !defensiveStack.villagerGroupIDs.isEmpty {
                        // Only villagers — start villager combat
                        if let firstVillagerID = defensiveStack.villagerGroupIDs.first {
                            _ = GameEngine.shared.combatEngine.startVillagerCombat(
                                attackerArmyID: attackerID,
                                defenderVillagerGroupID: firstVillagerID,
                                currentTime: combatTime
                            )
                        }
                    } else {
                        // No defenders — pure building combat
                        _ = GameEngine.shared.combatEngine.startBuildingCombat(
                            attackerArmyID: attackerID,
                            buildingID: buildingID,
                            currentTime: combatTime
                        )
                    }
                }
                return .success
            } else {
                debugLog("❌ No path found from (\(attacker.coordinate.q), \(attacker.coordinate.r)) to \(buildingName) at (\(destinationCoordinate.q), \(destinationCoordinate.r))")
                return .failure(reason: "No path to \(buildingName)")
            }
        }

        // Check for entity target (army or villagers NOT on a building)
        if let target = context.hexMap.getEntity(at: targetCoordinate) {
            // Branch: Army target vs Villager target
            if let defenderArmy = target.entity as? Army {
                // Army-vs-army combat (may become stack combat on arrival)
                // Use allowImpassableDestination to handle targets on enemy buildings
                if let path = hexMap.findPath(from: attacker.coordinate, to: targetCoordinate, for: attacker.entity.owner, allowImpassableDestination: true) {
                    debugLog("⚔️ \(attackerArmy.name) attacking army at (\(targetCoordinate.q), \(targetCoordinate.r)) - path: \(path.count) steps")

                    let attackerID = attackerArmy.id
                    let attackerOwnerID = playerID
                    let targetCoord = targetCoordinate

                    attacker.moveTo(path: path) {
                        debugLog("⚔️ \(attackerArmy.name) arrived - initiating combat!")
                        let combatTime = GameEngine.shared.gameState?.currentTime ?? 0
                        guard let gameState = GameEngine.shared.gameState else { return }

                        // Build defensive stack to check for multi-army defense
                        let defensiveStack = DefensiveStack.build(at: targetCoord, state: gameState, attackerOwnerID: attackerOwnerID)

                        if defensiveStack.armyEntries.count > 1 || defensiveStack.hasEntrenchedDefenders {
                            // Multiple defenders or entrenched defenders — use stack combat
                            var attackerIDs = [attackerID]
                            let friendlyArmies = gameState.getArmies(at: targetCoord)
                                .filter { $0.ownerID == attackerOwnerID && !$0.isInCombat && $0.id != attackerID }
                            attackerIDs.append(contentsOf: friendlyArmies.map { $0.id })

                            _ = GameEngine.shared.combatEngine.startStackCombat(
                                attackerArmyIDs: attackerIDs,
                                at: targetCoord,
                                currentTime: combatTime
                            )
                        } else {
                            // Simple 1v1 combat
                            _ = GameEngine.shared.combatEngine.startCombat(
                                attackerArmyID: attackerID,
                                defenderArmyID: defenderArmy.id,
                                currentTime: combatTime
                            )
                        }
                    }
                    return .success
                } else {
                    debugLog("❌ No path found from (\(attacker.coordinate.q), \(attacker.coordinate.r)) to enemy army at (\(targetCoordinate.q), \(targetCoordinate.r))")
                    return .failure(reason: "No path to target")
                }
            } else if let defenderVillagers = target.entity as? VillagerGroup {
                // Army-vs-villager combat
                // Use allowImpassableDestination to handle targets on enemy buildings
                if let path = hexMap.findPath(from: attacker.coordinate, to: targetCoordinate, for: attacker.entity.owner, allowImpassableDestination: true) {
                    debugLog("⚔️ \(attackerArmy.name) attacking villagers at (\(targetCoordinate.q), \(targetCoordinate.r)) - path: \(path.count) steps")
                    attacker.moveTo(path: path) {
                        // Initiate villager combat when army arrives
                        debugLog("⚔️ \(attackerArmy.name) arrived - attacking villagers!")
                        let combatTime = GameEngine.shared.gameState?.currentTime ?? 0
                        _ = GameEngine.shared.combatEngine.startVillagerCombat(
                            attackerArmyID: attackerArmy.id,
                            defenderVillagerGroupID: defenderVillagers.data.id,
                            currentTime: combatTime
                        )
                    }
                    return .success
                } else {
                    debugLog("❌ No path found from (\(attacker.coordinate.q), \(attacker.coordinate.r)) to villagers at (\(targetCoordinate.q), \(targetCoordinate.r))")
                    return .failure(reason: "No path to target")
                }
            }
        }

        // Check for entrenchment zone tile (cross-tile entrenched enemies covering this coordinate)
        if let gameState = GameEngine.shared.gameState {
            let crossTileEntrenched = gameState.getEntrenchedArmiesCovering(coordinate: targetCoordinate)
                .filter { $0.ownerID != playerID }

            if !crossTileEntrenched.isEmpty {
                // Path attacker to the zone tile
                if let path = hexMap.findPath(from: attacker.coordinate, to: targetCoordinate, for: attacker.entity.owner, allowImpassableDestination: true) {
                    debugLog("⚔️ \(attackerArmy.name) attacking entrenchment zone at (\(targetCoordinate.q), \(targetCoordinate.r)) - \(crossTileEntrenched.count) entrenched defender(s)")

                    let attackerID = attackerArmy.id
                    let attackerOwnerID = playerID
                    let targetCoord = targetCoordinate

                    attacker.moveTo(path: path) {
                        debugLog("⚔️ \(attackerArmy.name) arrived at entrenchment zone - initiating stack combat!")
                        let combatTime = GameEngine.shared.gameState?.currentTime ?? 0
                        guard let gameState = GameEngine.shared.gameState else { return }

                        // Build defensive stack (gathers cross-tile entrenched into Tier 1)
                        let defensiveStack = DefensiveStack.build(at: targetCoord, state: gameState, attackerOwnerID: attackerOwnerID)

                        if !defensiveStack.armyEntries.isEmpty {
                            // Gather friendly armies at arrival position
                            var attackerIDs = [attackerID]
                            let friendlyArmies = gameState.getArmies(at: targetCoord)
                                .filter { $0.ownerID == attackerOwnerID && !$0.isInCombat && $0.id != attackerID }
                            attackerIDs.append(contentsOf: friendlyArmies.map { $0.id })

                            _ = GameEngine.shared.combatEngine.startStackCombat(
                                attackerArmyIDs: attackerIDs,
                                at: targetCoord,
                                currentTime: combatTime
                            )
                        } else {
                            // Entrenched armies may have moved — attacker occupies the tile
                            debugLog("⚔️ Entrenched defenders moved — \(attackerArmy.name) occupies zone tile")
                        }
                    }
                    return .success
                } else {
                    return .failure(reason: "No path to entrenchment zone")
                }
            }
        }

        return .failure(reason: "No valid target found")
    }
}

