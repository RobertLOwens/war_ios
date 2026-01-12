import UIKit

class TrainingSliderContext: Hashable {
    let unitType: TrainableUnitType
    weak var container: UIView?
    weak var building: BuildingNode?
    
    init(unitType: TrainableUnitType, container: UIView, building: BuildingNode) {
        self.unitType = unitType
        self.container = container
        self.building = building
    }
    
    func hash(into hasher: inout Hasher) {
        // Create unique hash based on unit type and building
        hasher.combine(unitType.displayName)
        hasher.combine(building?.coordinate.q ?? 0)
        hasher.combine(building?.coordinate.r ?? 0)
    }
    
    static func == (lhs: TrainingSliderContext, rhs: TrainingSliderContext) -> Bool {
        return lhs.unitType.displayName == rhs.unitType.displayName &&
               lhs.building?.coordinate.q == rhs.building?.coordinate.q &&
               lhs.building?.coordinate.r == rhs.building?.coordinate.r
    }
}

class BuildingDetailViewController: UIViewController {
    
    var building: BuildingNode!
    var player: Player!
    var gameViewController: GameViewController?
    var trainingContexts: [Int: TrainingSliderContext]?
    var hexMap: HexMap!  // ✅ ADD THIS
    var gameScene: GameScene!  // ✅ ADD THIS
    
    var scrollView: UIScrollView!
    var contentView: UIView!
    
    // Training UI elements
    var trainingContainerView: UIView?
    var trainingSlider: UISlider?
    var trainingCountLabel: UILabel?
    var trainingCostLabel: UILabel?
    var trainingTimeLabel: UILabel?
    var queueLabel: UILabel?
    
    private struct AssociatedKeys {
        static var unitLabels = "unitLabels"
        static var garrisonData = "garrisonData"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        print("🎬 BuildingDetailViewController loaded for \(building.buildingType.displayName)")
        print("   Training queue: \(building.trainingQueue.count)")
        print("   Villager queue: \(building.villagerTrainingQueue.count)")
        
        // Update queue display every second
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            if self.building.state == .upgrading {
                self.updateUpgradeProgressDisplay()
            }
            self.updateQueueDisplay()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Adjust frames if needed
        if let topOverlay = view.subviews.first {
            topOverlay.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 60)
        }
        
        scrollView?.frame = CGRect(x: 0, y: 60, width: view.bounds.width, height: view.bounds.height - 60)
        
