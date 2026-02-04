// ============================================================================
// FILE: HexMap.swift
// PURPOSE: Visual layer for hex map (SpriteKit-based)
// NOTE: TerrainType is now defined in Data/MapData.swift and accessed via TypeAliases.swift
// ============================================================================

import UIKit
import SpriteKit

// MARK: - Terrain Visual Extensions

extension TerrainData {
    /// UIColor computed from colorHex (visual layer)
    var color: UIColor {
        return UIColor(hex: colorHex) ?? UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
    }

    /// Combat modifier struct for this terrain
    var combatModifier: TerrainCombatModifier {
        return TerrainCombatModifier(
            terrain: self,
            defenderDefenseBonus: defenderDefenseBonus,
            attackerAttackPenalty: attackerAttackPenalty
        )
    }
}

// MARK: - Terrain Combat Modifier

struct TerrainCombatModifier {
    let terrain: TerrainType
    let defenderDefenseBonus: Double    // e.g., 0.15 for +15%
    let attackerAttackPenalty: Double   // e.g., 0.10 for -10%

    var defenderMultiplier: Double { 1.0 + defenderDefenseBonus }
    var attackerMultiplier: Double { 1.0 - attackerAttackPenalty }

    var displayDescription: String {
        var parts: [String] = []
        if defenderDefenseBonus > 0 {
            parts.append("Defender +\(Int(defenderDefenseBonus * 100))% defense")
        } else if defenderDefenseBonus < 0 {
            parts.append("Defender \(Int(defenderDefenseBonus * 100))% defense")
        }
        if attackerAttackPenalty > 0 {
            parts.append("Attacker -\(Int(attackerAttackPenalty * 100))% attack")
        }
        return parts.isEmpty ? "No terrain effects" : parts.joined(separator: ", ")
    }
}

// MARK: - UIColor Hex Extension

extension UIColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}

// MARK: - Hex Tile Node

class HexTileNode: SKShapeNode {
    let coordinate: HexCoordinate
    var terrain: TerrainType {
        didSet {
            updateAppearance()
        }
    }
    var isSelected: Bool = false {
        didSet {
            updateAppearance()
        }
    }
    var elevation: Int = 0 {
        didSet {
            updateAppearance()
        }
    }

    static let hexRadius: CGFloat = 50

    // MARK: - Isometric Configuration
    /// Vertical compression ratio for isometric view (0.5 = 50% compression)
    static let isoRatio: CGFloat = 0.5

    /// Z-Position layer constants for isometric rendering
    enum ZLayer {
        static let terrain: CGFloat = 0
        static let resource: CGFloat = 100
        static let building: CGFloat = 200
        static let entity: CGFloat = 300
        static let fog: CGFloat = 1000
    }

    /// Calculates the z-position for isometric depth sorting
    /// Higher r (north on screen) renders behind lower r (south on screen)
    /// - Parameters:
    ///   - q: The q coordinate
    ///   - r: The r coordinate
    ///   - baseLayer: The base z-layer for this type of object
    /// - Returns: The z-position for correct depth sorting
    static func isometricZPosition(q: Int, r: Int, baseLayer: CGFloat) -> CGFloat {
        // Higher r values should render behind (lower z), lower r values in front (higher z)
        // We use a large constant minus the row to invert the order
        let maxRows: CGFloat = 200  // Support maps up to 200 rows
        let depthOrder = (maxRows - CGFloat(r)) + CGFloat(q) * 0.01
        return baseLayer + depthOrder
    }
    
