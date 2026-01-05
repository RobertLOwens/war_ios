import Foundation
import SpriteKit
import UIKit

// MARK: - Visibility Level

enum VisibilityLevel {
    case unexplored  // Never seen - completely black
    case explored    // Previously seen - shows terrain, last known buildings, no units
    case visible     // Currently visible - shows everything in real-time
    
    var fogAlpha: CGFloat {
        switch self {
        case .unexplored: return 1.0   // Completely black
        case .explored: return 0.6     // Semi-transparent dark overlay
        case .visible: return 0.0      // No fog
        }
    }
    
    var fogColor: UIColor {
        switch self {
        case .unexplored: return .black
        case .explored: return UIColor(white: 0.1, alpha: 1.0)
        case .visible: return .clear
        }
    }
}

// MARK: - Diplomatic Status

enum DiplomaticStatus {
    case self_       // The player themselves
    case guild       // Guild member - shares vision
    case ally        // Allied player - shares vision
    case neutral     // Neutral - no vision sharing
    case enemy       // Enemy - no vision sharing
    
    var sharesVision: Bool {
        switch self {
        case .self_, .guild, .ally: return true
        case .neutral, .enemy: return false
        }
    }
}

// MARK: - Tile Memory (for explored tiles)

struct TileMemory {
    let terrain: TerrainType
    var lastSeenBuilding: BuildingSnapshot?
    var lastSeenTime: TimeInterval
    
    init(terrain: TerrainType, lastSeenTime: TimeInterval) {
        self.terrain = terrain
        self.lastSeenTime = lastSeenTime
    }
}

struct BuildingSnapshot {
    let buildingType: BuildingType
    let ownerColor: UIColor?
    let coordinate: HexCoordinate
}

// MARK: - Fog of War Manager

class FogOfWarManager {
    
    private var visionMap: [HexCoordinate: VisibilityLevel] = [:]
    
    // Memory map: stores last known state of explored tiles
    private var memoryMap: [HexCoordinate: TileMemory] = [:]
    
    weak var player: Player?
    weak var hexMap: HexMap?
    
    init(player: Player, hexMap: HexMap) {
        self.player = player
        self.hexMap = hexMap
        
        // Initialize all tiles as unexplored
        initializeUnexploredMap()
    }
    
    private func initializeUnexploredMap() {
        guard let hexMap = hexMap else { return }
        
        for (coord, _) in hexMap.tiles {
            visionMap[coord] = .unexplored
        }
    }
    
    // MARK: - Vision Calculation
    
    func updateVision(allPlayers: [Player]) {
        guard let player = player, let hexMap = hexMap else { return }
        
        // ✅ FIX: Only mark CURRENTLY visible tiles as explored
        // Don't touch tiles that are already explored from save file
        for (coord, level) in visionMap {
            if level == .visible {
                // Save to memory before changing
                if memoryMap[coord] == nil {
                    saveToMemory(coord)
                }
                // Only mark as explored if we're about to lose visibility
                // This will be overwritten to .visible if still in range
                visionMap[coord] = .explored
            }
            // ✅ Don't touch .explored or .unexplored tiles
        }
        
        // Calculate vision from own entities and buildings
        updateVisionFromPlayer(player)
        
        // Calculate shared vision from allies/guild
        for otherPlayer in allPlayers {
            guard otherPlayer.id != player.id else { continue }
            
            let status = player.getDiplomacyStatus(with: otherPlayer)
            
            if status == .guild || status == .ally {
                updateVisionFromPlayer(otherPlayer)
            }
        }
    }
    
    private func updateVisionFromPlayer(_ player: Player) {
        guard let hexMap = hexMap else { return }
        
        // Vision from buildings (1 tile radius)
        var buildingVisionCount = 0
        for building in hexMap.buildings where building.state == .completed && building.owner?.id == player.id {
            let visibleTiles = getVisibleTilesInRadius(center: building.coordinate, radius: 1)
            buildingVisionCount += visibleTiles.count
            for coord in visibleTiles {
                setVisible(coord)
            }
        }
        
        // Vision from entities (2 tile radius)
        var entityVisionCount = 0
        for entity in hexMap.entities {
            guard entity.entity.owner?.id == player.id else { continue }
            
            let coord: HexCoordinate
            if let army = entity.entity as? Army {
                coord = army.coordinate
            } else if let villagers = entity.entity as? VillagerGroup {
                coord = villagers.coordinate
            } else {
                continue
            }
            
            let visibleTiles = getVisibleTilesInRadius(center: coord, radius: 2)
            entityVisionCount += visibleTiles.count
            for coord in visibleTiles {
                setVisible(coord)
            }
        }
    }

    
    private func getVisibleTilesInRadius(center: HexCoordinate, radius: Int) -> [HexCoordinate] {
        guard let hexMap = hexMap else { return [] }
        
        var tiles: [HexCoordinate] = []
        
        // Check each tile on the map
        for (coord, _) in hexMap.tiles {
            let dist = center.distance(to: coord)
            if dist <= radius {
                tiles.append(coord)
            }
        }
        
        return tiles
    }
    
