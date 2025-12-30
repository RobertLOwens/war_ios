import UIKit
import SpriteKit

// MARK: - Terrain Type

enum TerrainType {
    case grass
    case water
    case mountain
    case desert
    
    var color: UIColor {
        switch self {
        case .grass: return UIColor(red: 0.2, green: 0.7, blue: 0.2, alpha: 1.0)
        case .water: return UIColor(red: 0.2, green: 0.5, blue: 0.9, alpha: 1.0)
        case .mountain: return UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        case .desert: return UIColor(red: 0.9, green: 0.8, blue: 0.4, alpha: 1.0)
        }
    }
    
    var isWalkable: Bool {
        switch self {
        case .grass, .desert: return true
        case .water, .mountain: return false
        }
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
    
    static let hexRadius: CGFloat = 30
    
    init(coordinate: HexCoordinate, terrain: TerrainType) {
        self.coordinate = coordinate
        self.terrain = terrain
        super.init()
        
        self.path = HexTileNode.createHexagonPath(radius: HexTileNode.hexRadius)
        self.lineWidth = 2
        self.isUserInteractionEnabled = false
        updateAppearance()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateAppearance() {
        self.fillColor = terrain.color
        self.strokeColor = isSelected ? .yellow : UIColor(white: 0.3, alpha: 1.0)
        self.lineWidth = isSelected ? 4 : 2
    }
    
    static func createHexagonPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3.0 - .pi / 6.0
            let x = radius * cos(angle)
            let y = radius * sin(angle)
            
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
    var units: [UnitNode] = []
    var buildings: [BuildingNode] = []
    var entities: [EntityNode] = []
    let width: Int
    let height: Int
    var fogOverlays: [HexCoordinate: FogOverlayNode] = [:]

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
    
    func setupFogOverlays(in node: SKNode) {
        for (coord, _) in tiles {
            let overlay = FogOverlayNode(coordinate: coord)
            let position = HexMap.hexToPixel(q: coord.q, r: coord.r)
            overlay.position = position
            node.addChild(overlay)
            fogOverlays[coord] = overlay
        }
    }

    func updateFogOverlays(for player: Player) {
        for (coord, overlay) in fogOverlays {
            let visibility = player.getVisibilityLevel(at: coord)
            overlay.setVisibility(visibility)
        }
    }
    
    func generateMap(terrain: TerrainType = .grass) {
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
    
    func getUnit(at coordinate: HexCoordinate) -> UnitNode? {
        return units.first { $0.coordinate == coordinate }
    }
    
    func getBuilding(at coordinate: HexCoordinate) -> BuildingNode? {
        return buildings.first { $0.coordinate == coordinate }
    }
    
    func getEntity(at coordinate: HexCoordinate) -> EntityNode? {
        return entities.first { $0.coordinate == coordinate }
    }
    
    func canPlaceBuilding(at coordinate: HexCoordinate) -> Bool {
        guard isValidCoordinate(coordinate) && isWalkable(coordinate) else { return false }
        guard getBuilding(at: coordinate) == nil else { return false }
        return true
    }
    
    func addUnit(_ unit: UnitNode) {
        units.append(unit)
    }
    
    func removeUnit(_ unit: UnitNode) {
        units.removeAll { $0 === unit }
    }
    
    func addBuilding(_ building: BuildingNode) {
        buildings.append(building)
    }
    
    func removeBuilding(_ building: BuildingNode) {
        buildings.removeAll { $0 === building }
    }
    
    func addEntity(_ entity: EntityNode) {
        entities.append(entity)
    }
    
    func removeEntity(_ entity: EntityNode) {
        entities.removeAll { $0 === entity }
    }
    
    // MARK: - Pathfinding
    
    func findPath(from start: HexCoordinate, to goal: HexCoordinate) -> [HexCoordinate]? {
        guard isValidCoordinate(start) && isValidCoordinate(goal) else { return nil }
        guard isWalkable(goal) else { return nil }
        guard start != goal else { return [] }
        
        var frontier: [HexCoordinate] = [start]
        var cameFrom: [HexCoordinate: HexCoordinate] = [:]
        cameFrom[start] = start
        
        while !frontier.isEmpty {
            let current = frontier.removeFirst()
            
            if current == goal {
                break
            }
            
            for next in current.neighbors() {
                guard isValidCoordinate(next) && isWalkable(next) else { continue }
                
                if cameFrom[next] == nil {
                    frontier.append(next)
                    cameFrom[next] = current
                }
            }
        }
        
        guard cameFrom[goal] != nil else { return nil }
        
        var path: [HexCoordinate] = []
        var current = goal
        
        while current != start {
            path.append(current)
            guard let next = cameFrom[current] else { break }
            current = next
        }
        
        return path.reversed()
    }
    
    func findNearestWalkable(to target: HexCoordinate, maxDistance: Int = 5) -> HexCoordinate? {
        if isWalkable(target) && getEntity(at: target) == nil {
            return target
        }
        
        for distance in 1...maxDistance {
            let ring = getRing(center: target, radius: distance)
            for coord in ring {
                if isValidCoordinate(coord) && isWalkable(coord) && getEntity(at: coord) == nil {
                    return coord
                }
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
    
    // MARK: - Coordinate Conversion
    
    static func hexToPixel(q: Int, r: Int) -> CGPoint {
        let size = HexTileNode.hexRadius
        let sqrt3 = sqrt(3.0)
        
        let hexWidth = sqrt3 * size
        let hexHeight = 2.0 * size
        
        let horizontalSpacing = hexWidth
        let verticalSpacing = hexHeight * 0.75
        
        let xOffset = (r % 2 == 1) ? hexWidth / 2.0 : 0.0
        
        let x = CGFloat(q) * horizontalSpacing + xOffset
        let y = CGFloat(r) * verticalSpacing
        
        return CGPoint(x: x, y: y)
    }
    
    static func pixelToHex(point: CGPoint) -> HexCoordinate {
        let hexWidth = HexTileNode.hexRadius * sqrt(3.0)
        let hexHeight = HexTileNode.hexRadius * 2.0
        
        let r = Int(round(point.y / (hexHeight * 0.75)))
        let q = Int(round((point.x - CGFloat(r) * hexWidth * 0.5) / hexWidth))
        
        return HexCoordinate(q: q, r: r)
    }
}
