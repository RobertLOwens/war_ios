import Foundation
import SpriteKit
import UIKit

// MARK: - Building Category
enum BuildingCategory {
    case economic
    case military
    
    var displayName: String {
        switch self {
        case .economic: return "Economic"
        case .military: return "Military"
        }
    }
}

// MARK: - Building Type

enum BuildingType: String, CaseIterable, Codable {
    // Economic Buildings
    case cityCenter = "City Center"
    case farm = "Farm"
    case neighborhood = "Neighborhood"
    case blacksmith = "Blacksmith"
    case market = "Market"
    case miningCamp = "Mining Camp"
    case lumberCamp = "Lumber Camp"
    case warehouse = "Warehouse"
    case university = "University"
    case mill = "Mill"

    // Infrastructure
    case road = "Road"

    // Military Buildings
    case castle = "Castle"
    case barracks = "Barracks"
    case archeryRange = "Archery Range"
    case stable = "Stable"
    case siegeWorkshop = "Siege Workshop"
    case tower = "Tower"
    case woodenFort = "Wooden Fort"
    case wall = "Wall"
    case gate = "Gate"
    
    var displayName: String {
        return rawValue
    }
    
    var populationCapacity: Int {
        switch self {
        case .cityCenter: return 10
        case .neighborhood: return 5
        default: return 0
        }
    }
    
    var category: BuildingCategory {
        switch self {
        case .cityCenter, .farm, .neighborhood, .blacksmith, .market, .miningCamp, .lumberCamp, .warehouse, .university, .road, .mill:
            return .economic
        case .castle, .barracks, .archeryRange, .stable, .siegeWorkshop, .tower, .woodenFort, .wall, .gate:
            return .military
        }
    }
    
    var icon: String {
        switch self {
        case .cityCenter: return "🏛️"
        case .farm: return "🌾"
        case .neighborhood: return "🏘️"
        case .blacksmith: return "⚒️"
        case .market: return "🪙"
        case .miningCamp: return "⛏️"
        case .lumberCamp: return "🪓"
        case .warehouse: return "📦"
        case .university: return "🎓"
        case .road: return "🛤️"
        case .castle: return "🏰"
        case .barracks: return "🛡️"
        case .archeryRange: return "🏹"
        case .stable: return "🐴"
        case .siegeWorkshop: return "🎯"
        case .tower: return "🗼"
        case .woodenFort: return "🏰"
        case .mill: return "⚙️"
        case .wall: return "🧱"
        case .gate: return "🚪"
        }
    }

    var requiredCityCenterLevel: Int {
        switch self {
        case .cityCenter:
            return 1  // Always available (you start with one)
        case .neighborhood, .warehouse, .farm, .barracks, .road:
            return 1  // Tier 1
        case .archeryRange, .stable:
            return 2  // Tier 2
        case .market, .blacksmith, .tower:
            return 3  // Tier 3
        case .woodenFort:
            return 1  // Tier 4
        case .siegeWorkshop:
            return 5  // Tier 5
        case .castle:
            return 1  // Tier 6
        case .miningCamp, .lumberCamp:
            return 1  // Resource camps available early
        case .university:
            return 3  // Same as other advanced economic buildings
        case .mill:
            return 2  // Mills available at CC level 2
        case .wall, .gate:
            return 2  // Walls and gates available at CC level 2
        }
    }

    var buildCost: [ResourceType: Int] {
        switch self {
        case .cityCenter:
            return [.wood: 200, .stone: 150, .ore: 50]
        case .farm:
            return [.wood: 50, .stone: 20]
        case .neighborhood:
            return [.wood: 100, .stone: 80]
        case .blacksmith:
            return [.wood: 80, .stone: 60, .ore: 40]
        case .market:
            return [.wood: 100, .stone: 50]
        case .miningCamp:
            return [.wood: 100, .stone: 30]
        case .lumberCamp:
            return [.wood: 80, .stone: 20]
        case .warehouse:
            return [.wood: 120, .stone: 80]
        case .university:
            return [.wood: 150, .stone: 120, .ore: 60]
        case .road:
            return [.stone: 10]
        case .castle:
            return [.wood: 300, .stone: 400, .ore: 150]
        case .barracks:
            return [.wood: 150, .stone: 100]
        case .archeryRange:
            return [.wood: 120, .stone: 80]
        case .stable:
            return [.wood: 140, .stone: 90]
        case .siegeWorkshop:
            return [.wood: 180, .stone: 120, .ore: 80]
        case .tower:
            return [.wood: 80, .stone: 120]
        case .woodenFort:
            return [.wood: 200, .stone: 100]
        case .mill:
            return [.wood: 80, .stone: 40]
        case .wall:
            return [.wood: 30, .stone: 50]
        case .gate:
            return [.wood: 60, .stone: 40]
        }
    }

    var buildTime: TimeInterval {
        switch self {
        case .cityCenter: return 60.0
        case .farm: return 20.0
        case .neighborhood: return 35.0
        case .blacksmith: return 40.0
        case .market: return 30.0
        case .miningCamp: return 25.0
        case .lumberCamp: return 25.0
        case .warehouse: return 30.0
        case .university: return 50.0
        case .road: return 5.0  // Quick to build
        case .castle: return 90.0
        case .barracks: return 4.0
        case .archeryRange: return 35.0
        case .stable: return 35.0
        case .siegeWorkshop: return 45.0
        case .tower: return 30.0
        case .woodenFort: return 50.0
        case .mill: return 25.0
        case .wall: return 15.0
        case .gate: return 20.0
        }
    }

    var hexSize: Int {
        switch self {
        case .cityCenter: return 1  // City center is single tile
        case .castle, .woodenFort: return 3  // 3-tile wedge shape
        default: return 1
        }
    }

    /// Whether this building type requires rotation selection during placement
    var requiresRotation: Bool {
        return hexSize > 1
    }

    /// Returns the relative hex offsets for this building type at a given rotation
    /// NOTE: This returns offsets that work for even rows only. For actual coordinate
    /// calculation, use getOccupiedCoordinates() which handles odd-r offset coordinates.
    /// Rotation is 0-5 representing the 6 hex directions
    func getOccupiedOffsets(rotation: Int) -> [HexCoordinate] {
        guard hexSize > 1 else {
            return [HexCoordinate(q: 0, r: 0)]  // Single tile
        }

        // 3-tile wedge shape: anchor tile + 2 adjacent tiles
        // The shape looks like a triangle/wedge
        // Rotation determines which direction the wedge points

        // Directions are clockwise from East:
        // 0: East, 1: Southeast, 2: Southwest, 3: West, 4: Northwest, 5: Northeast
        // NOTE: Actual offsets depend on row parity in odd-r coordinates.
        // These offsets are for even rows only - use getOccupiedCoordinates() for accuracy.

        let directions: [(Int, Int)] = [
            (1, 0),   // 0: East
            (0, 1),   // 1: Southeast (even row)
            (-1, 1),  // 2: Southwest (even row)
            (-1, 0),  // 3: West
            (-1, -1), // 4: Northwest (even row)
            (0, -1)   // 5: Northeast (even row)
        ]

        let normalizedRotation = ((rotation % 6) + 6) % 6

        // Get two adjacent directions for the wedge
        let dir1 = directions[normalizedRotation]
        let dir2 = directions[(normalizedRotation + 1) % 6]

        return [
            HexCoordinate(q: 0, r: 0),  // Anchor tile
            HexCoordinate(q: dir1.0, r: dir1.1),  // First adjacent
            HexCoordinate(q: dir2.0, r: dir2.1)   // Second adjacent
        ]
    }

    /// Returns all coordinates this building would occupy at a given anchor position and rotation
    /// Uses proper odd-r offset coordinate neighbor calculation
    func getOccupiedCoordinates(anchor: HexCoordinate, rotation: Int) -> [HexCoordinate] {
        guard hexSize > 1 else {
            return [anchor]  // Single tile
        }

        // 3-tile wedge: anchor + two adjacent tiles in consecutive directions
        // Directions are clockwise from East:
        // 0: East, 1: Southeast, 2: Southwest, 3: West, 4: Northwest, 5: Northeast
        let normalizedRotation = ((rotation % 6) + 6) % 6
        let dir1 = normalizedRotation
        let dir2 = (normalizedRotation + 1) % 6

        return [
            anchor,
            anchor.neighbor(inDirection: dir1),
            anchor.neighbor(inDirection: dir2)
        ]
    }

    /// Returns a description of the current rotation for UI display
    /// Directions are clockwise from East:
    /// 0: East, 1: Southeast, 2: Southwest, 3: West, 4: Northwest, 5: Northeast
    static func rotationDescription(_ rotation: Int) -> String {
        let directions = ["East", "Southeast", "Southwest", "West", "Northwest", "Northeast"]
        let normalizedRotation = ((rotation % 6) + 6) % 6
        return "Pointing \(directions[normalizedRotation])"
    }
    
    var description: String {
        switch self {
        case .cityCenter: return "Main hub for economy and villagers"
        case .farm: return "Produces food resources"
        case .neighborhood: return "Houses population"
        case .blacksmith: return "Upgrades units and tools"
        case .market: return "Trade resources"
        case .miningCamp: return "Increases ore collection"
        case .lumberCamp: return "Increases wood collection"
        case .warehouse: return "Stores extra resources"
        case .university: return "Research technologies"
        case .road: return "Increases movement speed for units"
        case .castle: return "Defensive stronghold and military hub"
        case .barracks: return "Trains infantry units"
        case .archeryRange: return "Trains ranged units"
        case .stable: return "Trains cavalry units"
        case .siegeWorkshop: return "Builds siege weapons"
        case .tower: return "Defensive structure"
        case .woodenFort: return "Basic defensive structure"
        case .mill: return "Boosts adjacent farm gather rates by 25%"
        case .wall: return "Blocks all movement"
        case .gate: return "Allows passage for owner and allies"
        }
    }

