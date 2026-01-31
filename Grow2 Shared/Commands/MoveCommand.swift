// ============================================================================
// FILE: Grow2 Shared/Commands/MoveCommand.swift
// PURPOSE: Command to move an entity to a destination
// ============================================================================

import Foundation

struct MoveCommand: GameCommand {
    let id: UUID
    let timestamp: TimeInterval
    let playerID: UUID
    
    let entityID: UUID
    let destination: HexCoordinate
    
    static var commandType: CommandType { .move }
    
    init(playerID: UUID, entityID: UUID, destination: HexCoordinate) {
        self.id = UUID()
        self.timestamp = Date().timeIntervalSince1970
        self.playerID = playerID
        self.entityID = entityID
        self.destination = destination
    }
    
    func validate(in context: CommandContext) -> CommandResult {
        // Check player owns this entity
        guard let entity = context.getEntity(by: entityID) else {
            return .failure(reason: "Entity not found")
        }
        
        guard entity.entity.owner?.id == playerID else {
            return .failure(reason: "You don't own this entity")
        }
        
        // Check entity isn't busy
        if entity.isMoving {
            if let villagers = entity.entity as? VillagerGroup {
                switch villagers.currentTask {
                case .building(let building) where building.state != .completed:
                    return .failure(reason: "Villagers are busy building")
                case .gatheringResource:
                    return .failure(reason: "Villagers are busy gathering")
                case .hunting:
                    return .failure(reason: "Villagers are busy hunting")
                default:
                    break
                }
            }
        }

        // Check if army is in combat or awaiting reinforcements
        if let army = entity.entity as? Army {
            if GameEngine.shared.combatEngine.isInCombat(armyID: army.id) {
                return .failure(reason: "Cannot move while in combat")
            }
            if army.isAwaitingReinforcements {
                return .failure(reason: "Cannot move while reinforcements are en route")
            }

            // Check commander stamina
            if let commander = army.commander {
                if !commander.hasEnoughStamina() {
                    return .failure(reason: "Commander \(commander.name) is too exhausted! (Stamina: \(Int(commander.stamina))/\(Int(Commander.maxStamina)))")
                }
            }
        }

        // Check destination is valid
        guard context.hexMap.getTile(at: destination) != nil else {
            return .failure(reason: "Invalid destination")
        }
        
        // Check destination isn't blocked by enemy
        if let entityAtDest = context.hexMap.getEntity(at: destination) {
            let player = context.getPlayer(by: playerID)
            let diplomacy = player?.getDiplomacyStatus(with: entityAtDest.entity.owner) ?? .neutral
            if diplomacy == .enemy {
                return .failure(reason: "Cannot move onto enemy-occupied tile")
            }
        }
        
        // Check path exists (pass owner for wall/gate checks)
        guard context.hexMap.findPath(from: entity.coordinate, to: destination, for: entity.entity.owner) != nil else {
            return .failure(reason: "No valid path to destination")
        }

        return .success
    }
    
    func execute(in context: CommandContext) -> CommandResult {
        guard let entity = context.getEntity(by: entityID) else {
            return .failure(reason: "Entity not found")
        }

        // Find path and start movement (pass owner for wall/gate checks)
        guard let path = context.hexMap.findPath(from: entity.coordinate, to: destination, for: entity.entity.owner) else {
            return .failure(reason: "No valid path")
        }

        // Consume commander stamina for army movement
        if let army = entity.entity as? Army, let commander = army.commander {
            commander.consumeStamina()
        }

        entity.moveTo(path: path) {
            print("⚔️ \(String(describing: entity.name)) Moving")
        }

        print("🚶 Moving \(entity.entityType.displayName) to (\(destination.q), \(destination.r))")

        return .success
    }
}
