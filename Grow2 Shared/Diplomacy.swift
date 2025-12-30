import Foundation
import UIKit

enum DiplomacyStatus: String {
    case me = "Me"
    case guild = "Guild"
    case ally = "Ally"
    case enemy = "Enemy"
    case neutral = "Neutral"
    
    var displayName: String {
        return rawValue
    }
    
    var strokeColor: UIColor {
        switch self {
        case .me: return .blue
        case .guild: return .purple
        case .ally: return .green
        case .enemy: return .red
        case .neutral: return .orange
        }
    }
    
    var canMove: Bool {
        // Can only move onto tiles owned by me, guild, or allies
        switch self {
        case .me, .guild, .ally: return true
        case .enemy, .neutral: return false
        }
    }
    
    var canAttack: Bool {
        return self == .enemy
    }
}
