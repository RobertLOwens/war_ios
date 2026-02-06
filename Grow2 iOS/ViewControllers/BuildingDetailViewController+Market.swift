// ============================================================================
// FILE: BuildingDetailViewController+Market.swift
// PURPOSE: Market trading section UI and actions for BuildingDetailViewController
// ============================================================================

import UIKit

// MARK: - Market Trading Section

extension BuildingDetailViewController {

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

            let rowContainer = UIView(frame: CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 50))
            rowContainer.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
            rowContainer.layer.cornerRadius = 8
            contentView.addSubview(rowContainer)

            let resourceLabel = UILabel(frame: CGRect(x: 10, y: 5, width: 80, height: 20))
            resourceLabel.text = "\(resourceType.icon) \(resourceType.displayName)"
            resourceLabel.font = UIFont.systemFont(ofSize: 14)
            resourceLabel.textColor = .white
            rowContainer.addSubview(resourceLabel)

            let availableLabel = UILabel(frame: CGRect(x: 10, y: 25, width: 80, height: 18))
            availableLabel.text = "Max: \(available)"
            availableLabel.font = UIFont.systemFont(ofSize: 11)
            availableLabel.textColor = UIColor(white: 0.6, alpha: 1.0)
            rowContainer.addSubview(availableLabel)

            let slider = UISlider(frame: CGRect(x: 95, y: 10, width: contentWidth - 170, height: 30))
            slider.minimumValue = 0
            slider.maximumValue = Float(max(1, available))
            slider.value = 0
            slider.addTarget(self, action: #selector(tradeSliderChanged(_:)), for: .valueChanged)
            rowContainer.addSubview(slider)
            tradeFromSliders[resourceType] = slider

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

    // MARK: - Market Actions

    @objc func tradeSliderChanged(_ sender: UISlider) {
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

        for (resourceType, button) in tradeToButtons {
            button.backgroundColor = resourceType == selectedTradeToResource ?
                UIColor(red: 0.3, green: 0.6, blue: 0.3, alpha: 1.0) :
                UIColor(white: 0.25, alpha: 1.0)
        }

        updateTradePreview()
    }

    func updateTradePreview() {
        var totalInput = 0
        for (resourceType, slider) in tradeFromSliders {
            if resourceType != selectedTradeToResource {
                totalInput += Int(slider.value)
            }
        }

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

        let baseRate = 0.80
        let researchBonus = ResearchManager.shared.getMarketRateMultiplier()
        let effectiveRate = baseRate * researchBonus
        let output = Int(Double(totalInput) * effectiveRate)

        for (resourceType, amount) in resourcesToSpend {
            if !player.hasResource(resourceType, amount: amount) {
                showAlert(title: "Insufficient Resources", message: "You don't have enough \(resourceType.displayName).")
                return
            }
        }

        for (resourceType, amount) in resourcesToSpend {
            player.removeResource(resourceType, amount: amount)
        }
        player.addResource(selectedTradeToResource, amount: output)

        gameViewController?.updateResourceDisplay()

        let spentText = resourcesToSpend.map { "\($0.key.icon)\($0.value)" }.joined(separator: " ")
        showAlert(
            title: "✅ Trade Complete",
            message: "Traded \(spentText) for \(output) \(selectedTradeToResource.icon) \(selectedTradeToResource.displayName)"
        )

        for slider in tradeFromSliders.values {
            slider.value = 0
        }
        for label in tradeFromLabels.values {
            label.text = "0"
        }
        updateTradePreview()

        refreshContent()
    }
}
