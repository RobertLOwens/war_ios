import Foundation
import SpriteKit
import UIKit

// MARK: - Unit Type

enum UnitType {
    case soldier
    case tank
    case scout
    case villager
    case archer
    case cavalry
    case catapult
    
    var textureName: String {
        switch self {
        case .soldier: return "soldier"
        case .tank: return "tank"
        case .scout: return "scout"
        case .villager: return "villager"
        case .archer: return "archer"
        case .cavalry: return "cavalry"
        case .catapult: return "catapult"
        }
    }
    
    var icon: String {
        switch self {
        case .soldier: return "🪖"
        case .tank: return "🚂"
        case .scout: return "🔭"
        case .villager: return "👷"
        case .archer: return "🏹"
        case .cavalry: return "🐴"
        case .catapult: return "🎯"
        }
    }
    
    var displayName: String {
        switch self {
        case .soldier: return "Soldier"
        case .tank: return "Tank"
        case .scout: return "Scout"
        case .villager: return "Villager"
        case .archer: return "Archer"
        case .cavalry: return "Cavalry"
        case .catapult: return "Catapult"
        }
    }
    
    var moveSpeed: TimeInterval {
        switch self {
        case .soldier: return 0.3
        case .tank: return 0.5
        case .scout: return 0.2
        case .villager: return 0.4
        case .archer: return 0.35
        case .cavalry: return 0.25
        case .catapult: return 0.6
        }
    }
    
    var category: UnitCategory {
        switch self {
        case .villager:
            return .civilian
        case .soldier, .tank, .archer, .cavalry, .catapult, .scout:
            return .military
        }
    }
    
    var attackPower: Double {
        switch self {
        case .soldier: return 10
        case .archer: return 8
        case .cavalry: return 15
        case .tank: return 25
        case .catapult: return 30
        case .scout: return 5
        case .villager: return 1
        }
    }
    
    var defensePower: Double {
        switch self {
        case .soldier: return 8
        case .archer: return 5
        case .cavalry: return 10
        case .tank: return 30
        case .catapult: return 5
        case .scout: return 3
        case .villager: return 2
        }
    }
    
    var trainingCost: [ResourceType: Int] {
        switch self {
        case .soldier:
            return [.food: 50, .ore: 20]
        case .archer:
            return [.food: 40, .wood: 30]
        case .cavalry:
            return [.food: 80, .ore: 40]
        case .tank:
            return [.food: 100, .ore: 150]
        case .catapult:
            return [.wood: 100, .ore: 80]
        case .scout:
            return [.food: 30]
        case .villager:
            return [.food: 50]
        }
    }
    
    var trainingTime: TimeInterval {
        switch self {
        case .villager: return 15.0
        case .soldier: return 20.0
        case .archer: return 25.0
        case .scout: return 15.0
        case .cavalry: return 30.0
        case .tank: return 40.0
        case .catapult: return 35.0
        }
    }
}

// MARK: - Unit Category

enum UnitCategory {
    case civilian
    case military
}

// MARK: - Unit Node

class UnitNode: SKSpriteNode {
    var coordinate: HexCoordinate
    let unitType: UnitType
    var isMoving: Bool = false
    var movementPath: [HexCoordinate] = []
    
    init(coordinate: HexCoordinate, unitType: UnitType) {
        self.coordinate = coordinate
        self.unitType = unitType
        
        let texture = UnitNode.createUnitTexture(for: unitType)
        super.init(texture: texture, color: .clear, size: CGSize(width: 24, height: 24))
        
        self.zPosition = 10
        self.name = "unit"
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    static func createUnitTexture(for type: UnitType) -> SKTexture {
        let size = CGSize(width: 24, height: 24)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            
            let color: UIColor
            switch type {
            case .soldier:
                color = UIColor.blue
            case .tank:
                color = UIColor.red
            case .scout:
                color = UIColor.green
            case .villager:
                color = UIColor.orange
            case .archer:
                color = UIColor.purple
            case .cavalry:
                color = UIColor.brown
            case .catapult:
                color = UIColor.gray
            }
            
            color.setFill()
            context.cgContext.fillEllipse(in: rect.insetBy(dx: 2, dy: 2))
            
            UIColor.white.setStroke()
            context.cgContext.setLineWidth(2)
            context.cgContext.strokeEllipse(in: rect.insetBy(dx: 2, dy: 2))
            
            let icon: String
            switch type.category {
            case .civilian:
                icon = "👷"
            case .military:
                icon = "⚔️"
            }
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.white
            ]
            let iconString = NSAttributedString(string: icon, attributes: attributes)
            let iconSize = iconString.size()
            let iconRect = CGRect(
                x: (size.width - iconSize.width) / 2,
                y: (size.height - iconSize.height) / 2,
                width: iconSize.width,
                height: iconSize.height
            )
            iconString.draw(in: iconRect)
        }
        