    private func getRing(center: HexCoordinate, radius: Int) -> [HexCoordinate] {
        guard radius > 0 else { return [center] }
        
        var results: [HexCoordinate] = []
        
        // Convert center to axial coordinates
        let centerAxialQ = center.q - (center.r - (center.r & 1)) / 2
        let centerAxialR = center.r
        
        // Generate ring in axial space
        for dq in -radius...radius {
            let dr1 = max(-radius, -dq - radius)
            let dr2 = min(radius, -dq + radius)
            
            for dr in dr1...dr2 {
                if abs(dq) == radius || abs(dr) == radius || abs(dq + dr) == radius {
                    let axialQ = centerAxialQ + dq
                    let axialR = centerAxialR + dr
                    
                    // Convert back to offset coordinates
                    let offsetQ = axialQ + (axialR - (axialR & 1)) / 2
                    let offsetR = axialR
                    
                    let coord = HexCoordinate(q: offsetQ, r: offsetR)
                    if hexMap?.isValidCoordinate(coord) ?? false {
                        results.append(coord)
                    }
                }
            }
        }
        
        return results
    }
    
    private func getVisibleTiles(center: HexCoordinate, radius: Int) -> [HexCoordinate] {
        guard let hexMap = hexMap else { return [] }
        
        var tiles: [HexCoordinate] = [center]
        
        // ✅ FIX: Use proper distance calculation instead of ring-based approach
        for (coord, _) in hexMap.tiles {
            let distance = center.distance(to: coord)
            if distance <= radius && distance > 0 {  // Don't re-add center
                tiles.append(coord)
            }
        }
        
        return tiles.filter { hexMap.isValidCoordinate($0) }
    }
    
    private func setVisible(_ coord: HexCoordinate) {
        visionMap[coord] = .visible
        
        // Update memory with current state
        saveToMemory(coord)
    }
    
    private func saveToMemory(_ coord: HexCoordinate) {
        guard let hexMap = hexMap,
              let tile = hexMap.getTile(at: coord) else { return }
        
        let currentTime = Date().timeIntervalSince1970
        
        var memory = TileMemory(terrain: tile.terrain, lastSeenTime: currentTime)
        
        // Save building snapshot if present
        if let building = hexMap.getBuilding(at: coord) {
            memory.lastSeenBuilding = BuildingSnapshot(
                buildingType: building.buildingType,
                ownerColor: building.owner?.color,
                coordinate: coord
            )
        }
        
        memoryMap[coord] = memory
    }
    
    // MARK: - Vision Queries
    
    func getVisibilityLevel(at coord: HexCoordinate) -> VisibilityLevel {
        return visionMap[coord] ?? .unexplored
    }
    
    func isVisible(_ coord: HexCoordinate) -> Bool {
        return getVisibilityLevel(at: coord) == .visible
    }
    
    func isExplored(_ coord: HexCoordinate) -> Bool {
        let level = getVisibilityLevel(at: coord)
        return level == .explored || level == .visible
    }
    
    func getMemory(at coord: HexCoordinate) -> TileMemory? {
        return memoryMap[coord]
    }
    
    // MARK: - Entity/Building Filtering
    
    func shouldShowEntity(_ entity: MapEntity, at coord: HexCoordinate) -> Bool {
        guard let player = player else { return false }
        
        let visibility = getVisibilityLevel(at: coord)
        
        let shouldShow: Bool
        switch visibility {
        case .unexplored:
            shouldShow = false
            
        case .explored:
            // ✅ FIX: Don't show any entities in explored (but not visible) areas
            shouldShow = false
            
        case .visible:
            // Show all entities in visible areas
            shouldShow = true
        }
        
        // Debug logging
        if !shouldShow && entity.owner?.id == player.id {
            print("⚠️ Hiding own entity at (\(coord.q), \(coord.r)) - visibility: \(visibility)")
        }
        
        return shouldShow
    }
    
    func shouldShowBuilding(_ building: BuildingNode, at coord: HexCoordinate) -> BuildingDisplayMode {
        let visibility = getVisibilityLevel(at: coord)
        
        switch visibility {
        case .unexplored:
            return .hidden
            
        case .explored:
            // Show last known state from memory
            return .memory
            
        case .visible:
            return .current
        }
    }
    
    func markAsExplored(_ coord: HexCoordinate) {
        let previousState = visionMap[coord]
        visionMap[coord] = .explored
        
        // Also save to memory
        if let hexMap = hexMap, let tile = hexMap.getTile(at: coord) {
            let memory = TileMemory(terrain: tile.terrain, lastSeenTime: Date().timeIntervalSince1970)
            memoryMap[coord] = memory
        }
        
        // ✅ DEBUG: Log every 100th tile to avoid spam
        if coord.q % 10 == 0 && coord.r % 10 == 0 {
            print("  Marking (\(coord.q), \(coord.r)) as explored (was: \(previousState ?? .unexplored))")
        }
    }
    
    func getExploredCount() -> Int {
        return visionMap.filter { $0.value == .explored }.count
    }

    func getVisibleCount() -> Int {
        return visionMap.filter { $0.value == .visible }.count
    }

    func getUnexploredCount() -> Int {
        return visionMap.filter { $0.value == .unexplored }.count
    }

    func printFogStats() {
        print("📊 Fog of War Stats:")
        print("   Unexplored: \(getUnexploredCount())")
        print("   Explored: \(getExploredCount())")
        print("   Visible: \(getVisibleCount())")
        print("   Total: \(visionMap.count)")
    }

}

enum BuildingDisplayMode {
    case hidden    // Don't show at all
    case memory    // Show last known state (no real-time updates)
    case current   // Show current real-time state
}
