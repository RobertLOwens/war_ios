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
    
    let commanderName: String
    let specialty: CommanderSpecialty
    
    static var commandType: CommandType { .recruitCommander }
    
    init(playerID: UUID, commanderName: String, specialty: CommanderSpecialty) {
        self.id = UUID()
        self.timestamp = Date().timeIntervalSince1970
        self.playerID = playerID
        self.commanderName = commanderName
        self.specialty = specialty
    }
    
    func validate(in context: CommandContext) -> CommandResult {
        guard let player = context.getPlayer(by: playerID) else {
            return .failure(reason: "Player not found")
        }
        
        // Check for completed city center
        let cityCenters = player.buildings.filter {
            $0.buildingType == .cityCenter &&
            $0.state == .completed
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
        
        // Find city center
        guard let cityCenter = player.buildings.first(where: {
            $0.buildingType == .cityCenter && $0.state == .completed
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
        
        // Create new commander
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
        entityNode.zPosition = 10
        
        // Add to hexMap tracking
        context.hexMap.addEntity(entityNode)
        
        // ADD VISUAL SPRITE TO SCENE
        context.gameScene?.entitiesNode.addChild(entityNode)
        
        // Add to player's tracking
        player.addArmy(army)
        player.addEntity(army)
        
        print("✅ Recruited commander \(newCommander.name) (\(specialty.displayName)) with army at (\(spawnCoord.q), \(spawnCoord.r))")
        
        return .success
    }
}
