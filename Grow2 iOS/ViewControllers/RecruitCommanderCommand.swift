// ============================================================================
// FILE: RecruitCommanderCommand.swift
// LOCATION: Grow2 Shared/Commands/RecruitCommanderCommand.swift (NEW FILE)
// PURPOSE: Command for recruiting new commanders
// ============================================================================

import Foundation
import SpriteKit
import UIKit

// MARK: - Recruit Commander Command

struct RecruitCommanderCommand: GameCommand {
    let id: UUID
    let timestamp: TimeInterval
    let playerID: UUID

    let specialty: CommanderSpecialty

    static var commandType: CommandType { .recruitCommander }

    init(playerID: UUID, specialty: CommanderSpecialty) {
        self.id = UUID()
        self.timestamp = Date().timeIntervalSince1970
        self.playerID = playerID
        self.specialty = specialty
    }
    
    func validate(in context: CommandContext) -> CommandResult {
        guard let player = context.getPlayer(by: playerID) else {
            return .failure(reason: "Player not found")
        }

        // Check army limit (recruiting creates an army)
        if let error = player.getArmySpawnError() {
            return .failure(reason: error)
        }

        // Check for operational city center (completed or upgrading)
        let cityCenters = player.buildings.filter {
            $0.buildingType == .cityCenter &&
            ($0.state == .completed || $0.state == .upgrading)
        }

        guard let cityCenter = cityCenters.first else {
            return .failure(reason: "No City Center found. Build one first!")
        }

        // Check if city center is occupied
        let spawnCoord = cityCenter.coordinate
        if context.hexMap.getEntity(at: spawnCoord) != nil {
            return .failure(reason: "City Center is occupied. Move units away first.")
        }

        return .success
    }
    
    func execute(in context: CommandContext) -> CommandResult {
        guard let player = context.getPlayer(by: playerID) else {
            return .failure(reason: "Player not found")
        }
        
        // Find city center (completed or upgrading)
        guard let cityCenter = player.buildings.first(where: {
            $0.buildingType == .cityCenter && ($0.state == .completed || $0.state == .upgrading)
        }) else {
            return .failure(reason: "No City Center found")
        }
        
        let spawnCoord = cityCenter.coordinate
        
        // Generate random color for commander portrait
        let randomColor = UIColor(
            red: CGFloat.random(in: 0.3...0.8),
            green: CGFloat.random(in: 0.3...0.8),
            blue: CGFloat.random(in: 0.3...0.8),
            alpha: 1.0
        )
        
        // Create new commander with random name
        let commanderName = Commander.randomName()
        let newCommander = Commander(
            name: commanderName,
            rank: .recruit,
            specialty: specialty,
            baseLeadership: Int.random(in: 8...12),
            baseTactics: Int.random(in: 8...12),
            portraitColor: randomColor
        )
        
        // Add to player
        player.addCommander(newCommander)
        
        // Create army for commander
        let army = Army(
            name: "\(newCommander.name)'s Army",
            coordinate: spawnCoord,
            commander: newCommander,
            owner: player
        )
        
        // Link commander to army
        newCommander.assignToArmy(army)

        // Set the city center as the army's home base
        army.setHomeBase(cityCenter.data.id)
        
        // Create entity node
        let entityNode = EntityNode(
            coordinate: spawnCoord,
            entityType: .army,
            entity: army,
            currentPlayer: player
        )
        
        // Set position and add to scene
        let position = HexMap.hexToPixel(q: spawnCoord.q, r: spawnCoord.r)
        entityNode.position = position
        
        // Add to hexMap tracking
        context.hexMap.addEntity(entityNode)
        
        // ADD VISUAL SPRITE TO SCENE
        context.gameScene?.entitiesNode.addChild(entityNode)

        // Register in visual layer
        context.gameScene?.visualLayer?.registerEntityNode(id: army.id, node: entityNode)

        // Add to player's tracking
        player.addArmy(army)
        player.addEntity(army)
        
        debugLog("✅ Recruited commander \(newCommander.name) (\(specialty.displayName)) with army at (\(spawnCoord.q), \(spawnCoord.r))")
        
        return .success
    }
}