    init(coordinate: HexCoordinate, terrain: TerrainType, elevation: Int = 0) {
        self.coordinate = coordinate
        self.terrain = terrain
        super.init()
        self.elevation = elevation

        self.path = HexTileNode.createHexagonPath(radius: HexTileNode.hexRadius)
        self.lineWidth = 2
        self.isUserInteractionEnabled = false

        // Set isometric z-position based on coordinate for depth sorting
        self.zPosition = HexTileNode.isometricZPosition(q: coordinate.q, r: coordinate.r, baseLayer: ZLayer.terrain)

        updateAppearance()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateAppearance() {
        // Apply elevation-based brightness adjustment
        var baseColor = terrain.color
        if elevation > 0 {
            // Lighten color for higher elevations (each level adds 10% brightness)
            let brightnessIncrease = CGFloat(elevation) * 0.1
            var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
            baseColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
            let newBrightness = min(1.0, brightness + brightnessIncrease)
            let newSaturation = max(0.3, saturation - brightnessIncrease * 0.3) // Slightly desaturate
            baseColor = UIColor(hue: hue, saturation: newSaturation, brightness: newBrightness, alpha: alpha)
        }
        self.fillColor = baseColor
        self.strokeColor = isSelected ? .yellow : UIColor(white: 0.3, alpha: 1.0)
        self.lineWidth = isSelected ? 4 : 2
    }
    
    static func createHexagonPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let isoRatio = HexTileNode.isoRatio

        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3.0 - .pi / 6.0
            let x = radius * cos(angle)
            let y = radius * sin(angle) * isoRatio  // Apply isometric compression

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()

        return path
    }
}

// MARK: - Hex Map

class HexMap {
    var tiles: [HexCoordinate: HexTileNode] = [:]
    var buildings: [BuildingNode] = []
    var entities: [EntityNode] = []
    var resourcePoints: [ResourcePointNode] = []  // ✅ NEW
    let width: Int
    let height: Int
    var fogOverlays: [HexCoordinate: FogOverlayNode] = [:]

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
    
    func setupFogOverlays(in node: SKNode) {
        // Clear existing overlays
        fogOverlays.removeAll()
        
        // Create fog overlay for each tile
        for (coord, _) in tiles {
            let overlay = FogOverlayNode(coordinate: coord)
            let position = HexMap.hexToPixel(q: coord.q, r: coord.r)
            overlay.position = position
            node.addChild(overlay)
            fogOverlays[coord] = overlay
        }
        
        print("✅ Created \(fogOverlays.count) fog overlays")
    }

    func updateFogOverlays(for player: Player) {
        for (coord, overlay) in fogOverlays {
            let visibility = player.getVisibilityLevel(at: coord)
            overlay.setVisibility(visibility)
        }
    }
    
    // Generate varied terrain with natural distribution
    func generateVariedTerrain() {
        tiles.removeAll()

        for r in 0..<height {
            for q in 0..<width {
                let coord = HexCoordinate(q: q, r: r)

                // Generate terrain with weighted randomness for natural distribution
                let rand = Double.random(in: 0...1)
                let terrain: TerrainType

                if rand < 0.70 {
                    terrain = .plains      // 70% plains (most common)
                } else if rand < 0.80 {
                    terrain = .hill        // 10% hill
                } else if rand < 0.90 {
                    terrain = .desert      // 10% desert
                } else if rand < 0.95 {
                    terrain = .mountain    // 5% mountain
                } else {
                    terrain = .water       // 5% water
                }

                let tile = HexTileNode(coordinate: coord, terrain: terrain)
                tiles[coord] = tile
            }
        }
    }
    
    // ✅ NEW METHOD: Spawn resources based on terrain type
    func spawnResources(scene: SKNode) {
        resourcePoints.removeAll()
        
        for (coord, tile) in tiles {
            // Skip if tile already has building or entity
            if getBuilding(at: coord) != nil { continue }
            if getEntity(at: coord) != nil { continue }
            
            let rand = Double.random(in: 0...1)
            var resourceType: ResourcePointType? = nil
            
            // Terrain-specific resource spawning
            switch tile.terrain {
            case .plains:
                if rand < 0.05 {
                    resourceType = .deer
                } else if rand < 0.07 {
                    resourceType = .wildBoar
                } else if rand < 0.10 {
                    resourceType = .forage
                } else if rand < 0.20 {
                    resourceType = .trees
                }

            case .mountain:
                if rand < 0.3 {
                    resourceType = .oreMine
                } else if rand < 0.4 {
                    resourceType = .stoneQuarry
                }

            case .hill:
                if rand < 0.15 {
                    resourceType = .trees
                } else if rand < 0.25 {
                    resourceType = .stoneQuarry
                } else if rand < 0.30 {
                    resourceType = .deer
                }

            default:
                break
            }
            
            if let resourceType = resourceType {
                let resourceNode = ResourcePointNode(coordinate: coord, resourceType: resourceType)
                let position = HexMap.hexToPixel(q: coord.q, r: coord.r)
                resourceNode.position = position
                resourcePoints.append(resourceNode)
                scene.addChild(resourceNode)
            }
        }
        
        print("✅ Spawned \(resourcePoints.count) resource points")
    }
    
