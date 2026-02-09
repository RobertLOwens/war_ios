// ============================================================================
// FILE: AttackEntityPanelViewController.swift
// LOCATION: Grow2 iOS/ViewControllers/AttackEntityPanelViewController.swift
// PURPOSE: Left-side slide-out panel for selecting armies to attack enemies,
//          with route preview and combat information
// ============================================================================

import UIKit
import SpriteKit

class AttackEntityPanelViewController: SidePanelViewController {

    // MARK: - Properties

    var targetCoordinate: HexCoordinate!
    var enemies: [EntityNode] = []
    var targetBuilding: BuildingNode?  // For attacking buildings
    var availableArmies: [Army] = []

    var onConfirm: ((Army) -> Void)?

    private var selectedArmy: Army?

    // UI Elements for custom sections
    private var targetInfoView: UIView!
    private var combatInfoLabel: UILabel!

    // MARK: - SidePanelViewController Overrides

    override var panelTitle: String {
        "Select Army to Attack"
    }

    override var panelSubtitle: String {
        "Target: (\(targetCoordinate.q), \(targetCoordinate.r))"
    }

    override var confirmButtonTitle: String {
        "Attack"
    }

    override var theme: PanelTheme {
        .attack()
    }

    override var initialTravelTimeText: String {
        "Select an army to see travel time"
    }

    override var infoSectionHeight: CGFloat {
        PanelLayoutConstants.infoSectionHeight
    }

    // MARK: - Additional Setup

    override func additionalSetup() {
        setupTargetInfo()
        setupCombatInfoLabel()
    }

    private func setupTargetInfo() {
        // Target info section showing enemy units
        let targetInfoY: CGFloat = PanelLayoutConstants.headerHeight
        targetInfoView = UIView(frame: CGRect(
            x: 0,
            y: targetInfoY,
            width: panelWidth,
            height: PanelLayoutConstants.infoSectionHeight
        ))
        targetInfoView.backgroundColor = theme.previewSectionBackgroundColor
        panelView.addSubview(targetInfoView)

        let targetLabel = UILabel(frame: CGRect(
            x: PanelLayoutConstants.horizontalPadding,
            y: 8,
            width: PanelLayoutConstants.contentWidth,
            height: 18
        ))
        let isZoneAttack = enemies.isEmpty && targetBuilding == nil
        targetLabel.text = targetBuilding != nil ? "Target Building:" : (isZoneAttack ? "Entrenchment Zone:" : "Enemies at Target:")
        targetLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        targetLabel.textColor = theme.errorTextColor
        targetInfoView.addSubview(targetLabel)

        let enemyInfoLabel = UILabel(frame: CGRect(
            x: PanelLayoutConstants.horizontalPadding,
            y: 28,
            width: PanelLayoutConstants.contentWidth,
            height: 24
        ))
        enemyInfoLabel.text = buildEnemyDescription()
        enemyInfoLabel.font = UIFont.systemFont(ofSize: 14)
        enemyInfoLabel.textColor = theme.secondaryTextColor
        enemyInfoLabel.numberOfLines = 2
        targetInfoView.addSubview(enemyInfoLabel)
    }

    private func setupCombatInfoLabel() {
        // Replace the warning label with combat info label
        combatInfoLabel = UILabel(frame: CGRect(
            x: PanelLayoutConstants.horizontalPadding,
            y: 40,
            width: PanelLayoutConstants.contentWidth,
            height: PanelLayoutConstants.multiLineHeight
        ))
        combatInfoLabel.text = ""
        combatInfoLabel.font = UIFont.systemFont(ofSize: 13)
        combatInfoLabel.textColor = theme.warningTextColor
        combatInfoLabel.numberOfLines = 2
        previewSection.addSubview(combatInfoLabel)

        // Hide the default warning label
        warningLabel.isHidden = true
    }

