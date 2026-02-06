// ============================================================================
// FILE: BuildingDetailViewController+Garrison.swift
// PURPOSE: Garrison, deploy villagers, and reinforce army actions
//          for BuildingDetailViewController
// ============================================================================

import UIKit

// MARK: - Deploy Villagers

extension BuildingDetailViewController {

    @objc func deployVillagersTapped() {
        let villagerCount = building.villagerGarrison

        guard villagerCount > 0 else {
            showAlert(title: "No Villagers", message: "No villagers in garrison to deploy.")
            return
        }

        let panelVC = VillagerDeploymentPanelViewController()
        panelVC.building = building
        panelVC.hexMap = hexMap
        panelVC.gameScene = gameScene
        panelVC.player = player
        panelVC.modalPresentationStyle = .overFullScreen
        panelVC.modalTransitionStyle = .crossDissolve

        panelVC.onDeployNew = { [weak self] count in
            guard let self = self else { return }

            guard let spawnCoord = self.hexMap.findNearestWalkable(to: self.building.coordinate, maxDistance: 3) else {
                self.showAlert(title: "Cannot Deploy", message: "No walkable location nearby.")
                return
            }

            self.executeDeployVillagersCommand(count: count, at: spawnCoord)
        }

        panelVC.onJoinExisting = { [weak self] targetGroup, count in
            guard let self = self else { return }
            self.executeJoinVillagerGroupCommand(targetGroup: targetGroup, count: count)
        }

        panelVC.onCancel = {
            // Nothing to do on cancel
        }

        present(panelVC, animated: false)
    }

    func executeJoinVillagerGroupCommand(targetGroup: VillagerGroup, count: Int) {
        let command = JoinVillagerGroupCommand(
            playerID: player.id,
            buildingID: building.data.id,
            targetVillagerGroupID: targetGroup.id,
            count: count
        )

        let result = CommandExecutor.shared.execute(command)

        if result.succeeded {
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

    func deployVillagers(count: Int, at coordinate: HexCoordinate) {
        executeDeployVillagersCommand(count: count, at: coordinate)
    }
}

// MARK: - Reinforce Army

extension BuildingDetailViewController {

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
}
