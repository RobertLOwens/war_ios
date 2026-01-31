// ============================================================================
// FILE: PanelTheme.swift
// LOCATION: Grow2 iOS/UI/PanelTheme.swift
// PURPOSE: Centralized theming for side panel view controllers.
//          Makes future UI/branding overhauls much easier.
// ============================================================================

import UIKit

/// Defines the visual theme for a side panel view controller.
/// Use factory methods to get pre-configured themes for each panel type.
struct PanelTheme {

    // MARK: - Header Colors

    /// Background color for the panel header
    let headerBackgroundColor: UIColor

    // MARK: - Text Colors

    /// Primary text color (titles, main labels)
    let primaryTextColor: UIColor

    /// Secondary text color (subtitles, descriptions)
    let secondaryTextColor: UIColor

    /// Tertiary text color (hints, less important info)
    let tertiaryTextColor: UIColor

    /// Warning text color (task cancellation warnings)
    let warningTextColor: UIColor

    /// Error text color (no path available, errors)
    let errorTextColor: UIColor

    // MARK: - Button Colors

    /// Confirm button background color when enabled
    let confirmButtonEnabledColor: UIColor

    /// Confirm button background color when disabled
    let confirmButtonDisabledColor: UIColor

    /// Cancel button text color
    let cancelButtonTextColor: UIColor

    // MARK: - Cell Colors

    /// Cell background color when selected
    let cellSelectedBackgroundColor: UIColor

    /// Cell background color when not selected
    let cellBackgroundColor: UIColor

    /// Table view separator color
    let separatorColor: UIColor

    // MARK: - Panel Colors

    /// Main panel background color
    let panelBackgroundColor: UIColor

    /// Preview section background color
    let previewSectionBackgroundColor: UIColor

    /// Dimmed background overlay color
    let dimmedBackgroundColor: UIColor

    // MARK: - Warning Badge Colors

    /// Warning badge text color
    let warningBadgeTextColor: UIColor

    /// Warning badge background color
    let warningBadgeBackgroundColor: UIColor

    // MARK: - Factory Methods