    func generateMap(terrain: TerrainType = .plains) {
        tiles.removeAll()
        
        for r in 0..<height {
            for q in 0..<width {
                let coord = HexCoordinate(q: q, r: r)
                let tile = HexTileNode(coordinate: coord, terrain: terrain)
                tiles[coord] = tile
            }
        }
        
    }
    
    func getTile(at coordinate: HexCoordinate) -> HexTileNode? {
        return tiles[coordinate]
    }
    
    func isValidCoordinate(_ coord: HexCoordinate) -> Bool {
        return coord.q >= 0 && coord.q < width && coord.r >= 0 && coord.r < height
    }
    
    func isWalkable(_ coord: HexCoordinate) -> Bool {
        guard let tile = getTile(at: coord) else { return false }
        return tile.terrain.isWalkable
    }

    /// Check if a coordinate is passable for a specific player (considers walls/gates/forts)
    func isPassable(at coord: HexCoordinate, for requestingOwner: Player?) -> Bool {
        guard isWalkable(coord) else { return false }

        if let building = getBuilding(at: coord), building.state == .completed {
            switch building.buildingType {
            case .wall:
                return false  // Walls block everyone
            case .castle, .woodenFort:
                // Defensive structures block enemies and neutrals
                guard let fortOwner = building.owner,
                      let requestor = requestingOwner else { return false }
                let status = requestor.getDiplomacyStatus(with: fortOwner)
                return status.canMove  // true for .me, .guild, .ally
            case .gate:
                guard let gateOwner = building.owner,
                      let requestor = requestingOwner else { return false }
                let status = requestor.getDiplomacyStatus(with: gateOwner)
                return status.canMove  // true for .me, .guild, .ally
            default:
                break
            }
        }
        return true
    }
    
    func getBuilding(at coordinate: HexCoordinate) -> BuildingNode? {
        // First check anchor coordinates (fast path)
        if let building = buildings.first(where: { $0.coordinate == coordinate }) {
            return building
        }
        // Then check if any multi-tile building occupies this coordinate
        return buildings.first { $0.data.occupies(coordinate) }
    }
    
    func getEntity(at coordinate: HexCoordinate) -> EntityNode? {
        return entities.first { $0.coordinate == coordinate }
    }

    func getEntities(at coordinate: HexCoordinate) -> [EntityNode] {
        return entities.filter { $0.coordinate == coordinate }
    }

    // ✅ NEW METHOD
    func getResourcePoint(at coordinate: HexCoordinate) -> ResourcePointNode? {
        return resourcePoints.first { $0.coordinate == coordinate }
    }
    
    // ✅ NEW METHOD
    func removeResourcePoint(_ resource: ResourcePointNode) {
        resourcePoints.removeAll { $0 === resource }
    }

    /// Check if a coordinate has a road or building (buildings act as roads)
    func hasRoad(at coordinate: HexCoordinate) -> Bool {
        if let building = getBuilding(at: coordinate) {
            // All completed buildings provide road benefits
            return building.state == .completed
        }
        return false
    }