    // Resource bonuses provided by this building
    var resourceBonus: [ResourceType: Double]? {
        switch self {
        case .farm: return [.food: 2.0]
        case .miningCamp: return [.ore: 1.5]
        case .lumberCamp: return [.wood: 1.5]
        default: return nil
        }
    }
    
    var maxLevel: Int {
        switch self {
        case .cityCenter: return 10
        case .road: return 1  // Roads don't upgrade
        case .wall, .gate: return 1  // Walls and gates don't upgrade
        default: return 5
        }
    }

    /// Whether this building type is a road (special handling for placement and pathfinding)
    var isRoad: Bool {
        return self == .road
    }

    /// Whether this building provides road benefits (roads + all other buildings)
    var providesRoadBonus: Bool {
        // All buildings act as roads, plus actual roads (except walls/gates)
        return self != .wall && self != .gate
    }

    /// Whether this building blocks movement (walls always, gates conditionally)
    var blocksMovement: Bool {
        return self == .wall || self == .gate
    }
        
    /// Returns the upgrade cost for a given level (upgrading FROM this level)
    func upgradeCost(forLevel level: Int) -> [ResourceType: Int]? {
        guard level < maxLevel else { return nil }
        
        // Base costs scale with level
        let multiplier = Double(level + 1)
        
        // Get base build cost and scale it
        var cost: [ResourceType: Int] = [:]
        for (resourceType, baseAmount) in buildCost {
            cost[resourceType] = Int(Double(baseAmount) * multiplier * 0.75)
        }
        
        return cost
    }
        
    /// Returns the upgrade time for a given level (upgrading FROM this level)
    func upgradeTime(forLevel level: Int) -> TimeInterval? {
        guard level < maxLevel else { return nil }
        
        // Upgrade time scales with level
        let multiplier = Double(level + 1)
        return buildTime * multiplier * 0.8
    }
    
    static func maxCastleLevel(forCityCenterLevel ccLevel: Int) -> Int {
        guard ccLevel >= 6 else { return 0 }  // Can't build castle below CC6
        return min(ccLevel - 5, 5)  // CC6=1, CC7=2, CC8=3, CC9=4, CC10=5
    }
    
    var baseStorageCapacityPerResource: Int {
        switch self {
        case .cityCenter: return 1200  // City center provides 1200 per resource type (accommodates starting resources of 1000)
        case .warehouse: return 150    // Each warehouse adds 150 per resource type
        default: return 0
        }
    }
    
    /// Storage capacity bonus per level (added to base)
    var storageCapacityPerLevelPerResource: Int {
        switch self {
        case .cityCenter: return 100   // +100 per resource per city center level
        case .warehouse: return 75     // +75 per resource per warehouse level
        default: return 0
        }
    }
    
    /// Returns the storage capacity for this building at a given level
    func storageCapacityPerResource(forLevel level: Int) -> Int {
        return baseStorageCapacityPerResource + (storageCapacityPerLevelPerResource * (level - 1))
    }
    
    /// Returns the maximum number of warehouses allowed for a given city center level
    static func maxWarehousesAllowed(forCityCenterLevel ccLevel: Int) -> Int {
        switch ccLevel {
        case 0..<2: return 0   // No warehouses until CC level 2
        case 2..<5: return 1   // 1 warehouse at CC level 2-4
        case 5..<8: return 2   // 2 warehouses at CC level 5-7
        default: return 3      // 3 warehouses at CC level 8+
        }
    }
    
    /// Returns the city center level required to build the Nth warehouse
    static func cityCenterLevelRequired(forWarehouseNumber warehouseNumber: Int) -> Int {
        switch warehouseNumber {
        case 1: return 2   // 1st warehouse requires CC level 2
        case 2: return 5   // 2nd warehouse requires CC level 5
        case 3: return 8   // 3rd warehouse requires CC level 8
        default: return 99 // No more than 3 allowed
        }
    }
}

enum BuildingState: String, Codable {
    case planning
    case constructing
    case completed
    case upgrading
    case demolishing
    case damaged
    case destroyed
}

// MARK: - Building Node

class BuildingNode: SKSpriteNode {

    /// The data model for this building - source of truth for all state
    let data: BuildingData
    let id: UUID = UUID()

    // MARK: - Entity References (not part of data - runtime only)
    weak var builderEntity: EntityNode?
    weak var upgraderEntity: EntityNode?
    weak var demolisherEntity: EntityNode?
    weak var owner: Player?  // Keep for convenience, derived from data.ownerID

    // MARK: - Pending States
    var pendingDemolition: Bool = false

    // MARK: - UI Elements
    var progressBar: SKShapeNode?
    var timerLabel: SKLabelNode?
    var buildingLabel: SKLabelNode?
    var levelLabel: SKLabelNode?
    var upgradeProgressBar: SKShapeNode?
    var upgradeTimerLabel: SKLabelNode?
    var pendingUpgrade: Bool = false
    var demolitionProgressBar: SKShapeNode?
    var demolitionTimerLabel: SKLabelNode?

    // Health bar UI elements (for combat)
    private var healthBarBackground: SKShapeNode?
    private var healthBarFill: SKShapeNode?
    private var isInCombat: Bool = false

    // Construction progress bar UI elements (styled like HP bar)
    private var constructionBarContainer: SKNode?
    private var constructionBarBackground: SKShapeNode?
    private var constructionBarFill: SKShapeNode?
    private var additionalConstructionBarContainers: [SKNode] = []
    private var additionalConstructionBarFills: [SKShapeNode] = []

    // Upgrade progress bar UI elements (styled like HP bar)
    private var upgradeBarContainer: SKNode?
    private var upgradeBarBackground: SKShapeNode?
    private var upgradeBarFill: SKShapeNode?
    private var additionalUpgradeBarContainers: [SKNode] = []
    private var additionalUpgradeBarFills: [SKShapeNode] = []

    // MARK: - Multi-Tile Visual Overlays
    private var tileOverlays: [SKShapeNode] = []
    private var hasCreatedTileOverlays: Bool = false

    // MARK: - Convenience Accessors (delegate to data)
    
    var buildingType: BuildingType { data.buildingType }
    var coordinate: HexCoordinate {
        get { data.coordinate }
        set { data.coordinate = newValue }
    }
    var state: BuildingState {
        get { data.state }
        set {
            let oldValue = data.state
            data.state = newValue
            if oldValue != newValue {
                updateAppearance()
            }
        }
    }
    var level: Int {
        get { data.level }
        set { data.level = newValue }
    }
    var health: Double {
        get { data.health }
        set { data.health = newValue }
    }
    var maxHealth: Double { data.maxHealth }
    var constructionProgress: Double {
        get { data.constructionProgress }
        set { data.constructionProgress = newValue }
    }
    var constructionStartTime: TimeInterval? {
        get { data.constructionStartTime }
        set { data.constructionStartTime = newValue }
    }
    var buildersAssigned: Int {
        get { data.buildersAssigned }
        set { data.buildersAssigned = newValue }
    }
    var upgradeProgress: Double {
        get { data.upgradeProgress }
        set { data.upgradeProgress = newValue }
    }
    var upgradeStartTime: TimeInterval? {
        get { data.upgradeStartTime }
        set { data.upgradeStartTime = newValue }
    }
    var demolitionProgress: Double {
        get { data.demolitionProgress }
        set { data.demolitionProgress = newValue }
    }
    var demolitionStartTime: TimeInterval? {
        get { data.demolitionStartTime }
        set { data.demolitionStartTime = newValue }
    }
    var demolishersAssigned: Int {
        get { data.demolishersAssigned }
        set { data.demolishersAssigned = newValue }
    }
    var canDemolish: Bool { data.canDemolish }
    var garrison: [MilitaryUnitType: Int] {
        get { data.garrison }
        set { data.garrison = newValue }
    }
    var villagerGarrison: Int {
        get { data.villagerGarrison }
        set { data.villagerGarrison = newValue }
    }
    var trainingQueue: [TrainingQueueEntry] {
        get { data.trainingQueue }
        set { data.trainingQueue = newValue }
    }
    var villagerTrainingQueue: [VillagerTrainingEntry] {
        get { data.villagerTrainingQueue }
        set { data.villagerTrainingQueue = newValue }
    }
    var isOperational: Bool { data.isOperational }
    var canUpgrade: Bool { data.canUpgrade }
    var maxLevel: Int { data.maxLevel }
    
    // MARK: - Initialization
    
    init(coordinate: HexCoordinate, buildingType: BuildingType, owner: Player? = nil, rotation: Int = 0) {
        // Create data model
        self.data = BuildingData(
            buildingType: buildingType,
            coordinate: coordinate,
            ownerID: owner?.id,
            rotation: rotation
        )
        self.owner = owner

        let texture = BuildingNode.createBuildingTexture(for: buildingType, state: .planning)
        let nodeSize = BuildingNode.getNodeSize(for: buildingType)
        super.init(texture: texture, color: .clear, size: nodeSize)

        // Set isometric z-position for depth sorting
        self.zPosition = HexTileNode.isometricZPosition(q: coordinate.q, r: coordinate.r, baseLayer: HexTileNode.ZLayer.building)
        self.name = "building"

        setupUI()
    }

