// ============================================================================
// FILE: GameOverReason.swift
// PURPOSE: Enum defining reasons for game over
// ============================================================================

import Foundation

enum GameOverReason {
    case starvation           // 0 food for 60 seconds
    case resignation          // Player resigned
    case conquest             // Destroyed enemy (victory)
    case cityCenterDestroyed  // Lost city center (defeat)

    var displayMessage: String {
        switch self {
        case .starvation:
            return "Your people starved to death.\nYou had no food for too long."
        case .resignation:
            return "You have resigned from the game."
        case .conquest:
            return "You have conquered your enemies!\nAll opposing forces have been eliminated."
        case .cityCenterDestroyed:
            return "Your city center has been destroyed.\nYour civilization has fallen."
        }
    }
}