    /// Get the movement cost for a tile (lower = preferred in pathfinding)
    /// Roads have cost 1, terrain types have varying costs
    func getMovementCost(at coordinate: HexCoordinate) -> Int {
        if hasRoad(at: coordinate) {
            return 1  // Roads negate terrain penalty
        }
        guard let tile = getTile(at: coordinate) else {
            return 3
        }
        return tile.terrain.movementCost
    }

    /// Check if a single tile can have a building placed on it (no multi-tile calculation)
    func canPlaceBuildingOnTile(at coordinate: HexCoordinate) -> Bool {
        guard isValidCoordinate(coordinate) && isWalkable(coordinate) else { return false }
        guard getBuilding(at: coordinate) == nil else { return false }
        return true
    }

    func canPlaceBuilding(at coordinate: HexCoordinate, buildingType: BuildingType? = nil, rotation: Int = 0) -> Bool {
        guard let type = buildingType else {
            // Simple check without building type
            return canPlaceBuildingOnTile(at: coordinate)
        }

        // Get all coordinates this building would occupy
        let occupiedCoords = type.getOccupiedCoordinates(anchor: coordinate, rotation: rotation)

        // Check all tiles are valid for placement
        for coord in occupiedCoords {
            guard canPlaceBuildingOnTile(at: coord) else { return false }
        }

        // Mining camps and lumber camps CAN be placed on their required resource
        if type == .miningCamp {
            // Mining camp requires ore or stone resource at anchor
            if let resource = getResourcePoint(at: coordinate) {
                return resource.resourceType == .oreMine || resource.resourceType == .stoneQuarry
            }
            return false  // No valid resource here
        }
        if type == .lumberCamp {
            // Lumber camp requires trees at anchor
            if let resource = getResourcePoint(at: coordinate) {
                return resource.resourceType == .trees
            }
            return false  // No trees here
        }

        // Other buildings: allow on resources (will warn user and remove resource)
        return true
    }
    
    func hasCampCoverage(at coordinate: HexCoordinate, forResourceType resourceType: ResourcePointType) -> Bool {
        guard let requiredCampString = resourceType.requiredCampType else {
            return true  // No camp required for this resource type
        }

        // Check the tile itself and all neighbors within 1 tile
        let tilesToCheck = [coordinate] + coordinate.neighbors()

        for coord in tilesToCheck {
            if let building = getBuilding(at: coord),
               building.buildingType.rawValue == requiredCampString,
               building.state == .completed {
                return true
            }
        }

        return false
    }
    
    func getResourcesInCampRange(campCoordinate: HexCoordinate, campType: BuildingType) -> [ResourcePointNode] {
        let tilesToCheck = [campCoordinate] + campCoordinate.neighbors()
        var resources: [ResourcePointNode] = []
        
        for coord in tilesToCheck {
            if let resource = getResourcePoint(at: coord) {
                // Check if this resource type matches the camp type
                if campType == .lumberCamp && resource.resourceType == .trees {
                    resources.append(resource)
                } else if campType == .miningCamp &&
                          (resource.resourceType == .oreMine || resource.resourceType == .stoneQuarry) {
                    resources.append(resource)
                }
            }
        }
        
        return resources
    }
    
    func createCarcass(from huntedAnimal: ResourcePointNode, scene: SKNode) -> ResourcePointNode? {
        let carcassType: ResourcePointType
        
        switch huntedAnimal.resourceType {
        case .deer:
            carcassType = .deerCarcass
        case .wildBoar:
            carcassType = .boarCarcass
        default:
            return nil  // Not a huntable animal
        }
        
        // Create carcass with remaining food amount
        let carcass = ResourcePointNode(
            coordinate: huntedAnimal.coordinate,
            resourceType: carcassType
        )
        
        let position = HexMap.hexToPixel(q: huntedAnimal.coordinate.q, r: huntedAnimal.coordinate.r)
        carcass.position = position
        
        addResourcePoint(carcass)
        scene.addChild(carcass)

        print("✅ Created \(carcassType.displayName) at (\(huntedAnimal.coordinate.q), \(huntedAnimal.coordinate.r)) with \(huntedAnimal.remainingAmount) food")
        
        return carcass
    }
    
