// ============================================================================
// FILE: EntitySelectionCell.swift
// LOCATION: Grow2 iOS/Views/EntitySelectionCell.swift
// PURPOSE: Reusable table view cell for entity selection in side panels.
//          Replaces EntityCell, ArmyAttackCell, VillagerGatherCell,
//          VillagerBuildCell, BuildingGarrisonCell, and VillagerGroupCell.
// ============================================================================

import UIKit

/// Configuration for EntitySelectionCell content
struct EntityCellConfiguration {
    /// Icon to display (emoji or text)
    let icon: String

    /// Primary name/title
    let name: String

    /// Subtitle line (e.g., "5 villagers", "10 units")
    let subtitle: String

    /// Detail line (e.g., "Task: Idle", commander name)
    let detail: String

    /// Whether to show the warning badge
    let showWarningBadge: Bool

    /// Optional custom icon background color
    let iconBackgroundColor: UIColor?

    /// Whether the detail text indicates a warning state
    let isDetailWarning: Bool

    // MARK: - Factory Methods

    /// Creates a configuration for an army entity
    static func army(
        _ army: Army,
        targetCoordinate: HexCoordinate
    ) -> EntityCellConfiguration {
        let totalUnits = army.getTotalMilitaryUnits()
        let distance = army.coordinate.distance(to: targetCoordinate)

        let commanderText: String
        if let commander = army.commander {
            commanderText = commander.name
        } else {
            commanderText = "No Commander"
        }

        return EntityCellConfiguration(
            icon: "\u{1F6E1}\u{FE0F}", // shield emoji
            name: army.name,
            subtitle: "\(totalUnits) units \u{2022} \(distance) tiles away",
            detail: commanderText,
            showWarningBadge: false,
            iconBackgroundColor: nil,
            isDetailWarning: army.commander == nil
        )
    }

    /// Creates a configuration for a villager group entity
    static func villagerGroup(
        _ villagers: VillagerGroup,
        targetCoordinate: HexCoordinate
    ) -> EntityCellConfiguration {
        let distance = villagers.coordinate.distance(to: targetCoordinate)
        let isBusy = villagers.currentTask != .idle

        return EntityCellConfiguration(
            icon: "\u{1F477}", // construction worker emoji
            name: villagers.name,
            subtitle: "\(villagers.villagerCount) villagers \u{2022} \(distance) tiles away",
            detail: "Task: \(villagers.currentTask.displayName)",
            showWarningBadge: isBusy,
            iconBackgroundColor: nil,
            isDetailWarning: isBusy
        )
    }

    /// Creates a configuration for a villager group from an EntityNode
    static func villagerGroupFromEntity(
        _ entity: EntityNode,
        targetCoordinate: HexCoordinate
    ) -> EntityCellConfiguration? {
        guard let villagers = entity.entity as? VillagerGroup else { return nil }
        return villagerGroup(villagers, targetCoordinate: targetCoordinate)
    }

    /// Creates a configuration for a generic entity (army or villager group)
    static func entity(
        _ entity: EntityNode,
        targetCoordinate: HexCoordinate
    ) -> EntityCellConfiguration {
        if entity.entityType == .army, let army = entity.entity as? Army {
            let totalUnits = army.getTotalMilitaryUnits()
            let distance = entity.coordinate.distance(to: targetCoordinate)
            let isBusy = false // Armies don't have task status in this context

            return EntityCellConfiguration(
                icon: "\u{1F6E1}\u{FE0F}",
                name: army.name,
                subtitle: "\(totalUnits) units \u{2022} \(distance) tiles away",
                detail: "Task: Idle",
                showWarningBadge: false,
                iconBackgroundColor: nil,
                isDetailWarning: false
            )

        } else if entity.entityType == .villagerGroup, let villagers = entity.entity as? VillagerGroup {
            return villagerGroup(villagers, targetCoordinate: targetCoordinate)
        }

        // Fallback for unknown entity types
        return EntityCellConfiguration(
            icon: "?",
            name: "Unknown Entity",
            subtitle: "",
            detail: "",
            showWarningBadge: false,
            iconBackgroundColor: nil,
            isDetailWarning: false
        )
    }

    /// Creates a configuration for a building with garrison info
    static func building(
        _ building: BuildingNode,
        targetCoordinate: HexCoordinate
    ) -> EntityCellConfiguration {
        let totalGarrison = building.getTotalGarrisonedUnits()
        let distance = building.coordinate.distance(to: targetCoordinate)

        return EntityCellConfiguration(
            icon: building.buildingType.icon,
            name: building.buildingType.displayName,
            subtitle: "\(totalGarrison) units in garrison",
            detail: "\(distance) tiles away",
            showWarningBadge: false,
            iconBackgroundColor: nil,
            isDetailWarning: false
        )
    }

    /// Creates a configuration for a villager group in the deployment panel
    static func villagerGroupForJoin(
        _ group: VillagerGroup,
        targetCoordinate: HexCoordinate
    ) -> EntityCellConfiguration {
        let distance = group.coordinate.distance(to: targetCoordinate)
        let taskDesc = group.currentTask == .idle ? "Idle" : group.currentTask.displayName

        return EntityCellConfiguration(
            icon: "V",
            name: group.name,
            subtitle: "\(group.villagerCount) villagers - \(taskDesc)",
            detail: "\(distance) tiles away",
            showWarningBadge: false,
            iconBackgroundColor: UIColor(red: 0.4, green: 0.3, blue: 0.2, alpha: 1.0),
            isDetailWarning: false
        )
    }
}

