// ============================================================================
// FILE: BuildingDetailViewController+Training.swift
// PURPOSE: Training section UI and actions for BuildingDetailViewController
// ============================================================================

import UIKit

// MARK: - Training Section

extension BuildingDetailViewController {

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
        let costLabel = UILabel(frame: CGRect(x: 15, y: 35, width: contentWidth - 140, height: 20))
        costLabel.text = "Cost: \(costText)"
        costLabel.font = UIFont.systemFont(ofSize: 12)
        costLabel.textColor = costReduction > 0 ? UIColor(red: 0.5, green: 0.9, blue: 0.5, alpha: 1.0) : UIColor(white: 0.7, alpha: 1.0)
        costLabel.tag = 1000 + index
        container.addSubview(costLabel)

        // Training time per unit
        let effectiveTime: TimeInterval
        switch unitType {
        case .villager:
            effectiveTime = GameConfig.Training.villagerTrainingTime
        case .military:
            let buildingMultiplier = building.data.getTrainingSpeedMultiplier()
            let researchMultiplier = ResearchManager.shared.getMilitaryTrainingSpeedMultiplier()
            effectiveTime = unitType.trainingTime / (buildingMultiplier * researchMultiplier)
        }
        let timeText: String
        if effectiveTime == effectiveTime.rounded() {
            timeText = "\u{23F1}\u{FE0F} \(Int(effectiveTime))s each"
        } else {
            timeText = "\u{23F1}\u{FE0F} \(String(format: "%.1f", effectiveTime))s each"
        }
        let timeLabel = UILabel(frame: CGRect(x: contentWidth - 110, y: 35, width: 95, height: 20))
        timeLabel.text = timeText
        timeLabel.font = UIFont.systemFont(ofSize: 12)
        timeLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        timeLabel.textAlignment = .right
        container.addSubview(timeLabel)

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
        let availablePop = player.getAvailablePopulation()
        let maxByPop = availablePop / unitType.popSpace

        var maxAffordable = Int.max
        for (resourceType, costPerUnit) in unitType.trainingCost {
            if costPerUnit > 0 {
                let available = player.getResource(resourceType)
                let canAfford = available / costPerUnit
                maxAffordable = min(maxAffordable, canAfford)
            }
        }

        let maxTrainable = min(maxByPop, maxAffordable)
        return min(maxTrainable, 50)
    }

    // MARK: - Training Actions

    @objc func trainButtonTapped(_ sender: UIButton) {
        debugLog("🔘 Train button tapped")

        guard let context = trainingContexts?[sender.tag],
              let container = context.container else {
            debugLog("❌ No context found for button tag \(sender.tag)")
            return
        }

        guard let slider = container.subviews.first(where: { $0 is UISlider }) as? UISlider else {
            debugLog("❌ No slider found in container")
            return
        }

        let quantity = Int(slider.value)
        let unitType = context.unitType

        debugLog("📊 Training \(quantity)x \(unitType.displayName)")

        startTraining(unitType: unitType, quantity: quantity)

        slider.value = 1
        updateSliderLimits(slider: slider, unitType: unitType, container: container)
    }

    /// Executes training using Command pattern
    func executeTrainCommand(unitType: TrainableUnitType, quantity: Int) {
        debugLog("🎯 executeTrainCommand called: \(quantity)x \(unitType.displayName)")

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
                updateAllTrainingSliderLimits()
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
                updateAllTrainingSliderLimits()
            } else if let reason = result.failureReason {
                showAlert(title: "Cannot Train", message: reason)
            }
        }

        gameViewController?.updateResourceDisplay()
    }

    func startTraining(unitType: TrainableUnitType, quantity: Int) {
        executeTrainCommand(unitType: unitType, quantity: quantity)
    }

    @objc func trainingSliderChanged(_ slider: UISlider) {
        guard let context = trainingContexts?[slider.tag],
              let container = context.container else { return }

        let quantity = Int(slider.value)

        if let countLabel = container.viewWithTag(2000 + slider.tag) as? UILabel {
            countLabel.text = "\(quantity)"
        }

        if let costLabel = container.viewWithTag(1000 + slider.tag) as? UILabel {
            let totalCost = context.unitType.trainingCost.mapValues { $0 * quantity }
            costLabel.text = "Cost: \(formatCost(totalCost))"
        }
    }

    // MARK: - Training Slider Limits

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
        var maxAffordable = 100
        for (resourceType, unitCost) in unitType.trainingCost {
            let available = player.getResource(resourceType)
            let canAfford = unitCost > 0 ? available / unitCost : 100
            maxAffordable = min(maxAffordable, canAfford)
        }

        let availablePop = player.getAvailablePopulation()
        let maxByPop = availablePop / unitType.popSpace
        maxAffordable = min(maxAffordable, maxByPop)

        let sliderMax = max(1, min(maxAffordable, 20))
        let canTrain = maxAffordable >= 1

        slider.maximumValue = Float(sliderMax)
        slider.isEnabled = canTrain
        slider.alpha = canTrain ? 1.0 : 0.5

        if slider.value > Float(sliderMax) {
            slider.value = Float(sliderMax)
        }

        if canTrain && slider.value < 1 {
            slider.value = 1
        }

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

        trainingSliderChanged(slider)
    }
}
