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
    var gameViewController: GameViewController?
    var trainingContexts: [Int: TrainingSliderContext]?
    var hexMap: HexMap!
    var gameScene: GameScene!
    
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
    
    // MARK: - Lifecycle
    
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
        let contentWidth = view.bounds.width - 40
        let leftMargin: CGFloat = 20
        var yOffset: CGFloat = 20
        
        // Title
        let titleLabel = createLabel(
            text: "\(building.buildingType.icon) \(building.buildingType.displayName)",
            fontSize: 28,
            weight: .bold,
            color: .white
        )
        titleLabel.frame = CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: 35)
        contentView.addSubview(titleLabel)
        yOffset += 45
        
        // Level
        let levelLabel = createLabel(
            text: "⭐ Level \(building.level)/\(building.maxLevel)",
            fontSize: 18,
            weight: .semibold,
            color: UIColor(red: 1.0, green: 0.85, blue: 0.4, alpha: 1.0)
        )
        levelLabel.frame = CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: 25)
        contentView.addSubview(levelLabel)
        yOffset += 35
        
        // Description
        let descLabel = createLabel(
            text: building.buildingType.description,
            fontSize: 14,
            color: UIColor(white: 0.8, alpha: 1.0)
        )
        descLabel.frame = CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: 0)
        descLabel.numberOfLines = 0
        descLabel.sizeToFit()
        contentView.addSubview(descLabel)
        yOffset += descLabel.frame.height + 20
        
        // Location
        let locationLabel = createLabel(
            text: "📍 Location: (\(building.coordinate.q), \(building.coordinate.r))",
            fontSize: 14,
            color: UIColor(white: 0.7, alpha: 1.0)
        )
        locationLabel.frame = CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: 25)
        contentView.addSubview(locationLabel)
        yOffset += 35
        
        // Garrison info
        if building.getTotalGarrisonCount() > 0 {
            let garrisonLabel = createLabel(
                text: "🏰 Garrison: \(building.getTotalGarrisonCount())/\(building.getGarrisonCapacity()) units",
                fontSize: 16,
                weight: .semibold,
                color: .white
            )
            garrisonLabel.frame = CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: 25)
            contentView.addSubview(garrisonLabel)
            yOffset += 35
            
            let garrisonDetailLabel = createLabel(
                text: garrisonLabel.text!,
                fontSize: 14,
                color: UIColor(white: 0.8, alpha: 1.0)
            )
            garrisonDetailLabel.frame = CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: 0)
            garrisonDetailLabel.numberOfLines = 0
            garrisonDetailLabel.sizeToFit()
            contentView.addSubview(garrisonDetailLabel)
            yOffset += garrisonDetailLabel.frame.height + 20
            
            // Deploy button for City Center
            if building.buildingType == .cityCenter && building.villagerGarrison > 0 {
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
            
            // Reinforce Army button
            if building.getTotalGarrisonedUnits() > 0 {
                let reinforceButton = createActionButton(
                    title: "⚔️ Reinforce Army",
                    y: yOffset,
                    width: contentWidth,
                    leftMargin: leftMargin,
                    color: UIColor(red: 0.6, green: 0.4, blue: 0.7, alpha: 1.0),
                    action: #selector(reinforceArmyTapped)
                )
                contentView.addSubview(reinforceButton)
                yOffset += 70
            }
        }
        
        // Training Section
        if canTrainUnits() && building.state == .completed {
            yOffset = setupTrainingSection(yOffset: yOffset, contentWidth: contentWidth, leftMargin: leftMargin)
        }
        
        // Queue display
        let queueTitleLabel = createLabel(
            text: "📋 Training Queue",
            fontSize: 18,
            weight: .semibold,
            color: .white
        )
        queueTitleLabel.frame = CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: 25)
        contentView.addSubview(queueTitleLabel)
        yOffset += 35
        
        queueLabel = createLabel(
            text: getQueueDisplayText(),
            fontSize: 14,
            color: UIColor(white: 0.8, alpha: 1.0)
        )
        queueLabel?.frame = CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: 0)
        queueLabel?.numberOfLines = 0
        queueLabel?.sizeToFit()
        contentView.addSubview(queueLabel!)
        yOffset += (queueLabel?.frame.height ?? 20) + 30
        
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
        var currentY = yOffset
        
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
        
        // Cost label
        let costText = formatCost(unitType.trainingCost)
        let costLabel = UILabel(frame: CGRect(x: 15, y: 35, width: contentWidth - 30, height: 20))
        costLabel.text = "Cost: \(costText)"
        costLabel.font = UIFont.systemFont(ofSize: 12)
        costLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        costLabel.tag = 1000 + index
        container.addSubview(costLabel)
        
        // Slider
        let slider = UISlider(frame: CGRect(x: 15, y: 60, width: contentWidth - 110, height: 30))
        slider.minimumValue = 1
        slider.maximumValue = 10
        slider.value = 1
        slider.tag = index
        slider.addTarget(self, action: #selector(trainingSliderChanged(_:)), for: .valueChanged)
        container.addSubview(slider)
        
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
        trainButton.backgroundColor = UIColor(red: 0.2, green: 0.6, blue: 0.3, alpha: 1.0)
        trainButton.layer.cornerRadius = 20
        trainButton.tag = index
        trainButton.addTarget(self, action: #selector(trainButtonTapped(_:)), for: .touchUpInside)
        container.addSubview(trainButton)
        
        // Store context
        let context = TrainingSliderContext(unitType: unitType, container: container, building: building)
        trainingContexts?[index] = context
        
        return currentY + 130
    }
    
    // =========================================================================
    // MARK: - Training Actions (Using Commands)
    // =========================================================================
    
    @objc func trainButtonTapped(_ sender: UIButton) {
        guard let context = trainingContexts?[sender.tag],
              let container = context.container else {
            print("❌ No context found for button tag \(sender.tag)")
            return
        }
        
        guard let slider = container.subviews.first(where: { $0 is UISlider }) as? UISlider else {
            print("❌ No slider found in container")
            return
        }
        
        let quantity = Int(slider.value)
        let unitType = context.unitType
        
        print("📊 Training \(quantity)x \(unitType.displayName)")
        
        executeTrainCommand(unitType: unitType, quantity: quantity)
        
        // Reset slider to 1
        slider.value = 1
        trainingSliderChanged(slider)
    }
    
    /// Executes training using Command pattern
    func executeTrainCommand(unitType: TrainableUnitType, quantity: Int) {
        print("🎯 executeTrainCommand called: \(quantity)x \(unitType.displayName)")
        
        switch unitType {
        case .villager:
            let command = TrainVillagerCommand(
                playerID: player.id,
                buildingID: building.data.id,
                quantity: quantity
            )
            
            let result = CommandExecutor.shared.execute(command)
            
            if result.succeeded {
                showAlert(title: "✅ Training Started", message: "Training \(quantity) Villager\(quantity > 1 ? "s" : "")")
                updateQueueDisplay()
            } else if let reason = result.failureReason {
                showAlert(title: "Cannot Train", message: reason)
            }
            
        case .military(let militaryType):
            let command = TrainMilitaryCommand(
                playerID: player.id,
                buildingID: building.data.id,
                unitType: militaryType,
                quantity: quantity
            )
            
            let result = CommandExecutor.shared.execute(command)
            
            if result.succeeded {
                showAlert(title: "✅ Training Started", message: "Training \(quantity) \(militaryType.displayName)\(quantity > 1 ? "s" : "")")
                updateQueueDisplay()
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
        
        guard let spawnCoord = hexMap.findNearestWalkable(to: building.coordinate, maxDistance: 3) else {
            showAlert(title: "Cannot Deploy", message: "No walkable location nearby.")
            return
        }
        
        let alert = UIAlertController(
            title: "👷 Deploy Villagers",
            message: "Select how many villagers to deploy\n\nAvailable: \(villagerCount)",
            preferredStyle: .alert
        )
        
        let containerVC = UIViewController()
        containerVC.preferredContentSize = CGSize(width: 270, height: 100)
        
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 270, height: 100))
        
        let slider = UISlider(frame: CGRect(x: 20, y: 20, width: 230, height: 30))
        slider.minimumValue = 1
        slider.maximumValue = Float(villagerCount)
        slider.value = Float(min(5, villagerCount))
        containerView.addSubview(slider)
        
        let countLabel = UILabel(frame: CGRect(x: 20, y: 55, width: 230, height: 30))
        countLabel.text = "\(Int(slider.value)) villagers"
        countLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        countLabel.textAlignment = .center
        containerView.addSubview(countLabel)
        
        slider.addTarget(self, action: #selector(deploySliderChanged(_:)), for: .valueChanged)
        objc_setAssociatedObject(self, &AssociatedKeys.villagerCountLabel, countLabel, .OBJC_ASSOCIATION_RETAIN)
        
        containerVC.view.addSubview(containerView)
        alert.setValue(containerVC, forKey: "contentViewController")
        
        alert.addAction(UIAlertAction(title: "Deploy", style: .default) { [weak self] _ in
            let count = Int(slider.value)
            self?.executeDeployVillagersCommand(count: count, at: spawnCoord)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
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
        // Override in subclass if needed
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
}
