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
    
    struct AssociatedKeys {
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
        
        debugLog("🎬 BuildingDetailViewController loaded for \(building.buildingType.displayName)")
        debugLog("   Training queue: \(building.trainingQueue.count)")
        debugLog("   Villager queue: \(building.villagerTrainingQueue.count)")
        
        // Update queue display every second
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            if self.building.state == .upgrading {
                self.updateUpgradeProgressDisplay()
            }
            self.updateUnitUpgradeProgressDisplay()
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
        debugLog("🎓 Building \(building.buildingType.displayName) trainable units: \(trainableUnits.map { $0.displayName })")
        
        if !trainableUnits.isEmpty && building.state == .completed {
            debugLog("   → Showing training section")
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
            debugLog("   → Skipping training section (no trainable units or not completed)")
        }
        
        // Unit upgrade section (for military buildings that are completed)
        if building.buildingType.category == .military && building.state == .completed {
            yOffset = setupUnitUpgradeSection(yOffset: yOffset, contentWidth: contentWidth, leftMargin: leftMargin)
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
        debugLog("🔧 DEBUG - Upgrade section check:")
        debugLog("   state: \(building.state)")
        debugLog("   canUpgrade: \(building.canUpgrade)")
        debugLog("   level: \(building.level)/\(building.maxLevel)")
        
        if building.state == .upgrading {
            debugLog("   → Showing upgrade PROGRESS section")
            yOffset = setupUpgradingProgressSection(yOffset: yOffset, leftMargin: leftMargin, contentWidth: contentWidth)
        } else if building.state == .completed && building.canUpgrade {
            debugLog("   → Showing upgrade OPTION section")
            yOffset = setupUpgradeSection(yOffset: yOffset, leftMargin: leftMargin, contentWidth: contentWidth)
        } else if building.state == .completed && building.level >= building.maxLevel {
            debugLog("   → Showing MAX LEVEL label")
            let maxLevelLabel = createLabel(
                text: "✨ Maximum Level Reached",
                fontSize: 14,
                color: UIColor(red: 1.0, green: 0.85, blue: 0.4, alpha: 1.0)
            )
            maxLevelLabel.frame = CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: 25)
            contentView.addSubview(maxLevelLabel)
            yOffset += 35
        } else {
            debugLog("   → No upgrade section shown")
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
    
    // Training section: see BuildingDetailViewController+Training.swift
    // Market trading: see BuildingDetailViewController+Market.swift
    // Deploy/garrison/reinforce: see BuildingDetailViewController+Garrison.swift
    
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
        let researchMultiplier = ResearchManager.shared.getMilitaryTrainingSpeedMultiplier()
        let buildingMultiplier = building.data.getTrainingSpeedMultiplier()
        let combinedMultiplier = researchMultiplier * buildingMultiplier

        // Military training queue
        for entry in building.trainingQueue {
            let progress = entry.getProgress(currentTime: currentTime, trainingSpeedMultiplier: combinedMultiplier)
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
    // Upgrade/demolition: see BuildingDetailViewController+Upgrades.swift
}
