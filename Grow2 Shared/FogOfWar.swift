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
        
        // Reset all tiles to explored (if they were previously visible)
        for (coord, level) in visionMap {
            if level == .visible {
                // Save current state to memory before reducing visibility
                saveToMemory(coord)
                visionMap[coord] = .explored
            }
        }
        
        // Calculate vision from own entities and buildings
        updateVisionFromPlayer(player)
        
        // ✅ FIX: Calculate shared vision from allies/guild using diplomacy system
        for otherPlayer in allPlayers {
            guard otherPlayer.id != player.id else { continue }
            
            // Get diplomacy status from player's relations
            let status = player.getDiplomacyStatus(with: otherPlayer)
            
            // Share vision with guild and allies
            if status == .guild || status == .ally {
                print("👁️ Sharing vision with \(status.displayName): \(otherPlayer.name)")
                updateVisionFromPlayer(otherPlayer)
            }
        }
    }
    
    private func updateVisionFromPlayer(_ player: Player) {
        guard let hexMap = hexMap else { return }
        
        // Vision from buildings (2 tile radius - increased from 1)
        for building in player.buildings where building.state == .completed {
            let visibleTiles = getVisibleTilesInRadius(center: building.coordinate, radius: 2)
            for coord in visibleTiles {
                setVisible(coord)
            }
        }
        
        // Vision from entities (3 tile radius - increased from 2)
        for entity in player.entities {
            let coord: HexCoordinate
            if let army = entity as? Army {
                coord = army.coordinate
            } else if let villagers = entity as? VillagerGroup {
                coord = villagers.coordinate
            } else {
                continue
            }
            
            let visibleTiles = getVisibleTilesInRadius(center: coord, radius: 3)
            for coord in visibleTiles {
                setVisible(coord)
            }
        }
    }
    
    private func getVisibleTilesInRadius(center: HexCoordinate, radius: Int) -> [HexCoordinate] {
        guard let hexMap = hexMap else { return [] }
        
        var tiles: Set<HexCoordinate> = [center]
        
        // Use hex rings for accurate circular vision
        for r in 1...radius {
            let ring = getRing(center: center, radius: r)
            for coord in ring {
                if hexMap.isValidCoordinate(coord) {
                    tiles.insert(coord)
                }
            }
        }
        
        return Array(tiles)
    }
    
    private func getRing(center: HexCoordinate, radius: Int) -> [HexCoordinate] {
        guard radius > 0 else { return [center] }
        
        var results: [HexCoordinate] = []
        
        // Start at one corner of the ring
        var hex = HexCoordinate(q: center.q - radius, r: center.r + radius)
        
        // Six directions to walk around the ring
        let directions = [
            HexCoordinate(q: 1, r: 0),   // Right
            HexCoordinate(q: 1, r: -1),  // Up-right
            HexCoordinate(q: 0, r: -1),  // Up-left
            HexCoordinate(q: -1, r: 0),  // Left
            HexCoordinate(q: -1, r: 1),  // Down-left
            HexCoordinate(q: 0, r: 1)    // Down-right
        ]
        
        // Walk around the ring
        for direction in directions {
            for _ in 0..<radius {
                results.append(hex)
                hex = HexCoordinate(q: hex.q + direction.q, r: hex.r + direction.r)
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
        
        switch visibility {
        case .unexplored:
            return false
            
        case .explored:
            // Don't show any entities in explored (but not visible) areas
            return false
            
        case .visible:
            // Show all entities in visible areas
            return true
        }
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
}

enum BuildingDisplayMode {
    case hidden    // Don't show at all
    case memory    // Show last known state (no real-time updates)
    case current   // Show current real-time state
}
