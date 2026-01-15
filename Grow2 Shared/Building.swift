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
    
    // Military Buildings
    case castle = "Castle"
    case barracks = "Barracks"
    case archeryRange = "Archery Range"
    case stable = "Stable"
    case siegeWorkshop = "Siege Workshop"
    case tower = "Tower"
    case woodenFort = "Wooden Fort"
    
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
        case .cityCenter, .farm, .neighborhood, .blacksmith, .market, .miningCamp, .lumberCamp, .warehouse, .university:
            return .economic
        case .castle, .barracks, .archeryRange, .stable, .siegeWorkshop, .tower, .woodenFort:
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
        case .castle: return "🏰"
        case .barracks: return "🛡️"
        case .archeryRange: return "🏹"
        case .stable: return "🐴"
        case .siegeWorkshop: return "🎯"
        case .tower: return "🗼"
        case .woodenFort: return "🗝️"
        }
    }
    
    var requiredCityCenterLevel: Int {
        switch self {
        case .cityCenter:
            return 1  // Always available (you start with one)
        case .neighborhood, .warehouse, .farm, .barracks:
            return 1  // Tier 1
        case .archeryRange, .stable:
            return 2  // Tier 2
        case .market, .blacksmith, .tower:
            return 3  // Tier 3
        case .woodenFort:
            return 4  // Tier 4
        case .siegeWorkshop:
            return 5  // Tier 5
        case .castle:
            return 6  // Tier 6
        case .miningCamp, .lumberCamp:
            return 1  // Resource camps available early
        case .university:
            return 3  // Same as other advanced economic buildings
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
        case .castle: return 90.0
        case .barracks: return 4.0
        case .archeryRange: return 35.0
        case .stable: return 35.0
        case .siegeWorkshop: return 45.0
        case .tower: return 30.0
        case .woodenFort: return 50.0
        }
    }
    
    var hexSize: Int {
        switch self {
        case .cityCenter, .castle: return 2  // Takes up 2x2 hexes
        case .university, .warehouse, .market: return 1  // Takes up single hex
        default: return 1
        }
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
        case .castle: return "Defensive stronghold and military hub"
        case .barracks: return "Trains infantry units"
        case .archeryRange: return "Trains ranged units"
        case .stable: return "Trains cavalry units"
        case .siegeWorkshop: return "Builds siege weapons"
        case .tower: return "Defensive structure"
        case .woodenFort: return "Basic defensive structure"
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
        default: return 5
        }
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
    

}

enum BuildingState: String, Codable {
    case planning
    case constructing
    case completed
    case upgrading
    case damaged
    case destroyed
}

// MARK: - Building Node

class BuildingNode: SKSpriteNode {
    
    // MARK: - Data Reference
    
    /// The data model for this building - source of truth for all state
    let data: BuildingData
    
    // MARK: - Entity References (not part of data - runtime only)
    weak var builderEntity: EntityNode?
    weak var upgraderEntity: EntityNode?
    weak var owner: Player?  // Keep for convenience, derived from data.ownerID
    
    // MARK: - UI Elements
    var progressBar: SKShapeNode?
    var timerLabel: SKLabelNode?
    var buildingLabel: SKLabelNode?
    var levelLabel: SKLabelNode?
    var upgradeProgressBar: SKShapeNode?
    var upgradeTimerLabel: SKLabelNode?
    
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
    
    init(coordinate: HexCoordinate, buildingType: BuildingType, owner: Player? = nil) {
        // Create data model
        self.data = BuildingData(
            buildingType: buildingType,
            coordinate: coordinate,
            ownerID: owner?.id
        )
        self.owner = owner
        
        let texture = BuildingNode.createBuildingTexture(for: buildingType, state: .planning)
        super.init(texture: texture, color: .clear, size: CGSize(width: 40, height: 40))
        
        self.zPosition = 5
        self.name = "building"
        
        setupUI()
    }
    