        return SKTexture(image: image)
    }
    
    func moveTo(path: [HexCoordinate], completion: @escaping () -> Void) {
        guard !path.isEmpty else {
            completion()
            return
        }
        
        isMoving = true
        movementPath = path
        
        var actions: [SKAction] = []
        
        for coord in path {
            let position = HexMap.hexToPixel(q: coord.q, r: coord.r)
            let moveAction = SKAction.move(to: position, duration: unitType.moveSpeed)
            moveAction.timingMode = .easeInEaseOut
            actions.append(moveAction)
        }
        
        let sequence = SKAction.sequence(actions)
        
        run(sequence) { [weak self] in
            guard let self = self else { return }
            if let lastCoord = path.last {
                self.coordinate = lastCoord
            }
            self.isMoving = false
            self.movementPath = []
            completion()
        }
    }
}

// MARK: - Unit Group

class UnitGroup {
    let id: UUID
    var name: String
    private(set) var units: [UnitNode] = []
    weak var owner: Player?
    
    var formationType: FormationType = .cluster
    var spacing: CGFloat = 1.5
    
    init(name: String, units: [UnitNode] = [], owner: Player? = nil) {
        self.id = UUID()
        self.name = name
        self.units = units
        self.owner = owner
    }
    
    func addUnit(_ unit: UnitNode) {
        if !units.contains(where: { $0 === unit }) {
            units.append(unit)
            unit.group = self
        }
    }
    
    func removeUnit(_ unit: UnitNode) {
        units.removeAll { $0 === unit }
        if unit.group === self {
            unit.group = nil
        }
    }
    
    func removeAllUnits() {
        for unit in units {
            unit.group = nil
        }
        units.removeAll()
    }
    
    var isEmpty: Bool {
        return units.isEmpty
    }
    
    var count: Int {
        return units.count
    }
    
    var centerPosition: HexCoordinate? {
        guard !units.isEmpty else { return nil }
        
        let totalQ = units.reduce(0) { $0 + $1.coordinate.q }
        let totalR = units.reduce(0) { $0 + $1.coordinate.r }
        
        return HexCoordinate(
            q: totalQ / units.count,
            r: totalR / units.count
        )
    }
    
    func moveTo(destination: HexCoordinate, hexMap: HexMap, completion: @escaping () -> Void) {
        guard !units.isEmpty else {
            completion()
            return
        }
        
        let positions = formationType.calculatePositions(
            center: destination,
            unitCount: units.count,
            spacing: spacing
        )
        
        var completedMoves = 0
        let totalMoves = units.count
        
        for (index, unit) in units.enumerated() {
            guard index < positions.count else { continue }
            
            let targetPosition = positions[index]
            let validPosition = hexMap.findNearestWalkable(to: targetPosition) ?? targetPosition
            
            if let path = hexMap.findPath(from: unit.coordinate, to: validPosition) {
                unit.moveTo(path: path) {
                    completedMoves += 1
                    if completedMoves == totalMoves {
                        completion()
                    }
                }
            } else {
                completedMoves += 1
                if completedMoves == totalMoves {
                    completion()
                }
            }
        }
    }
    
    func getUnitCounts() -> [UnitType: Int] {
        var counts: [UnitType: Int] = [:]
        for unit in units {
            counts[unit.unitType, default: 0] += 1
        }
        return counts
    }
    