    func addBuilding(_ building: BuildingNode) {
        // Check for duplicates before adding
        guard !buildings.contains(where: { $0.data.id == building.data.id }) else {
            print("⚠️ Attempted to add duplicate building: \(building.buildingType.displayName) (ID: \(building.data.id))")
            return
        }
        buildings.append(building)
    }
    
    func removeBuilding(_ building: BuildingNode) {
        buildings.removeAll { $0 === building }
    }
    
    func addEntity(_ entity: EntityNode) {
        // ✅ FIX: Check for duplicates before adding
        guard !entities.contains(where: { $0.entity.id == entity.entity.id }) else {
            print("⚠️ Attempted to add duplicate entity: \(entity.entity.name) (ID: \(entity.entity.id))")
            return
        }
        entities.append(entity)
    }
    
    func removeEntity(_ entity: EntityNode) {
        entities.removeAll { $0 === entity }
    }
    
    // MARK: - Pathfinding

    /// Find a path from start to goal
    /// - Parameters:
    ///   - start: Starting coordinate
    ///   - goal: Target coordinate
    ///   - requestingOwner: The player requesting the path (for passability checks)
    ///   - allowImpassableDestination: If true, allows pathfinding to an impassable destination (for attacking buildings)
    ///   - targetBuilding: Optional target building (allows pathing through all tiles of an attacked building)
    func findPath(from start: HexCoordinate, to goal: HexCoordinate, for requestingOwner: Player? = nil, allowImpassableDestination: Bool = false, targetBuilding: BuildingNode? = nil) -> [HexCoordinate]? {
        guard isValidCoordinate(start) && isValidCoordinate(goal) else { return nil }

        // Check if destination is passable (unless we're allowing impassable destinations for attacks)
        let destinationPassable = isPassable(at: goal, for: requestingOwner)
        if !destinationPassable && !allowImpassableDestination {
            return nil
        }

        guard start != goal else { return [] }

        // A* pathfinding with road preference
        // Roads have lower movement cost, so paths will prefer roads when available
        var openSet: Set<HexCoordinate> = [start]
        var cameFrom: [HexCoordinate: HexCoordinate] = [:]

        var gScore: [HexCoordinate: Int] = [start: 0]
        // Heuristic uses minimum possible cost (1) to ensure admissibility
        var fScore: [HexCoordinate: Int] = [start: start.distance(to: goal)]

        while !openSet.isEmpty {
            // Find node in openSet with lowest fScore
            let current = openSet.min(by: { fScore[$0] ?? Int.max < fScore[$1] ?? Int.max })!

            if current == goal {
                // Reconstruct path
                var path: [HexCoordinate] = []
                var currentNode = goal

                while currentNode != start {
                    path.append(currentNode)
                    guard let next = cameFrom[currentNode] else { break }
                    currentNode = next
                }

                return path.reversed()
            }

            openSet.remove(current)

            for neighbor in current.neighbors() {
                // Allow the goal tile even if impassable (for attacking)
                let neighborPassable = isPassable(at: neighbor, for: requestingOwner)
                let isGoalTile = neighbor == goal && allowImpassableDestination
                let isTargetBuildingTile = targetBuilding?.data.occupies(neighbor) ?? false
                guard isValidCoordinate(neighbor) && (neighborPassable || isGoalTile || isTargetBuildingTile) else { continue }

                // Use movement cost based on whether tile has road
                let movementCost = getMovementCost(at: neighbor)
                let tentativeGScore = (gScore[current] ?? Int.max) + movementCost

                if tentativeGScore < (gScore[neighbor] ?? Int.max) {
                    cameFrom[neighbor] = current
                    gScore[neighbor] = tentativeGScore
                    // Heuristic: minimum cost per tile (1) * distance
                    fScore[neighbor] = tentativeGScore + neighbor.distance(to: goal)
                    openSet.insert(neighbor)
                }
            }
        }

        return nil // No path found
    }
        
    
    func findNearestWalkable(to target: HexCoordinate, maxDistance: Int = 5, for requestingOwner: Player? = nil) -> HexCoordinate? {
        // Check if target itself is passable and unoccupied
        if isPassable(at: target, for: requestingOwner) && getEntity(at: target) == nil && getBuilding(at: target) == nil {
            return target
        }

        // Search in expanding rings using proper hex distance
        for distance in 1...maxDistance {
            var candidates: [HexCoordinate] = []

            // Check all tiles on the map within this distance
            for (coord, _) in tiles {
                // Use proper hex distance calculation
                if coord.distance(to: target) == distance {
                    if isPassable(at: coord, for: requestingOwner) && getEntity(at: coord) == nil && getBuilding(at: coord) == nil {
                        candidates.append(coord)
                    }
                }
            }

            // Return closest candidate by actual distance
            if !candidates.isEmpty {
                return candidates.min(by: {
                    $0.distance(to: target) < $1.distance(to: target)
                })
            }
        }

        return nil
    }

    
    func getRing(center: HexCoordinate, radius: Int) -> [HexCoordinate] {
        if radius == 0 {
            return [center]
        }
        
        var results: [HexCoordinate] = []
        var hex = HexCoordinate(q: center.q - radius, r: center.r + radius)
        
        let directions = [
            HexCoordinate(q: 1, r: 0), HexCoordinate(q: 1, r: -1),
            HexCoordinate(q: 0, r: -1), HexCoordinate(q: -1, r: 0),
            HexCoordinate(q: -1, r: 1), HexCoordinate(q: 0, r: 1)
        ]
        
        for direction in directions {
            for _ in 0..<radius {
                results.append(hex)
                hex = HexCoordinate(q: hex.q + direction.q, r: hex.r + direction.r)
            }
        }
        
        return results
    }
    