    /// Initialize from existing data (used when loading saves)
    init(data: BuildingData, owner: Player? = nil) {
        self.data = data
        self.owner = owner
        
        let texture = BuildingNode.createBuildingTexture(for: data.buildingType, state: data.state)
        super.init(texture: texture, color: .clear, size: CGSize(width: 40, height: 40))
        
        self.zPosition = 5
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
    
    func takeDamage(_ amount: Double) {
        data.takeDamage(amount)
        updateAppearance()
    }
    
    func repair(_ amount: Double) {
        data.repair(amount)
        updateAppearance()
    }
    
    // ... Keep all the visual/UI methods unchanged:
    // setupUI(), updateAppearance(), updateUIVisibility(), updateTimerLabel(),
    // updateUpgradeTimerLabel(), updateLevelLabel(), completeConstruction(),
    // createBuildingTexture(), updateVisibility(), etc.
    
    // NOTE: The visual methods stay the same - they just read from data now
    
    static func createBuildingTexture(for type: BuildingType, state: BuildingState) -> SKTexture {
        let size = CGSize(width: 40, height: 40)
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
            context.cgContext.fillEllipse(in: rect.insetBy(dx: 4, dy: 4))
            
            // Border
            UIColor.white.setStroke()
            context.cgContext.setLineWidth(2)
            context.cgContext.strokeEllipse(in: rect.insetBy(dx: 4, dy: 4))
            
            // Draw icon text
            let icon = type.icon
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20),
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
    
    func setupUI() {
        // Building name label only
        buildingLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        buildingLabel?.fontSize = 9
        buildingLabel?.fontColor = .white
        buildingLabel?.text = buildingType.displayName
        buildingLabel?.position = CGPoint(x: 0, y: 25)
        buildingLabel?.zPosition = 1
        buildingLabel?.name = "buildingLabel"
        
        // Level label (only shown when completed)
        levelLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        levelLabel?.fontSize = 10
        levelLabel?.fontColor = .yellow
        levelLabel?.position = CGPoint(x: 18, y: 15)
        levelLabel?.zPosition = 2
        levelLabel?.name = "levelLabel"
        levelLabel?.horizontalAlignmentMode = .right
        updateLevelLabel()
        addChild(levelLabel!)
        
        // Add shadow effect to label
        let shadow = SKLabelNode(fontNamed: "Helvetica-Bold")
        shadow.fontSize = 9
        shadow.fontColor = UIColor(white: 0, alpha: 0.7)
        shadow.text = buildingType.displayName
        shadow.position = CGPoint(x: 1, y: -1)
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
        
        switch state {
        case .planning:
            self.alpha = 0.6
        case .constructing:
            self.alpha = 0.5 + (constructionProgress * 0.5)
        case .completed:
            self.alpha = 1.0
        case .upgrading:
            self.alpha = 0.8  // Slightly dimmed during upgrade
        case .damaged:
            self.alpha = 0.8
        case .destroyed:
            self.alpha = 0.3
        }
        
        updateUIVisibility()
    }
    
    func updateUIVisibility() {
        let showConstruction = state == .constructing
        let showUpgrading = state == .upgrading
        let showCompleted = state == .completed
        
        // Construction UI
        childNode(withName: "progressBarBg")?.isHidden = !showConstruction
        progressBar?.isHidden = !showConstruction
        timerLabel?.isHidden = !showConstruction
        
        // Upgrade UI
        upgradeProgressBar?.isHidden = !showUpgrading
        upgradeTimerLabel?.isHidden = !showUpgrading
        
        // Building label - show during construction, upgrading, or completed
        buildingLabel?.isHidden = !(showCompleted || showConstruction || showUpgrading)
        
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
            return
        }
        
        guard let startTime = constructionStartTime else { return }
        
        let currentTime = Date().timeIntervalSince1970
        let elapsed = currentTime - startTime
        
        let buildSpeedMultiplier = 1.0 + (Double(buildersAssigned - 1) * 0.5)
        let effectiveBuildTime = buildingType.buildTime / buildSpeedMultiplier
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
            timerLabel?.fontSize = 11
            timerLabel?.fontColor = .white
            timerLabel?.position = CGPoint(x: 0, y: -30)
            timerLabel?.zPosition = 15
            timerLabel?.name = "timerLabel"
            addChild(timerLabel!)
        }
        
        // Format time remaining
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        timerLabel?.text = String(format: "%d:%02d", minutes, seconds)
        
        // ✅ Update progress bar - use simpler SKShapeNode rect
        progressBar?.removeFromParent()
        
