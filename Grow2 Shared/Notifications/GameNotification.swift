// ============================================================================
// FILE: GameNotification.swift
// LOCATION: Grow2 Shared/Notifications/GameNotification.swift
// PURPOSE: Data models for game notifications (toast banners)
// ============================================================================

import Foundation

// MARK: - Game Notification Type

/// Types of notifications that can be displayed to the player
enum GameNotificationType {
    case gatheringCompleted(resourceType: ResourceTypeData, amount: Int, coordinate: HexCoordinate)
    case buildingCompleted(buildingType: BuildingType, coordinate: HexCoordinate)
    case upgradeCompleted(buildingType: BuildingType, newLevel: Int, coordinate: HexCoordinate)
    case armyAttacked(armyName: String, coordinate: HexCoordinate)
    case armySighted(coordinate: HexCoordinate)
    case villagerAttacked(coordinate: HexCoordinate)
    case resourcesMaxed(resourceType: ResourceTypeData)
    case researchCompleted(researchName: String)
    case resourcePointDepleted(resourceType: String, coordinate: HexCoordinate)
    case trainingCompleted(unitType: String, quantity: Int, coordinate: HexCoordinate)

    /// Icon to display for this notification type
    var icon: String {
        switch self {
        case .gatheringCompleted(let resourceType, _, _):
            return resourceType.icon
        case .buildingCompleted:
            return "🏗️"
        case .upgradeCompleted:
            return "⬆️"
        case .armyAttacked:
            return "⚔️"
        case .armySighted:
            return "👁️"
        case .villagerAttacked:
            return "🚨"
        case .resourcesMaxed(let resourceType):
            return resourceType.icon
        case .researchCompleted:
            return "🔬"
        case .resourcePointDepleted:
            return "⚠️"
        case .trainingCompleted:
            return "🎖️"
        }
    }

    /// Generate the display message for this notification
    var message: String {
        switch self {
        case .gatheringCompleted(let resourceType, let amount, _):
            return "Gathered \(amount) \(resourceType.displayName)"
        case .buildingCompleted(let buildingType, _):
            return "\(buildingType.displayName) completed"
        case .upgradeCompleted(let buildingType, let newLevel, _):
            return "\(buildingType.displayName) upgraded to level \(newLevel)"
        case .armyAttacked(let armyName, _):
            return "\(armyName) is under attack!"
        case .armySighted:
            return "Enemy army spotted!"
        case .villagerAttacked:
            return "Villagers are under attack!"
        case .resourcesMaxed(let resourceType):
            return "\(resourceType.displayName) storage is full!"
        case .researchCompleted(let researchName):
            return "\(researchName) research completed"
        case .resourcePointDepleted(let resourceType, _):
            return "\(resourceType) deposit depleted"
        case .trainingCompleted(let unitType, let quantity, _):
            return "Training complete: \(quantity)x \(unitType)"
        }
    }

    /// The coordinate to jump to when tapped (if applicable)
    var coordinate: HexCoordinate? {
        switch self {
        case .gatheringCompleted(_, _, let coord):
            return coord
        case .buildingCompleted(_, let coord):
            return coord
        case .upgradeCompleted(_, _, let coord):
            return coord
        case .armyAttacked(_, let coord):
            return coord
        case .armySighted(let coord):
            return coord
        case .villagerAttacked(let coord):
            return coord
        case .resourcesMaxed:
            return nil
        case .researchCompleted:
            return nil
        case .resourcePointDepleted(_, let coord):
            return coord
        case .trainingCompleted(_, _, let coord):
            return coord
        }
    }

    /// Unique key for deduplication purposes
    var deduplicationKey: String {
        switch self {
        case .gatheringCompleted(let resourceType, _, _):
            return "gathering_\(resourceType.rawValue)"
        case .buildingCompleted(let buildingType, _):
            return "building_\(buildingType.rawValue)"
        case .upgradeCompleted(let buildingType, _, _):
            return "upgrade_\(buildingType.rawValue)"
        case .armyAttacked(_, let coord):
            return "armyAttacked_\(coord.q)_\(coord.r)"
        case .armySighted(let coord):
            return "armySighted_\(coord.q)_\(coord.r)"
        case .villagerAttacked(let coord):
            return "villagerAttacked_\(coord.q)_\(coord.r)"
        case .resourcesMaxed(let resourceType):
            return "resourcesMaxed_\(resourceType.rawValue)"
        case .researchCompleted(let name):
            return "research_\(name)"
        case .resourcePointDepleted(let resourceType, let coord):
            return "depleted_\(resourceType)_\(coord.q)_\(coord.r)"
        case .trainingCompleted(let unitType, _, _):
            return "training_\(unitType)"
        }
    }

    /// Priority level for sorting notifications (higher = more important)
    var priority: Int {
        switch self {
        case .armyAttacked:
            return 100
        case .villagerAttacked:
            return 90
        case .armySighted:
            return 80
        case .resourcesMaxed:
            return 70
        case .researchCompleted:
            return 60
        case .buildingCompleted:
            return 50
        case .upgradeCompleted:
            return 50
        case .trainingCompleted:
            return 40
        case .resourcePointDepleted:
            return 30
        case .gatheringCompleted:
            return 20
        }
    }
}

// MARK: - Game Notification

/// Represents a single notification to be displayed to the player
struct GameNotification {
    let id: UUID
    let type: GameNotificationType
    let timestamp: Date
    let playerID: UUID

    init(type: GameNotificationType, playerID: UUID) {
        self.id = UUID()
        self.type = type
        self.timestamp = Date()
        self.playerID = playerID
    }

    var icon: String { type.icon }
    var message: String { type.message }
    var coordinate: HexCoordinate? { type.coordinate }
    var priority: Int { type.priority }
    var deduplicationKey: String { type.deduplicationKey }
}

// MARK: - Notification.Name Extension

extension Notification.Name {
    /// Posted when a new game notification should be displayed
    static let gameNotificationReceived = Notification.Name("GameNotificationReceived")

    /// Posted when the camera should jump to a coordinate
    static let jumpToCoordinate = Notification.Name("JumpToCoordinate")
}