    private func buildEnemyDescription() -> String {
        // If targeting a building, show building info
        if let building = targetBuilding {
            let healthPercent = Int((building.health / building.maxHealth) * 100)
            return "\(building.buildingType.icon) \(building.buildingType.displayName) - HP: \(healthPercent)%"
        }

        // Zone attack — show cross-tile entrenched info
        if enemies.isEmpty {
            if let gameState = GameEngine.shared.gameState,
               let player = player {
                let entrenched = gameState.getEntrenchedArmiesCovering(coordinate: targetCoordinate)
                    .filter { $0.ownerID != player.id }
                let totalUnits = entrenched.reduce(0) { $0 + $1.getTotalUnits() }
                return "\(entrenched.count) entrenched army(ies), \(totalUnits) units"
            }
            return "Entrenched defenders"
        }

        // Otherwise show enemy entities
        var parts: [String] = []
        for enemy in enemies {
            if let army = enemy.entity as? Army {
                let unitCount = army.getTotalMilitaryUnits()
                parts.append("\(army.name) (\(unitCount) units)")
            } else if let villagers = enemy.entity as? VillagerGroup {
                parts.append("\(villagers.name) (\(villagers.villagerCount) villagers)")
            }
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Actions

    override func handleConfirm() {
        guard let army = selectedArmy else { return }
        completeAndDismiss { [weak self] in
            self?.onConfirm?(army)
        }
    }

    // MARK: - Army Selection

    private func selectArmy(_ army: Army, at indexPath: IndexPath) {
        handleSelection(at: indexPath)
        selectedArmy = army

        // When attacking a building or entrenchment zone, allow pathing to impassable destination
        let isZoneAttack = enemies.isEmpty && targetBuilding == nil
        let allowImpassable = targetBuilding != nil || isZoneAttack

        // Show route preview
        showRoutePreview(from: army.coordinate, to: targetCoordinate, for: army.owner, allowImpassableDestination: allowImpassable)

        // Update travel time
        updateTravelTimeForArmy(army)

        // Update combat info
        updateCombatInfo(for: army)

        // Enable confirm button
        enableConfirmButton()
    }

    private func updateTravelTimeForArmy(_ army: Army) {
        guard let hexMap = hexMap else {
            travelTimeLabel.text = "Unable to calculate"
            return
        }

        // Find entity node for the army
        guard let entityNode = hexMap.entities.first(where: {
            ($0.entity as? Army)?.id == army.id
        }) else {
            travelTimeLabel.text = "Unable to calculate"
            return
        }

        // When attacking a building or entrenchment zone, allow pathing to impassable destination
        let isZoneAttack = enemies.isEmpty && targetBuilding == nil
        let allowImpassable = targetBuilding != nil || isZoneAttack
        updateTravelTime(for: entityNode, to: targetCoordinate, allowImpassableDestination: allowImpassable)
    }

    private func updateCombatInfo(for army: Army) {
        let armyUnits = army.getTotalMilitaryUnits()
        var enemyUnits = 0

        if enemies.isEmpty && targetBuilding == nil {
            // Zone attack — count units from cross-tile entrenched armies
            if let gameState = GameEngine.shared.gameState {
                let entrenched = gameState.getEntrenchedArmiesCovering(coordinate: targetCoordinate)
                    .filter { $0.ownerID != army.owner?.id }
                enemyUnits = entrenched.reduce(0) { $0 + $1.getTotalUnits() }
            }
        } else {
            for enemy in enemies {
                if let enemyArmy = enemy.entity as? Army {
                    enemyUnits += enemyArmy.getTotalMilitaryUnits()
                } else if let villagers = enemy.entity as? VillagerGroup {
                    enemyUnits += villagers.villagerCount
                }
            }
        }

        if armyUnits > enemyUnits * 2 {
            combatInfoLabel.text = "Overwhelming advantage"
            combatInfoLabel.textColor = UIColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1.0)
        } else if armyUnits > enemyUnits {
            combatInfoLabel.text = "Favorable odds"
            combatInfoLabel.textColor = UIColor(red: 0.5, green: 0.8, blue: 0.5, alpha: 1.0)
        } else if armyUnits == enemyUnits {
            combatInfoLabel.text = "Even match"
            combatInfoLabel.textColor = UIColor(red: 1.0, green: 0.8, blue: 0.3, alpha: 1.0)
        } else if armyUnits * 2 > enemyUnits {
            combatInfoLabel.text = "Unfavorable odds"
            combatInfoLabel.textColor = UIColor(red: 1.0, green: 0.5, blue: 0.3, alpha: 1.0)
        } else {
            combatInfoLabel.text = "Heavily outnumbered!"
            combatInfoLabel.textColor = UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0)
        }
    }
}

// MARK: - UITableViewDelegate & DataSource

extension AttackEntityPanelViewController {

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return availableArmies.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: EntitySelectionCell.reuseIdentifier,
            for: indexPath
        ) as! EntitySelectionCell

        let army = availableArmies[indexPath.row]
        let config = EntityCellConfiguration.army(army, targetCoordinate: targetCoordinate)
        cell.configure(with: config, theme: theme)
        cell.setSelectedState(indexPath == selectedIndexPath)

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        let army = availableArmies[indexPath.row]
        selectArmy(army, at: indexPath)
    }
}
