// ============================================================================
// FILE: BuildingDetailViewController.swift
// LOCATION: Grow2 iOS/ViewControllers/BuildingDetailViewController.swift
// PURPOSE: Shows detailed building information and actions
//          Uses Command pattern for all game actions
// ============================================================================

import UIKit

// MARK: - Training Slider Context

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

// MARK: - Building Detail View Controller

class BuildingDetailViewController: UIViewController {
    
    // MARK: - Properties
    
    var building: BuildingNode!
    var player: Player!
    weak var gameViewController: GameViewController?
    var trainingContexts: [Int: TrainingSliderContext]?
    var hexMap: HexMap!
    var gameScene: GameScene!
    
    private var updateTimer: Timer?

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
        static var villagerCountLabel: UInt8 = 0
    }

    // Market Trading UI
    var tradeFromSliders: [ResourceType: UISlider] = [:]
    var tradeFromLabels: [ResourceType: UILabel] = [:]
    var tradeToButtons: [ResourceType: UIButton] = [:]
    var selectedTradeToResource: ResourceType = .food
    var tradeResultLabel: UILabel?
    var tradeButton: UIButton?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        print("🎬 BuildingDetailViewController loaded for \(building.buildingType.displayName)")
        print("   Training queue: \(building.trainingQueue.count)")
        print("   Villager queue: \(building.villagerTrainingQueue.count)")
        
        // Update queue display every second
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
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

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if let topOverlay = view.subviews.first {
            topOverlay.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 60)
        }
        
        scrollView?.frame = CGRect(x: 0, y: 60, width: view.bounds.width, height: view.bounds.height - 60)
        
        if contentView.subviews.isEmpty {
            setupContent()
        }
    }
    
    // MARK: - UI Setup
    
    func setupUI() {
        view.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        view.isUserInteractionEnabled = true
        
        let topOverlay = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 60))
        topOverlay.backgroundColor = UIColor(white: 0.1, alpha: 0.95)
        view.addSubview(topOverlay)
        
        scrollView = UIScrollView()
        scrollView.frame = CGRect(x: 0, y: 60, width: view.bounds.width, height: view.bounds.height - 60)
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.showsVerticalScrollIndicator = true
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        
        contentView = UIView()
        scrollView.addSubview(contentView)
    }
    
    func setupContent() {
        let leftMargin: CGFloat = 20
        let contentWidth = view.bounds.width - 40
        var yOffset: CGFloat = 20
        
        // Title
        let titleLabel = createLabel(
            text: "\(building.buildingType.icon) \(building.buildingType.displayName)",
            fontSize: 24,
            weight: .bold,
            color: .white
        )
        titleLabel.frame = CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: 30)
        contentView.addSubview(titleLabel)
        yOffset += 40
        
        // Level and State
        let stateText = building.state == .constructing ? "🔨 Under Construction" :
                        building.state == .upgrading ? "⬆️ Upgrading" :
                        building.state == .demolishing ? "🏚️ Being Demolished" :
                        "✅ Operational"
        let levelLabel = createLabel(
            text: "Level \(building.level) • \(stateText)",
            fontSize: 16,
            color: UIColor(white: 0.8, alpha: 1.0)
        )
        levelLabel.frame = CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: 25)
        contentView.addSubview(levelLabel)
        yOffset += 35
        
        // Location
        let locationLabel = createLabel(
            text: "📍 Location: (\(building.coordinate.q), \(building.coordinate.r))",
            fontSize: 14,
            color: UIColor(white: 0.6, alpha: 1.0)
        )
        locationLabel.frame = CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: 20)
        contentView.addSubview(locationLabel)
        yOffset += 30

        // Adjacency Bonuses (if any)
        if let bonusData = AdjacencyBonusManager.shared.getBonusData(for: building.data.id),
           !bonusData.bonusSources.isEmpty {
            let bonusHeader = createLabel(
                text: "🏘️ Adjacency Bonuses",
                fontSize: 16,
                weight: .semibold,
                color: UIColor(red: 0.5, green: 0.9, blue: 0.5, alpha: 1.0)
            )
            bonusHeader.frame = CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: 25)
            contentView.addSubview(bonusHeader)
            yOffset += 28

            for source in bonusData.bonusSources {
                let bonusLabel = createLabel(
                    text: "  • \(source)",
                    fontSize: 14,
                    color: UIColor(white: 0.8, alpha: 1.0)
                )
                bonusLabel.frame = CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: 20)
                contentView.addSubview(bonusLabel)
                yOffset += 22
            }
            yOffset += 10
        }

        // Storage info (if applicable)
        if let storageInfo = getStorageInfoString(for: building, player: player) {
            let storageLabel = createLabel(
                text: storageInfo,
                fontSize: 14,
                color: UIColor(white: 0.7, alpha: 1.0)
            )
            storageLabel.numberOfLines = 0
            storageLabel.frame = CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: 0)
            storageLabel.sizeToFit()
            storageLabel.frame = CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: storageLabel.frame.height)
            contentView.addSubview(storageLabel)
            yOffset += storageLabel.frame.height + 20
        }
        
        // Separator
        let separator1 = UIView(frame: CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: 1))
        separator1.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
        contentView.addSubview(separator1)
        yOffset += 20
        
        // ✅ FIX 4: Only show training section if building can train units
        let trainableUnits = building.getTrainableUnits()
        print("🎓 Building \(building.buildingType.displayName) trainable units: \(trainableUnits.map { $0.displayName })")
        
        if !trainableUnits.isEmpty && building.state == .completed {
            print("   → Showing training section")
            yOffset = setupTrainingSection(yOffset: yOffset, contentWidth: contentWidth, leftMargin: leftMargin)
            
            // Queue display (only if can train)
            queueLabel = createLabel(text: getQueueDisplayText(), fontSize: 14, color: UIColor(white: 0.7, alpha: 1.0))
            queueLabel?.frame = CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: 0)
            queueLabel?.numberOfLines = 0
            queueLabel?.sizeToFit()
            if let label = queueLabel {
                contentView.addSubview(label)
                yOffset += (label.frame.height > 0 ? label.frame.height + 30 : 0)
            }
        } else {
            print("   → Skipping training section (no trainable units or not completed)")
        }
        
        // Garrison info
        let garrisonText = getGarrisonText()
        if !garrisonText.isEmpty {
            let garrisonLabel = createLabel(
                text: "🏰 Garrison",
                fontSize: 16,
                weight: .semibold,
                color: .white
            )
            garrisonLabel.frame = CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: 25)
            contentView.addSubview(garrisonLabel)
            yOffset += 30
            
            let garrisonDetailLabel = createLabel(
                text: garrisonText,
                fontSize: 14,
                color: UIColor(white: 0.8, alpha: 1.0)
            )
            garrisonDetailLabel.frame = CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: 0)
            garrisonDetailLabel.numberOfLines = 0
            garrisonDetailLabel.sizeToFit()
            contentView.addSubview(garrisonDetailLabel)
            yOffset += garrisonDetailLabel.frame.height + 20

            // Add "Send Reinforcements" button if there are military units in garrison
            if building.getTotalGarrisonedUnits() > 0 {
                let reinforceButton = createActionButton(
                    title: "🔄 Send Reinforcements to Army",
                    y: yOffset,
                    width: contentWidth,
                    leftMargin: leftMargin,
                    color: UIColor(red: 0.3, green: 0.5, blue: 0.7, alpha: 1.0),
                    action: #selector(reinforceArmyTapped)
                )
                contentView.addSubview(reinforceButton)
                yOffset += 60
            }
        }

        // ✅ FIX 6: Upgrade section with proper debug logging
        print("🔧 DEBUG - Upgrade section check:")
        print("   state: \(building.state)")
        print("   canUpgrade: \(building.canUpgrade)")
        print("   level: \(building.level)/\(building.maxLevel)")
        
        if building.state == .upgrading {
            print("   → Showing upgrade PROGRESS section")
            yOffset = setupUpgradingProgressSection(yOffset: yOffset, leftMargin: leftMargin, contentWidth: contentWidth)
        } else if building.state == .completed && building.canUpgrade {
            print("   → Showing upgrade OPTION section")
            yOffset = setupUpgradeSection(yOffset: yOffset, leftMargin: leftMargin, contentWidth: contentWidth)
        } else if building.state == .completed && building.level >= building.maxLevel {
            print("   → Showing MAX LEVEL label")
            let maxLevelLabel = createLabel(
                text: "✨ Maximum Level Reached",
                fontSize: 14,
                color: UIColor(red: 1.0, green: 0.85, blue: 0.4, alpha: 1.0)
            )
            maxLevelLabel.frame = CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: 25)
            contentView.addSubview(maxLevelLabel)
            yOffset += 35
        } else {
            print("   → No upgrade section shown")
        }

        // Demolition section (only for completed buildings, not City Center)
        if building.state == .completed && building.buildingType != .cityCenter {
            yOffset = setupDemolishSection(yOffset: yOffset, leftMargin: leftMargin, contentWidth: contentWidth)
        } else if building.state == .demolishing {
            yOffset = setupDemolishingProgressSection(yOffset: yOffset, leftMargin: leftMargin, contentWidth: contentWidth)
        }

        // Market Trading Section
        if building.buildingType == .market && building.state == .completed {
            yOffset = setupMarketTradingSection(yOffset: yOffset, contentWidth: contentWidth, leftMargin: leftMargin)
        }

        // Deploy button for City Center with garrisoned villagers
        if building.buildingType == .cityCenter && building.villagerGarrison > 0 {
            let deployButton = createActionButton(
                title: "👷 Deploy \(building.villagerGarrison) Villagers",
                y: yOffset,
                width: contentWidth,
                leftMargin: leftMargin,
                color: UIColor(red: 0.3, green: 0.6, blue: 0.3, alpha: 1.0),
                action: #selector(deployVillagersTapped)
            )
            contentView.addSubview(deployButton)
            yOffset += 60
        }
        
        // Close button
        let closeButton = createActionButton(
            title: "Close",
            y: yOffset,
            width: contentWidth,
            leftMargin: leftMargin,
            color: UIColor(white: 0.3, alpha: 1.0),
            action: #selector(closeTapped)
        )
        contentView.addSubview(closeButton)
        yOffset += 80
        
        // Set content size
        contentView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: yOffset)
        scrollView.contentSize = CGSize(width: view.bounds.width, height: yOffset)
    }
    
    func setupTrainingSection(yOffset: CGFloat, contentWidth: CGFloat, leftMargin: CGFloat) -> CGFloat {
        var currentY = yOffset
        
        let sectionLabel = createLabel(
            text: "🎓 Train New Units",
            fontSize: 18,
            weight: .semibold,
            color: .white
        )
        sectionLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 25)
        contentView.addSubview(sectionLabel)
        currentY += 35
        
        trainingContexts = [:]
        
        let trainableUnits = getTrainableUnits()
        
        for (index, unitType) in trainableUnits.enumerated() {
            currentY = createTrainingRow(
                unitType: unitType,
                index: index,
                yOffset: currentY,
                contentWidth: contentWidth,
                leftMargin: leftMargin
            )
        }
        
        return currentY + 20
    }
    
    func createTrainingRow(unitType: TrainableUnitType, index: Int, yOffset: CGFloat, contentWidth: CGFloat, leftMargin: CGFloat) -> CGFloat {
        let currentY = yOffset

        let container = UIView(frame: CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 120))
        container.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        container.layer.cornerRadius = 10
        container.tag = index
        contentView.addSubview(container)

        // Unit name
        let nameLabel = UILabel(frame: CGRect(x: 15, y: 10, width: contentWidth - 30, height: 25))
        nameLabel.text = "\(unitType.icon) \(unitType.displayName)"
        nameLabel.font = UIFont.boldSystemFont(ofSize: 16)
        nameLabel.textColor = .white
        container.addSubview(nameLabel)

        // Cost label with warehouse discount if applicable
        let costReduction = AdjacencyBonusManager.shared.getTrainingCostReduction(for: building.data.id)
        var costText = formatCost(unitType.trainingCost)
        if costReduction > 0 {
            costText += " (-\(Int(costReduction * 100))% 📦)"
        }
        let costLabel = UILabel(frame: CGRect(x: 15, y: 35, width: contentWidth - 30, height: 20))
        costLabel.text = "Cost: \(costText)"
        costLabel.font = UIFont.systemFont(ofSize: 12)
        costLabel.textColor = costReduction > 0 ? UIColor(red: 0.5, green: 0.9, blue: 0.5, alpha: 1.0) : UIColor(white: 0.7, alpha: 1.0)
        costLabel.tag = 1000 + index
        container.addSubview(costLabel)

        // Calculate max trainable based on resources and population
        let maxTrainable = calculateMaxTrainable(unitType: unitType)

        // Slider
        let slider = UISlider(frame: CGRect(x: 15, y: 60, width: contentWidth - 110, height: 30))
        slider.minimumValue = 1
        slider.maximumValue = Float(max(1, maxTrainable))
        slider.value = 1
        slider.tag = index
        slider.isEnabled = maxTrainable >= 1
        slider.addTarget(self, action: #selector(trainingSliderChanged(_:)), for: .valueChanged)
        container.addSubview(slider)

        // Max info label
        let maxLabel = UILabel(frame: CGRect(x: 15, y: 90, width: contentWidth - 30, height: 18))
        maxLabel.text = maxTrainable >= 1 ? "Max: \(maxTrainable)" : "Cannot train (check resources/pop)"
        maxLabel.font = UIFont.systemFont(ofSize: 11)
        maxLabel.textColor = maxTrainable >= 1 ? UIColor(white: 0.6, alpha: 1.0) : UIColor(red: 0.9, green: 0.4, blue: 0.4, alpha: 1.0)
        maxLabel.tag = 3000 + index
        container.addSubview(maxLabel)

        // Count label
        let countLabel = UILabel(frame: CGRect(x: contentWidth - 90, y: 60, width: 30, height: 30))
        countLabel.text = "1"
        countLabel.font = UIFont.boldSystemFont(ofSize: 16)
        countLabel.textColor = .white
        countLabel.textAlignment = .center
        countLabel.tag = 2000 + index
        container.addSubview(countLabel)

        // Train button
        let trainButton = UIButton(frame: CGRect(x: contentWidth - 55, y: 55, width: 40, height: 40))
        trainButton.setTitle("✅", for: .normal)
        trainButton.titleLabel?.font = UIFont.systemFont(ofSize: 24)
        trainButton.backgroundColor = maxTrainable >= 1 ?
            UIColor(red: 0.2, green: 0.6, blue: 0.3, alpha: 1.0) :
            UIColor(white: 0.4, alpha: 1.0)
        trainButton.layer.cornerRadius = 20
        trainButton.tag = index
        trainButton.isEnabled = maxTrainable >= 1
        trainButton.addTarget(self, action: #selector(trainButtonTapped(_:)), for: .touchUpInside)
        container.addSubview(trainButton)

        // Store context
        let context = TrainingSliderContext(unitType: unitType, container: container, building: building)
        trainingContexts?[index] = context

        return currentY + 130
    }

    /// Calculate the maximum number of units that can be trained based on resources and population
    func calculateMaxTrainable(unitType: TrainableUnitType) -> Int {
        // Get available population space
        let availablePop = player.getAvailablePopulation()

        // Calculate max affordable based on each resource
        var maxAffordable = Int.max
        for (resourceType, costPerUnit) in unitType.trainingCost {
            if costPerUnit > 0 {
                let available = player.getResource(resourceType)
                let canAfford = available / costPerUnit
                maxAffordable = min(maxAffordable, canAfford)
            }
        }

        // Take the minimum of population space and affordable units
        let maxTrainable = min(availablePop, maxAffordable)

        // Cap at a reasonable maximum for UI purposes
        return min(maxTrainable, 50)
    }

    // =========================================================================
    // MARK: - Market Trading Section
    // =========================================================================

    func setupMarketTradingSection(yOffset: CGFloat, contentWidth: CGFloat, leftMargin: CGFloat) -> CGFloat {
        var currentY = yOffset

        // Section header
        let sectionLabel = createLabel(
            text: "💱 Trade Resources",
            fontSize: 18,
            weight: .semibold,
            color: .white
        )
        sectionLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 25)
        contentView.addSubview(sectionLabel)
        currentY += 35

        // Exchange rate info
        let baseRate = 0.80
        let researchBonus = ResearchManager.shared.getMarketRateMultiplier()
        let effectiveRate = baseRate * researchBonus
        let ratePercent = Int(effectiveRate * 100)

        let rateLabel = createLabel(
            text: "Exchange Rate: \(ratePercent)%\(researchBonus > 1.0 ? " (Research bonus!)" : "")",
            fontSize: 14,
            color: UIColor(white: 0.7, alpha: 1.0)
        )
        rateLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 20)
        contentView.addSubview(rateLabel)
        currentY += 30

        // "Trade FROM" section
        let fromLabel = createLabel(
            text: "📤 Resources to Trade:",
            fontSize: 16,
            weight: .medium,
            color: .white
        )
        fromLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 25)
        contentView.addSubview(fromLabel)
        currentY += 30

        // Create sliders for each resource type
        tradeFromSliders.removeAll()
        tradeFromLabels.removeAll()

        for resourceType in ResourceType.allCases {
            let available = player.getResource(resourceType)

            // Resource row container
            let rowContainer = UIView(frame: CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 50))
            rowContainer.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
            rowContainer.layer.cornerRadius = 8
            contentView.addSubview(rowContainer)

            // Resource icon and name
            let resourceLabel = UILabel(frame: CGRect(x: 10, y: 5, width: 80, height: 20))
            resourceLabel.text = "\(resourceType.icon) \(resourceType.displayName)"
            resourceLabel.font = UIFont.systemFont(ofSize: 14)
            resourceLabel.textColor = .white
            rowContainer.addSubview(resourceLabel)

            // Available amount
            let availableLabel = UILabel(frame: CGRect(x: 10, y: 25, width: 80, height: 18))
            availableLabel.text = "Max: \(available)"
            availableLabel.font = UIFont.systemFont(ofSize: 11)
            availableLabel.textColor = UIColor(white: 0.6, alpha: 1.0)
            rowContainer.addSubview(availableLabel)

            // Slider
            let slider = UISlider(frame: CGRect(x: 95, y: 10, width: contentWidth - 170, height: 30))
            slider.minimumValue = 0
            slider.maximumValue = Float(max(1, available))
            slider.value = 0
            slider.addTarget(self, action: #selector(tradeSliderChanged(_:)), for: .valueChanged)
            rowContainer.addSubview(slider)
            tradeFromSliders[resourceType] = slider

            // Amount label
            let amountLabel = UILabel(frame: CGRect(x: contentWidth - 70, y: 10, width: 60, height: 30))
            amountLabel.text = "0"
            amountLabel.font = UIFont.boldSystemFont(ofSize: 16)
            amountLabel.textColor = .white
            amountLabel.textAlignment = .right
            rowContainer.addSubview(amountLabel)
            tradeFromLabels[resourceType] = amountLabel

            currentY += 55
        }

        currentY += 10

        // "Trade TO" section
        let toLabel = createLabel(
            text: "📥 Receive Resource:",
            fontSize: 16,
            weight: .medium,
            color: .white
        )
        toLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 25)
        contentView.addSubview(toLabel)
        currentY += 30

        // Resource selection buttons
        tradeToButtons.removeAll()
        let buttonWidth = (contentWidth - 30) / 4

        for (index, resourceType) in ResourceType.allCases.enumerated() {
            let button = UIButton(frame: CGRect(
                x: leftMargin + CGFloat(index) * (buttonWidth + 10),
                y: currentY,
                width: buttonWidth,
                height: 50
            ))
            button.setTitle("\(resourceType.icon)\n\(resourceType.displayName)", for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 12)
            button.titleLabel?.numberOfLines = 2
            button.titleLabel?.textAlignment = .center
            button.backgroundColor = resourceType == selectedTradeToResource ?
                UIColor(red: 0.3, green: 0.6, blue: 0.3, alpha: 1.0) :
                UIColor(white: 0.25, alpha: 1.0)
            button.layer.cornerRadius = 8
            button.tag = index
            button.addTarget(self, action: #selector(tradeToResourceTapped(_:)), for: .touchUpInside)
            contentView.addSubview(button)
            tradeToButtons[resourceType] = button
        }
        currentY += 60

        // Trade result preview
        tradeResultLabel = createLabel(
            text: "Select resources to trade",
            fontSize: 14,
            color: UIColor(white: 0.8, alpha: 1.0)
        )
        tradeResultLabel?.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 25)
        tradeResultLabel?.textAlignment = .center
        contentView.addSubview(tradeResultLabel!)
        currentY += 35

        // Trade button
        tradeButton = createActionButton(
            title: "💱 Execute Trade",
            y: currentY,
            width: contentWidth,
            leftMargin: leftMargin,
            color: UIColor(red: 0.3, green: 0.5, blue: 0.7, alpha: 1.0),
            action: #selector(executeTradeTapped)
        )
        contentView.addSubview(tradeButton!)
        currentY += 70

        return currentY
    }

    @objc func tradeSliderChanged(_ sender: UISlider) {
        // Find which resource this slider belongs to
        for (resourceType, slider) in tradeFromSliders {
            if slider === sender {
                let value = Int(sender.value)
                tradeFromLabels[resourceType]?.text = "\(value)"
                break
            }
        }
        updateTradePreview()
    }

    @objc func tradeToResourceTapped(_ sender: UIButton) {
        let resourceTypes = ResourceType.allCases
        guard sender.tag < resourceTypes.count else { return }

        selectedTradeToResource = resourceTypes[sender.tag]

        // Update button appearances
        for (resourceType, button) in tradeToButtons {
            button.backgroundColor = resourceType == selectedTradeToResource ?
                UIColor(red: 0.3, green: 0.6, blue: 0.3, alpha: 1.0) :
                UIColor(white: 0.25, alpha: 1.0)
        }

        updateTradePreview()
    }

    func updateTradePreview() {
        // Calculate total resources being traded (excluding the target resource)
        var totalInput = 0
        for (resourceType, slider) in tradeFromSliders {
            if resourceType != selectedTradeToResource {
                totalInput += Int(slider.value)
            }
        }

        // Calculate output with market rate and research bonus
        let baseRate = 0.80
        let researchBonus = ResearchManager.shared.getMarketRateMultiplier()
        let effectiveRate = baseRate * researchBonus
        let output = Int(Double(totalInput) * effectiveRate)

        if totalInput > 0 {
            tradeResultLabel?.text = "Trade \(totalInput) resources → Receive \(output) \(selectedTradeToResource.icon) \(selectedTradeToResource.displayName)"
            tradeResultLabel?.textColor = UIColor(red: 0.5, green: 0.9, blue: 0.5, alpha: 1.0)
        } else {
            tradeResultLabel?.text = "Select resources to trade"
            tradeResultLabel?.textColor = UIColor(white: 0.8, alpha: 1.0)
        }
    }

    @objc func executeTradeTapped() {
        // Calculate resources to spend
        var resourcesToSpend: [ResourceType: Int] = [:]
        var totalInput = 0

        for (resourceType, slider) in tradeFromSliders {
            let amount = Int(slider.value)
            if amount > 0 && resourceType != selectedTradeToResource {
                resourcesToSpend[resourceType] = amount
                totalInput += amount
            }
        }

        guard totalInput > 0 else {
            showAlert(title: "No Resources Selected", message: "Select resources to trade using the sliders.")
            return
        }

        // Calculate output
        let baseRate = 0.80
        let researchBonus = ResearchManager.shared.getMarketRateMultiplier()
        let effectiveRate = baseRate * researchBonus
        let output = Int(Double(totalInput) * effectiveRate)

        // Verify player has the resources
        for (resourceType, amount) in resourcesToSpend {
            if !player.hasResource(resourceType, amount: amount) {
                showAlert(title: "Insufficient Resources", message: "You don't have enough \(resourceType.displayName).")
                return
            }
        }

        // Execute the trade
        for (resourceType, amount) in resourcesToSpend {
            player.removeResource(resourceType, amount: amount)
        }
        player.addResource(selectedTradeToResource, amount: output)

        // Update UI
        gameViewController?.updateResourceDisplay()

        // Show confirmation
        let spentText = resourcesToSpend.map { "\($0.key.icon)\($0.value)" }.joined(separator: " ")
        showAlert(
            title: "✅ Trade Complete",
            message: "Traded \(spentText) for \(output) \(selectedTradeToResource.icon) \(selectedTradeToResource.displayName)"
        )

        // Reset sliders and refresh
        for slider in tradeFromSliders.values {
            slider.value = 0
        }
        for label in tradeFromLabels.values {
            label.text = "0"
        }
        updateTradePreview()

        // Refresh the section to update max values
        refreshContent()
    }

    // =========================================================================
    // MARK: - Training Actions (Using Commands)
    // =========================================================================
    
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
        
        // ✅ UPDATED: Reset slider and recalculate limits
        slider.value = 1
        updateSliderLimits(slider: slider, unitType: unitType, container: container)
    }
    
    /// Executes training using Command pattern
    func executeTrainCommand(unitType: TrainableUnitType, quantity: Int) {
        print("🎯 executeTrainCommand called: \(quantity)x \(unitType.displayName)")
        
        switch unitType {
        case .villager:
            let command = TrainVillagerCommand(
                playerID: player.id,
                buildingID: building.data.id,    // ✅ FIXED: was building.id
                quantity: quantity
            )
            
            let result = CommandExecutor.shared.execute(command)
            
            if result.succeeded {
                showAlert(title: "✅ Training Started", message: "Training \(quantity) Villager\(quantity > 1 ? "s" : "")")
                updateQueueDisplay()
                updateAllTrainingSliderLimits()
            } else if let reason = result.failureReason {
                showAlert(title: "Cannot Train", message: reason)
            }
            
        case .military(let militaryType):
            let command = TrainMilitaryCommand(
                playerID: player.id,
                buildingID: building.data.id,    // ✅ FIXED: was building.id
                unitType: militaryType,
                quantity: quantity
            )
            
            let result = CommandExecutor.shared.execute(command)
            
            if result.succeeded {
                showAlert(title: "✅ Training Started", message: "Training \(quantity) \(militaryType.displayName)\(quantity > 1 ? "s" : "")")
                updateQueueDisplay()
                updateAllTrainingSliderLimits()
            } else if let reason = result.failureReason {
                showAlert(title: "Cannot Train", message: reason)
            }
        }
        
        gameViewController?.updateResourceDisplay()
    }
    
    // Legacy method for compatibility - now uses command
    func startTraining(unitType: TrainableUnitType, quantity: Int) {
        executeTrainCommand(unitType: unitType, quantity: quantity)
    }
    
    @objc func trainingSliderChanged(_ slider: UISlider) {
        guard let context = trainingContexts?[slider.tag],
              let container = context.container else { return }
        
        let quantity = Int(slider.value)
        
        // Update count label
        if let countLabel = container.viewWithTag(2000 + slider.tag) as? UILabel {
            countLabel.text = "\(quantity)"
        }
        
        // Update cost label
        if let costLabel = container.viewWithTag(1000 + slider.tag) as? UILabel {
            let totalCost = context.unitType.trainingCost.mapValues { $0 * quantity }
            costLabel.text = "Cost: \(formatCost(totalCost))"
        }
    }
    
    // =========================================================================
    // MARK: - Deploy Villagers (Using Commands)
    // =========================================================================
    
    @objc func deployVillagersTapped() {
        let villagerCount = building.villagerGarrison

        guard villagerCount > 0 else {
            showAlert(title: "No Villagers", message: "No villagers in garrison to deploy.")
            return
        }

        // Present the new villager deployment panel
        let panelVC = VillagerDeploymentPanelViewController()
        panelVC.building = building
        panelVC.hexMap = hexMap
        panelVC.gameScene = gameScene
        panelVC.player = player
        panelVC.modalPresentationStyle = .overFullScreen
        panelVC.modalTransitionStyle = .crossDissolve

        // Handle deploy new action
        panelVC.onDeployNew = { [weak self] count in
            guard let self = self else { return }

            // Find spawn location
            guard let spawnCoord = self.hexMap.findNearestWalkable(to: self.building.coordinate, maxDistance: 3) else {
                self.showAlert(title: "Cannot Deploy", message: "No walkable location nearby.")
                return
            }

            self.executeDeployVillagersCommand(count: count, at: spawnCoord)
        }

        // Handle join existing action
        panelVC.onJoinExisting = { [weak self] targetGroup, count in
            guard let self = self else { return }
            self.executeJoinVillagerGroupCommand(targetGroup: targetGroup, count: count)
        }

        panelVC.onCancel = {
            // Nothing to do on cancel
        }

        present(panelVC, animated: false)
    }

    /// Executes join villager group command
    func executeJoinVillagerGroupCommand(targetGroup: VillagerGroup, count: Int) {
        let command = JoinVillagerGroupCommand(
            playerID: player.id,
            buildingID: building.data.id,
            targetVillagerGroupID: targetGroup.id,
            count: count
        )

        let result = CommandExecutor.shared.execute(command)

        if result.succeeded {
            // Show alert from parent before dismissing to ensure it's displayed
            gameViewController?.showAlert(
                title: "Villagers Dispatched",
                message: "\(count) villagers marching to join \(targetGroup.name)"
            )
            dismiss(animated: true)
        } else if let reason = result.failureReason {
            showAlert(title: "Send Failed", message: reason)
        }
    }
    
    @objc func deploySliderChanged(_ slider: UISlider) {
        if let label = objc_getAssociatedObject(self, &AssociatedKeys.villagerCountLabel) as? UILabel {
            label.text = "\(Int(slider.value)) villagers"
        }
    }
    
    /// Executes deploy villagers using Command pattern
    func executeDeployVillagersCommand(count: Int, at coordinate: HexCoordinate) {
        let command = DeployVillagersCommand(
            playerID: player.id,
            buildingID: building.data.id,
            count: count
        )
        
        let result = CommandExecutor.shared.execute(command)
        
        if result.succeeded {
            dismiss(animated: true) { [weak self] in
                self?.gameViewController?.showAlert(
                    title: "✅ Villagers Deployed",
                    message: "Deployed \(count) villagers at (\(coordinate.q), \(coordinate.r))"
                )
            }
        } else if let reason = result.failureReason {
            showAlert(title: "Deploy Failed", message: reason)
        }
    }
    
    // Legacy method for compatibility - now uses command
    func deployVillagers(count: Int, at coordinate: HexCoordinate) {
        executeDeployVillagersCommand(count: count, at: coordinate)
    }
    
    // =========================================================================
    // MARK: - Reinforce Army (Using Commands)
    // =========================================================================
    
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
            showAlert(title: "No Military Units", message: "This building has no military units to reinforce with.")
            return
        }
        
        let alert = UIAlertController(
            title: "🔄 Reinforce \(army.name)",
            message: "Select units to transfer",
            preferredStyle: .alert
        )
        
        let containerVC = UIViewController()
        let containerHeight = min(CGFloat(militaryGarrison.count * 65 + 20), 300.0)
        containerVC.preferredContentSize = CGSize(width: 270, height: containerHeight)
        
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 270, height: containerHeight))
        let contentView = UIView()
        var yOffset: CGFloat = 10
        var sliders: [MilitaryUnitType: UISlider] = [:]
        var labels: [MilitaryUnitType: UILabel] = [:]
        var garrisonData: [MilitaryUnitType: Int] = [:]
        
        for (unitType, count) in militaryGarrison.sorted(by: { $0.key.displayName < $1.key.displayName }) {
            let label = UILabel(frame: CGRect(x: 10, y: yOffset, width: 250, height: 20))
            label.text = "\(unitType.icon) \(unitType.displayName): 0/\(count)"
            label.font = UIFont.systemFont(ofSize: 14)
            label.textColor = .label
            label.tag = unitType.hashValue
            contentView.addSubview(label)
            labels[unitType] = label
            garrisonData[unitType] = count
            
            let slider = UISlider(frame: CGRect(x: 10, y: yOffset + 25, width: 250, height: 30))
            slider.minimumValue = 0
            slider.maximumValue = Float(count)
            slider.value = 0
            slider.tag = unitType.hashValue
            slider.addTarget(self, action: #selector(reinforceSliderChanged(_:)), for: .valueChanged)
            contentView.addSubview(slider)
            sliders[unitType] = slider
            
            yOffset += 65
        }
        
        contentView.frame = CGRect(x: 0, y: 0, width: 270, height: yOffset)
        scrollView.addSubview(contentView)
        scrollView.contentSize = contentView.frame.size
        containerVC.view.addSubview(scrollView)
        
        // Store for slider callbacks
        objc_setAssociatedObject(self, &AssociatedKeys.unitLabels, labels, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(self, &AssociatedKeys.garrisonData, garrisonData, .OBJC_ASSOCIATION_RETAIN)
        
        alert.setValue(containerVC, forKey: "contentViewController")
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Reinforce", style: .default) { [weak self] _ in
            self?.executeReinforcementCommand(army: army, sliders: sliders)
        })
        
        present(alert, animated: true)
    }
    
    @objc func reinforceSliderChanged(_ slider: UISlider) {
        guard let labelsDict = objc_getAssociatedObject(self, &AssociatedKeys.unitLabels) as? [MilitaryUnitType: UILabel],
              let garrisonDict = objc_getAssociatedObject(self, &AssociatedKeys.garrisonData) as? [MilitaryUnitType: Int] else {
            return
        }
        
        for (unitType, label) in labelsDict {
            if unitType.hashValue == slider.tag {
                let available = garrisonDict[unitType] ?? 0
                label.text = "\(unitType.icon) \(unitType.displayName): \(Int(slider.value))/\(available)"
                break
            }
        }
    }
    
    /// Executes reinforcement using Command pattern
    func executeReinforcementCommand(army: Army, sliders: [MilitaryUnitType: UISlider]) {
        var units: [MilitaryUnitType: Int] = [:]
        
        for (unitType, slider) in sliders {
            let count = Int(slider.value)
            if count > 0 {
                units[unitType] = count
            }
        }
        
        guard !units.isEmpty else {
            showAlert(title: "No Units Selected", message: "Select at least one unit to transfer.")
            return
        }
        
        let command = ReinforceArmyCommand(
            playerID: player.id,
            buildingID: building.data.id,
            armyID: army.id,
            units: units
        )
        
        let result = CommandExecutor.shared.execute(command)
        
        if !result.succeeded, let reason = result.failureReason {
            showAlert(title: "Reinforcement Failed", message: reason)
        }
    }
    
    // Legacy method for compatibility - now uses command
    func reinforceArmy(_ army: Army, with units: [MilitaryUnitType: Int]) {
        let command = ReinforceArmyCommand(
            playerID: player.id,
            buildingID: building.data.id,
            armyID: army.id,
            units: units
        )
        
        let result = CommandExecutor.shared.execute(command)
        
        if result.succeeded {
            dismiss(animated: true) { [weak self] in
                let total = units.values.reduce(0, +)
                self?.gameViewController?.showSimpleAlert(
                    title: "✅ Reinforcement Complete",
                    message: "Transferred \(total) units to \(army.name)"
                )
            }
        } else if let reason = result.failureReason {
            showAlert(title: "Reinforcement Failed", message: reason)
        }
    }
    
    // =========================================================================
    // MARK: - Helper Methods
    // =========================================================================
    
    @objc func closeTapped() {
        dismiss(animated: true)
    }
    
    func updateQueueDisplay() {
        queueLabel?.text = getQueueDisplayText()
        queueLabel?.sizeToFit()
    }
    
    func updateUpgradeProgressDisplay() {
        guard building.state == .upgrading else { return }
        
        let currentTime = Date().timeIntervalSince1970
        let progress = building.upgradeProgress
        let progressPercent = Int(progress * 100)
        
        // Update progress bar fill (tag 9001)
        if let progressBarFill = contentView.viewWithTag(9001) {
            let contentWidth = view.bounds.width - 40
            let fillWidth = max(0, contentWidth * CGFloat(progress))
            progressBarFill.frame.size.width = fillWidth
        }
        
        // Update progress label (tag 9002)
        if let progressLabel = contentView.viewWithTag(9002) as? UILabel {
            progressLabel.text = "Progress: \(progressPercent)%"
        }
        
        // Update time remaining label (tag 9003)
        if let timeLabel = contentView.viewWithTag(9003) as? UILabel,
           let remainingTime = building.data.getRemainingUpgradeTime(currentTime: currentTime) {
            let minutes = Int(remainingTime) / 60
            let seconds = Int(remainingTime) % 60
            timeLabel.text = "⏱️ Time Remaining: \(minutes)m \(seconds)s"
        }
        
        // Check if upgrade completed
        if progress >= 1.0 {
            refreshContent()
        }
    }
    
    func performUpgrade(villagerEntity: EntityNode) {
        guard let player = player else {
            showAlert(title: "Error", message: "Player not available.")
            return
        }
        
        // Create and execute the upgrade command
        let command = UpgradeCommand(
            playerID: player.id,
            buildingID: building.data.id,
            upgraderEntityID: villagerEntity.entity.id
        )
        
        let result = CommandExecutor.shared.execute(command)
        
        if result.succeeded {
            // Refresh the content to show upgrade progress
            refreshContent()
            
            // Update resource display in game view
            gameViewController?.updateResourceDisplay()
        } else if let reason = result.failureReason {
            showAlert(title: "Upgrade Failed", message: reason)
        }
    }
    
    func performCancelUpgrade() {
        guard let player = player else {
            showAlert(title: "Error", message: "Player not available.")
            return
        }
        
        // Create and execute the cancel upgrade command
        let command = CancelUpgradeCommand(
            playerID: player.id,
            buildingID: building.data.id
        )
        
        let result = CommandExecutor.shared.execute(command)
        
        if result.succeeded {
            // Refresh the content to show completed state
            refreshContent()
            
            // Update resource display
            gameViewController?.updateResourceDisplay()
            
            showAlert(title: "✅ Upgrade Cancelled", message: "Resources have been refunded.")
        } else if let reason = result.failureReason {
            showAlert(title: "Cancel Failed", message: reason)
        }
    }
    
    func getQueueDisplayText() -> String {
        var text = ""
        let currentTime = Date().timeIntervalSince1970
        
        // Military training queue
        for entry in building.trainingQueue {
            let progress = entry.getProgress(currentTime: currentTime)
            let progressPercent = Int(progress * 100)
            text += "\(entry.unitType.icon) \(entry.quantity)x \(entry.unitType.displayName) - \(progressPercent)%\n"
        }
        
        // Villager training queue
        for entry in building.villagerTrainingQueue {
            let progress = entry.getProgress(currentTime: currentTime)
            let progressPercent = Int(progress * 100)
            text += "👷 \(entry.quantity)x Villager - \(progressPercent)%\n"
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
    
    func formatCost(_ cost: [ResourceType: Int]) -> String {
        cost.sorted(by: { $0.key.rawValue < $1.key.rawValue })
            .map { "\($0.key.icon)\($0.value)" }
            .joined(separator: " ")
    }
    
    func createLabel(text: String, fontSize: CGFloat, weight: UIFont.Weight = .regular, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: fontSize, weight: weight)
        label.textColor = color
        return label
    }
    
    func createActionButton(title: String, y: CGFloat, width: CGFloat, leftMargin: CGFloat, color: UIColor, action: Selector) -> UIButton {
        let button = UIButton(frame: CGRect(x: leftMargin, y: y, width: width, height: 55))
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.backgroundColor = color
        button.layer.cornerRadius = 12
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }
    
    func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    func showActionSheet(title: String, message: String? = nil, actions: [AlertAction]) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        
        for action in actions {
            alert.addAction(UIAlertAction(title: action.title, style: action.style) { _ in
                action.handler?()
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }
        
        present(alert, animated: true)
    }
    
    func refreshContent() {
        // Remove all content and rebuild
        for subview in contentView.subviews {
            subview.removeFromSuperview()
        }
        setupContent()
    }
    
    func getStorageInfoString(for building: BuildingNode, player: Player) -> String? {
        guard building.buildingType == .warehouse || building.buildingType == .cityCenter else {
            return nil
        }
        
        let perResourceCapacity = building.buildingType.storageCapacityPerResource(forLevel: building.level)
        
        var info = "📦 Storage Per Resource: +\(perResourceCapacity)"
        
        if building.level < building.buildingType.maxLevel {
            let nextLevelCapacity = building.buildingType.storageCapacityPerResource(forLevel: building.level + 1)
            let increase = nextLevelCapacity - perResourceCapacity
            info += "\n📈 Next Level: +\(increase) per resource"
        }
        
        // Show current storage status for each resource
        info += "\n\n📊 Current Storage:"
        for type in ResourceType.allCases {
            let current = player.getResource(type)
            let cap = player.getStorageCapacity(for: type)
            let percent = Int(player.getStoragePercent(for: type) * 100)
            let statusIcon = percent >= 100 ? "🔴" : (percent >= 90 ? "🟡" : "🟢")
            info += "\n   \(statusIcon) \(type.icon) \(current)/\(cap)"
        }
        
        if building.buildingType == .cityCenter {
            let ccLevel = player.getCityCenterLevel()
            let maxWarehouses = BuildingType.maxWarehousesAllowed(forCityCenterLevel: ccLevel)
            let currentWarehouses = player.getWarehouseCount()
            info += "\n\n🏭 Warehouses: \(currentWarehouses)/\(maxWarehouses) allowed"
            
            if ccLevel < 8 {
                let nextUnlock: Int
                if ccLevel < 2 {
                    nextUnlock = 2
                } else if ccLevel < 5 {
                    nextUnlock = 5
                } else {
                    nextUnlock = 8
                }
                info += "\n🔓 CC Lv.\(nextUnlock): +1 warehouse slot"
            }
        }
        
        return info
    }
    func updateAllTrainingSliderLimits() {
        guard let contexts = trainingContexts else { return }
        
        for (_, context) in contexts {
            guard let container = context.container,
                  let slider = container.subviews.first(where: { $0 is UISlider }) as? UISlider else {
                continue
            }
            
            updateSliderLimits(slider: slider, unitType: context.unitType, container: container)
        }
    }
    
    func updateSliderLimits(slider: UISlider, unitType: TrainableUnitType, container: UIView) {
        // Calculate max affordable based on resources
        var maxAffordable = 100
        for (resourceType, unitCost) in unitType.trainingCost {
            let available = player.getResource(resourceType)
            let canAfford = unitCost > 0 ? available / unitCost : 100
            maxAffordable = min(maxAffordable, canAfford)
        }
        
        // Also cap by available population space
        let availablePop = player.getAvailablePopulation()
        maxAffordable = min(maxAffordable, availablePop)
        
        // Ensure at least 1 for slider to work, but button will be disabled if 0
        let sliderMax = max(1, min(maxAffordable, 20))  // Cap at 20
        let canTrain = maxAffordable >= 1
        
        // Update slider
        slider.maximumValue = Float(sliderMax)
        slider.isEnabled = canTrain
        slider.alpha = canTrain ? 1.0 : 0.5
        
        // Clamp current value to new max
        if slider.value > Float(sliderMax) {
            slider.value = Float(sliderMax)
        }
        
        // Ensure value is at least 1 if slider is enabled
        if canTrain && slider.value < 1 {
            slider.value = 1
        }
        
        // Update the train button state
        if let trainButton = container.subviews.first(where: {
            ($0 as? UIButton)?.title(for: .normal)?.contains("Training") == true ||
            ($0 as? UIButton)?.title(for: .normal)?.contains("Pop Limit") == true
        }) as? UIButton {
            trainButton.isEnabled = canTrain
            trainButton.alpha = canTrain ? 1.0 : 0.5
            
            if canTrain {
                trainButton.setTitle("✅ Start Training", for: .normal)
                trainButton.backgroundColor = UIColor(red: 0.3, green: 0.7, blue: 0.4, alpha: 1.0)
            } else {
                trainButton.setTitle("⚠️ Pop Limit Reached", for: .normal)
                trainButton.backgroundColor = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
            }
        }
        
        // Update population label
        let currentPop = player.getCurrentPopulation()
        let maxPop = player.getPopulationCapacity()
        let popColor: UIColor = availablePop == 0 ? .systemRed : UIColor(white: 0.8, alpha: 1.0)
        
        for subview in container.subviews {
            if let label = subview as? UILabel,
               label.text?.contains("Population:") == true {
                label.text = "👥 Population: \(currentPop)/\(maxPop) (\(availablePop) available)"
                label.textColor = popColor
                break
            }
        }
        
        // Trigger slider changed to update cost/time labels
        trainingSliderChanged(slider)
    }
    
    func getGarrisonText() -> String {
        var text = ""
        
        if building.villagerGarrison > 0 {
            text += "👷 Villagers: \(building.villagerGarrison)\n"
        }
        
        for (unitType, count) in building.garrison where count > 0 {
            text += "\(unitType.icon) \(unitType.displayName): \(count)\n"
        }
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // ============================================================================
    // MARK: - Upgrade Actions
    // Add this section after the Training Actions section
    // ============================================================================

    @objc func upgradeTapped() {
        print("⬆️ Upgrade button tapped for \(building.buildingType.displayName)")
        
        // Find available villager groups to perform the upgrade
        let availableVillagers = player.entities.compactMap { entity -> VillagerGroup? in
            guard let villagerGroup = entity as? VillagerGroup,
                  villagerGroup.currentTask == .idle else {
                return nil
            }
            return villagerGroup
        }
        
        if availableVillagers.isEmpty {
            // No villagers available - show selection anyway, upgrade will work without assigned villager
            // Or you can choose to require a villager
            showVillagerSelectionForUpgrade(availableVillagers: [])
        } else {
            showVillagerSelectionForUpgrade(availableVillagers: availableVillagers)
        }
    }

    func showVillagerSelectionForUpgrade(availableVillagers: [VillagerGroup]) {
        if availableVillagers.isEmpty {
            // Proceed without assigning a villager (optional based on your game design)
            // OR show error that no villagers are available
            let alert = UIAlertController(
                title: "No Idle Villagers",
                message: "All your villagers are busy. Start upgrade anyway?",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Start Upgrade", style: .default) { [weak self] _ in
                self?.executeUpgrade(villagerEntity: nil)
            })
            
            present(alert, animated: true)
            return
        }
        
        // Show villager selection
        let alert = UIAlertController(
            title: "👷 Select Villager",
            message: "Choose a villager group to perform the upgrade:",
            preferredStyle: .actionSheet
        )
        
        for villagerGroup in availableVillagers {
            // Find the EntityNode for this villager group
            if let entityNode = hexMap.entities.first(where: {
                ($0.entity as? VillagerGroup)?.id == villagerGroup.id
            }) {
                let distance = villagerGroup.coordinate.distance(to: building.coordinate)
                let title = "👷 \(villagerGroup.name) (\(villagerGroup.villagerCount) villagers) - Distance: \(distance)"
                
                alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                    self?.executeUpgrade(villagerEntity: entityNode)
                })
            }
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }
        
        present(alert, animated: true)
    }

    func executeUpgrade(villagerEntity: EntityNode?) {
        guard let player = player else {
            showAlert(title: "Error", message: "Player not available.")
            return
        }
        
        // Create and execute the upgrade command
        let command = UpgradeCommand(
            playerID: player.id,
            buildingID: building.data.id,  // ✅ Use data.id, not building.id
            upgraderEntityID: villagerEntity?.entity.id
        )
        
        let result = CommandExecutor.shared.execute(command)
        
        if result.succeeded {
            showAlert(title: "✅ Upgrade Started", message: "Upgrading \(building.buildingType.displayName) to Level \(building.level + 1)")
            
            // Refresh the content to show upgrade progress
            refreshContent()
            
            // Update resource display in game view
            gameViewController?.updateResourceDisplay()
        } else if let reason = result.failureReason {
            showAlert(title: "Upgrade Failed", message: reason)
        }
    }


    // ============================================================================
    // MARK: - Upgrade Progress Section (when building IS upgrading)
    // Add this method near setupUpgradeSection
    // ============================================================================

    func setupUpgradingProgressSection(yOffset: CGFloat, leftMargin: CGFloat, contentWidth: CGFloat) -> CGFloat {
        var currentY = yOffset
        
        // Section header
        let upgradeHeader = createLabel(
            text: "⬆️ Upgrading to Level \(building.level + 1)",
            fontSize: 18,
            weight: .bold,
            color: .cyan
        )
        upgradeHeader.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 25)
        contentView.addSubview(upgradeHeader)
        currentY += 35
        
        // Progress calculation
        let currentTime = Date().timeIntervalSince1970
        let progress = building.upgradeProgress
        let progressPercent = Int(progress * 100)
        
        // Progress bar background
        let progressBarBg = UIView(frame: CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 20))
        progressBarBg.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
        progressBarBg.layer.cornerRadius = 10
        contentView.addSubview(progressBarBg)
        
        // Progress bar fill
        let fillWidth = max(0, contentWidth * CGFloat(progress))
        let progressBarFill = UIView(frame: CGRect(x: leftMargin, y: currentY, width: fillWidth, height: 20))
        progressBarFill.backgroundColor = UIColor(red: 0.3, green: 0.7, blue: 0.9, alpha: 1.0)
        progressBarFill.layer.cornerRadius = 10
        progressBarFill.tag = 9001  // Tag for updating later
        contentView.addSubview(progressBarFill)
        currentY += 30
        
        // Progress percentage label
        let progressLabel = createLabel(
            text: "Progress: \(progressPercent)%",
            fontSize: 14,
            color: UIColor(white: 0.8, alpha: 1.0)
        )
        progressLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 20)
        progressLabel.tag = 9002  // Tag for updating later
        contentView.addSubview(progressLabel)
        currentY += 25
        
        // Time remaining
        if let remainingTime = building.data.getRemainingUpgradeTime(currentTime: currentTime) {
            let minutes = Int(remainingTime) / 60
            let seconds = Int(remainingTime) % 60
            
            let timeLabel = createLabel(
                text: "⏱️ Time Remaining: \(minutes)m \(seconds)s",
                fontSize: 14,
                color: UIColor(white: 0.7, alpha: 1.0)
            )
            timeLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 20)
            timeLabel.tag = 9003  // Tag for updating later
            contentView.addSubview(timeLabel)
            currentY += 30
        }
        
        // Cancel upgrade button
        let cancelButton = UIButton(type: .system)
        cancelButton.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 50)
        cancelButton.setTitle("🚫 Cancel Upgrade", for: .normal)
        cancelButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.backgroundColor = UIColor(red: 0.8, green: 0.3, blue: 0.3, alpha: 1.0)
        cancelButton.layer.cornerRadius = 10
        cancelButton.addTarget(self, action: #selector(cancelUpgradeTapped), for: .touchUpInside)
        contentView.addSubview(cancelButton)
        currentY += 60
        
        return currentY
    }

    @objc func cancelUpgradeTapped() {
        let alert = UIAlertController(
            title: "Cancel Upgrade?",
            message: "Are you sure you want to cancel the upgrade? Resources will be refunded.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Keep Upgrading", style: .cancel))
        alert.addAction(UIAlertAction(title: "Cancel Upgrade", style: .destructive) { [weak self] _ in
            self?.performCancelUpgrade()
        })
        
        present(alert, animated: true)
    }
    
    func setupUpgradeSection(yOffset: CGFloat, leftMargin: CGFloat, contentWidth: CGFloat) -> CGFloat {
        var currentY = yOffset
        
        // Section header
        let upgradeHeader = createLabel(text: "⬆️ Upgrade to Level \(building.level + 1)",
                                       fontSize: 18,
                                       weight: .bold,
                                       color: .cyan)
        
        // Check if upgrade is blocked by City Center level (for Castle)
        if let blockedReason = building.upgradeBlockedReason {
            // Show the blocked reason
            let blockedLabel = createLabel(text: "🔒 \(blockedReason)",
                                           fontSize: 14,
                                           color: UIColor(red: 1.0, green: 0.6, blue: 0.3, alpha: 1.0))
            blockedLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 25)
            contentView.addSubview(blockedLabel)
            currentY += 35
            
            return currentY
        }
        
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
                                       color: canAfford ? UIColor(white: 0.8, alpha: 1.0) : UIColor.systemRed)
            costLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 20)
            contentView.addSubview(costLabel)
            currentY += 25
            
            // Time display
            if let upgradeTime = building.getUpgradeTime() {
                let minutes = Int(upgradeTime) / 60
                let seconds = Int(upgradeTime) % 60
                let timeLabel = createLabel(text: "⏱️ Time: \(minutes)m \(seconds)s",
                                           fontSize: 14,
                                           color: UIColor(white: 0.7, alpha: 1.0))
                timeLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 20)
                contentView.addSubview(timeLabel)
                currentY += 30
            }
            
            // Upgrade button
            let upgradeButton = UIButton(type: .system)
            upgradeButton.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 50)
            upgradeButton.setTitle("⬆️ Start Upgrade", for: .normal)
            upgradeButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
            upgradeButton.setTitleColor(.white, for: .normal)
            upgradeButton.backgroundColor = canAfford ? UIColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 1.0) : UIColor.gray
            upgradeButton.layer.cornerRadius = 10
            upgradeButton.isEnabled = canAfford
            upgradeButton.addTarget(self, action: #selector(upgradeTapped), for: .touchUpInside)
            contentView.addSubview(upgradeButton)
            currentY += 60
        }

        return currentY
    }

    // ============================================================================
    // MARK: - Demolition Section
    // ============================================================================

    func setupDemolishSection(yOffset: CGFloat, leftMargin: CGFloat, contentWidth: CGFloat) -> CGFloat {
        var currentY = yOffset

        // Separator
        let separator = UIView(frame: CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 1))
        separator.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
        contentView.addSubview(separator)
        currentY += 20

        // Section header
        let demolishHeader = createLabel(
            text: "🏚️ Demolish Building",
            fontSize: 18,
            weight: .bold,
            color: .orange
        )
        demolishHeader.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 25)
        contentView.addSubview(demolishHeader)
        currentY += 30

        // Refund info
        let refund = building.data.getDemolitionRefund()
        let refundText = refund.map { "\($0.key.icon)\($0.value)" }.joined(separator: " ")
        let refundLabel = createLabel(
            text: "Refund: \(refundText)",
            fontSize: 14,
            color: UIColor(white: 0.7, alpha: 1.0)
        )
        refundLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 20)
        contentView.addSubview(refundLabel)
        currentY += 25

        // Time info
        let demolitionTime = building.data.getDemolitionTime()
        let minutes = Int(demolitionTime) / 60
        let seconds = Int(demolitionTime) % 60
        let timeLabel = createLabel(
            text: "⏱️ Time: \(minutes)m \(seconds)s",
            fontSize: 14,
            color: UIColor(white: 0.7, alpha: 1.0)
        )
        timeLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 20)
        contentView.addSubview(timeLabel)
        currentY += 30

        // Check for garrisoned units
        let hasGarrison = building.getTotalGarrisonCount() > 0

        // Demolish button
        let demolishButton = createActionButton(
            title: "🏚️ Demolish",
            y: currentY,
            width: contentWidth,
            leftMargin: leftMargin,
            color: hasGarrison ? .gray : UIColor(red: 0.8, green: 0.4, blue: 0.2, alpha: 1.0),
            action: #selector(demolishTapped)
        )
        demolishButton.isEnabled = !hasGarrison
        contentView.addSubview(demolishButton)
        currentY += 60

        if hasGarrison {
            let warningLabel = createLabel(
                text: "⚠️ Remove garrisoned units before demolishing",
                fontSize: 12,
                color: .systemRed
            )
            warningLabel.frame = CGRect(x: leftMargin, y: currentY - 25, width: contentWidth, height: 20)
            contentView.addSubview(warningLabel)
        }

        return currentY
    }

    func setupDemolishingProgressSection(yOffset: CGFloat, leftMargin: CGFloat, contentWidth: CGFloat) -> CGFloat {
        var currentY = yOffset

        // Section header
        let demolishHeader = createLabel(
            text: "🏚️ Demolishing...",
            fontSize: 18,
            weight: .bold,
            color: .orange
        )
        demolishHeader.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 25)
        contentView.addSubview(demolishHeader)
        currentY += 35

        // Progress bar background
        let progress = building.demolitionProgress
        let progressBarBg = UIView(frame: CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 20))
        progressBarBg.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
        progressBarBg.layer.cornerRadius = 10
        contentView.addSubview(progressBarBg)

        // Progress bar fill
        let fillWidth = max(0, contentWidth * CGFloat(progress))
        let progressBarFill = UIView(frame: CGRect(x: leftMargin, y: currentY, width: fillWidth, height: 20))
        progressBarFill.backgroundColor = .orange
        progressBarFill.layer.cornerRadius = 10
        progressBarFill.tag = 9101
        contentView.addSubview(progressBarFill)
        currentY += 30

        // Progress label
        let progressPercent = Int(progress * 100)
        let progressLabel = createLabel(
            text: "Progress: \(progressPercent)%",
            fontSize: 14,
            color: UIColor(white: 0.8, alpha: 1.0)
        )
        progressLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 20)
        progressLabel.tag = 9102
        contentView.addSubview(progressLabel)
        currentY += 25

        // Time remaining
        let currentTime = Date().timeIntervalSince1970
        if let remainingTime = building.data.getRemainingDemolitionTime(currentTime: currentTime) {
            let minutes = Int(remainingTime) / 60
            let seconds = Int(remainingTime) % 60
            let timeLabel = createLabel(
                text: "⏱️ Time Remaining: \(minutes)m \(seconds)s",
                fontSize: 14,
                color: UIColor(white: 0.7, alpha: 1.0)
            )
            timeLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 20)
            timeLabel.tag = 9103
            contentView.addSubview(timeLabel)
            currentY += 30
        }

        // Refund preview
        let refund = building.data.getDemolitionRefund()
        let refundText = refund.map { "\($0.key.icon)\($0.value)" }.joined(separator: " ")
        let refundLabel = createLabel(
            text: "Will refund: \(refundText)",
            fontSize: 14,
            color: UIColor(white: 0.6, alpha: 1.0)
        )
        refundLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 20)
        contentView.addSubview(refundLabel)
        currentY += 30

        // Cancel button
        let cancelButton = createActionButton(
            title: "🚫 Cancel Demolition",
            y: currentY,
            width: contentWidth,
            leftMargin: leftMargin,
            color: UIColor(red: 0.6, green: 0.3, blue: 0.3, alpha: 1.0),
            action: #selector(cancelDemolitionTapped)
        )
        contentView.addSubview(cancelButton)
        currentY += 60

        return currentY
    }

    @objc func demolishTapped() {
        // Show confirmation
        let refund = building.data.getDemolitionRefund()
        let refundText = refund.map { "\($0.key.icon)\($0.value)" }.joined(separator: " ")
        let demolitionTime = building.data.getDemolitionTime()
        let minutes = Int(demolitionTime) / 60
        let seconds = Int(demolitionTime) % 60

        let alert = UIAlertController(
            title: "🏚️ Demolish \(building.buildingType.displayName)?",
            message: "This will take \(minutes)m \(seconds)s and refund \(refundText).",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Demolish", style: .destructive) { [weak self] _ in
            self?.showVillagerSelectionForDemolition()
        })

        present(alert, animated: true)
    }

    func showVillagerSelectionForDemolition() {
        // Find available villager groups
        let availableVillagers = player.entities.compactMap { entity -> VillagerGroup? in
            guard let villagerGroup = entity as? VillagerGroup,
                  villagerGroup.currentTask == .idle else {
                return nil
            }
            return villagerGroup
        }

        if availableVillagers.isEmpty {
            // Proceed without villager
            executeDemolition(villagerEntity: nil)
        } else {
            // Show villager selection
            let alert = UIAlertController(
                title: "👷 Select Villager",
                message: "Choose a villager group to perform the demolition:",
                preferredStyle: .actionSheet
            )

            for villagerGroup in availableVillagers {
                if let entityNode = hexMap.entities.first(where: {
                    ($0.entity as? VillagerGroup)?.id == villagerGroup.id
                }) {
                    let distance = villagerGroup.coordinate.distance(to: building.coordinate)
                    let title = "👷 \(villagerGroup.name) (\(villagerGroup.villagerCount) villagers) - Distance: \(distance)"

                    alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                        self?.executeDemolition(villagerEntity: entityNode)
                    })
                }
            }

            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

            if let popover = alert.popoverPresentationController {
                popover.sourceView = view
                popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            }

            present(alert, animated: true)
        }
    }

    func executeDemolition(villagerEntity: EntityNode?) {
        let command = DemolishCommand(
            playerID: player.id,
            buildingID: building.data.id,
            demolisherEntityID: villagerEntity?.entity.id
        )

        let result = CommandExecutor.shared.execute(command)

        if result.succeeded {
            showAlert(title: "🏚️ Demolition Started", message: "Demolishing \(building.buildingType.displayName)")
            refreshContent()
            gameViewController?.updateResourceDisplay()
        } else if let reason = result.failureReason {
            showAlert(title: "Demolition Failed", message: reason)
        }
    }

    @objc func cancelDemolitionTapped() {
        let alert = UIAlertController(
            title: "Cancel Demolition?",
            message: "Are you sure you want to stop demolishing this building?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Keep Demolishing", style: .cancel))
        alert.addAction(UIAlertAction(title: "Cancel Demolition", style: .default) { [weak self] _ in
            self?.performCancelDemolition()
        })

        present(alert, animated: true)
    }

    func performCancelDemolition() {
        let command = CancelDemolitionCommand(
            playerID: player.id,
            buildingID: building.data.id
        )

        let result = CommandExecutor.shared.execute(command)

        if result.succeeded {
            showAlert(title: "🚫 Demolition Cancelled", message: "The building is no longer being demolished.")
            refreshContent()
        } else if let reason = result.failureReason {
            showAlert(title: "Cancel Failed", message: reason)
        }
    }
}