    /// Theme for attack panels (red/combat themed)
    static func attack() -> PanelTheme {
        PanelTheme(
            headerBackgroundColor: UIColor(red: 0.4, green: 0.15, blue: 0.15, alpha: 1.0),
            primaryTextColor: .white,
            secondaryTextColor: UIColor(white: 0.7, alpha: 1.0),
            tertiaryTextColor: UIColor(white: 0.5, alpha: 1.0),
            warningTextColor: UIColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 1.0),
            errorTextColor: UIColor(red: 1.0, green: 0.5, blue: 0.5, alpha: 1.0),
            confirmButtonEnabledColor: UIColor(red: 0.7, green: 0.2, blue: 0.2, alpha: 1.0),
            confirmButtonDisabledColor: UIColor(white: 0.3, alpha: 1.0),
            cancelButtonTextColor: UIColor(white: 0.7, alpha: 1.0),
            cellSelectedBackgroundColor: UIColor(white: 0.25, alpha: 1.0),
            cellBackgroundColor: .clear,
            separatorColor: UIColor(white: 0.3, alpha: 1.0),
            panelBackgroundColor: UIColor(white: 0.15, alpha: 0.98),
            previewSectionBackgroundColor: UIColor(white: 0.12, alpha: 1.0),
            dimmedBackgroundColor: UIColor.black.withAlphaComponent(0.4),
            warningBadgeTextColor: UIColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 1.0),
            warningBadgeBackgroundColor: UIColor(red: 0.4, green: 0.3, blue: 0.1, alpha: 1.0)
        )
    }

    /// Theme for build panels (brown/construction themed)
    static func build() -> PanelTheme {
        PanelTheme(
            headerBackgroundColor: UIColor(red: 0.3, green: 0.25, blue: 0.15, alpha: 1.0),
            primaryTextColor: .white,
            secondaryTextColor: UIColor(white: 0.7, alpha: 1.0),
            tertiaryTextColor: UIColor(white: 0.5, alpha: 1.0),
            warningTextColor: UIColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 1.0),
            errorTextColor: UIColor(red: 1.0, green: 0.5, blue: 0.5, alpha: 1.0),
            confirmButtonEnabledColor: UIColor(red: 0.5, green: 0.4, blue: 0.2, alpha: 1.0),
            confirmButtonDisabledColor: UIColor(white: 0.3, alpha: 1.0),
            cancelButtonTextColor: UIColor(white: 0.7, alpha: 1.0),
            cellSelectedBackgroundColor: UIColor(white: 0.25, alpha: 1.0),
            cellBackgroundColor: .clear,
            separatorColor: UIColor(white: 0.3, alpha: 1.0),
            panelBackgroundColor: UIColor(white: 0.15, alpha: 0.98),
            previewSectionBackgroundColor: UIColor(white: 0.12, alpha: 1.0),
            dimmedBackgroundColor: UIColor.black.withAlphaComponent(0.4),
            warningBadgeTextColor: UIColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 1.0),
            warningBadgeBackgroundColor: UIColor(red: 0.4, green: 0.3, blue: 0.1, alpha: 1.0)
        )
    }

    /// Theme for gather panels (green/resource themed)
    static func gather() -> PanelTheme {
        PanelTheme(
            headerBackgroundColor: UIColor(red: 0.15, green: 0.35, blue: 0.2, alpha: 1.0),
            primaryTextColor: .white,
            secondaryTextColor: UIColor(white: 0.7, alpha: 1.0),
            tertiaryTextColor: UIColor(white: 0.5, alpha: 1.0),
            warningTextColor: UIColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 1.0),
            errorTextColor: UIColor(red: 1.0, green: 0.5, blue: 0.5, alpha: 1.0),
            confirmButtonEnabledColor: UIColor(red: 0.2, green: 0.6, blue: 0.3, alpha: 1.0),
            confirmButtonDisabledColor: UIColor(white: 0.3, alpha: 1.0),
            cancelButtonTextColor: UIColor(white: 0.7, alpha: 1.0),
            cellSelectedBackgroundColor: UIColor(white: 0.25, alpha: 1.0),
            cellBackgroundColor: .clear,
            separatorColor: UIColor(white: 0.3, alpha: 1.0),
            panelBackgroundColor: UIColor(white: 0.15, alpha: 0.98),
            previewSectionBackgroundColor: UIColor(white: 0.12, alpha: 1.0),
            dimmedBackgroundColor: UIColor.black.withAlphaComponent(0.4),
            warningBadgeTextColor: UIColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 1.0),
            warningBadgeBackgroundColor: UIColor(red: 0.4, green: 0.3, blue: 0.1, alpha: 1.0)
        )
    }

    /// Theme for hunt panels (brown/orange hunting themed)
    static func hunt() -> PanelTheme {
        PanelTheme(
            headerBackgroundColor: UIColor(red: 0.4, green: 0.25, blue: 0.15, alpha: 1.0),
            primaryTextColor: .white,
            secondaryTextColor: UIColor(white: 0.7, alpha: 1.0),
            tertiaryTextColor: UIColor(white: 0.5, alpha: 1.0),
            warningTextColor: UIColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 1.0),
            errorTextColor: UIColor(red: 1.0, green: 0.5, blue: 0.5, alpha: 1.0),
            confirmButtonEnabledColor: UIColor(red: 0.6, green: 0.35, blue: 0.2, alpha: 1.0),
            confirmButtonDisabledColor: UIColor(white: 0.3, alpha: 1.0),
            cancelButtonTextColor: UIColor(white: 0.7, alpha: 1.0),
            cellSelectedBackgroundColor: UIColor(white: 0.25, alpha: 1.0),
            cellBackgroundColor: .clear,
            separatorColor: UIColor(white: 0.3, alpha: 1.0),
            panelBackgroundColor: UIColor(white: 0.15, alpha: 0.98),
            previewSectionBackgroundColor: UIColor(white: 0.12, alpha: 1.0),
            dimmedBackgroundColor: UIColor.black.withAlphaComponent(0.4),
            warningBadgeTextColor: UIColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 1.0),
            warningBadgeBackgroundColor: UIColor(red: 0.4, green: 0.3, blue: 0.1, alpha: 1.0)
        )
    }

    /// Theme for move panels (neutral/gray themed)
    static func move() -> PanelTheme {
        PanelTheme(
            headerBackgroundColor: UIColor(white: 0.1, alpha: 1.0),
            primaryTextColor: .white,
            secondaryTextColor: UIColor(white: 0.6, alpha: 1.0),
            tertiaryTextColor: UIColor(white: 0.5, alpha: 1.0),
            warningTextColor: UIColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 1.0),
            errorTextColor: UIColor(red: 1.0, green: 0.5, blue: 0.5, alpha: 1.0),
            confirmButtonEnabledColor: UIColor(red: 0.2, green: 0.6, blue: 0.3, alpha: 1.0),
            confirmButtonDisabledColor: UIColor(white: 0.3, alpha: 1.0),
            cancelButtonTextColor: UIColor(white: 0.7, alpha: 1.0),
            cellSelectedBackgroundColor: UIColor(white: 0.25, alpha: 1.0),
            cellBackgroundColor: .clear,
            separatorColor: UIColor(white: 0.3, alpha: 1.0),
            panelBackgroundColor: UIColor(white: 0.15, alpha: 0.98),
            previewSectionBackgroundColor: UIColor(white: 0.12, alpha: 1.0),
            dimmedBackgroundColor: UIColor.black.withAlphaComponent(0.4),
            warningBadgeTextColor: UIColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 1.0),
            warningBadgeBackgroundColor: UIColor(red: 0.4, green: 0.3, blue: 0.1, alpha: 1.0)
        )
    }

    /// Theme for reinforce panels (blue/military themed)
    static func reinforce() -> PanelTheme {
        PanelTheme(
            headerBackgroundColor: UIColor(red: 0.2, green: 0.5, blue: 0.6, alpha: 1.0),
            primaryTextColor: .white,
            secondaryTextColor: UIColor(white: 0.8, alpha: 1.0),
            tertiaryTextColor: UIColor(white: 0.6, alpha: 1.0),
            warningTextColor: UIColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 1.0),
            errorTextColor: UIColor(red: 1.0, green: 0.5, blue: 0.5, alpha: 1.0),
            confirmButtonEnabledColor: UIColor(red: 0.2, green: 0.5, blue: 0.6, alpha: 1.0),
            confirmButtonDisabledColor: UIColor(white: 0.3, alpha: 1.0),
            cancelButtonTextColor: UIColor(white: 0.7, alpha: 1.0),
            cellSelectedBackgroundColor: UIColor(white: 0.25, alpha: 1.0),
            cellBackgroundColor: .clear,
            separatorColor: UIColor(white: 0.3, alpha: 1.0),
            panelBackgroundColor: UIColor(white: 0.15, alpha: 0.98),
            previewSectionBackgroundColor: UIColor(white: 0.12, alpha: 1.0),
            dimmedBackgroundColor: UIColor.black.withAlphaComponent(0.4),
            warningBadgeTextColor: UIColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 1.0),
            warningBadgeBackgroundColor: UIColor(red: 0.4, green: 0.3, blue: 0.1, alpha: 1.0)
        )
    }

    /// Theme for villager deployment panels (brown/worker themed)
    static func villagerDeploy() -> PanelTheme {
        PanelTheme(
            headerBackgroundColor: UIColor(red: 0.4, green: 0.3, blue: 0.2, alpha: 1.0),
            primaryTextColor: .white,
            secondaryTextColor: UIColor(white: 0.8, alpha: 1.0),
            tertiaryTextColor: UIColor(white: 0.6, alpha: 1.0),
            warningTextColor: UIColor(red: 1.0, green: 0.6, blue: 0.4, alpha: 1.0),
            errorTextColor: UIColor(red: 1.0, green: 0.5, blue: 0.5, alpha: 1.0),
            confirmButtonEnabledColor: UIColor(red: 0.3, green: 0.6, blue: 0.3, alpha: 1.0),
            confirmButtonDisabledColor: UIColor(white: 0.3, alpha: 1.0),
            cancelButtonTextColor: UIColor(white: 0.7, alpha: 1.0),
            cellSelectedBackgroundColor: UIColor(white: 0.25, alpha: 1.0),
            cellBackgroundColor: .clear,
            separatorColor: UIColor(white: 0.3, alpha: 1.0),
            panelBackgroundColor: UIColor(white: 0.15, alpha: 0.98),
            previewSectionBackgroundColor: UIColor(white: 0.12, alpha: 1.0),
            dimmedBackgroundColor: UIColor.black.withAlphaComponent(0.4),
            warningBadgeTextColor: UIColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 1.0),
            warningBadgeBackgroundColor: UIColor(red: 0.4, green: 0.3, blue: 0.2, alpha: 1.0)
        )
    }
}