    func getAverageSpeed() -> TimeInterval {
        guard !units.isEmpty else { return 0 }
        let totalSpeed = units.reduce(0.0) { $0 + $1.unitType.moveSpeed }
        return totalSpeed / Double(units.count)
    }
    
    func getSlowestSpeed() -> TimeInterval {
        guard !units.isEmpty else { return 0 }
        return units.map { $0.unitType.moveSpeed }.max() ?? 0
    }
}

// MARK: - Formation Type

enum FormationType {
    case cluster
    case line
    case column
    case wedge
    case circle
    
    func calculatePositions(center: HexCoordinate, unitCount: Int, spacing: CGFloat) -> [HexCoordinate] {
        var positions: [HexCoordinate] = []
        
        switch self {
        case .cluster:
            positions = calculateClusterPositions(center: center, unitCount: unitCount)
        case .line:
            positions = calculateLinePositions(center: center, unitCount: unitCount)
        case .column:
            positions = calculateColumnPositions(center: center, unitCount: unitCount)
        case .wedge:
            positions = calculateWedgePositions(center: center, unitCount: unitCount)
        case .circle:
            positions = calculateCirclePositions(center: center, unitCount: unitCount)
        }
        
        return positions
    }
    
    private func calculateClusterPositions(center: HexCoordinate, unitCount: Int) -> [HexCoordinate] {
        var positions: [HexCoordinate] = [center]
        
        if unitCount == 1 {
            return positions
        }
        
        var ring = 1
        while positions.count < unitCount {
            let ringPositions = getHexRing(center: center, radius: ring)
            for pos in ringPositions {
                positions.append(pos)
                if positions.count >= unitCount {
                    break
                }
            }
            ring += 1
        }
        
        return Array(positions.prefix(unitCount))
    }
    
    private func calculateLinePositions(center: HexCoordinate, unitCount: Int) -> [HexCoordinate] {
        var positions: [HexCoordinate] = []
        let halfCount = unitCount / 2
        
        for i in 0..<unitCount {
            let offset = i - halfCount
            positions.append(HexCoordinate(q: center.q + offset, r: center.r))
        }
        
        return positions
    }
    
    private func calculateColumnPositions(center: HexCoordinate, unitCount: Int) -> [HexCoordinate] {
        var positions: [HexCoordinate] = []
        let halfCount = unitCount / 2
        
        for i in 0..<unitCount {
            let offset = i - halfCount
            positions.append(HexCoordinate(q: center.q, r: center.r + offset))
        }
        
        return positions
    }
    
    private func calculateWedgePositions(center: HexCoordinate, unitCount: Int) -> [HexCoordinate] {
        var positions: [HexCoordinate] = [center]
        
        if unitCount == 1 {
            return positions
        }
        
        var row = 1
        while positions.count < unitCount {
            let unitsInRow = row + 1
            for i in 0..<unitsInRow {
                if positions.count >= unitCount {
                    break
                }
                let offset = i - row / 2
                positions.append(HexCoordinate(q: center.q + offset, r: center.r - row))
            }
            row += 1
        }
        
        return Array(positions.prefix(unitCount))
    }
    
    private func calculateCirclePositions(center: HexCoordinate, unitCount: Int) -> [HexCoordinate] {
        if unitCount == 1 {
            return [center]
        }
        
        let radius = max(1, Int(ceil(sqrt(Double(unitCount)) / 2.0)))
        return Array(getHexRing(center: center, radius: radius).prefix(unitCount))
    }
    
    private func getHexRing(center: HexCoordinate, radius: Int) -> [HexCoordinate] {
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
}

// MARK: - UnitNode Group Extension

extension UnitNode {
    private static var groupKey: UInt8 = 0
    
    var group: UnitGroup? {
        get {
            return objc_getAssociatedObject(self, &UnitNode.groupKey) as? UnitGroup
        }
        set {
            objc_setAssociatedObject(self, &UnitNode.groupKey, newValue, .OBJC_ASSOCIATION_ASSIGN)
        }
    }
}