    // MARK: - Coordinate Conversion (Isometric)

    static func hexToPixel(q: Int, r: Int) -> CGPoint {
        let size = HexTileNode.hexRadius
        let sqrt3 = sqrt(3.0)
        let isoRatio = HexTileNode.isoRatio

        let hexWidth = sqrt3 * size
        let hexHeight = 2.0 * size

        // Base horizontal spacing
        let horizontalSpacing = hexWidth

        // Isometric vertical spacing (compressed)
        let verticalSpacing = hexHeight * 0.75 * isoRatio

        // Offset for odd rows (standard hex offset)
        let oddRowOffset = (r % 2 == 1) ? hexWidth / 2.0 : 0.0

        // NO isometric skew - vertical compression alone creates isometric look
        let x = CGFloat(q) * horizontalSpacing + oddRowOffset
        let y = CGFloat(r) * verticalSpacing

        return CGPoint(x: x, y: y)
    }

    static func pixelToHex(point: CGPoint) -> HexCoordinate {
        let size = HexTileNode.hexRadius
        let sqrt3 = sqrt(3.0)
        let isoRatio = HexTileNode.isoRatio

        let hexWidth = sqrt3 * size
        let hexHeight = 2.0 * size
        let verticalSpacing = hexHeight * 0.75 * isoRatio

        // Estimate row first (no skew to reverse)
        let estimatedR = Int(round(point.y / verticalSpacing))

        // Calculate x offset for this row
        let oddRowOffset = (estimatedR % 2 == 1) ? hexWidth / 2.0 : 0.0
        let estimatedQ = Int(round((point.x - oddRowOffset) / hexWidth))

        // Best-match search around estimate
        var bestCoord = HexCoordinate(q: estimatedQ, r: estimatedR)
        var bestDistance = CGFloat.greatestFiniteMagnitude

        for dr in -1...1 {
            for dq in -1...1 {
                let testQ = estimatedQ + dq
                let testR = estimatedR + dr
                let testPos = hexToPixel(q: testQ, r: testR)
                let dx = point.x - testPos.x
                let dy = point.y - testPos.y
                let dist = dx * dx + dy * dy
                if dist < bestDistance {
                    bestDistance = dist
                    bestCoord = HexCoordinate(q: testQ, r: testR)
                }
            }
        }

        return bestCoord
    }
    