        // Only setup once
        if contentView.subviews.isEmpty {
            setupContent()
        }
    }
    
    func setupUI() {
        // ✅ Solid background that blocks all touches to game beneath
        view.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        view.isUserInteractionEnabled = true
        
        // Add a dimmed overlay at the top to make it look modal
        let topOverlay = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 60))
        topOverlay.backgroundColor = UIColor(white: 0.1, alpha: 0.95)
        view.addSubview(topOverlay)
        
        // Scroll view for content
        scrollView = UIScrollView()
        scrollView.frame = CGRect(x: 0, y: 60, width: view.bounds.width, height: view.bounds.height - 60)
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.showsVerticalScrollIndicator = true
        scrollView.isUserInteractionEnabled = true
        scrollView.delaysContentTouches = false // ✅ Important for buttons/sliders
        view.addSubview(scrollView)
        
        contentView = UIView()
        contentView.frame = CGRect(x: 0, y: 0, width: scrollView.bounds.width, height: 0)
        scrollView.addSubview(contentView)
        
        // Close button (on top overlay)
        let closeButton = UIButton(frame: CGRect(x: view.bounds.width - 70, y: 10, width: 50, height: 40))
        closeButton.setTitle("✕", for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.backgroundColor = UIColor(white: 0.3, alpha: 0.8)
        closeButton.layer.cornerRadius = 8
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        topOverlay.addSubview(closeButton)
        
        // Title on top overlay
        let titleLabel = UILabel(frame: CGRect(x: 20, y: 10, width: view.bounds.width - 100, height: 40))
        titleLabel.text = "\(building.buildingType.icon) \(building.buildingType.displayName)"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 24)
        titleLabel.textColor = .white
        topOverlay.addSubview(titleLabel)
    }
    
    func setupContent() {
        var yOffset: CGFloat = 20
        let leftMargin: CGFloat = 20
        let rightMargin: CGFloat = 20
        let contentWidth = view.bounds.width - leftMargin - rightMargin
        
        // Status
        let statusLabel = createLabel(text: "Status: Completed ✅",
                                     fontSize: 16,
                                     color: UIColor(white: 0.9, alpha: 1.0))
        statusLabel.frame = CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: 25)
        contentView.addSubview(statusLabel)
        yOffset += 30
        
        // Health
        let healthLabel = createLabel(text: "Health: \(Int(building.health))/\(Int(building.maxHealth))",
                                     fontSize: 16,
                                     color: UIColor(white: 0.9, alpha: 1.0))
        healthLabel.frame = CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: 25)
        contentView.addSubview(healthLabel)
        yOffset += 30
        
        let levelLabel = createLabel(text: "⭐ Level: \(building.level)/\(building.maxLevel)",
                                    fontSize: 16,
                                    color: UIColor(white: 0.9, alpha: 1.0))
        levelLabel.frame = CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: 25)
        contentView.addSubview(levelLabel)
        yOffset += 35
        
        // Upgrade Section (only if building can be upgraded)
        if building.state == .completed && building.canUpgrade {
            yOffset = setupUpgradeSection(yOffset: yOffset, leftMargin: leftMargin, contentWidth: contentWidth)
        } else if building.state == .upgrading {
            yOffset = setupUpgradingProgressSection(yOffset: yOffset, leftMargin: leftMargin, contentWidth: contentWidth)
        } else if building.level >= building.maxLevel {
            let maxLevelLabel = createLabel(text: "✨ Maximum Level Reached",
                                           fontSize: 14,
                                           color: UIColor(red: 1.0, green: 0.85, blue: 0.4, alpha: 1.0))
            maxLevelLabel.frame = CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: 25)
            contentView.addSubview(maxLevelLabel)
            yOffset += 35
        }
        
        // Location
        let locationLabel = createLabel(text: "📍 Location: (\(building.coordinate.q), \(building.coordinate.r))",
                                       fontSize: 14,
                                       color: UIColor(white: 0.7, alpha: 1.0))
        locationLabel.frame = CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: 25)
        contentView.addSubview(locationLabel)
        yOffset += 35
        
        // Garrison info
        if building.getTotalGarrisonCount() > 0 {
            let garrisonLabel = createLabel(text: "🏰 Garrison: \(building.getTotalGarrisonCount())/\(building.getGarrisonCapacity()) units",
                                           fontSize: 16,
                                           weight: .semibold,
                                           color: .white)
            garrisonLabel.frame = CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: 25)
            contentView.addSubview(garrisonLabel)
            yOffset += 35
            
            let garrisonDesc = building.getGarrisonDescription()
            let garrisonDetailLabel = createLabel(text: garrisonDesc,
                                                  fontSize: 14,
                                                  color: UIColor(white: 0.8, alpha: 1.0))
            garrisonDetailLabel.frame = CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: 0)
            garrisonDetailLabel.numberOfLines = 0
            garrisonDetailLabel.sizeToFit()
            contentView.addSubview(garrisonDetailLabel)
            yOffset += garrisonDetailLabel.frame.height + 20
            
            // Deploy button for City Center
            if building.buildingType == .cityCenter {
                let deployButton = createActionButton(
                    title: "🚀 Deploy Villagers",
                    y: yOffset,
                    width: contentWidth,
                    leftMargin: leftMargin,
                    color: UIColor(red: 0.5, green: 0.6, blue: 0.8, alpha: 1.0),
                    action: #selector(deployVillagersTapped)
                )
                contentView.addSubview(deployButton)
                yOffset += 70
            }
            
            // Reinforce Army button (non-City Center buildings)
            if building.buildingType != .cityCenter {
                let reinforceButton = createActionButton(
                    title: "⚔️ Reinforce Army",
                    y: yOffset,
                    width: contentWidth,
                    leftMargin: leftMargin,
                    color: UIColor(red: 0.8, green: 0.4, blue: 0.2, alpha: 1.0),
                    action: #selector(reinforceArmyTapped)
                )
                contentView.addSubview(reinforceButton)
                yOffset += 70
            }
        }
        
        // Divider
        let divider = UIView(frame: CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: 1))
        divider.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
        contentView.addSubview(divider)
        yOffset += 20
        
        // ✅ Training section - THIS WAS MISSING
        yOffset = addTrainingSection(yOffset: yOffset, leftMargin: leftMargin, contentWidth: contentWidth)
        
        // Set content size
        contentView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: yOffset + 20)
        scrollView.contentSize = CGSize(width: view.bounds.width, height: yOffset + 20)
    }
    
    func addTrainingSection(yOffset: CGFloat, leftMargin: CGFloat, contentWidth: CGFloat) -> CGFloat {
        var currentY = yOffset
        
        // Training queue display
        let queueTitleLabel = createLabel(text: "📋 Training Queue",
                                         fontSize: 18,
                                         weight: .bold,
                                         color: .white)
        queueTitleLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 30)
        contentView.addSubview(queueTitleLabel)
        currentY += 35
        
        // Queue display label
        queueLabel = createLabel(text: getQueueText(),
                                fontSize: 13,
                                color: UIColor(white: 0.8, alpha: 1.0))
        queueLabel?.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 0)
        queueLabel?.numberOfLines = 0
        queueLabel?.sizeToFit()
        contentView.addSubview(queueLabel!)
        currentY += max(queueLabel?.frame.height ?? 0, 20) + 30
        
        // Training controls - show sliders for each trainable unit
        if canTrainUnits() {
            let trainTitleLabel = createLabel(text: "🎖️ Train New Units",
                                             fontSize: 18,
                                             weight: .bold,
                                             color: .white)
            trainTitleLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 30)
            contentView.addSubview(trainTitleLabel)
            currentY += 40
            
            let trainableUnits = getTrainableUnits()
            
            for trainableUnit in trainableUnits {
                currentY = addTrainingSlider(for: trainableUnit, yOffset: currentY, leftMargin: leftMargin, contentWidth: contentWidth)
            }
        }
        
        return currentY
    }

    func addTrainingSlider(for unitType: TrainableUnitType, yOffset: CGFloat, leftMargin: CGFloat, contentWidth: CGFloat) -> CGFloat {
        var currentY = yOffset
        
        // Container for this training slider
        let container = UIView(frame: CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 0))
        container.backgroundColor = UIColor(white: 0.2, alpha: 0.5)
        container.layer.cornerRadius = 12
        container.isUserInteractionEnabled = true
        contentView.addSubview(container)
        
        var containerY: CGFloat = 15
        let containerInnerWidth = contentWidth - 30
        
        // Unit title
        let titleLabel = createLabel(text: "\(unitType.icon) \(unitType.displayName)",
                                     fontSize: 16,
                                     weight: .semibold,
                                     color: .white)
        titleLabel.frame = CGRect(x: 15, y: containerY, width: containerInnerWidth, height: 25)
        container.addSubview(titleLabel)
        containerY += 35
        
        // Calculate max affordable based on resources
        var maxAffordable = 100
        for (resourceType, unitCost) in unitType.trainingCost {
            let available = player.getResource(resourceType)
            let canAfford = available / unitCost
            maxAffordable = min(maxAffordable, canAfford)
        }
        
        // Also cap by available population space
        let availablePop = player.getAvailablePopulation()
        maxAffordable = min(maxAffordable, availablePop)
        
        // Ensure at least 1 for slider to work, but button will be disabled if 0
        let sliderMax = max(1, maxAffordable)
        let canTrain = maxAffordable >= 1
        
        // Create a training context object to hold all the data
        let trainingContext = TrainingSliderContext(
            unitType: unitType,
            container: container,
            building: building
        )

        // Slider
        let slider = UISlider(frame: CGRect(x: 15, y: containerY, width: containerInnerWidth, height: 30))
        slider.minimumValue = 1
        slider.maximumValue = Float(min(sliderMax, 20))
        slider.value = 1
        slider.isContinuous = true
        slider.isEnabled = canTrain
        slider.isUserInteractionEnabled = true
        slider.alpha = canTrain ? 1.0 : 0.5
        slider.tag = trainingContext.hashValue
        slider.addTarget(self, action: #selector(trainingSliderChanged(_:)), for: .valueChanged)
        container.addSubview(slider)
        containerY += 45
        
        slider.isEnabled = canTrain
        if !canTrain {
            slider.alpha = 0.5
        }
        
        // Store context in a dictionary keyed by hash
        if trainingContexts == nil {
            trainingContexts = [:]
        }
        trainingContexts?[trainingContext.hashValue] = trainingContext
        
        // Count label
        let countLabel = createLabel(text: "Quantity: 1",
                                     fontSize: 14,
                                     weight: .medium,
                                     color: .white)
        countLabel.frame = CGRect(x: 15, y: containerY, width: containerInnerWidth, height: 20)
        countLabel.tag = 1000
        container.addSubview(countLabel)
        containerY += 25
        
        // Cost label
        let costDesc = unitType.trainingCost.map { "\($0.value) \($0.key.icon) \($0.key.displayName)" }.joined(separator: ", ")
        let costLabel = createLabel(text: "Cost: \(costDesc)",
                                    fontSize: 13,
                                    color: UIColor(white: 0.8, alpha: 1.0))
        costLabel.frame = CGRect(x: 15, y: containerY, width: containerInnerWidth, height: 20)
        costLabel.tag = 1001
        container.addSubview(costLabel)
        containerY += 25
        
        // Time label
        let time = Int(unitType.trainingTime)
        let timeLabel = createLabel(text: "Time: \(time/60)m \(time%60)s per unit",
                                    fontSize: 13,
                                    color: UIColor(white: 0.8, alpha: 1.0))
        timeLabel.frame = CGRect(x: 15, y: containerY, width: containerInnerWidth, height: 20)
        timeLabel.tag = 1002
        container.addSubview(timeLabel)
        containerY += 30
        
        let currentPop = player.getCurrentPopulation()
        let maxPop = player.getPopulationCapacity()
        let popColor: UIColor = availablePop == 0 ? UIColor.systemRed : UIColor(white: 0.8, alpha: 1.0)
        let popLabel = createLabel(text: "👥 Population: \(currentPop)/\(maxPop) (\(availablePop) available)",
                                   fontSize: 13,
                                   color: popColor)
        popLabel.frame = CGRect(x: 15, y: containerY, width: containerInnerWidth, height: 20)
        container.addSubview(popLabel)
        containerY += 30
        
        // Train button
        let trainButton = UIButton(type: .system)
        trainButton.frame = CGRect(x: 15, y: containerY, width: containerInnerWidth, height: 44)
        trainButton.setTitle("✅ Start Training", for: .normal)
        trainButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        trainButton.setTitleColor(.white, for: .normal)
        trainButton.backgroundColor = UIColor(red: 0.3, green: 0.7, blue: 0.4, alpha: 1.0)
        trainButton.layer.cornerRadius = 10
        trainButton.isEnabled = true
        trainButton.isUserInteractionEnabled = true
        trainButton.tag = trainingContext.hashValue // Use same hash
        trainButton.addTarget(self, action: #selector(trainButtonTapped(_:)), for: .touchUpInside)
        container.addSubview(trainButton)
        containerY += 55
        
        trainButton.isEnabled = canTrain
        trainButton.alpha = canTrain ? 1.0 : 0.5
        if !canTrain {
            trainButton.setTitle("⚠️ Pop Limit Reached", for: .normal)
            trainButton.backgroundColor = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        }
        
        container.frame.size.height = containerY + 10
        
        return currentY + containerY + 25
    }
    
    @objc func trainingSliderChanged(_ slider: UISlider) {
        guard let context = trainingContexts?[slider.tag],
              let container = context.container else {
            print("❌ Slider changed but no context found for tag \(slider.tag)")
            return
        }
        
        let count = Int(slider.value)
        let unitType = context.unitType
        
        // Update count label
        if let countLabel = container.viewWithTag(1000) as? UILabel {
            countLabel.text = "Quantity: \(count)"
        }
        
        // Update cost label
        if let costLabel = container.viewWithTag(1001) as? UILabel {
            let totalCost = unitType.trainingCost.map { "\($0.value * count) \($0.key.icon) \($0.key.displayName)" }.joined(separator: ", ")
            costLabel.text = "Cost: \(totalCost)"
        }
        
        let availablePop = player.getAvailablePopulation()
        if count > availablePop {
            // This shouldn't happen with proper slider max, but just in case
            slider.value = Float(availablePop)
        }
        
        // Update time label
        if let timeLabel = container.viewWithTag(1002) as? UILabel {
            let totalTime = Int(unitType.trainingTime * Double(count))
            let mins = totalTime / 60
            let secs = totalTime % 60
            timeLabel.text = "Total Time: \(mins)m \(secs)s"
        }
    }

    @objc func trainButtonTapped(_ sender: UIButton) {
        print("🔘 Train button tapped")
        
        guard let context = trainingContexts?[sender.tag],
              let container = context.container else {
            print("❌ No context found for button tag \(sender.tag)")
            return
        }
        
        // Find the slider in the same container
        guard let slider = container.subviews.first(where: { $0 is UISlider }) as? UISlider else {
            print("❌ No slider found in container")
            return
        }
        
        let quantity = Int(slider.value)
        let unitType = context.unitType
        
        print("📊 Training \(quantity)x \(unitType.displayName)")
        
        startTraining(unitType: unitType, quantity: quantity)
        
        // Reset slider to 1
        slider.value = 1
        trainingSliderChanged(slider)
    }

    func startTraining(unitType: TrainableUnitType, quantity: Int) {
        print("🎯 startTraining called: \(quantity)x \(unitType.displayName)")
        
        // Check resources
        var canAfford = true
        var missingResources: [String] = []
        
        for (resourceType, unitCost) in unitType.trainingCost {
            let totalCost = unitCost * quantity
            let available = player.getResource(resourceType)
            print("   \(resourceType.displayName): need \(totalCost), have \(available)")
            
            if !player.hasResource(resourceType, amount: totalCost) {
                canAfford = false
                missingResources.append("\(resourceType.icon) \(resourceType.displayName): need \(totalCost), have \(available)")
            }
        }
        
        if !canAfford {
            let message = "Insufficient resources:\n" + missingResources.joined(separator: "\n")
            showAlert(title: "Cannot Afford", message: message)
        }
        
        // Check popuation space
        let popNeeded = quantity
        if !player.hasPopulationSpace(for: popNeeded) {
            let available = player.getAvailablePopulation()
            showAlert(
                title: "Population Limit Reached",
                message: "Need \(popNeeded) population space, but only \(available) available.\n\nBuild more Neighborhoods or City Centers to increase capacity."
            )
            return
        }
        
        // Deduct resources
        print("💰 Deducting resources...")
        for (resourceType, unitCost) in unitType.trainingCost {
            let totalCost = unitCost * quantity
            player.removeResource(resourceType, amount: totalCost)
        }
        
        // Start training
        let currentTime = Date().timeIntervalSince1970
        print("⏰ Current time: \(currentTime)")
        
        switch unitType {
        case .villager:
            print("👷 Starting villager training...")
            building.startVillagerTraining(quantity: quantity, at: currentTime)
            print("✅ Villager training queue count: \(building.villagerTrainingQueue.count)")
            
        case .military(let militaryType):
            print("⚔️ Starting military training...")
            building.startTraining(unitType: militaryType, quantity: quantity, at: currentTime)
            print("✅ Military training queue count: \(building.trainingQueue.count)")
        }
        
        // Update resource display
        gameViewController?.updateResourceDisplay()
        
        // Refresh queue display
        print("🔄 Updating queue display...")
        updateQueueDisplay()
        
        showAlert(
            title: "✅ Training Started",
            message: "Training \(quantity) \(unitType.displayName)\(quantity > 1 ? "s" : "")"
        )
    }
    
    func updateQueueDisplay() {
        
        queueLabel?.text = queueText
        
        // Force the label to recalculate its size
        queueLabel?.frame = CGRect(x: 20, y: queueLabel?.frame.origin.y ?? 0,
                                   width: view.bounds.width - 40, height: 0)
        queueLabel?.numberOfLines = 0
        queueLabel?.sizeToFit()
    }
    
    func getQueueText() -> String {
        let militaryQueue = building.trainingQueue
        let villagerQueue = building.villagerTrainingQueue
        
        if militaryQueue.isEmpty && villagerQueue.isEmpty {
            return "No units currently training"
        }
        
        var text = ""
        let currentTime = Date().timeIntervalSince1970
        
        for entry in villagerQueue {
            let remaining = entry.getTimeRemaining(currentTime: currentTime)
            let completed = entry.getVillagersCompleted(currentTime: currentTime)
            let mins = Int(remaining) / 60
            let secs = Int(remaining) % 60
            text += "👷 Villagers: \(completed)/\(entry.quantity) - \(mins)m \(secs)s\n"
        }
        
        for entry in militaryQueue {
            let remaining = entry.getTimeRemaining(currentTime: currentTime)
            let completed = entry.getUnitsCompleted(currentTime: currentTime)
            let mins = Int(remaining) / 60
            let secs = Int(remaining) % 60
            text += "\(entry.unitType.icon) \(entry.unitType.displayName): \(completed)/\(entry.quantity) - \(mins)m \(secs)s\n"
        }
        
        return text.isEmpty ? "No units currently training" : text
    }
    
    func canTrainUnits() -> Bool {
        return building.buildingType == .cityCenter ||
               building.buildingType == .neighborhood ||
               building.buildingType.category == .military
    }
    
    func getTrainableUnits() -> [TrainableUnitType] {
        var units: [TrainableUnitType] = []
        
        if building.buildingType == .cityCenter || building.buildingType == .neighborhood {
            units.append(.villager)
        }
        
        if building.buildingType.category == .military {
            for militaryType in MilitaryUnitType.allCases {
                if militaryType.trainingBuilding == building.buildingType {
                    units.append(.military(militaryType))
                }
            }
        }
        
        return units
    }
    
    func createLabel(text: String, fontSize: CGFloat, weight: UIFont.Weight = .regular, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: fontSize, weight: weight)
        label.textColor = color
        return label
    }
    
    func createActionButton(title: String, y: CGFloat, width: CGFloat, leftMargin: CGFloat, color: UIColor, action: Selector) -> UIButton {
        let button = UIButton(frame: CGRect(x: 0, y: y, width: width, height: 55))
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.backgroundColor = color
        button.layer.cornerRadius = 12
        button.isUserInteractionEnabled = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }
    
    @objc func trainVillagersTapped() {
        // Don't dismiss - show training UI inline
        print("🎯 Train Villagers tapped - showing inline training")
        
        // Scroll to training section if it exists
        if let trainingSection = contentView.subviews.first(where: {
            ($0.subviews.first as? UILabel)?.text?.contains("Train New Units") == true
        }) {
            scrollView.scrollRectToVisible(trainingSection.frame, animated: true)
        }
    }

    @objc func trainUnitsTapped() {
        // Don't dismiss - show training UI inline
        print("🎯 Train Units tapped - showing inline training")
        
        // Scroll to training section if it exists
        if let trainingSection = contentView.subviews.first(where: {
            ($0.subviews.first as? UILabel)?.text?.contains("Train New Units") == true
        }) {
            scrollView.scrollRectToVisible(trainingSection.frame, animated: true)
        }
    }
    
    func showDeployError_Updated() {
        showAlert(title: "Cannot Deploy", message: "No walkable location near \(building.buildingType.displayName) to deploy villagers.")
    }

    @objc func deployVillagersTapped() {
        let villagerCount = building.getTotalGarrisonCount()
        
        guard villagerCount > 0 else {
            showAlert(title: "No Villagers", message: "There are no villagers in the garrison to deploy.")
            return
        }
        
        guard let spawnCoord = hexMap.findNearestWalkable(to: building.coordinate, maxDistance: 3) else {
            showAlert(title: "Cannot Deploy", message: "No walkable location near \(building.buildingType.displayName) to deploy villagers.")
            return
        }
        
        // Create custom alert with slider
        let alert = UIAlertController(
            title: "👷 Deploy Villagers",
            message: "Select how many villagers to deploy\n\nAvailable: \(villagerCount) villagers",
            preferredStyle: .alert
        )
        
        // Create container for slider
        let containerVC = UIViewController()
        containerVC.preferredContentSize = CGSize(width: 270, height: 120)
        
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 270, height: 120))
        
        // Slider
        let slider = UISlider(frame: CGRect(x: 20, y: 20, width: 230, height: 30))
        slider.minimumValue = 1
        slider.maximumValue = Float(villagerCount)
        slider.value = Float(min(5, villagerCount))
        slider.isContinuous = true
        slider.tag = 100 // Tag to identify slider
        containerView.addSubview(slider)
        
        // Count label
        let countLabel = UILabel(frame: CGRect(x: 20, y: 60, width: 230, height: 30))
        countLabel.text = "\(Int(slider.value)) villagers"
        countLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        countLabel.textColor = .label
        countLabel.textAlignment = .center
        countLabel.tag = 101 // Tag to identify label
        containerView.addSubview(countLabel)
        
        // Update label when slider moves
        slider.addTarget(self, action: #selector(deploySliderChanged(_:)), for: .valueChanged)
        
        containerVC.view.addSubview(containerView)
        alert.setValue(containerVC, forKey: "contentViewController")
        
        // Deploy action
        alert.addAction(UIAlertAction(title: "Deploy", style: .default) { [weak self] _ in
            let deployCount = Int(slider.value)
            self?.deployVillagers(count: deployCount, at: spawnCoord)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    @objc func deploySliderChanged(_ slider: UISlider) {
        // Find the label in the same superview
        if let containerView = slider.superview,
           let label = containerView.viewWithTag(101) as? UILabel {
            label.text = "\(Int(slider.value)) villagers"
        }
    }
    
    func deployVillagers(count: Int, at coordinate: HexCoordinate) {
        let removed = building.removeVillagersFromGarrison(quantity: count)
        
        guard removed > 0 else {
            showAlert(title: "Deploy Failed", message: "Could not remove villagers from garrison.")
            return
        }
        
        // Create villager group
        let villagerGroup = VillagerGroup(name: "Villagers", coordinate: coordinate, villagerCount: removed, owner: player)
        
        // Create entity node
        let entityNode = EntityNode(coordinate: coordinate, entityType: .villagerGroup, entity: villagerGroup, currentPlayer: player)
        let position = HexMap.hexToPixel(q: coordinate.q, r: coordinate.r)
        entityNode.position = position
        
        // Add to game
        hexMap.addEntity(entityNode)
        gameScene.entitiesNode.addChild(entityNode)
        player.addEntity(villagerGroup)
        
        print("✅ Deployed \(removed) villagers from \(building.buildingType.displayName) at (\(coordinate.q), \(coordinate.r))")
        
        // Dismiss and show success
        dismiss(animated: true) { [weak self] in
            self?.gameViewController?.showAlert(
                title: "✅ Villagers Deployed",
                message: "Deployed \(removed) villagers at (\(coordinate.q), \(coordinate.r))"
            )
        }
    }

    @objc func reinforceArmyTapped() {
        let armiesOnField = player.getArmies()
        
        guard !armiesOnField.isEmpty else {
            showAlert(title: "No Armies", message: "You don't have any armies to reinforce. Recruit a commander first!")
            return
        }
        
        var actions: [AlertAction] = []
        
        for army in armiesOnField {
            let unitCount = army.getTotalMilitaryUnits()
            let commanderName = army.commander?.name ?? "No Commander"
            let distance = army.coordinate.distance(to: building.coordinate)
            let title = "🛡️ \(army.name) - \(commanderName) (\(unitCount) units) - Distance: \(distance)"
            
            actions.append(AlertAction(title: title) { [weak self] in
                self?.showReinforceMenu(for: army)
            })
        }
        
        showActionSheet(
            title: "⚔️ Select Army to Reinforce",
            message: "Choose which army to reinforce from \(building.buildingType.displayName):\n\nGarrison: \(building.getTotalGarrisonedUnits()) units available",
            actions: actions
        )
    }
    
    func showReinforceMenu(for army: Army) {
        let militaryGarrison = building.garrison
        
        guard !militaryGarrison.isEmpty else {
            showAlert(title: "No Military Units", message: "This building has no military units to reinforce with. Only military units can reinforce armies.")
            return
        }
        
        // Build the custom slider container
        let containerVC = UIViewController()
        let containerHeight = CGFloat(militaryGarrison.count * 90 + 40)
        containerVC.preferredContentSize = CGSize(width: 270, height: min(containerHeight, 400))
        
        let contentView = UIView(frame: CGRect(x: 0, y: 0, width: 270, height: containerHeight))
        
        var unitSliders: [MilitaryUnitType: UISlider] = [:]
        var unitLabels: [MilitaryUnitType: UILabel] = [:]
        var yOffset: CGFloat = 20
        
        for (militaryType, count) in militaryGarrison.sorted(by: { $0.key.displayName < $1.key.displayName }) {
            guard count > 0 else { continue }
            
            // Unit label
            let unitLabel = UILabel(frame: CGRect(x: 10, y: yOffset, width: 250, height: 20))
            unitLabel.text = "\(militaryType.icon) \(militaryType.displayName): \(count) available"
            unitLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
            unitLabel.textColor = .label
            contentView.addSubview(unitLabel)
            yOffset += 25
            
            // Slider
            let slider = UISlider(frame: CGRect(x: 10, y: yOffset, width: 250, height: 30))
            slider.minimumValue = 0
            slider.maximumValue = Float(count)
            slider.value = 0
            slider.isContinuous = true
            slider.tag = militaryType.hashValue
            contentView.addSubview(slider)
            unitSliders[militaryType] = slider
            yOffset += 35
            
            // Count label
            let countLabel = UILabel(frame: CGRect(x: 10, y: yOffset, width: 250, height: 20))
            countLabel.text = "0 / \(count) units"
            countLabel.font = UIFont.systemFont(ofSize: 12)
            countLabel.textColor = .secondaryLabel
            countLabel.textAlignment = .center
            contentView.addSubview(countLabel)
            unitLabels[militaryType] = countLabel
            yOffset += 30
        }
        
        // Store references for slider change handler
        objc_setAssociatedObject(self, &AssociatedKeys.unitLabels, unitLabels, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(self, &AssociatedKeys.garrisonData, militaryGarrison, .OBJC_ASSOCIATION_RETAIN)
        
        // Add slider targets
        for slider in unitSliders.values {
            slider.addTarget(self, action: #selector(reinforceSliderChanged(_:)), for: .valueChanged)
        }
        
        contentView.frame.size.height = yOffset
        containerVC.view.addSubview(contentView)
        
        // Use showAlertWithCustomContent from AlertHelper
        showAlertWithCustomContent(
            title: "⚔️ Reinforce \(army.name)",
            message: "Select military units to transfer from garrison",
            contentViewController: containerVC,
            actions: [
                AlertAction(title: "Reinforce") { [weak self, unitSliders] in
                    guard let self = self else { return }
                    
                    var unitsToTransfer: [MilitaryUnitType: Int] = [:]
                    for (unitType, slider) in unitSliders {
                        let count = Int(slider.value)
                        if count > 0 {
                            unitsToTransfer[unitType] = count
                        }
                    }
                    
                    if !unitsToTransfer.isEmpty {
                        self.executeReinforcement(to: army, units: unitsToTransfer)
                    }
                },
                .cancel()
            ]
        )
    }
    
    func executeReinforcement(to army: Army, units: [MilitaryUnitType: Int]) {
        var totalTransferred = 0
        
        for (unitType, count) in units {
            let removed = building.removeFromGarrison(unitType: unitType, quantity: count)
            if removed > 0 {
                army.addMilitaryUnits(unitType, count: removed)
                totalTransferred += removed
            }
        }
        
        if totalTransferred > 0 {
            showAlert(
                title: "✅ Reinforcement Complete",
                message: "Transferred \(totalTransferred) units to \(army.name)\nNew Army Size: \(army.getTotalMilitaryUnits()) units"
            )
            print("✅ Reinforced \(army.name) with \(totalTransferred) units from \(building.buildingType.displayName)")
        }
    }
    
    func reinforceArmy(_ army: Army, with units: [MilitaryUnitType: Int]) {
        var totalTransferred = 0
        
        for (militaryType, count) in units {
            let removed = building.removeFromGarrison(unitType: militaryType, quantity: count)
            if removed > 0 {
                army.addMilitaryUnits(militaryType, count: removed)
                totalTransferred += removed
            }
        }
        
        if totalTransferred > 0 {
            dismiss(animated: true) { [weak self] in
                self?.gameViewController?.showSimpleAlert(
                    title: "✅ Reinforcement Complete",
                    message: "Transferred \(totalTransferred) units to \(army.name)\nNew Army Size: \(army.getTotalMilitaryUnits()) units"
                )
            }
            
            print("✅ Reinforced \(army.name) with \(totalTransferred) units from \(building.buildingType.displayName)")
        }
    }
    
    @objc func reinforceSliderChanged(_ slider: UISlider) {
        guard let labelsDict = objc_getAssociatedObject(self, &AssociatedKeys.unitLabels) as? [MilitaryUnitType: UILabel],
              let garrisonDict = objc_getAssociatedObject(self, &AssociatedKeys.garrisonData) as? [MilitaryUnitType: Int] else {
            return
        }
        
        // Find the label that matches this slider's tag
        for (unitType, label) in labelsDict {
            if unitType.hashValue == slider.tag {
                let available = garrisonDict[unitType] ?? 0
                let sliderValue = Int(slider.value)
                label.text = "\(sliderValue) / \(available) units"
                break
            }
        }
    }

    @objc func closeTapped() {
        dismiss(animated: true)
    }
    
    func setupUpgradeSection(yOffset: CGFloat, leftMargin: CGFloat, contentWidth: CGFloat) -> CGFloat {
       var currentY = yOffset
       
       // Section header
       let upgradeHeader = createLabel(text: "⬆️ Upgrade to Level \(building.level + 1)",
                                      fontSize: 18,
                                      weight: .bold,
                                      color: .cyan)
       upgradeHeader.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 25)
       contentView.addSubview(upgradeHeader)
       currentY += 30
       
       // Cost display
       if let upgradeCost = building.getUpgradeCost() {
           var costText = "Cost: "
           var canAfford = true
           
           for (resourceType, amount) in upgradeCost {
               let hasEnough = player.hasResource(resourceType, amount: amount)
               let currentAmount = player.getResource(resourceType)
               if !hasEnough { canAfford = false }
               let checkmark = hasEnough ? "✅" : "❌"
               costText += "\(checkmark) \(resourceType.icon)\(amount) (\(currentAmount)) "
           }
           
           let costLabel = createLabel(text: costText,
                                      fontSize: 14,
                                      color: canAfford ? UIColor(white: 0.9, alpha: 1.0) : UIColor(red: 1.0, green: 0.5, blue: 0.5, alpha: 1.0))
           costLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 25)
           contentView.addSubview(costLabel)
           currentY += 25
       }
       
       // Time display
       if let upgradeTime = building.getUpgradeTime() {
           let minutes = Int(upgradeTime) / 60
           let seconds = Int(upgradeTime) % 60
           let timeLabel = createLabel(text: "⏱️ Time: \(minutes)m \(seconds)s",
                                      fontSize: 14,
                                      color: UIColor(white: 0.8, alpha: 1.0))
           timeLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 25)
           contentView.addSubview(timeLabel)
           currentY += 30
       }
       
       // Check for villager on tile
       let villagerEntity = getVillagerEntityOnBuildingTile()
       let hasVillager = villagerEntity != nil
       
       // Villager requirement label
       let villagerStatusText = hasVillager
           ? "✅ Villagers ready to upgrade"
           : "⚠️ Send villagers to this tile to upgrade"
       let villagerStatusColor = hasVillager
           ? UIColor(red: 0.5, green: 0.9, blue: 0.5, alpha: 1.0)
           : UIColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 1.0)
       
       let villagerStatusLabel = createLabel(text: villagerStatusText,
                                            fontSize: 13,
                                            color: villagerStatusColor)
       villagerStatusLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 25)
       contentView.addSubview(villagerStatusLabel)
       currentY += 30
       
       // Upgrade button
       let canAffordUpgrade = canAffordUpgradeCost()
       let buttonEnabled = hasVillager && canAffordUpgrade
       let buttonColor: UIColor = buttonEnabled
           ? UIColor(red: 0.2, green: 0.7, blue: 0.9, alpha: 1.0)
           : UIColor(white: 0.4, alpha: 1.0)
       
       let upgradeButton = createActionButton(
           title: "⬆️ Level Up",
           y: currentY,
           width: contentWidth,
           leftMargin: leftMargin,
           color: buttonColor,
           action: #selector(upgradeBuildingTapped)
       )
       upgradeButton.isEnabled = buttonEnabled
       upgradeButton.alpha = buttonEnabled ? 1.0 : 0.5
       upgradeButton.tag = 999  // Tag to identify upgrade button
       contentView.addSubview(upgradeButton)
       currentY += 70
       
       return currentY
   }
   
    func setupUpgradingProgressSection(yOffset: CGFloat, leftMargin: CGFloat, contentWidth: CGFloat) -> CGFloat {
         var currentY = yOffset
         
         // Section header
         let upgradeHeader = createLabel(text: "⬆️ Upgrading to Level \(building.level + 1)...",
                                        fontSize: 18,
                                        weight: .bold,
                                        color: .cyan)
         upgradeHeader.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 25)
         contentView.addSubview(upgradeHeader)
         currentY += 30
         
         // Progress
         let progressPercent = Int(building.upgradeProgress * 100)
         let progressLabel = createLabel(text: "Progress: \(progressPercent)%",
                                        fontSize: 14,
                                        color: UIColor(white: 0.9, alpha: 1.0))
         progressLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 25)
         progressLabel.tag = 1001
         contentView.addSubview(progressLabel)
         currentY += 25
         
         // Progress bar background
         let progressBarBg = UIView(frame: CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 20))
         progressBarBg.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
         progressBarBg.layer.cornerRadius = 10
         progressBarBg.tag = 1004  // Tag for finding parent
         contentView.addSubview(progressBarBg)
         
         // Progress bar fill
         let progressBarFill = UIView(frame: CGRect(x: 2, y: 2, width: (contentWidth - 4) * CGFloat(building.upgradeProgress), height: 16))
         progressBarFill.backgroundColor = .cyan
         progressBarFill.layer.cornerRadius = 8
         progressBarFill.tag = 1002
         progressBarBg.addSubview(progressBarFill)
         currentY += 25
         
         // Time remaining
         if let startTime = building.upgradeStartTime,
            let upgradeTime = building.getUpgradeTime() {
             let currentTime = Date().timeIntervalSince1970
             let elapsed = currentTime - startTime
             let remaining = max(0, upgradeTime - elapsed)
             let minutes = Int(remaining) / 60
             let seconds = Int(remaining) % 60
             
             let timeLabel = createLabel(text: "⏱️ Time Remaining: \(minutes)m \(seconds)s",
                                        fontSize: 14,
                                        color: UIColor(white: 0.8, alpha: 1.0))
             timeLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 25)
             timeLabel.tag = 1003
             contentView.addSubview(timeLabel)
             currentY += 35
         }
         
         // ✅ ADD: Cancel Upgrade button
         let cancelButton = createActionButton(
             title: "🚫 Cancel Upgrade",
             y: currentY,
             width: contentWidth,
             leftMargin: leftMargin,
             color: UIColor(red: 0.8, green: 0.3, blue: 0.3, alpha: 1.0),
             action: #selector(cancelUpgradeTapped)
         )
         contentView.addSubview(cancelButton)
         currentY += 70
         
         return currentY
     }

    func getVillagerEntityOnBuildingTile() -> EntityNode? {
       guard let hexMap = hexMap else { return nil }
       
       // Find a villager entity at the building's coordinate that is idle (not busy)
       for entity in hexMap.entities {
           if entity.coordinate == building.coordinate &&
              entity.entityType == .villagerGroup &&
              !entity.isMoving {
               // Check if villager group is idle
               if let villagerGroup = entity.entity as? VillagerGroup {
                   switch villagerGroup.currentTask {
                   case .idle:
                       return entity
                   default:
                       continue
                   }
               }
           }
       }
       return nil
   }
   
   func canAffordUpgradeCost() -> Bool {
       guard let upgradeCost = building.getUpgradeCost() else { return false }
       
       for (resourceType, amount) in upgradeCost {
           if !player.hasResource(resourceType, amount: amount) {
               return false
           }
       }
       return true
   }
   
   @objc func upgradeBuildingTapped() {
       guard building.canUpgrade else {
           showSimpleAlert(title: "Cannot Upgrade", message: "This building cannot be upgraded.")
           return
       }
       
       guard let villagerEntity = getVillagerEntityOnBuildingTile() else {
           showSimpleAlert(title: "No Villagers", message: "Send an idle villager group to this tile to perform the upgrade.")
           return
       }
       
       guard canAffordUpgradeCost() else {
           showSimpleAlert(title: "Cannot Afford", message: "You don't have enough resources for this upgrade.")
           return
       }
       
       // Confirm upgrade
       let upgradeCost = building.getUpgradeCost() ?? [:]
       var costString = ""
       for (resourceType, amount) in upgradeCost {
           costString += "\(resourceType.icon)\(amount) "
       }
       
       let alert = UIAlertController(
           title: "⬆️ Confirm Upgrade",
           message: "Upgrade \(building.buildingType.displayName) to Level \(building.level + 1)?\n\nCost: \(costString)",
           preferredStyle: .alert
       )
       
       alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
       alert.addAction(UIAlertAction(title: "Upgrade", style: .default) { [weak self] _ in
           self?.performUpgrade(villagerEntity: villagerEntity)
       })
       
       present(alert, animated: true)
   }
   
    func performUpgrade(villagerEntity: EntityNode) {
        guard let gameScene = gameScene else {
            showSimpleAlert(title: "Error", message: "Game scene not available.")
            return
        }
        
        // Call the game scene to start the upgrade
        gameScene.startBuildingUpgrade(building: building, villagerEntity: villagerEntity)
        
        // ✅ FIX: Don't dismiss - instead refresh the content to show upgrade progress
        refreshContent()
        
        // Update resource display in game view
        gameViewController?.updateResourceDisplay()
    }
   
   func showSimpleAlert(title: String, message: String) {
       let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
       alert.addAction(UIAlertAction(title: "OK", style: .default))
       present(alert, animated: true)
   }
    
    func updateUpgradeProgressDisplay() {
        guard building.state == .upgrading else { return }
        
        // Update progress label (tag 1001)
        if let progressLabel = contentView.viewWithTag(1001) as? UILabel {
            let progressPercent = Int(building.upgradeProgress * 100)
            progressLabel.text = "Progress: \(progressPercent)%"
        }
        
        // Update progress bar (tag 1002)
        if let progressBarFill = contentView.viewWithTag(1002) {
            let contentWidth = view.bounds.width - 40  // leftMargin + rightMargin
            let newWidth = (contentWidth - 4) * CGFloat(building.upgradeProgress)
            progressBarFill.frame.size.width = newWidth
        }
        
        // Update time remaining (tag 1003)
        if let timeLabel = contentView.viewWithTag(1003) as? UILabel,
           let startTime = building.upgradeStartTime,
           let upgradeTime = building.getUpgradeTime() {
            let currentTime = Date().timeIntervalSince1970
            let elapsed = currentTime - startTime
            let remaining = max(0, upgradeTime - elapsed)
            let minutes = Int(remaining) / 60
            let seconds = Int(remaining) % 60
            timeLabel.text = "⏱️ Time Remaining: \(minutes)m \(seconds)s"
            
            // Check if upgrade completed
            if remaining <= 0 {
                // Refresh the entire view
                refreshContent()
            }
        }
    }
        
    func refreshContent() {
        // Remove all content and rebuild
        for subview in contentView.subviews {
            subview.removeFromSuperview()
        }
        setupContent()
    }
    
    @objc func cancelUpgradeTapped() {
        guard building.state == .upgrading else {
            showSimpleAlert(title: "Not Upgrading", message: "This building is not currently upgrading.")
            return
        }
        
        let alert = UIAlertController(
            title: "🚫 Cancel Upgrade?",
            message: "Cancel the upgrade to Level \(building.level + 1)?\n\nAll resources will be refunded.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Keep Upgrading", style: .cancel))
        alert.addAction(UIAlertAction(title: "Cancel Upgrade", style: .destructive) { [weak self] _ in
            self?.performCancelUpgrade()
        })
        
        present(alert, animated: true)
    }
        
    func performCancelUpgrade() {
        guard let gameScene = gameScene else {
            showSimpleAlert(title: "Error", message: "Game scene not available.")
            return
        }
        
        gameScene.cancelBuildingUpgrade(building: building)
        
        // Refresh the content to show completed state
        refreshContent()
        
        // Update resource display
        gameViewController?.updateResourceDisplay()
        
        showSimpleAlert(title: "✅ Upgrade Cancelled", message: "Resources have been refunded.")
    }
}