        let barWidth: CGFloat = 44
        let barHeight: CGFloat = 6
        let progressWidth = max(1.0, barWidth * CGFloat(constructionProgress)) // ✅ Ensure minimum width
        
        // Create new progress bar
        progressBar = SKShapeNode(rectOf: CGSize(width: progressWidth, height: barHeight), cornerRadius: 3)
        progressBar?.fillColor = .green
        progressBar?.strokeColor = .white
        progressBar?.lineWidth = 1
        progressBar?.position = CGPoint(x: -barWidth/2 + progressWidth/2, y: -40)
        progressBar?.zPosition = 15
        progressBar?.name = "progressBar"
        addChild(progressBar!)
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
        
        // ✅ Unlock the builder entity
        if let builder = builderEntity {
            builder.isMoving = false
            
            // Clear the task for the villager group
            if let villagerGroup = builder.entity as? VillagerGroup {
                villagerGroup.clearTask()
                print("✅ Villagers unlocked and available for new tasks")
            }
        }
        
        // Update visual appearance
        updateAppearance()
        
        if buildingType == .farm {
            NotificationCenter.default.post(
                name: NSNotification.Name("FarmCompletedNotification"),
                object: self,
                userInfo: ["coordinate": coordinate]
            )
        }
        
        print("✅ \(buildingType.displayName) construction completed at (\(coordinate.q), \(coordinate.r))")
    }

    func updateConstruction() {
        guard state == .constructing, let startTime = constructionStartTime else { return }
        
        let currentTime = Date().timeIntervalSince1970
        let elapsed = currentTime - startTime
        
        let buildSpeedMultiplier = 1.0 + (Double(buildersAssigned - 1) * 0.5)
        let effectiveBuildTime = buildingType.buildTime / buildSpeedMultiplier
        
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
            self.alpha = 0.5  // Dimmed to show it's last-known
            // Hide real-time UI elements
            childNode(withName: "progressBarBg")?.isHidden = true
            progressBar?.isHidden = true
            timerLabel?.isHidden = true
            
        case .current:
            self.isHidden = false
            self.alpha = 1.0
            updateUIVisibility()  // Show appropriate UI
        }
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
              let upgradeTime = getUpgradeTime() else { return }
        
        let currentTime = Date().timeIntervalSince1970
        let elapsed = currentTime - startTime
        
        upgradeProgress = min(1.0, elapsed / upgradeTime)
        
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
            return
        }
        
        guard let startTime = upgradeStartTime else {
            print("⚠️ Upgrading but no start time set!")
            return
        }
        
        guard let totalUpgradeTime = getUpgradeTime() else {
            print("⚠️ Could not get upgrade time for level \(level)")
            return
        }
        
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
            upgradeTimerLabel?.fontSize = 11
            upgradeTimerLabel?.fontColor = .cyan
            upgradeTimerLabel?.position = CGPoint(x: 0, y: -30)
            upgradeTimerLabel?.zPosition = 15
            upgradeTimerLabel?.name = "upgradeTimerLabel"
            addChild(upgradeTimerLabel!)
        }
        
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        upgradeTimerLabel?.text = "⬆️ \(minutes):\(String(format: "%02d", seconds))"
        
        // ✅ FIX: Recreate progress bar with correct width
        upgradeProgressBar?.removeFromParent()
        
        let barWidth: CGFloat = 44
        let barHeight: CGFloat = 6
        let progressWidth = max(2.0, barWidth * CGFloat(newProgress))  // ✅ Use newProgress directly
        
        upgradeProgressBar = SKShapeNode(rectOf: CGSize(width: progressWidth, height: barHeight), cornerRadius: 3)
        upgradeProgressBar?.fillColor = .cyan
        upgradeProgressBar?.strokeColor = .white
        upgradeProgressBar?.lineWidth = 1
        upgradeProgressBar?.position = CGPoint(x: -barWidth/2 + progressWidth/2, y: -40)
        upgradeProgressBar?.zPosition = 15
        upgradeProgressBar?.name = "upgradeProgressBar"
        addChild(upgradeProgressBar!)
    }
    
    func updateLevelLabel() {
        if state == .completed || state == .upgrading {
            levelLabel?.text = "Lv.\(level)"
            levelLabel?.isHidden = false
        } else {
            levelLabel?.isHidden = true
        }
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