    func spawnResourcesWithDensity(scene: SKNode, densityMultiplier: Double) {
        resourcePoints.removeAll()
        
        for (coord, tile) in tiles {
            // Skip if tile already has building or entity
            if getBuilding(at: coord) != nil { continue }
            if getEntity(at: coord) != nil { continue }
            
            let rand = Double.random(in: 0...1)
            var resourceType: ResourcePointType? = nil
            
            // Apply density multiplier to spawn chances
            let densityAdjustedRand = rand / densityMultiplier
            
            // Terrain-specific resource spawning
            switch tile.terrain {
            case .plains:
                if densityAdjustedRand < 0.05 {
                    resourceType = .deer
                } else if densityAdjustedRand < 0.07 {
                    resourceType = .wildBoar
                } else if densityAdjustedRand < 0.10 {
                    resourceType = .forage
                } else if densityAdjustedRand < 0.20 {
                    resourceType = .trees
                }

            case .mountain:
                if densityAdjustedRand < 0.3 {
                    resourceType = .oreMine
                } else if densityAdjustedRand < 0.4 {
                    resourceType = .stoneQuarry
                }

            case .hill:
                if densityAdjustedRand < 0.15 {
                    resourceType = .trees
                } else if densityAdjustedRand < 0.25 {
                    resourceType = .stoneQuarry
                } else if densityAdjustedRand < 0.30 {
                    resourceType = .deer
                }

            default:
                break
            }
            
            if let resourceType = resourceType {
                let resourceNode = ResourcePointNode(coordinate: coord, resourceType: resourceType)
                let position = HexMap.hexToPixel(q: coord.q, r: coord.r)
                resourceNode.position = position
                resourcePoints.append(resourceNode)
                scene.addChild(resourceNode)
            }
        }
        
        print("✅ Spawned \(resourcePoints.count) resource points (density: \(densityMultiplier)x)")
    }
    
    func addResourcePoint(_ resource: ResourcePointNode) {
        // Clean up orphaned resource points (removed from scene but still in array)
        // This prevents crashes when iterating resourcePoints with stale nodes
        let validResources = resourcePoints.filter { $0.parent != nil }
        if validResources.count != resourcePoints.count {
            print("⚠️ Cleaning up \(resourcePoints.count - validResources.count) orphaned resource points")
            resourcePoints = validResources
        }

        // Check for duplicates at same coordinate
        guard !resourcePoints.contains(where: { $0.coordinate == resource.coordinate }) else {
            print("⚠️ Resource point already exists at (\(resource.coordinate.q), \(resource.coordinate.r))")
            return
        }
        resourcePoints.append(resource)
        print("✅ Added resource point: \(resource.resourceType.displayName) at (\(resource.coordinate.q), \(resource.coordinate.r))")
    }

    // MARK: - Adjacency Bonus Support

    /// Gets all buildings within a specified radius of a coordinate
    func getBuildingsNear(coordinate: HexCoordinate, radius: Int) -> [BuildingNode] {
        var nearbyBuildings: [BuildingNode] = []

        for building in buildings {
            // Check distance from any coordinate the building occupies
            for occupiedCoord in building.data.occupiedCoordinates {
                if occupiedCoord.distance(to: coordinate) <= radius {
                    if !nearbyBuildings.contains(where: { $0.data.id == building.data.id }) {
                        nearbyBuildings.append(building)
                    }
                    break
                }
            }
        }

        return nearbyBuildings
    }

    // MARK: - Garrison Defense Support

    /// Gets all enemy armies within a specified range of a coordinate for a given player
    /// Used by garrison defense to find targets for defensive fire
    func getEnemyArmiesInRange(of coordinate: HexCoordinate, range: Int, for player: Player) -> [Army] {
        var enemyArmies: [Army] = []

        for entity in entities {
            // Only consider army entities
            guard let entityArmy = entity.armyReference else { continue }

            // Check if this is an enemy (different owner)
            guard let entityOwner = entityArmy.owner, entityOwner.id != player.id else { continue }

            // Check if within range
            if entity.coordinate.distance(to: coordinate) <= range {
                enemyArmies.append(entityArmy)
            }
        }

        return enemyArmies
    }

