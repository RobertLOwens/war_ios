// ============================================================================
// FILE: Grow2 Shared/Commands/CancelReinforcementCommand.swift
// PURPOSE: Command to cancel marching reinforcements and return them to source
// ============================================================================

import Foundation

struct CancelReinforcementCommand: GameCommand {
    let id: UUID
    let timestamp: TimeInterval
    let playerID: UUID

    let reinforcementID: UUID

    static var commandType: CommandType { .cancelReinforcement }

    init(playerID: UUID, reinforcementID: UUID) {
        self.id = UUID()
        self.timestamp = Date().timeIntervalSince1970
        self.playerID = playerID
        self.reinforcementID = reinforcementID
    }

    func validate(in context: CommandContext) -> CommandResult {
        // Check player exists
        guard context.getPlayer(by: playerID) != nil else {
            return .failure(reason: "Player not found")
        }

        // Check reinforcement exists
        guard let gameScene = context.gameScene,
              let reinforcementNode = gameScene.getReinforcementNode(id: reinforcementID) else {
            return .failure(reason: "Reinforcement not found")
        }

        // Check player owns this reinforcement
        guard reinforcementNode.reinforcement.owner?.id == playerID else {
            return .failure(reason: "You don't own these reinforcements")
        }

        // Check not already cancelled
        guard !reinforcementNode.reinforcement.isCancelled else {
            return .failure(reason: "Reinforcement already cancelled")
        }

        return .success
    }

    func execute(in context: CommandContext) -> CommandResult {
        guard let gameScene = context.gameScene else {
            return .failure(reason: "Game scene not found")
        }

        gameScene.cancelReinforcement(id: reinforcementID)

        context.onAlert?("Reinforcements Recalled", "Units are returning to their garrison")

        return .success
    }
}
