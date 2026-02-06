// ============================================================================
// FILE: Grow2 Shared/Diplomacy.swift
// PURPOSE: Visual layer extensions for diplomacy
// NOTE: DiplomacyStatus is now defined in Data/PlayerState.swift and accessed via TypeAliases.swift
// ============================================================================

import Foundation
import UIKit

// MARK: - DiplomacyStatus Visual Extensions

extension DiplomacyStatusData {
    /// UIColor computed from strokeColorHex (visual layer)
    var strokeColor: UIColor {
        return UIColor(hex: strokeColorHex) ?? .gray
    }
}
