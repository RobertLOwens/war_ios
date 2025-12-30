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

enum BuildingType: String, CaseIterable {
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
}

// MARK: - Building State

enum BuildingState {
    case planning      // Placement phase, not yet built
    case constructing  // Being built
    case completed     // Fully built and operational
    case damaged       // Has taken damage
    case destroyed     // Destroyed
}

// MARK: - Building Node

class BuildingNode: SKSpriteNode {
    
    let buildingType: BuildingType
    var coordinate: HexCoordinate
    var owner: Player?
    weak var builderEntity: EntityNode?

    
    var state: BuildingState = .planning {
        didSet {
            updateAppearance()
        }
    }
    
    var health: Double
    var maxHealth: Double
    
    var constructionProgress: Double = 0.0 {
        didSet {
            if state == .constructing {
                updateAppearance()
                updateTimerLabel()
            }
        }
    }
    
    var constructionStartTime: TimeInterval?
    var buildersAssigned: Int = 0  // Number of villagers working on this building
    
    // Completion callback
    var onConstructionComplete: (() -> Void)?
    
    var garrison: [MilitaryUnitType: Int] {
        get {
            return objc_getAssociatedObject(self, &BuildingNode.garrisonKey) as? [MilitaryUnitType: Int] ?? [:]
        }
        set {
            objc_setAssociatedObject(self, &BuildingNode.garrisonKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    var villagerGarrison: Int {
        get {
            return objc_getAssociatedObject(self, &BuildingNode.villagerGarrisonKey) as? Int ?? 0
        }
        set {
            objc_setAssociatedObject(self, &BuildingNode.villagerGarrisonKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    var trainingQueue: [TrainingQueueEntry] {
        get {
            return objc_getAssociatedObject(self, &BuildingNode.trainingQueueKey) as? [TrainingQueueEntry] ?? []
        }
        set {
            objc_setAssociatedObject(self, &BuildingNode.trainingQueueKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    var villagerTrainingQueue: [VillagerTrainingEntry] {
        get {
            return objc_getAssociatedObject(self, &BuildingNode.villagerTrainingQueueKey) as? [VillagerTrainingEntry] ?? []
        }
        set {
            objc_setAssociatedObject(self, &BuildingNode.villagerTrainingQueueKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    // UI Elements for construction
    private var progressBar: SKShapeNode?
    private var timerLabel: SKLabelNode?
    private var buildingLabel: SKLabelNode?
    private static var garrisonKey: UInt8 = 0
    private static var trainingQueueKey: UInt8 = 1
    private static var villagerGarrisonKey: UInt8 = 2
    private static var villagerTrainingQueueKey: UInt8 = 3

    init(coordinate: HexCoordinate, buildingType: BuildingType, owner: Player? = nil) {
        self.coordinate = coordinate
        self.buildingType = buildingType
        self.owner = owner
        
        // Set health based on building type
        switch buildingType.category {
        case .military:
            self.maxHealth = 500.0
        case .economic:
            self.maxHealth = 200.0
        }
        self.health = maxHealth
        
        let texture = BuildingNode.createBuildingTexture(for: buildingType, state: .planning)
        super.init(texture: texture, color: .clear, size: CGSize(width: 40, height: 40))
        
        self.zPosition = 5
        self.name = "building"
        
        setupUI()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
     
     // MARK: - Training Methods
     
    func canTrain(_ unitType: MilitaryUnitType) -> Bool {
        guard state == .completed else { return false }
        return unitType.trainingBuilding == buildingType
    }

    // âœ… ADD THIS NEW METHOD:
    func canTrainVillagers() -> Bool {
        guard state == .completed else { return false }
        return buildingType == .cityCenter || buildingType == .neighborhood
    }
    
    func getTrainableUnits() -> [TrainableUnitType] {
        guard state == .completed else { return [] }
        
        var trainable: [TrainableUnitType] = []
        
        // Check if can train villagers
        if canTrainVillagers() {
            trainable.append(.villager)
        }
        
        // Check military units
        for unitType in MilitaryUnitType.allCases {
            if unitType.trainingBuilding == buildingType {
                trainable.append(.military(unitType))
            }
        }
        
        return trainable
    }

    func startTraining(unitType: MilitaryUnitType, quantity: Int, at time: TimeInterval) {
        guard canTrain(unitType) else { return }
        
        let entry = TrainingQueueEntry(unitType: unitType, quantity: quantity, startTime: time)
        trainingQueue.append(entry)
        
        print("âœ… Started training \(quantity)x \(unitType.displayName) in \(buildingType.displayName)")
    }
    
    func updateTraining(currentTime: TimeInterval) {
        guard !trainingQueue.isEmpty else { return }
        
        var completedIndices: [Int] = []
        
        for (index, entry) in trainingQueue.enumerated() {
            let progress = entry.getProgress(currentTime: currentTime)
            trainingQueue[index].progress = progress
            
            if progress >= 1.0 {
                // Training complete - add units to garrison
                addToGarrison(unitType: entry.unitType, quantity: entry.quantity)
                completedIndices.append(index)
            }
        }
        
        // Remove completed entries (in reverse order to maintain indices)
        for index in completedIndices.reversed() {
            let entry = trainingQueue[index]
            print("✅ Training complete: \(entry.quantity)x \(entry.unitType.displayName)")
            trainingQueue.remove(at: index)
        }
    }
    
    func addVillagersToGarrison(quantity: Int) {
        villagerGarrison += quantity
        print("✅ \(buildingType.displayName) garrison: +\(quantity) villagers (Total: \(villagerGarrison))")
    }

    func removeVillagersFromGarrison(quantity: Int) -> Int {
        let toRemove = min(villagerGarrison, quantity)
        villagerGarrison -= toRemove
        if toRemove > 0 {
            print("✅ Removed \(toRemove) villagers from \(buildingType.displayName) garrison")
        }
        return toRemove
    }

    func getTotalGarrisonCount() -> Int {
        return getTotalGarrisonedUnits() + villagerGarrison
    }
    
    func cancelTraining(at index: Int) -> Bool {
        guard index >= 0 && index < trainingQueue.count else { return false }
        trainingQueue.remove(at: index)
        return true
    }

     // MARK: - Garrison Methods
     
    func addToGarrison(unitType: MilitaryUnitType, quantity: Int) {
        garrison[unitType, default: 0] += quantity
        print("âœ… \(buildingType.displayName) garrison: +\(quantity)x \(unitType.displayName) (Total: \(garrison[unitType] ?? 0))")
    }
     
    func removeFromGarrison(unitType: MilitaryUnitType, quantity: Int) -> Int {
        let current = garrison[unitType] ?? 0
        let toRemove = min(current, quantity)
        
        if toRemove > 0 {
            let remaining = current - toRemove
            if remaining > 0 {
                garrison[unitType] = remaining
            } else {
                garrison.removeValue(forKey: unitType)
            }
            print("âœ… Removed \(toRemove)x \(unitType.displayName) from \(buildingType.displayName) garrison")
        }
        
        return toRemove
    }
     
    func getTotalGarrisonedUnits() -> Int {
        return garrison.values.reduce(0, +)
    }

    func getGarrisonCount(of unitType: MilitaryUnitType) -> Int {
        return garrison[unitType] ?? 0
    }

    func hasGarrisonedUnits() -> Bool {
        return getTotalGarrisonedUnits() > 0
    }

     
    func getGarrisonDescription() -> String {
        let militaryCount = getTotalGarrisonedUnits()
        let hasUnits = militaryCount > 0 || villagerGarrison > 0
        
        guard hasUnits else { return "No units garrisoned" }
        
        var desc = "Garrisoned Units (\(getTotalGarrisonCount())/\(getGarrisonCapacity())):"
        
        // Show villagers first
        if villagerGarrison > 0 {
            desc += "\n  • \(villagerGarrison)x 👷 Villager"
        }
        
        // Then military units
        for (unitType, count) in garrison.sorted(by: { $0.key.displayName < $1.key.displayName }) {
            desc += "\n  • \(count)x \(unitType.icon) \(unitType.displayName)"
        }
        return desc
    }

    func getTrainingDescription() -> String {
        guard !trainingQueue.isEmpty else { return "No units training" }
        
        var desc = "Training Queue:"
        for (index, entry) in trainingQueue.enumerated() {
            let progress = Int(entry.progress * 100)
            desc += "\n  \(index + 1). \(entry.quantity)x \(entry.unitType.displayName) (\(progress)%)"
        }
        return desc
    }
    
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
            case .constructing:
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
        // Progress bar background
        let barWidth: CGFloat = 50
        let barHeight: CGFloat = 6
        let barY: CGFloat = -30
        
        let progressBarBg = SKShapeNode(rectOf: CGSize(width: barWidth, height: barHeight), cornerRadius: 2)
        progressBarBg.fillColor = UIColor(white: 0.2, alpha: 0.8)
        progressBarBg.strokeColor = .white
        progressBarBg.lineWidth = 1
        progressBarBg.position = CGPoint(x: 0, y: barY)
        progressBarBg.zPosition = 1
        progressBarBg.name = "progressBarBg"
        addChild(progressBarBg)
        
        // Progress bar fill - using SKSpriteNode instead for easier scaling
        let progressBarTexture = SKTexture(image: createProgressBarImage(width: barWidth - 2, height: barHeight - 2))
        progressBar = SKShapeNode(rectOf: CGSize(width: 1, height: barHeight - 2), cornerRadius: 1)
        progressBar?.fillColor = UIColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1.0)
        progressBar?.strokeColor = .clear
        progressBar?.position = CGPoint(x: -(barWidth - 2) / 2, y: barY)
        progressBar?.zPosition = 2
        progressBar?.name = "progressBarFill"
        addChild(progressBar!)
        
        // Timer label
        timerLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        timerLabel?.fontSize = 11
        timerLabel?.fontColor = .white
        timerLabel?.text = "0:00"
        timerLabel?.position = CGPoint(x: 0, y: barY - 12)
        timerLabel?.zPosition = 1
        timerLabel?.name = "timerLabel"
        addChild(timerLabel!)
        
        // Building name label
        buildingLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        buildingLabel?.fontSize = 9
        buildingLabel?.fontColor = .white
        buildingLabel?.text = buildingType.displayName
        buildingLabel?.position = CGPoint(x: 0, y: 25)
        buildingLabel?.zPosition = 1
        buildingLabel?.name = "buildingLabel"
        
        // Add shadow effect to label
        let shadow = SKLabelNode(fontNamed: "Helvetica-Bold")
        shadow.fontSize = 9
        shadow.fontColor = UIColor(white: 0, alpha: 0.7)
        shadow.text = buildingType.displayName
        shadow.position = CGPoint(x: 1, y: -1)
        shadow.zPosition = -1
        buildingLabel?.addChild(shadow)
        
        addChild(buildingLabel!)
        
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
        
        // Update alpha based on state
        switch state {
        case .planning:
            self.alpha = 0.6
        case .constructing:
            self.alpha = 0.5 + (constructionProgress * 0.5)
        case .completed:
            self.alpha = 1.0
        case .damaged:
            self.alpha = 0.8
        case .destroyed:
            self.alpha = 0.3
        }
        
        updateUIVisibility()
    }
    
    func updateUIVisibility() {
        let showConstruction = state == .constructing
        let showCompleted = state == .completed
        
        childNode(withName: "progressBarBg")?.isHidden = !showConstruction
        progressBar?.isHidden = !showConstruction
        timerLabel?.isHidden = !showConstruction
        buildingLabel?.isHidden = !(showCompleted || showConstruction)
    }
    
    func updateTimerLabel() {
        guard state == .constructing, let startTime = constructionStartTime else {
            timerLabel?.text = "0:00"
            progressBar?.xScale = 0
            return
        }
        
        let currentTime = Date().timeIntervalSince1970  // ✅ Use Unix epoch time
        let elapsed = currentTime - startTime
        
        let buildSpeedMultiplier = 1.0 + (Double(buildersAssigned - 1) * 0.5)
        let effectiveBuildTime = buildingType.buildTime / buildSpeedMultiplier
        
        let remaining = max(0, effectiveBuildTime - elapsed)
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        
        timerLabel?.text = String(format: "%d:%02d", minutes, seconds)
        progressBar?.xScale = CGFloat(constructionProgress)
    }
    
    func startConstruction(builders: Int = 1) {
        state = .constructing
        constructionStartTime = Date().timeIntervalSince1970  // ✅ Use consistent Unix epoch time
        constructionProgress = 0.0
        buildersAssigned = max(1, builders)
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
    
    func addBuilder() {
        buildersAssigned += 1
    }
    
    func removeBuilder() {
        buildersAssigned = max(1, buildersAssigned - 1)
    }
    
    func completeConstruction() {
        state = .completed
        constructionProgress = 1.0
        constructionStartTime = nil
        
        // Apply resource bonuses
        if let bonus = buildingType.resourceBonus {
            for (resourceType, amount) in bonus {
                owner?.increaseCollectionRate(resourceType, amount: amount)
            }
        }
        
        // ✅ Unlock the builder entity using stored reference
        if let entity = builderEntity {
            entity.isMoving = false
            print("✅ Unlocked builder entity")
        }
        
        // Clear villager tasks
        if let owner = owner {
            for villagerGroup in owner.getVillagerGroups() {
                if case .building(let building) = villagerGroup.currentTask,
                   building === self {
                    villagerGroup.clearTask()
                    print("✅ Cleared building task for \(villagerGroup.name)")
                }
            }
        }
        
        print("✅ Building \(buildingType.displayName) completed!")
    }
    
    func takeDamage(_ amount: Double) {
        guard state == .completed || state == .damaged else { return }
        
        health = max(0, health - amount)
        
        if health <= 0 {
            state = .destroyed
        } else if health < maxHealth / 2 {
            state = .damaged
        }
    }
    
    func repair(_ amount: Double) {
        guard state == .damaged else { return }
        
        health = min(maxHealth, health + amount)
        
        if health >= maxHealth / 2 {
            state = .completed
        }
    }
        
    var garrisonedUnits: [UnitType: Int] {
            get {
                return (objc_getAssociatedObject(self, &BuildingNode.garrisonKey) as? [UnitType: Int]) ?? [:]
            }
            set {
                objc_setAssociatedObject(self, &BuildingNode.garrisonKey, newValue, .OBJC_ASSOCIATION_RETAIN)
            }
        }
        
        func garrisonUnits(_ unitType: UnitType, count: Int) {
            garrisonedUnits[unitType, default: 0] += count
        }
        
        func ungarrisonUnits(_ unitType: UnitType, count: Int) -> Int {
            let current = garrisonedUnits[unitType] ?? 0
            let toRemove = min(current, count)
            
            if toRemove > 0 {
                let remaining = current - toRemove
                if remaining > 0 {
                    garrisonedUnits[unitType] = remaining
                } else {
                    garrisonedUnits.removeValue(forKey: unitType)
                }
            }
            
            return toRemove
        }
        
    func getGarrisonCapacity() -> Int {
        switch buildingType.category {
        case .military:
            return 500  // Increased capacity for military buildings
        case .economic:
            return 100
        }
    }
        
    func hasGarrisonSpace(for count: Int) -> Bool {
        return getTotalGarrisonedUnits() + count <= getGarrisonCapacity()
    }
    
    func startVillagerTraining(quantity: Int, at time: TimeInterval) {
        let entry = VillagerTrainingEntry(quantity: quantity, startTime: time)
        villagerTrainingQueue.append(entry)
        print("✅ Started training \(quantity)x Villagers in \(buildingType.displayName)")
    }

    // âœ… ADD THIS NEW METHOD:
    func updateVillagerTraining(currentTime: TimeInterval) {
        guard !villagerTrainingQueue.isEmpty else { return }
        
        var completedIndices: [Int] = []
        
        for (index, entry) in villagerTrainingQueue.enumerated() {
            let progress = entry.getProgress(currentTime: currentTime)
            villagerTrainingQueue[index].progress = progress
            
            if progress >= 1.0 {
                // Training complete - add villagers to garrison
                addVillagersToGarrison(quantity: entry.quantity)
                completedIndices.append(index)
            }
        }
        
        // Remove completed entries
        for index in completedIndices.reversed() {
            let entry = villagerTrainingQueue[index]
            print("✅ Villager training complete: \(entry.quantity) villagers")
            villagerTrainingQueue.remove(at: index)
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

    
}
