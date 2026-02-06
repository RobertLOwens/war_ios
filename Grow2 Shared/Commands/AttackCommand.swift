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
            return .success
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

        // Store reference for use in completion handler
        let hexMap = context.hexMap

        // If targeting a specific entity by ID, use its current position
        if let entityID = targetEntityID,
           let target = context.hexMap.entities.first(where: { $0.entity.id == entityID }) {
            let currentCoordinate = target.coordinate

            if let defenderArmy = target.entity as? Army {
                if let path = hexMap.findPath(from: attacker.coordinate, to: currentCoordinate, for: attacker.entity.owner, allowImpassableDestination: true) {
                    print("⚔️ \(attackerArmy.name) attacking army at (\(currentCoordinate.q), \(currentCoordinate.r)) [tracked by ID] - path: \(path.count) steps")
                    attacker.moveTo(path: path) {
                        print("⚔️ \(attackerArmy.name) arrived - initiating combat!")
                        let combatTime = GameEngine.shared.gameState?.currentTime ?? 0
                        _ = GameEngine.shared.combatEngine.startCombat(
                            attackerArmyID: attackerArmy.id,
                            defenderArmyID: defenderArmy.id,
                            currentTime: combatTime
                        )
                    }
                    return .success
                } else {
                    return .failure(reason: "No path to target")
                }
            } else if let defenderVillagers = target.entity as? VillagerGroup {
                if let path = hexMap.findPath(from: attacker.coordinate, to: currentCoordinate, for: attacker.entity.owner, allowImpassableDestination: true) {
                    print("⚔️ \(attackerArmy.name) attacking villagers at (\(currentCoordinate.q), \(currentCoordinate.r)) [tracked by ID] - path: \(path.count) steps")
                    attacker.moveTo(path: path) {
                        print("⚔️ \(attackerArmy.name) arrived - attacking villagers!")
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

            // Check if there's a defending army on any tile of the building
            var defendingArmy: Army? = nil
            let occupiedTiles = targetBuilding.getOccupiedCoordinates()
            for tile in occupiedTiles {
                if let entity = context.hexMap.getEntity(at: tile),
                   entity.entityType == .army,
                   let army = entity.entity as? Army {
                    defendingArmy = army
                    break
                }
            }

            // Path to building and initiate combat on arrival
            // Use allowImpassableDestination to path onto enemy defensive buildings
            // Pass targetBuilding to allow pathing through all tiles of multi-tile buildings
            if let path = hexMap.findPath(from: attacker.coordinate, to: destinationCoordinate, for: attacker.entity.owner, allowImpassableDestination: true, targetBuilding: targetBuilding) {
                print("⚔️ \(attackerArmy.name) attacking \(buildingName) at (\(destinationCoordinate.q), \(destinationCoordinate.r)) - path: \(path.count) steps")

                // Capture defender ID for closure
                let defenderArmyID = defendingArmy?.id

                attacker.moveTo(path: path) {
                    print("⚔️ \(attackerArmy.name) arrived - attacking \(buildingName)!")
                    let combatTime = GameEngine.shared.gameState?.currentTime ?? 0

                    if let defenderID = defenderArmyID {
                        // Building has a defending army - start army combat with building context
                        print("🛡️ Defender army present - they will defend the building!")
                        _ = GameEngine.shared.combatEngine.startCombat(
                            attackerArmyID: attackerArmy.id,
                            defenderArmyID: defenderID,
                            currentTime: combatTime
                        )
                    } else {
                        // No defending army - pure building combat
                        _ = GameEngine.shared.combatEngine.startBuildingCombat(
                            attackerArmyID: attackerArmy.id,
                            buildingID: buildingID,
                            currentTime: combatTime
                        )
                    }
                }
                return .success
            } else {
                print("❌ No path found from (\(attacker.coordinate.q), \(attacker.coordinate.r)) to \(buildingName) at (\(destinationCoordinate.q), \(destinationCoordinate.r))")
                return .failure(reason: "No path to \(buildingName)")
            }
        }

        // Check for entity target (army or villagers NOT on a building)
        if let target = context.hexMap.getEntity(at: targetCoordinate) {
            // Branch: Army target vs Villager target
            if let defenderArmy = target.entity as? Army {
                // Army-vs-army combat
                // Use allowImpassableDestination to handle targets on enemy buildings
                if let path = hexMap.findPath(from: attacker.coordinate, to: targetCoordinate, for: attacker.entity.owner, allowImpassableDestination: true) {
                    print("⚔️ \(attackerArmy.name) attacking army at (\(targetCoordinate.q), \(targetCoordinate.r)) - path: \(path.count) steps")
                    attacker.moveTo(path: path) {
                        // Initiate combat when army arrives
                        print("⚔️ \(attackerArmy.name) arrived - initiating combat!")
                        let combatTime = GameEngine.shared.gameState?.currentTime ?? 0
                        _ = GameEngine.shared.combatEngine.startCombat(
                            attackerArmyID: attackerArmy.id,
                            defenderArmyID: defenderArmy.id,
                            currentTime: combatTime
                        )
                    }
                    return .success
                } else {
                    print("❌ No path found from (\(attacker.coordinate.q), \(attacker.coordinate.r)) to enemy army at (\(targetCoordinate.q), \(targetCoordinate.r))")
                    return .failure(reason: "No path to target")
                }
            } else if let defenderVillagers = target.entity as? VillagerGroup {
                // Army-vs-villager combat
                // Use allowImpassableDestination to handle targets on enemy buildings
                if let path = hexMap.findPath(from: attacker.coordinate, to: targetCoordinate, for: attacker.entity.owner, allowImpassableDestination: true) {
                    print("⚔️ \(attackerArmy.name) attacking villagers at (\(targetCoordinate.q), \(targetCoordinate.r)) - path: \(path.count) steps")
                    attacker.moveTo(path: path) {
                        // Initiate villager combat when army arrives
                        print("⚔️ \(attackerArmy.name) arrived - attacking villagers!")
                        let combatTime = GameEngine.shared.gameState?.currentTime ?? 0
                        _ = GameEngine.shared.combatEngine.startVillagerCombat(
                            attackerArmyID: attackerArmy.id,
                            defenderVillagerGroupID: defenderVillagers.data.id,
                            currentTime: combatTime
                        )
                    }
                    return .success
                } else {
                    print("❌ No path found from (\(attacker.coordinate.q), \(attacker.coordinate.r)) to villagers at (\(targetCoordinate.q), \(targetCoordinate.r))")
                    return .failure(reason: "No path to target")
                }
            }
        }

        return .failure(reason: "No valid target found")
    }
}