    /// Initialize from existing data (used when loading saves)
    init(data: BuildingData, owner: Player? = nil) {
        self.data = data
        self.owner = owner

        let texture = BuildingNode.createBuildingTexture(for: data.buildingType, state: data.state)
        let nodeSize = BuildingNode.getNodeSize(for: data.buildingType)
        super.init(texture: texture, color: .clear, size: nodeSize)

        // Set isometric z-position for depth sorting
        self.zPosition = HexTileNode.isometricZPosition(q: data.coordinate.q, r: data.coordinate.r, baseLayer: HexTileNode.ZLayer.building)
        self.name = "building"

        setupUI()
        updateAppearance()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Data Logic Methods (delegate to BuildingData)
    
    func canTrain(_ unitType: MilitaryUnitType) -> Bool {
        return data.canTrain(unitType)
    }
    
    func canTrainVillagers() -> Bool {
        return data.canTrainVillagers()
    }
    
    func getTrainableUnits() -> [TrainableUnitType] {
        guard data.state == .completed else { return [] }
        
        var trainable: [TrainableUnitType] = []
        
        if canTrainVillagers() {
            trainable.append(.villager)
        }
        
        for unitType in MilitaryUnitType.allCases {
            if unitType.trainingBuilding == buildingType {
                trainable.append(.military(unitType))
            }
        }
        
        return trainable
    }
    
    func startTraining(unitType: MilitaryUnitType, quantity: Int, at time: TimeInterval) {
        data.startTraining(unitType: unitType, quantity: quantity, at: time)
        print("✅ Started training \(quantity)x \(unitType.displayName) in \(buildingType.displayName)")
    }
    
    func updateTraining(currentTime: TimeInterval) {
        let completed = data.updateTraining(currentTime: currentTime)
        for entry in completed {
            print("✅ Training complete: \(entry.quantity)x \(entry.unitType.displayName)")
        }
    }
    
    func startVillagerTraining(quantity: Int, at time: TimeInterval) {
        data.startVillagerTraining(quantity: quantity, at: time)
        print("✅ Started training \(quantity)x Villagers in \(buildingType.displayName)")
    }
    
    func updateVillagerTraining(currentTime: TimeInterval) {
        let completed = data.updateVillagerTraining(currentTime: currentTime)
        for entry in completed {
            print("✅ Villager training complete: \(entry.quantity) villagers")
        }
    }
    
    func addToGarrison(unitType: MilitaryUnitType, quantity: Int) {
        data.addToGarrison(unitType: unitType, quantity: quantity)
        print("✅ \(buildingType.displayName) garrison: +\(quantity)x \(unitType.displayName)")
    }
    
    func removeFromGarrison(unitType: MilitaryUnitType, quantity: Int) -> Int {
        let removed = data.removeFromGarrison(unitType: unitType, quantity: quantity)
        if removed > 0 {
            print("✅ Removed \(removed)x \(unitType.displayName) from \(buildingType.displayName) garrison")
        }
        return removed
    }
    
    func addVillagersToGarrison(quantity: Int) {
        data.addVillagersToGarrison(quantity: quantity)
        print("✅ \(buildingType.displayName) garrison: +\(quantity) villagers")
    }
    
    func removeVillagersFromGarrison(quantity: Int) -> Int {
        let removed = data.removeVillagersFromGarrison(quantity: quantity)
        if removed > 0 {
            print("✅ Removed \(removed) villagers from \(buildingType.displayName) garrison")
        }
        return removed
    }
    
    func getTotalGarrisonedUnits() -> Int { data.getTotalGarrisonedUnits() }
    func getTotalGarrisonCount() -> Int { data.getTotalGarrisonCount() }
    func getGarrisonCapacity() -> Int { data.getGarrisonCapacity() }
    func hasGarrisonSpace(for count: Int) -> Bool { data.hasGarrisonSpace(for: count) }
    func getGarrisonCount(of unitType: MilitaryUnitType) -> Int { data.garrison[unitType] ?? 0 }
    func hasGarrisonedUnits() -> Bool { data.getTotalGarrisonedUnits() > 0 }
    
    func getUpgradeCost() -> [ResourceType: Int]? { data.getUpgradeCost() }
    func getUpgradeTime() -> TimeInterval? { data.getUpgradeTime() }
    
    func startConstruction(builders: Int = 1) {
        data.startConstruction(builders: builders)
        updateAppearance()
        print("🏗️ Started construction of \(buildingType.displayName)")
    }
    
    func startUpgrade() {
        data.startUpgrade()
        print("⬆️ Started upgrading \(buildingType.displayName) to level \(level + 1)")
        updateAppearance()
        updateLevelLabel()
    }
    
    func completeUpgrade() {
        data.completeUpgrade()

        // Remove upgrade UI elements
        upgradeTimerLabel?.removeFromParent()
        upgradeTimerLabel = nil
        upgradeProgressBar?.removeFromParent()
        upgradeProgressBar = nil
        removeUpgradeBar()
        
        // Unlock the upgrader entity
        if let upgrader = upgraderEntity {
            upgrader.isMoving = false
            if let villagerGroup = upgrader.entity as? VillagerGroup {
                villagerGroup.clearTask()
            }
        }
        upgraderEntity = nil
        
        print("🎉 UPGRADE COMPLETE: \(buildingType.displayName) → Lv.\(level)")
        
        updateAppearance()
        updateLevelLabel()
        NotificationCenter.default.post(name: .buildingDidComplete, object: self)
    }
    
    func cancelUpgrade() -> [ResourceType: Int]? {
        let refund = data.cancelUpgrade()

        // Remove upgrade UI elements
        upgradeTimerLabel?.removeFromParent()
        upgradeTimerLabel = nil
        upgradeProgressBar?.removeFromParent()
        upgradeProgressBar = nil
        removeUpgradeBar()

        // Unlock the upgrader entity
        if let upgrader = upgraderEntity {
            upgrader.isMoving = false
            if let villagerGroup = upgrader.entity as? VillagerGroup {
                villagerGroup.clearTask()
            }
        }
        upgraderEntity = nil

        updateAppearance()
        updateLevelLabel()
        print("🚫 Upgrade cancelled for \(buildingType.displayName)")

        return refund
    }

    // MARK: - Demolition Methods

    func startDemolition(demolishers: Int = 1) {
        data.startDemolition(demolishers: demolishers)
        print("🏚️ Started demolition of \(buildingType.displayName)")
        updateAppearance()
    }

    func cancelDemolition() {
        data.cancelDemolition()

        // Remove demolition UI elements
        demolitionTimerLabel?.removeFromParent()
        demolitionTimerLabel = nil
        demolitionProgressBar?.removeFromParent()
        demolitionProgressBar = nil

        // Unlock the demolisher entity
        if let demolisher = demolisherEntity {
            demolisher.isMoving = false
            if let villagerGroup = demolisher.entity as? VillagerGroup {
                villagerGroup.clearTask()
            }
        }
        demolisherEntity = nil
        pendingDemolition = false

        updateAppearance()
        print("🚫 Demolition cancelled for \(buildingType.displayName)")
    }

    /// Returns the resources to refund after demolition
    func completeDemolition() -> [ResourceType: Int] {
        let refund = data.getDemolitionRefund()

        // Remove demolition UI elements
        demolitionTimerLabel?.removeFromParent()
        demolitionTimerLabel = nil
        demolitionProgressBar?.removeFromParent()
        demolitionProgressBar = nil

        // Unlock the demolisher entity
        if let demolisher = demolisherEntity {
            demolisher.isMoving = false
            if let villagerGroup = demolisher.entity as? VillagerGroup {
                villagerGroup.clearTask()
            }
        }
        demolisherEntity = nil

        print("🏚️ Demolition complete: \(buildingType.displayName) - refunding resources")

        return refund
    }

    func updateDemolitionTimerLabel() {
        guard state == .demolishing else {
            // Remove demolition UI if not demolishing
            demolitionTimerLabel?.removeFromParent()
            demolitionTimerLabel = nil
            demolitionProgressBar?.removeFromParent()
            demolitionProgressBar = nil
            return
        }

        guard let startTime = demolitionStartTime else { return }

        let currentTime = Date().timeIntervalSince1970
        let elapsed = currentTime - startTime

        let demolisherMultiplier = 1.0 + (Double(demolishersAssigned - 1) * 0.5)
        let effectiveDemolitionTime = data.getDemolitionTime() / demolisherMultiplier
        let remaining = max(0, effectiveDemolitionTime - elapsed)

        let newProgress = min(1.0, max(0.0, elapsed / effectiveDemolitionTime))

        // Check completion - handled by GameScene update loop
        if newProgress >= 1.0 || remaining <= 0 {
            return
        }

        demolitionProgress = newProgress

        // Create timer label if needed
        if demolitionTimerLabel == nil {
            demolitionTimerLabel = SKLabelNode(fontNamed: "Menlo-Bold")
            demolitionTimerLabel?.fontSize = 6
            demolitionTimerLabel?.fontColor = .orange
            demolitionTimerLabel?.position = CGPoint(x: 0, y: -15)
            demolitionTimerLabel?.zPosition = 15
            demolitionTimerLabel?.name = "demolitionTimerLabel"
            addChild(demolitionTimerLabel!)
        }

        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        demolitionTimerLabel?.text = "🏚️ \(minutes):\(String(format: "%02d", seconds))"

        // Update progress bar
        demolitionProgressBar?.removeFromParent()

        let barWidth: CGFloat = 22
        let barHeight: CGFloat = 3
        let progressWidth = max(1.0, barWidth * CGFloat(newProgress))

        demolitionProgressBar = SKShapeNode(rectOf: CGSize(width: progressWidth, height: barHeight), cornerRadius: 1.5)
        demolitionProgressBar?.fillColor = .orange
        demolitionProgressBar?.strokeColor = .white
        demolitionProgressBar?.lineWidth = 0.5
        demolitionProgressBar?.position = CGPoint(x: -barWidth/2 + progressWidth/2, y: -20)
        demolitionProgressBar?.zPosition = 15
        demolitionProgressBar?.name = "demolitionProgressBar"
        addChild(demolitionProgressBar!)
    }

    func takeDamage(_ amount: Double) {
        data.takeDamage(amount)
        updateAppearance()
        updateHealthBar()
    }

    func repair(_ amount: Double) {
        data.repair(amount)
        updateAppearance()
        updateHealthBar()
    }

    // MARK: - Health Bar (for Combat)

    // Container node for health bar (allows rotation)
    private var healthBarContainer: SKNode?
    // Additional health bar containers for multi-tile buildings
    private var additionalHealthBarContainers: [SKNode] = []
    private var additionalHealthBarFills: [SKShapeNode] = []

    /// Sets up the health bar for combat visualization
    /// Positioned along the bottom-right edge of the hex tile, spanning full edge length
    /// For multi-tile buildings (castle, fort), creates health bars on all tiles
    func setupHealthBar() {
        // Guard against duplicate health bars
        if healthBarBackground != nil && healthBarFill != nil {
            return
        }

        let barHeight: CGFloat = 3  // Thinner bar

        // Calculate position along bottom-right hex edge
        // Hex vertices (pointy-top with iso compression):
        // Vertex 5 (bottom): angle = -π/2, pos = (0, -radius * isoRatio)
        // Vertex 0 (bottom-right): angle = -π/6, pos = (radius * √3/2, -radius * 0.5 * isoRatio)
        let hexRadius: CGFloat = HexTileNode.hexRadius
        let isoRatio = HexTileNode.isoRatio

        // Bottom vertex (vertex 5)
        let bottomX: CGFloat = 0
        let bottomY: CGFloat = -hexRadius * isoRatio

        // Bottom-right vertex (vertex 0)
        let bottomRightX: CGFloat = hexRadius * cos(-CGFloat.pi / 6)  // ≈ radius * 0.866
        let bottomRightY: CGFloat = hexRadius * sin(-CGFloat.pi / 6) * isoRatio  // ≈ -radius * 0.5 * isoRatio

        // Calculate full edge length
        let edgeDx = bottomRightX - bottomX
        let edgeDy = bottomRightY - bottomY
        let barWidth: CGFloat = sqrt(edgeDx * edgeDx + edgeDy * edgeDy)

        // Midpoint of bottom-right edge
        let edgeMidX = (bottomX + bottomRightX) / 2
        let edgeMidY = (bottomY + bottomRightY) / 2

        // Offset inward towards center of tile
        let inwardOffset: CGFloat = 5
        let distToCenter = sqrt(edgeMidX * edgeMidX + edgeMidY * edgeMidY)
        let midX = edgeMidX - (edgeMidX / distToCenter) * inwardOffset
        let midY = edgeMidY - (edgeMidY / distToCenter) * inwardOffset

        // Calculate angle of the edge for rotation
        let edgeAngle = atan2(bottomRightY - bottomY, bottomRightX - bottomX)

        // Create container node for rotation (anchor tile)
        healthBarContainer = SKNode()
        healthBarContainer?.position = CGPoint(x: midX, y: midY)
        healthBarContainer?.zRotation = edgeAngle
        healthBarContainer?.zPosition = 1
        addChild(healthBarContainer!)

        // Background (dark) - centered at origin of container, with white outline
        let bgRect = CGRect(x: -barWidth/2, y: -barHeight/2, width: barWidth, height: barHeight)
        healthBarBackground = SKShapeNode(rect: bgRect, cornerRadius: 1)
        healthBarBackground?.fillColor = UIColor(white: 0.2, alpha: 0.8)
        healthBarBackground?.strokeColor = .white
        healthBarBackground?.lineWidth = 1
        healthBarBackground?.zPosition = 1
        healthBarContainer?.addChild(healthBarBackground!)

        // Fill (starts green, changes with health) - left-aligned within bar
        let fillRect = CGRect(x: -barWidth/2, y: -barHeight/2, width: barWidth, height: barHeight)
        healthBarFill = SKShapeNode(rect: fillRect, cornerRadius: 1)
        healthBarFill?.fillColor = UIColor(red: 0.3, green: 0.7, blue: 0.3, alpha: 1.0)
        healthBarFill?.strokeColor = .clear
        healthBarFill?.zPosition = 2
        healthBarContainer?.addChild(healthBarFill!)

        // For multi-tile buildings, create health bars on additional tiles
        let isMultiTile = buildingType == .castle || buildingType == .woodenFort
        if isMultiTile {
            let occupiedCoords = getOccupiedCoordinates()
            let anchorPixelPos = HexMap.hexToPixel(q: coordinate.q, r: coordinate.r)

            // Skip the first coordinate (anchor tile - already has a health bar)
            for tileCoord in occupiedCoords.dropFirst() {
                let tilePixelPos = HexMap.hexToPixel(q: tileCoord.q, r: tileCoord.r)
                // Calculate offset from anchor to this tile
                let offsetX = tilePixelPos.x - anchorPixelPos.x
                let offsetY = tilePixelPos.y - anchorPixelPos.y

                // Create container at the offset position + health bar edge offset
                let container = SKNode()
                container.position = CGPoint(x: offsetX + midX, y: offsetY + midY)
                container.zRotation = edgeAngle
                container.zPosition = 1
                addChild(container)
                additionalHealthBarContainers.append(container)

                // Background with white outline
                let bg = SKShapeNode(rect: bgRect, cornerRadius: 1)
                bg.fillColor = UIColor(white: 0.2, alpha: 0.8)
                bg.strokeColor = .white
                bg.lineWidth = 1
                bg.zPosition = 1
                container.addChild(bg)

                // Fill
                let fill = SKShapeNode(rect: fillRect, cornerRadius: 1)
                fill.fillColor = UIColor(red: 0.3, green: 0.7, blue: 0.3, alpha: 1.0)
                fill.strokeColor = .clear
                fill.zPosition = 2
                container.addChild(fill)
                additionalHealthBarFills.append(fill)
            }
        }

        isInCombat = true
        updateHealthBar()
    }

    /// Updates the health bar fill based on current health
    func updateHealthBar() {
        guard let fill = healthBarFill else { return }

        let percentage = CGFloat(health / max(maxHealth, 1))
        let hexRadius: CGFloat = HexTileNode.hexRadius
        let isoRatio = HexTileNode.isoRatio

        // Match setupHealthBar dimensions - full edge length
        let bottomRightX: CGFloat = hexRadius * cos(-CGFloat.pi / 6)
        let bottomRightY: CGFloat = hexRadius * sin(-CGFloat.pi / 6) * isoRatio
        let bottomY: CGFloat = -hexRadius * isoRatio
        let edgeDx = bottomRightX
        let edgeDy = bottomRightY - bottomY
        let fullWidth: CGFloat = sqrt(edgeDx * edgeDx + edgeDy * edgeDy)
        let barHeight: CGFloat = 3

        // Update fill width based on health percentage (left-aligned)
        let barWidth = fullWidth * max(0, min(1, percentage))
        let fillRect = CGRect(x: -fullWidth/2, y: -barHeight/2, width: barWidth, height: barHeight)
        fill.path = CGPath(roundedRect: fillRect, cornerWidth: 1, cornerHeight: 1, transform: nil)

        // Determine fill color based on health percentage
        let fillColor: UIColor
        if percentage > 0.6 {
            fillColor = UIColor(red: 0.3, green: 0.7, blue: 0.3, alpha: 1.0) // Green
        } else if percentage > 0.3 {
            fillColor = UIColor(red: 0.9, green: 0.7, blue: 0.2, alpha: 1.0) // Yellow/Orange
        } else {
            fillColor = UIColor(red: 0.9, green: 0.3, blue: 0.2, alpha: 1.0) // Red
        }
        fill.fillColor = fillColor

        // Update additional health bars for multi-tile buildings
        for additionalFill in additionalHealthBarFills {
            additionalFill.path = CGPath(roundedRect: fillRect, cornerWidth: 1, cornerHeight: 1, transform: nil)
            additionalFill.fillColor = fillColor
        }
    }

    /// Marks combat as ended but keeps health bar visible (always-visible HP bars)
    func removeHealthBar() {
        // Health bars are now always visible - just mark combat as ended
        isInCombat = false
    }

    /// Forces removal of health bar regardless of health state
    func forceRemoveHealthBar() {
        healthBarContainer?.removeFromParent()
        healthBarContainer = nil
        healthBarBackground = nil
        healthBarFill = nil

        // Remove additional health bars for multi-tile buildings
        for container in additionalHealthBarContainers {
            container.removeFromParent()
        }
        additionalHealthBarContainers.removeAll()
        additionalHealthBarFills.removeAll()

        isInCombat = false
    }

    /// Returns true if the building has taken damage and is not at full health
    var isDamaged: Bool {
        return health < maxHealth
    }

    /// Shows the health bar if the building is damaged
    func showHealthBarIfDamaged() {
        if isDamaged {
            setupHealthBar()
        }
    }

    /// Shows or hides the health bar
    func setHealthBarVisible(_ visible: Bool) {
        healthBarContainer?.isHidden = !visible
    }

    // MARK: - Construction Progress Bar (styled like HP bar)

    /// Sets up the construction progress bar (same style/position as HP bar)
    func setupConstructionBar() {
        // Guard against duplicate bars
        if constructionBarBackground != nil && constructionBarFill != nil {
            return
        }

        let barHeight: CGFloat = 3
        let hexRadius: CGFloat = HexTileNode.hexRadius
        let isoRatio = HexTileNode.isoRatio

        // Bottom vertex (vertex 5)
        let bottomX: CGFloat = 0
        let bottomY: CGFloat = -hexRadius * isoRatio

        // Bottom-right vertex (vertex 0)
        let bottomRightX: CGFloat = hexRadius * cos(-CGFloat.pi / 6)
        let bottomRightY: CGFloat = hexRadius * sin(-CGFloat.pi / 6) * isoRatio

        // Calculate full edge length
        let edgeDx = bottomRightX - bottomX
        let edgeDy = bottomRightY - bottomY
        let barWidth: CGFloat = sqrt(edgeDx * edgeDx + edgeDy * edgeDy)

        // Midpoint of bottom-right edge
        let edgeMidX = (bottomX + bottomRightX) / 2
        let edgeMidY = (bottomY + bottomRightY) / 2

        // Offset inward towards center of tile
        let inwardOffset: CGFloat = 5
        let distToCenter = sqrt(edgeMidX * edgeMidX + edgeMidY * edgeMidY)
        let midX = edgeMidX - (edgeMidX / distToCenter) * inwardOffset
        let midY = edgeMidY - (edgeMidY / distToCenter) * inwardOffset

        // Calculate angle of the edge for rotation
        let edgeAngle = atan2(bottomRightY - bottomY, bottomRightX - bottomX)

        // Create container node for rotation
        constructionBarContainer = SKNode()
        constructionBarContainer?.position = CGPoint(x: midX, y: midY)
        constructionBarContainer?.zRotation = edgeAngle
        constructionBarContainer?.zPosition = 10
        addChild(constructionBarContainer!)

        // Background (no outline - overlays HP bar)
        let bgRect = CGRect(x: -barWidth/2, y: -barHeight/2, width: barWidth, height: barHeight)
        constructionBarBackground = SKShapeNode(rect: bgRect, cornerRadius: 1)
        constructionBarBackground?.fillColor = UIColor(white: 0.2, alpha: 0.8)
        constructionBarBackground?.strokeColor = .clear
        constructionBarBackground?.lineWidth = 0
        constructionBarBackground?.zPosition = 1
        constructionBarContainer?.addChild(constructionBarBackground!)

        // Fill (green for construction)
        let fillRect = CGRect(x: -barWidth/2, y: -barHeight/2, width: 0, height: barHeight)
        constructionBarFill = SKShapeNode(rect: fillRect, cornerRadius: 1)
        constructionBarFill?.fillColor = UIColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1.0)
        constructionBarFill?.strokeColor = .clear
        constructionBarFill?.zPosition = 2
        constructionBarContainer?.addChild(constructionBarFill!)

        // For multi-tile buildings, create progress bars on additional tiles
        let isMultiTile = buildingType == .castle || buildingType == .woodenFort
        if isMultiTile {
            let occupiedCoords = getOccupiedCoordinates()
            let anchorPixelPos = HexMap.hexToPixel(q: coordinate.q, r: coordinate.r)

            for tileCoord in occupiedCoords.dropFirst() {
                let tilePixelPos = HexMap.hexToPixel(q: tileCoord.q, r: tileCoord.r)
                let offsetX = tilePixelPos.x - anchorPixelPos.x
                let offsetY = tilePixelPos.y - anchorPixelPos.y

                let container = SKNode()
                container.position = CGPoint(x: offsetX + midX, y: offsetY + midY)
                container.zRotation = edgeAngle
                container.zPosition = 1
                addChild(container)
                additionalConstructionBarContainers.append(container)

                let bg = SKShapeNode(rect: bgRect, cornerRadius: 1)
                bg.fillColor = UIColor(white: 0.2, alpha: 0.8)
                bg.strokeColor = .clear
                bg.lineWidth = 0
                bg.zPosition = 1
                container.addChild(bg)

                let fill = SKShapeNode(rect: fillRect, cornerRadius: 1)
                fill.fillColor = UIColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1.0)
                fill.strokeColor = .clear
                fill.zPosition = 2
                container.addChild(fill)
                additionalConstructionBarFills.append(fill)
            }
        }
    }

    /// Updates the construction progress bar fill
    func updateConstructionBar(progress: Double) {
        guard let fill = constructionBarFill else { return }

        let percentage = CGFloat(max(0, min(1, progress)))
        let hexRadius: CGFloat = HexTileNode.hexRadius
        let isoRatio = HexTileNode.isoRatio

        let bottomRightX: CGFloat = hexRadius * cos(-CGFloat.pi / 6)
        let bottomRightY: CGFloat = hexRadius * sin(-CGFloat.pi / 6) * isoRatio
        let bottomY: CGFloat = -hexRadius * isoRatio
        let edgeDx = bottomRightX
        let edgeDy = bottomRightY - bottomY
        let fullWidth: CGFloat = sqrt(edgeDx * edgeDx + edgeDy * edgeDy)
        let barHeight: CGFloat = 3

        let barWidth = fullWidth * percentage
        let fillRect = CGRect(x: -fullWidth/2, y: -barHeight/2, width: barWidth, height: barHeight)
        fill.path = CGPath(roundedRect: fillRect, cornerWidth: 1, cornerHeight: 1, transform: nil)

        // Update additional bars for multi-tile buildings
        for additionalFill in additionalConstructionBarFills {
            additionalFill.path = CGPath(roundedRect: fillRect, cornerWidth: 1, cornerHeight: 1, transform: nil)
        }
    }

    /// Removes the construction progress bar
    func removeConstructionBar() {
        constructionBarContainer?.removeFromParent()
        constructionBarContainer = nil
        constructionBarBackground = nil
        constructionBarFill = nil

        for container in additionalConstructionBarContainers {
            container.removeFromParent()
        }
        additionalConstructionBarContainers.removeAll()
        additionalConstructionBarFills.removeAll()
    }

    // MARK: - Upgrade Progress Bar (styled like HP bar)

    /// Sets up the upgrade progress bar above the HP bar on the bottom-RIGHT hex edge
    func setupUpgradeBar() {
        // Guard against duplicate bars
        if upgradeBarBackground != nil && upgradeBarFill != nil {
            return
        }

        let barHeight: CGFloat = 3
        let hexRadius: CGFloat = HexTileNode.hexRadius
        let isoRatio = HexTileNode.isoRatio

        // Bottom vertex (vertex 5)
        let bottomX: CGFloat = 0
        let bottomY: CGFloat = -hexRadius * isoRatio

        // Bottom-right vertex (vertex 0): angle = -π/6
        let bottomRightX: CGFloat = hexRadius * cos(-CGFloat.pi / 6)
        let bottomRightY: CGFloat = hexRadius * sin(-CGFloat.pi / 6) * isoRatio

        // Calculate full edge length
        let edgeDx = bottomRightX - bottomX
        let edgeDy = bottomRightY - bottomY
        let barWidth: CGFloat = sqrt(edgeDx * edgeDx + edgeDy * edgeDy)

        // Midpoint of bottom-right edge
        let edgeMidX = (bottomX + bottomRightX) / 2
        let edgeMidY = (bottomY + bottomRightY) / 2

        // Offset inward towards center of tile (same as HP bar)
        let inwardOffset: CGFloat = 5
        let distToCenter = sqrt(edgeMidX * edgeMidX + edgeMidY * edgeMidY)
        let midX = edgeMidX - (edgeMidX / distToCenter) * inwardOffset
        let midY = edgeMidY - (edgeMidY / distToCenter) * inwardOffset

        // Calculate angle of the edge for rotation
        let edgeAngle = atan2(bottomRightY - bottomY, bottomRightX - bottomX)

        // Create container node for rotation
        upgradeBarContainer = SKNode()
        upgradeBarContainer?.position = CGPoint(x: midX, y: midY)
        upgradeBarContainer?.zRotation = edgeAngle
        upgradeBarContainer?.zPosition = 1
        addChild(upgradeBarContainer!)

        // Background (no outline - overlays HP bar)
        let bgRect = CGRect(x: -barWidth/2, y: -barHeight/2, width: barWidth, height: barHeight)
        upgradeBarBackground = SKShapeNode(rect: bgRect, cornerRadius: 1)
        upgradeBarBackground?.fillColor = UIColor(white: 0.2, alpha: 0.8)
        upgradeBarBackground?.strokeColor = .clear
        upgradeBarBackground?.lineWidth = 0
        upgradeBarBackground?.zPosition = 1
        upgradeBarContainer?.addChild(upgradeBarBackground!)

        // Fill (cyan for upgrade)
        let fillRect = CGRect(x: -barWidth/2, y: -barHeight/2, width: 0, height: barHeight)
        upgradeBarFill = SKShapeNode(rect: fillRect, cornerRadius: 1)
        upgradeBarFill?.fillColor = UIColor(red: 0.3, green: 0.8, blue: 0.9, alpha: 1.0)
        upgradeBarFill?.strokeColor = .clear
        upgradeBarFill?.zPosition = 2
        upgradeBarContainer?.addChild(upgradeBarFill!)

        // For multi-tile buildings, create progress bars on additional tiles
        let isMultiTile = buildingType == .castle || buildingType == .woodenFort
        if isMultiTile {
            let occupiedCoords = getOccupiedCoordinates()
            let anchorPixelPos = HexMap.hexToPixel(q: coordinate.q, r: coordinate.r)

            for tileCoord in occupiedCoords.dropFirst() {
                let tilePixelPos = HexMap.hexToPixel(q: tileCoord.q, r: tileCoord.r)
                let offsetX = tilePixelPos.x - anchorPixelPos.x
                let offsetY = tilePixelPos.y - anchorPixelPos.y

                let container = SKNode()
                container.position = CGPoint(x: offsetX + midX, y: offsetY + midY)
                container.zRotation = edgeAngle
                container.zPosition = 1
                addChild(container)
                additionalUpgradeBarContainers.append(container)

                let bg = SKShapeNode(rect: bgRect, cornerRadius: 1)
                bg.fillColor = UIColor(white: 0.2, alpha: 0.8)
                bg.strokeColor = .clear
                bg.lineWidth = 0
                bg.zPosition = 1
                container.addChild(bg)

                let fill = SKShapeNode(rect: fillRect, cornerRadius: 1)
                fill.fillColor = UIColor(red: 0.3, green: 0.8, blue: 0.9, alpha: 1.0)
                fill.strokeColor = .clear
                fill.zPosition = 2
                container.addChild(fill)
                additionalUpgradeBarFills.append(fill)
            }
        }
    }

    /// Updates the upgrade progress bar fill
    func updateUpgradeBar(progress: Double) {
        guard let fill = upgradeBarFill else { return }

        let percentage = CGFloat(max(0, min(1, progress)))
        let hexRadius: CGFloat = HexTileNode.hexRadius
        let isoRatio = HexTileNode.isoRatio

        // Bottom-right edge (matching setupUpgradeBar)
        let bottomRightX: CGFloat = hexRadius * cos(-CGFloat.pi / 6)
        let bottomRightY: CGFloat = hexRadius * sin(-CGFloat.pi / 6) * isoRatio
        let bottomY: CGFloat = -hexRadius * isoRatio
        let edgeDx = bottomRightX
        let edgeDy = bottomRightY - bottomY
        let fullWidth: CGFloat = sqrt(edgeDx * edgeDx + edgeDy * edgeDy)
        let barHeight: CGFloat = 3

        let barWidth = fullWidth * percentage
        let fillRect = CGRect(x: -fullWidth/2, y: -barHeight/2, width: barWidth, height: barHeight)
        fill.path = CGPath(roundedRect: fillRect, cornerWidth: 1, cornerHeight: 1, transform: nil)

        // Update additional bars for multi-tile buildings
        for additionalFill in additionalUpgradeBarFills {
            additionalFill.path = CGPath(roundedRect: fillRect, cornerWidth: 1, cornerHeight: 1, transform: nil)
        }
    }

    /// Removes the upgrade progress bar
    func removeUpgradeBar() {
        upgradeBarContainer?.removeFromParent()
        upgradeBarContainer = nil
        upgradeBarBackground = nil
        upgradeBarFill = nil

        for container in additionalUpgradeBarContainers {
            container.removeFromParent()
        }
        additionalUpgradeBarContainers.removeAll()
        additionalUpgradeBarFills.removeAll()
    }

    // ... Keep all the visual/UI methods unchanged:
    // setupUI(), updateAppearance(), updateUIVisibility(), updateTimerLabel(),
    // updateUpgradeTimerLabel(), updateLevelLabel(), completeConstruction(),
    // createBuildingTexture(), updateVisibility(), etc.
    
    // NOTE: The visual methods stay the same - they just read from data now
    
    static func createBuildingTexture(for type: BuildingType, state: BuildingState) -> SKTexture {
        // Multi-tile buildings (Castle, Wooden Fort) get special large texture
        if type == .castle || type == .woodenFort {
            return createMultiTileBuildingTexture(for: type, state: state)
        }

        let size = CGSize(width: 20, height: 20)
        let renderer = UIGraphicsImageRenderer(size: size)

        let image = renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)

            // Background color based on category and state
            let bgColor: UIColor
            switch state {
            case .planning:
                bgColor = UIColor(white: 0.8, alpha: 0.5)
            case .constructing, .upgrading:
                bgColor = UIColor(red: 0.9, green: 0.7, blue: 0.4, alpha: 1.0)
            case .demolishing:
                bgColor = UIColor(red: 0.9, green: 0.5, blue: 0.2, alpha: 1.0)  // Orange for demolition
            case .completed:
                switch type.category {
                case .economic:
                    bgColor = UIColor(red: 0.4, green: 0.6, blue: 0.9, alpha: 1.0)
                case .military:
                    bgColor = UIColor(red: 0.8, green: 0.3, blue: 0.3, alpha: 1.0)
                }
            case .damaged:
                bgColor = UIColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1.0)
            case .destroyed:
                bgColor = UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0)
            }

            bgColor.setFill()
            context.cgContext.fillEllipse(in: rect.insetBy(dx: 2, dy: 2))

            // Border
            UIColor.white.setStroke()
            context.cgContext.setLineWidth(1)
            context.cgContext.strokeEllipse(in: rect.insetBy(dx: 2, dy: 2))

            // Draw icon text
            let icon = type.icon
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

    /// Creates a larger texture for multi-tile buildings (Castle, Wooden Fort)
    static func createMultiTileBuildingTexture(for type: BuildingType, state: BuildingState) -> SKTexture {
        // Size to cover approximately 3 hex tiles
        let size = CGSize(width: 45, height: 40)
        let renderer = UIGraphicsImageRenderer(size: size)

        let image = renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)

            // Background color - gray for Castle, brown for Wooden Fort
            let bgColor: UIColor
            switch state {
            case .planning:
                bgColor = UIColor(white: 0.6, alpha: 0.5)
            case .constructing, .upgrading:
                bgColor = UIColor(red: 0.7, green: 0.6, blue: 0.4, alpha: 1.0)
            case .demolishing:
                bgColor = UIColor(red: 0.7, green: 0.4, blue: 0.2, alpha: 1.0)  // Orange for demolition
            case .completed:
                // Both Castle and Wooden Fort use same gray stone appearance
                bgColor = UIColor(red: 0.5, green: 0.5, blue: 0.55, alpha: 1.0)  // Gray stone
            case .damaged:
                bgColor = UIColor(red: 0.5, green: 0.4, blue: 0.3, alpha: 1.0)
            case .destroyed:
                bgColor = UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0)
            }

            // Draw rounded rectangle fill
            let buildingPath = UIBezierPath(roundedRect: rect.insetBy(dx: 2, dy: 2), cornerRadius: 6)
            bgColor.setFill()
            buildingPath.fill()

            // Draw border/outline - same dark gray for both Castle and Fort
            let borderColor = UIColor(red: 0.3, green: 0.3, blue: 0.35, alpha: 1.0)  // Dark gray
            borderColor.setStroke()
            buildingPath.lineWidth = 1.5
            buildingPath.stroke()

            // Inner border for depth
            UIColor.white.withAlphaComponent(0.3).setStroke()
            let innerPath = UIBezierPath(roundedRect: rect.insetBy(dx: 4, dy: 4), cornerRadius: 5)
            innerPath.lineWidth = 0.5
            innerPath.stroke()

            // Draw building name text in center
            let buildingName = type == .castle ? "CASTLE" : "FORT"
            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 7),
                .foregroundColor: UIColor.white
            ]
            let textString = NSAttributedString(string: buildingName, attributes: textAttributes)
            let textSize = textString.size()
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )

            // Text shadow for readability
            let shadowAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 7),
                .foregroundColor: UIColor.black.withAlphaComponent(0.5)
            ]
            let shadowString = NSAttributedString(string: buildingName, attributes: shadowAttributes)
            let shadowRect = textRect.offsetBy(dx: 1, dy: 1)
            shadowString.draw(in: shadowRect)

            textString.draw(in: textRect)
        }

        return SKTexture(image: image)
    }

    /// Returns the node size based on building type
    static func getNodeSize(for type: BuildingType) -> CGSize {
        if type == .castle || type == .woodenFort {
            return CGSize(width: 45, height: 40)
        }
        return CGSize(width: 20, height: 20)
    }
    
    func setupUI() {
        let isMultiTile = buildingType == .castle || buildingType == .woodenFort

        // Building name label (hidden for multi-tile buildings since name is in texture)
        buildingLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        buildingLabel?.fontSize = 6
        buildingLabel?.fontColor = .white
        buildingLabel?.text = buildingType.displayName
        buildingLabel?.position = isMultiTile ? CGPoint(x: 0, y: 22) : CGPoint(x: 0, y: 12)
        buildingLabel?.zPosition = 1
        buildingLabel?.name = "buildingLabel"
        buildingLabel?.isHidden = isMultiTile  // Hide for multi-tile since name is in texture

        // Level label removed from map display

        // Add shadow effect to label
        let shadow = SKLabelNode(fontNamed: "Helvetica-Bold")
        shadow.fontSize = 6
        shadow.fontColor = UIColor(white: 0, alpha: 0.7)
        shadow.text = buildingType.displayName
        shadow.position = CGPoint(x: 0.5, y: -0.5)
        shadow.zPosition = -1
        buildingLabel?.addChild(shadow)

        addChild(buildingLabel!)

        // Progress bars and timer will be created by updateTimerLabel when needed
        updateUIVisibility()
    }
    
    func createProgressBarImage(width: CGFloat, height: CGFloat) -> UIImage {
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1.0).setFill()
            context.cgContext.fill(CGRect(origin: .zero, size: size))
        }
    }
    
    func updateAppearance() {
        self.texture = BuildingNode.createBuildingTexture(for: buildingType, state: state)
        self.size = BuildingNode.getNodeSize(for: buildingType)

        // For multi-tile buildings with overlays, keep main sprite hidden
        if hasCreatedTileOverlays {
            // Hide the sprite texture but keep alpha=1 so children (bars, labels) remain visible
            self.texture = nil
            self.color = .clear
            self.alpha = 1.0
            updateTileOverlays()
        } else {
            switch state {
            case .planning:
                self.alpha = 0.6
            case .constructing:
                self.alpha = 1.0
            case .completed:
                self.alpha = 1.0
            case .upgrading:
                self.alpha = 0.8  // Slightly dimmed during upgrade
            case .demolishing:
                self.alpha = 0.6  // Dimmed during demolition
            case .damaged:
                self.alpha = 0.8
            case .destroyed:
                self.alpha = 0.3
            }
        }

        updateUIVisibility()
    }
    
    func updateUIVisibility() {
        let showConstruction = state == .constructing
        let showUpgrading = state == .upgrading
        let showDemolishing = state == .demolishing
        let showCompleted = state == .completed

        // Construction UI
        childNode(withName: "progressBarBg")?.isHidden = !showConstruction
        progressBar?.isHidden = !showConstruction
        timerLabel?.isHidden = !showConstruction

        // Upgrade UI
        upgradeProgressBar?.isHidden = !showUpgrading
        upgradeTimerLabel?.isHidden = !showUpgrading

        // Demolition UI
        demolitionProgressBar?.isHidden = !showDemolishing
        demolitionTimerLabel?.isHidden = !showDemolishing

        // Building label - show during construction, upgrading, demolishing, or completed
        buildingLabel?.isHidden = !(showCompleted || showConstruction || showUpgrading || showDemolishing)

        // Level label - show when completed or upgrading
        updateLevelLabel()
    }
    
    func updateTimerLabel() {
        // ✅ Only update timer for buildings that are actually constructing
        guard state == .constructing else {
            // Remove any existing timer/progress elements if building is not constructing
            timerLabel?.removeFromParent()
            timerLabel = nil
            progressBar?.removeFromParent()
            progressBar = nil
            removeConstructionBar()
            return
        }

        guard let startTime = constructionStartTime else { return }

        let currentTime = Date().timeIntervalSince1970
        let elapsed = currentTime - startTime

        // Builder bonus + Research bonus
        let builderMultiplier = 1.0 + (Double(buildersAssigned - 1) * 0.5)
        let researchMultiplier = ResearchManager.shared.getBuildingSpeedMultiplier()
        let totalSpeedMultiplier = builderMultiplier * researchMultiplier
        let effectiveBuildTime = buildingType.buildTime / totalSpeedMultiplier
        let remaining = max(0, effectiveBuildTime - elapsed)

        // Update progress (without triggering didSet)
        let newProgress = min(1.0, max(0.0, elapsed / effectiveBuildTime))
        if abs(constructionProgress - newProgress) > 0.01 {
            constructionProgress = newProgress
        }

        // Check if construction is complete
        if remaining <= 0 {
            completeConstruction()
            return
        }

        // ✅ Create timer label if needed
        if timerLabel == nil {
            timerLabel = SKLabelNode(fontNamed: "Menlo-Bold")
            timerLabel?.fontSize = 6
            timerLabel?.fontColor = .white
            timerLabel?.position = CGPoint(x: 0, y: -15)
            timerLabel?.zPosition = 15
            timerLabel?.name = "timerLabel"
            addChild(timerLabel!)
        }

        // Format time remaining
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        timerLabel?.text = String(format: "%d:%02d", minutes, seconds)

        // ✅ Setup and update styled construction bar (same as HP bar)
        setupConstructionBar()
        updateConstructionBar(progress: newProgress)
    }
    
    func completeConstruction() {
        guard state == .constructing else { return }

        state = .completed
        constructionProgress = 1.0
        health = maxHealth

        // ✅ Remove all construction UI elements
        timerLabel?.removeFromParent()
        timerLabel = nil
        progressBar?.removeFromParent()
        progressBar = nil
        removeConstructionBar()
        setupHealthBar()

        // Unlock the builder entity (unless it's a farm or camp - they'll start gathering)
        if let builder = builderEntity {
            if buildingType == .farm || buildingType == .miningCamp || buildingType == .lumberCamp {
                // For farms and camps, don't clear task - they'll start gathering automatically
                print("✅ \(buildingType.displayName) completed - villagers will start gathering")
            } else {
                builder.isMoving = false

                // Clear the task for the villager group
                if let villagerGroup = builder.entity as? VillagerGroup {
                    villagerGroup.clearTask()
                    print("✅ Villagers unlocked and available for new tasks")
                }
            }
        }
        
        // Update visual appearance
        updateAppearance()
        
        if buildingType == .farm {
            var userInfo: [String: Any] = ["coordinate": coordinate]
            if let builder = builderEntity {
                userInfo["builder"] = builder
            }
            NotificationCenter.default.post(
                name: NSNotification.Name("FarmCompletedNotification"),
                object: self,
                userInfo: userInfo
            )
        }

        // Post notification for mining/lumber camp completion to auto-start gathering
        if buildingType == .miningCamp || buildingType == .lumberCamp {
            var userInfo: [String: Any] = ["coordinate": coordinate, "campType": buildingType]
            if let builder = builderEntity {
                userInfo["builder"] = builder
            }
            NotificationCenter.default.post(
                name: NSNotification.Name("CampCompletedNotification"),
                object: self,
                userInfo: userInfo
            )
        }

        print("✅ \(buildingType.displayName) construction completed at (\(coordinate.q), \(coordinate.r))")
    }

    func updateConstruction() {
        guard state == .constructing, let startTime = constructionStartTime else { return }

        let currentTime = Date().timeIntervalSince1970
        let elapsed = currentTime - startTime

        // Builder bonus + Research bonus
        let builderMultiplier = 1.0 + (Double(buildersAssigned - 1) * 0.5)
        let researchMultiplier = ResearchManager.shared.getBuildingSpeedMultiplier()
        let totalSpeedMultiplier = builderMultiplier * researchMultiplier
        let effectiveBuildTime = buildingType.buildTime / totalSpeedMultiplier

        constructionProgress = min(1.0, elapsed / effectiveBuildTime)

        // Add debug logging
        print("Building: \(buildingType.displayName)")
        print("  Start time: \(startTime)")
        print("  Current time: \(currentTime)")
        print("  Elapsed: \(elapsed)s")
        print("  Effective build time: \(effectiveBuildTime)s")
        print("  Progress: \(constructionProgress * 100)%")

        if constructionProgress >= 1.0 {
            completeConstruction()
        }
    }
    
 
    
    func updateVisibility(displayMode: BuildingDisplayMode) {
        switch displayMode {
        case .hidden:
            self.isHidden = true

        case .memory:
            self.isHidden = false
            if hasCreatedTileOverlays {
                self.texture = nil
                self.color = .clear
                self.alpha = 0.5
            } else {
                self.alpha = 0.5  // Dimmed to show it's last-known
            }
            // Hide real-time UI elements
            childNode(withName: "progressBarBg")?.isHidden = true
            progressBar?.isHidden = true
            timerLabel?.isHidden = true

        case .current:
            self.isHidden = false
            if hasCreatedTileOverlays {
                self.texture = nil
                self.color = .clear
                self.alpha = 1.0
            } else {
                self.alpha = 1.0
            }
            updateUIVisibility()  // Show appropriate UI
        }

        // Also update tile overlays visibility
        updateTileOverlayVisibility(displayMode: displayMode)
    }
    
    func getAssociatedResource(from hexMap: HexMap) -> ResourcePointNode? {
        guard buildingType == .miningCamp || buildingType == .lumberCamp else { return nil }
        return hexMap.getResourcePoint(at: coordinate)
    }
    
    func getResourceGatheringSummary(from hexMap: HexMap) -> String? {
        guard let resource = getAssociatedResource(from: hexMap) else { return nil }
        
        var summary = "\(resource.resourceType.icon) \(resource.remainingAmount)"
        
        let villagerCount = resource.getTotalVillagersGathering()
        if villagerCount > 0 {
            summary += " 👷\(villagerCount)"
        }
        
        return summary
    }
    
    func updateUpgrade() {
        guard state == .upgrading,
              let startTime = upgradeStartTime,
              let baseUpgradeTime = getUpgradeTime() else { return }

        let currentTime = Date().timeIntervalSince1970
        let elapsed = currentTime - startTime

        // Apply research bonus to upgrade time
        let researchMultiplier = ResearchManager.shared.getBuildingSpeedMultiplier()
        let effectiveUpgradeTime = baseUpgradeTime / researchMultiplier

        upgradeProgress = min(1.0, elapsed / effectiveUpgradeTime)

        if upgradeProgress >= 1.0 {
            completeUpgrade()
        }
    }

    func updateUpgradeTimerLabel() {
        // ✅ FIX: Early exit if not upgrading
        guard state == .upgrading else {
            // Remove upgrade UI if not upgrading
            upgradeTimerLabel?.removeFromParent()
            upgradeTimerLabel = nil
            upgradeProgressBar?.removeFromParent()
            upgradeProgressBar = nil
            removeUpgradeBar()
            return
        }

        guard let startTime = upgradeStartTime else {
            print("⚠️ Upgrading but no start time set!")
            return
        }

        guard let baseUpgradeTime = getUpgradeTime() else {
            print("⚠️ Could not get upgrade time for level \(level)")
            return
        }

        // Apply research bonus to upgrade time
        let researchMultiplier = ResearchManager.shared.getBuildingSpeedMultiplier()
        let totalUpgradeTime = baseUpgradeTime / researchMultiplier

        let currentTime = Date().timeIntervalSince1970
        let elapsed = currentTime - startTime
        let remaining = max(0, totalUpgradeTime - elapsed)

        // ✅ FIX: Calculate and SET progress correctly
        let newProgress = min(1.0, max(0.0, elapsed / totalUpgradeTime))

        // Debug logging
        print("⬆️ Upgrade Update: \(buildingType.displayName)")
        print("   Elapsed: \(String(format: "%.1f", elapsed))s / \(String(format: "%.1f", totalUpgradeTime))s")
        print("   Progress: \(String(format: "%.1f", newProgress * 100))%")
        print("   Remaining: \(String(format: "%.1f", remaining))s")

        // ✅ FIX: Check completion BEFORE updating progress to avoid race condition
        if newProgress >= 1.0 || remaining <= 0 {
            print("✅ Upgrade complete! Calling completeUpgrade()")
            completeUpgrade()
            return
        }

        // Update stored progress
        upgradeProgress = newProgress

        // Create/update timer label
        if upgradeTimerLabel == nil {
            upgradeTimerLabel = SKLabelNode(fontNamed: "Menlo-Bold")
            upgradeTimerLabel?.fontSize = 6
            upgradeTimerLabel?.fontColor = .cyan
            upgradeTimerLabel?.position = CGPoint(x: 0, y: -15)
            upgradeTimerLabel?.zPosition = 15
            upgradeTimerLabel?.name = "upgradeTimerLabel"
            addChild(upgradeTimerLabel!)
        }

        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        upgradeTimerLabel?.text = "⬆️ \(minutes):\(String(format: "%02d", seconds))"

        // ✅ Setup and update styled upgrade bar (same as HP bar)
        setupUpgradeBar()
        updateUpgradeBar(progress: newProgress)
    }
    
    func updateLevelLabel() {
        // Level label removed from map display
    }

    // MARK: - Multi-Tile Visual Overlays

    /// Creates per-tile hex overlays for multi-tile buildings (Castle, Wooden Fort)
    /// Call this after the building is added to a scene
    func createTileOverlays(in scene: SKScene) {
        guard buildingType.hexSize > 1 else { return }
        guard !hasCreatedTileOverlays else { return }

        // Clear any existing overlays
        clearTileOverlays()

        let occupiedCoords = buildingType.getOccupiedCoordinates(anchor: coordinate, rotation: data.rotation)

        for (index, coord) in occupiedCoords.enumerated() {
            let worldPos = HexMap.hexToPixel(q: coord.q, r: coord.r)
            let isAnchor = index == 0

            let overlay = createHexTileOverlay(at: worldPos, isAnchor: isAnchor)
            overlay.name = "tileOverlay_\(coord.q)_\(coord.r)"
            // Use isometric z-position for each tile overlay
            overlay.zPosition = HexTileNode.isometricZPosition(q: coord.q, r: coord.r, baseLayer: HexTileNode.ZLayer.building - 1)

            scene.addChild(overlay)
            tileOverlays.append(overlay)
        }

        // Hide the main sprite texture; keep alpha=1 so children (bars, labels) stay visible
        self.texture = nil
        self.color = .clear

        // Move UI elements to anchor tile position (they're children of this node)
        // They'll still be visible since only the sprite itself is hidden

        hasCreatedTileOverlays = true
        print("✅ Created \(tileOverlays.count) tile overlays for \(buildingType.displayName)")
    }

    /// Creates a single hex-shaped overlay for one tile (isometric)
    private func createHexTileOverlay(at position: CGPoint, isAnchor: Bool) -> SKShapeNode {
        let radius: CGFloat = HexTileNode.hexRadius - 1
        let isoRatio = HexTileNode.isoRatio
        let path = CGMutablePath()

        for i in 0..<6 {
            let angle = CGFloat(i) * CGFloat.pi / 3 - CGFloat.pi / 6
            let x = radius * cos(angle)
            let y = radius * sin(angle) * isoRatio  // Apply isometric compression

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()

        let overlay = SKShapeNode(path: path)
        overlay.position = position

        // Color based on building type and state
        let fillColor = getTileOverlayColor()
        overlay.fillColor = fillColor
        overlay.strokeColor = getOverlayStrokeColor()
        overlay.lineWidth = isAnchor ? 3 : 2
        overlay.glowWidth = isAnchor ? 1 : 0

        // Add building label on anchor tile
        if isAnchor {
            let label = SKLabelNode(fontNamed: "Helvetica-Bold")
            label.text = buildingType == .castle ? "CASTLE" : "FORT"
            label.fontSize = 6
            label.fontColor = .white
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            label.zPosition = 1

            // Add shadow for readability
            let shadow = SKLabelNode(fontNamed: "Helvetica-Bold")
            shadow.text = label.text
            shadow.fontSize = 6
            shadow.fontColor = UIColor.black.withAlphaComponent(0.7)
            shadow.verticalAlignmentMode = .center
            shadow.horizontalAlignmentMode = .center
            shadow.position = CGPoint(x: 0.5, y: -0.5)
            shadow.zPosition = 0
            overlay.addChild(shadow)

            overlay.addChild(label)
        }

        return overlay
    }

    /// Returns the fill color for tile overlays based on building type and state
    private func getTileOverlayColor() -> UIColor {
        switch state {
        case .planning:
            return UIColor(white: 0.5, alpha: 0.4)
        case .constructing, .upgrading:
            return UIColor(red: 0.7, green: 0.6, blue: 0.4, alpha: 0.7)
        case .demolishing:
            return UIColor(red: 0.7, green: 0.4, blue: 0.2, alpha: 0.7)
        case .completed:
            if buildingType == .castle {
                return UIColor(red: 0.45, green: 0.45, blue: 0.5, alpha: 0.85)  // Gray stone
            } else {
                return UIColor(red: 0.5, green: 0.38, blue: 0.25, alpha: 0.85)  // Brown wood
            }
        case .damaged:
            return UIColor(red: 0.5, green: 0.4, blue: 0.3, alpha: 0.7)
        case .destroyed:
            return UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.5)
        }
    }

    /// Returns the stroke color for tile overlays
    private func getOverlayStrokeColor() -> UIColor {
        if buildingType == .castle {
            return UIColor(red: 0.3, green: 0.3, blue: 0.35, alpha: 1.0)  // Dark gray
        } else {
            return UIColor(red: 0.35, green: 0.25, blue: 0.15, alpha: 1.0)  // Dark brown
        }
    }

    /// Updates the appearance of tile overlays
    func updateTileOverlays() {
        let fillColor = getTileOverlayColor()
        let strokeColor = getOverlayStrokeColor()

        for overlay in tileOverlays {
            overlay.fillColor = fillColor
            overlay.strokeColor = strokeColor
        }
    }

    /// Clears all tile overlays
    func clearTileOverlays() {
        for overlay in tileOverlays {
            overlay.removeFromParent()
        }
        tileOverlays.removeAll()
        hasCreatedTileOverlays = false
    }

    /// Updates visibility of tile overlays for fog of war
    func updateTileOverlayVisibility(displayMode: BuildingDisplayMode) {
        for overlay in tileOverlays {
            switch displayMode {
            case .hidden:
                overlay.isHidden = true
            case .memory:
                overlay.isHidden = false
                overlay.alpha = 0.5
            case .current:
                overlay.isHidden = false
                overlay.alpha = 1.0
            }
        }
    }

    /// Returns the coordinates this building occupies (for multi-tile buildings)
    func getOccupiedCoordinates() -> [HexCoordinate] {
        return buildingType.getOccupiedCoordinates(anchor: coordinate, rotation: data.rotation)
    }

    var upgradeBlockedReason: String? {
        guard state == .completed else { return "Building must be completed first" }
        guard level < maxLevel else { return "Already at max level" }
        
        if buildingType == .castle, let owner = owner {
            let ccLevel = owner.getCityCenterLevel()
            let allowedCastleLevel = BuildingType.maxCastleLevel(forCityCenterLevel: ccLevel)
            if level >= allowedCastleLevel {
                let requiredCC = level + 6  // To get castle Lv.2, need CC7, etc.
                return "Requires City Center Level \(requiredCC)"
            }
        }
        
        return nil
    }
    
}
