// ============================================================================
// FILE: BuildingDetailViewController+HomeBase.swift
// PURPOSE: Home base section UI for BuildingDetailViewController
//          Shows army capacity and list of armies based at this building
// ============================================================================

import UIKit

// MARK: - Home Base Section

extension BuildingDetailViewController {

    func setupHomeBaseSection(yOffset: CGFloat, contentWidth: CGFloat, leftMargin: CGFloat) -> CGFloat {
        var currentY = yOffset

        // Section header
        let sectionLabel = createLabel(
            text: "🏠 Home Base",
            fontSize: 18,
            weight: .semibold,
            color: .white
        )
        sectionLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 25)
        contentView.addSubview(sectionLabel)
        currentY += 35

        // Capacity line
        let buildingData = building.data
        let currentCount = GameEngine.shared.gameState?.getArmyCountForHomeBase(buildingID: buildingData.id) ?? 0
        let capacity = buildingData.getArmyHomeBaseCapacity()

        let capacityText: String
        if capacity == nil {
            capacityText = "Army Capacity: \(currentCount) (Unlimited)"
        } else if let cap = capacity {
            capacityText = "Army Capacity: \(currentCount)/\(cap)"
        } else {
            capacityText = "Army Capacity: \(currentCount)"
        }

        let capacityLabel = createLabel(
            text: capacityText,
            fontSize: 15,
            color: UIColor(white: 0.85, alpha: 1.0)
        )
        capacityLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 22)
        contentView.addSubview(capacityLabel)
        currentY += 30

        // Army list
        let armies = GameEngine.shared.gameState?.getArmiesForHomeBase(buildingID: buildingData.id) ?? []

        if armies.isEmpty {
            let emptyLabel = createLabel(
                text: "No armies based here",
                fontSize: 13,
                color: UIColor(white: 0.5, alpha: 1.0)
            )
            emptyLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 20)
            contentView.addSubview(emptyLabel)
            currentY += 30
        } else {
            for army in armies {
                let unitCount = army.getTotalUnits()
                let coord = army.coordinate
                let armyText = "\(army.name) — \(unitCount) units at (\(coord.q), \(coord.r))"

                let armyLabel = createLabel(
                    text: armyText,
                    fontSize: 13,
                    color: UIColor(white: 0.75, alpha: 1.0)
                )
                armyLabel.frame = CGRect(x: leftMargin + 10, y: currentY, width: contentWidth - 10, height: 20)
                contentView.addSubview(armyLabel)
                currentY += 24
            }
        }

        return currentY + 10
    }
}
