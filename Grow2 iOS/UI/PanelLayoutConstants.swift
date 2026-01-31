// ============================================================================
// FILE: PanelLayoutConstants.swift
// LOCATION: Grow2 iOS/UI/PanelLayoutConstants.swift
// PURPOSE: Centralized layout constants for side panel view controllers.
//          All magic numbers in one place for easy maintenance.
// ============================================================================

import UIKit

/// Layout constants shared across all side panel view controllers.
struct PanelLayoutConstants {

    // MARK: - Panel Dimensions

    /// Width of the side panel
    static let panelWidth: CGFloat = 300

    /// Corner radius of the panel
    static let panelCornerRadius: CGFloat = 16

    // MARK: - Header Dimensions

    /// Height of the panel header
    static let headerHeight: CGFloat = 80

    /// Title label top offset from header top
    static let headerTitleTopOffset: CGFloat = 20

    /// Subtitle label top offset from header top
    static let headerSubtitleTopOffset: CGFloat = 46

    /// Close button size
    static let closeButtonSize: CGFloat = 40

    /// Close button trailing margin from panel edge
    static let closeButtonTrailingMargin: CGFloat = 50

    // MARK: - Table View Dimensions

    /// Default cell height
    static let cellHeight: CGFloat = 80

    /// Compact cell height (for villager group cells)
    static let compactCellHeight: CGFloat = 70

    /// Bottom padding from table to preview section
    static let tableBottomPadding: CGFloat = 200

    // MARK: - Preview Section Dimensions

    /// Height of the preview section
    static let previewSectionHeight: CGFloat = 80

    /// Distance from bottom of panel to preview section
    static let previewSectionBottomOffset: CGFloat = 200

    // MARK: - Button Dimensions

    /// Height of the confirm button
    static let confirmButtonHeight: CGFloat = 50

    /// Height of the cancel button
    static let cancelButtonHeight: CGFloat = 44

    /// Button corner radius
    static let buttonCornerRadius: CGFloat = 12

    /// Distance from bottom of panel to confirm button
    static let confirmButtonBottomOffset: CGFloat = 120

    /// Spacing between confirm and cancel buttons
    static let buttonSpacing: CGFloat = 55

    // MARK: - Padding & Margins

    /// Standard horizontal padding
    static let horizontalPadding: CGFloat = 16

    /// Standard vertical spacing between elements
    static let verticalSpacing: CGFloat = 12

    /// Label height for single line text
    static let singleLineHeight: CGFloat = 24

    /// Label height for subtitle text
    static let subtitleHeight: CGFloat = 20

    /// Label height for multi-line text (2 lines)
    static let multiLineHeight: CGFloat = 36

    // MARK: - Cell Layout

    /// Icon size in cells
    static let cellIconSize: CGFloat = 40

    /// Icon leading margin
    static let cellIconLeading: CGFloat = 16

    /// Icon top margin
    static let cellIconTop: CGFloat = 15

    /// Text content leading (after icon)
    static let cellTextLeading: CGFloat = 65

    /// Text content width
    static let cellTextWidth: CGFloat = 180

    /// Name label top offset in cell
    static let cellNameTop: CGFloat = 12

    /// Name label height
    static let cellNameHeight: CGFloat = 22

    /// Subtitle label top offset in cell
    static let cellSubtitleTop: CGFloat = 34

    /// Subtitle label height
    static let cellSubtitleHeight: CGFloat = 18

    /// Detail label top offset in cell
    static let cellDetailTop: CGFloat = 52

    /// Detail label height
    static let cellDetailHeight: CGFloat = 18

    /// Warning badge size
    static let warningBadgeSize: CGFloat = 24

    /// Warning badge leading position
    static let warningBadgeLeading: CGFloat = 260

    /// Warning badge top offset in cell
    static let warningBadgeTop: CGFloat = 28

    // MARK: - Animation Durations

    /// Duration for panel slide-in animation
    static let animateInDuration: TimeInterval = 0.3

    /// Duration for panel slide-out animation
    static let animateOutDuration: TimeInterval = 0.25

    // MARK: - Info Section Dimensions

    /// Height of a standard info section (target info, resource info, etc.)
    static let infoSectionHeight: CGFloat = 60

    /// Height of a tall info section (building info with cost and time)
    static let tallInfoSectionHeight: CGFloat = 90

    /// Height of a resource info section
    static let resourceInfoSectionHeight: CGFloat = 70

    // MARK: - Computed Properties

    /// Width available for content (panel width minus horizontal padding on both sides)
    static var contentWidth: CGFloat {
        return panelWidth - (horizontalPadding * 2)
    }

    /// Width available for labels in header (accounting for close button)
    static var headerLabelWidth: CGFloat {
        return panelWidth - closeButtonTrailingMargin - horizontalPadding
    }
}