/// Reusable cell for displaying entities in side panel selection lists.
class EntitySelectionCell: UITableViewCell {

    // MARK: - UI Elements

    private let iconLabel = UILabel()
    private let nameLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let detailLabel = UILabel()
    private let warningBadge = UILabel()

    // MARK: - Theme

    private var theme: PanelTheme = .move()

    // MARK: - Initialization

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupCell() {
        backgroundColor = .clear
        selectionStyle = .none

        // Icon
        iconLabel.frame = CGRect(
            x: PanelLayoutConstants.cellIconLeading,
            y: PanelLayoutConstants.cellIconTop,
            width: PanelLayoutConstants.cellIconSize,
            height: PanelLayoutConstants.cellIconSize
        )
        iconLabel.font = UIFont.systemFont(ofSize: 28)
        iconLabel.textAlignment = .center
        contentView.addSubview(iconLabel)

        // Name
        nameLabel.frame = CGRect(
            x: PanelLayoutConstants.cellTextLeading,
            y: PanelLayoutConstants.cellNameTop,
            width: PanelLayoutConstants.cellTextWidth,
            height: PanelLayoutConstants.cellNameHeight
        )
        nameLabel.font = UIFont.boldSystemFont(ofSize: 16)
        nameLabel.textColor = .white
        contentView.addSubview(nameLabel)

        // Subtitle
        subtitleLabel.frame = CGRect(
            x: PanelLayoutConstants.cellTextLeading,
            y: PanelLayoutConstants.cellSubtitleTop,
            width: PanelLayoutConstants.cellTextWidth,
            height: PanelLayoutConstants.cellSubtitleHeight
        )
        subtitleLabel.font = UIFont.systemFont(ofSize: 14)
        subtitleLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        contentView.addSubview(subtitleLabel)

        // Detail
        detailLabel.frame = CGRect(
            x: PanelLayoutConstants.cellTextLeading,
            y: PanelLayoutConstants.cellDetailTop,
            width: PanelLayoutConstants.cellTextWidth,
            height: PanelLayoutConstants.cellDetailHeight
        )
        detailLabel.font = UIFont.systemFont(ofSize: 13)
        detailLabel.textColor = UIColor(white: 0.5, alpha: 1.0)
        contentView.addSubview(detailLabel)

        // Warning badge
        warningBadge.frame = CGRect(
            x: PanelLayoutConstants.warningBadgeLeading,
            y: PanelLayoutConstants.warningBadgeTop,
            width: PanelLayoutConstants.warningBadgeSize,
            height: PanelLayoutConstants.warningBadgeSize
        )
        warningBadge.text = "!"
        warningBadge.font = UIFont.boldSystemFont(ofSize: 16)
        warningBadge.textColor = UIColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 1.0)
        warningBadge.textAlignment = .center
        warningBadge.backgroundColor = UIColor(red: 0.4, green: 0.3, blue: 0.1, alpha: 1.0)
        warningBadge.layer.cornerRadius = PanelLayoutConstants.warningBadgeSize / 2
        warningBadge.clipsToBounds = true
        warningBadge.isHidden = true
        contentView.addSubview(warningBadge)
    }

    // MARK: - Configuration

    /// Configures the cell with the given configuration and optional theme
    func configure(with config: EntityCellConfiguration, theme: PanelTheme? = nil) {
        if let theme = theme {
            self.theme = theme
            applyTheme()
        }

        iconLabel.text = config.icon
        nameLabel.text = config.name
        subtitleLabel.text = config.subtitle
        detailLabel.text = config.detail
        warningBadge.isHidden = !config.showWarningBadge

        // Apply icon background if specified
        if let iconBgColor = config.iconBackgroundColor {
            iconLabel.backgroundColor = iconBgColor
            iconLabel.layer.cornerRadius = PanelLayoutConstants.cellIconSize / 2
            iconLabel.clipsToBounds = true
            iconLabel.textColor = .white
            iconLabel.font = UIFont.systemFont(ofSize: 24)
        } else {
            iconLabel.backgroundColor = .clear
            iconLabel.layer.cornerRadius = 0
            iconLabel.textColor = nil // Use default emoji color
            iconLabel.font = UIFont.systemFont(ofSize: 28)
        }

        // Apply warning color to detail if needed
        if config.isDetailWarning {
            detailLabel.textColor = self.theme.warningTextColor
        } else {
            detailLabel.textColor = self.theme.tertiaryTextColor
        }
    }

    /// Applies the current theme to the cell
    private func applyTheme() {
        nameLabel.textColor = theme.primaryTextColor
        subtitleLabel.textColor = theme.secondaryTextColor
        detailLabel.textColor = theme.tertiaryTextColor
        warningBadge.textColor = theme.warningBadgeTextColor
        warningBadge.backgroundColor = theme.warningBadgeBackgroundColor
    }

    /// Sets the selected state of the cell
    func setSelectedState(_ selected: Bool) {
        backgroundColor = selected ? theme.cellSelectedBackgroundColor : theme.cellBackgroundColor
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        iconLabel.text = nil
        nameLabel.text = nil
        subtitleLabel.text = nil
        detailLabel.text = nil
        warningBadge.isHidden = true
        backgroundColor = .clear
        iconLabel.backgroundColor = .clear
        iconLabel.layer.cornerRadius = 0
    }
}

// MARK: - Static Cell Identifier

extension EntitySelectionCell {
    static let reuseIdentifier = "EntitySelectionCell"
}