    /// Gets all enemy armies within range of any coordinate a building occupies
    /// Accounts for multi-tile buildings like castles
    func getEnemyArmiesInRange(of building: BuildingNode, range: Int, for player: Player) -> [Army] {
        var enemyArmies: Set<UUID> = []
        var result: [Army] = []

        // Check from all coordinates the building occupies
        for coord in building.data.occupiedCoordinates {
            let armies = getEnemyArmiesInRange(of: coord, range: range, for: player)
            for army in armies {
                if !enemyArmies.contains(army.id) {
                    enemyArmies.insert(army.id)
                    result.append(army)
                }
            }
        }

        return result
    }

    // MARK: - Road-Extended Camp Coverage

    /// Uses BFS to find all coordinates reachable from a camp via connected roads
    /// Roads extend camp coverage for resource gathering
    func getExtendedCampReach(from campCoordinate: HexCoordinate) -> Set<HexCoordinate> {
        var reachableCoordinates: Set<HexCoordinate> = []
        var visited: Set<HexCoordinate> = []
        var queue: [HexCoordinate] = [campCoordinate]

        // Start with the camp's direct neighbors (always reachable)
        for neighbor in campCoordinate.neighbors() {
            reachableCoordinates.insert(neighbor)
        }
        reachableCoordinates.insert(campCoordinate)

        // BFS through connected roads
        while !queue.isEmpty {
            let current = queue.removeFirst()

            guard !visited.contains(current) else { continue }
            visited.insert(current)

            // Check all neighbors
            for neighbor in current.neighbors() {
                guard isValidCoordinate(neighbor) else { continue }

                // If neighbor has a road, it extends coverage
                if hasRoad(at: neighbor), !visited.contains(neighbor) {
                    // Add the road tile itself
                    reachableCoordinates.insert(neighbor)

                    // Add all neighbors of the road tile (resource can be gathered)
                    for roadNeighbor in neighbor.neighbors() {
                        reachableCoordinates.insert(roadNeighbor)
                    }

                    // Continue BFS through this road
                    queue.append(neighbor)
                }
            }
        }

        return reachableCoordinates
    }

    /// Checks if a coordinate can be reached by a matching camp via roads
    /// This allows resources to be gathered even if they're far from the camp
    func hasExtendedCampCoverage(at coordinate: HexCoordinate, forResourceType resourceType: ResourcePointType) -> Bool {
        guard let requiredCampString = resourceType.requiredCampType else {
            return true  // No camp required for this resource type
        }

        // Find all camps of the required type
        let matchingCamps = buildings.filter {
            $0.buildingType.rawValue == requiredCampString && $0.state == .completed
        }

        // Check if any camp can reach this coordinate via roads
        for camp in matchingCamps {
            let reachableCoords = getExtendedCampReach(from: camp.coordinate)
            if reachableCoords.contains(coordinate) {
                return true
            }
        }

        return false
    }

    /// Gets all resources that can be gathered by a specific camp, including road-extended reach
    func getResourcesInExtendedCampRange(campCoordinate: HexCoordinate, campType: BuildingType) -> [ResourcePointNode] {
        let reachableCoords = getExtendedCampReach(from: campCoordinate)
        var resources: [ResourcePointNode] = []

        for coord in reachableCoords {
            if let resource = getResourcePoint(at: coord) {
                // Check if this resource type matches the camp type
                if campType == .lumberCamp && resource.resourceType == .trees {
                    resources.append(resource)
                } else if campType == .miningCamp &&
                          (resource.resourceType == .oreMine || resource.resourceType == .stoneQuarry) {
                    resources.append(resource)
                }
            }
        }

        return resources
    }
}
