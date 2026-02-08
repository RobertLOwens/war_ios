// ============================================================================
// FILE: NotificationSettings.swift
// LOCATION: Grow2 Shared/NotificationSettings.swift
// PURPOSE: Settings manager for notification preferences
// ============================================================================

import Foundation

/// Manages user preferences for notification categories
/// Persists settings to UserDefaults
struct NotificationSettings {

    // MARK: - UserDefaults Keys (In-Game Notifications)

    private static let combatAlertsKey = "notification_combat_alerts"
    private static let enemySightingsKey = "notification_enemy_sightings"
    private static let buildingUpdatesKey = "notification_building_updates"
    private static let trainingUpdatesKey = "notification_training_updates"
    private static let researchUpdatesKey = "notification_research_updates"
    private static let resourceAlertsKey = "notification_resource_alerts"

    // MARK: - UserDefaults Keys (Push Notifications)

    private static let pushNotificationsEnabledKey = "push_notifications_enabled"
    private static let pushCombatAlertsKey = "push_combat_alerts"
    private static let pushEnemySightingsKey = "push_enemy_sightings"
    private static let pushBuildingUpdatesKey = "push_building_updates"
    private static let pushTrainingUpdatesKey = "push_training_updates"
    private static let pushResearchUpdatesKey = "push_research_updates"
    private static let pushResourceAlertsKey = "push_resource_alerts"

    // MARK: - In-Game Notification Categories

    /// Combat Alerts: armyAttacked, villagerAttacked
    static var combatAlertsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: combatAlertsKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: combatAlertsKey) }
    }

    /// Enemy Sightings: armySighted
    static var enemySightingsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: enemySightingsKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: enemySightingsKey) }
    }

    /// Building Updates: buildingCompleted, upgradeCompleted
    static var buildingUpdatesEnabled: Bool {
        get { UserDefaults.standard.object(forKey: buildingUpdatesKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: buildingUpdatesKey) }
    }

    /// Training Updates: trainingCompleted
    static var trainingUpdatesEnabled: Bool {
        get { UserDefaults.standard.object(forKey: trainingUpdatesKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: trainingUpdatesKey) }
    }

    /// Research Updates: researchCompleted
    static var researchUpdatesEnabled: Bool {
        get { UserDefaults.standard.object(forKey: researchUpdatesKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: researchUpdatesKey) }
    }

    /// Resource Alerts: gatheringCompleted, resourcesMaxed, resourcePointDepleted
    static var resourceAlertsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: resourceAlertsKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: resourceAlertsKey) }
    }

    // MARK: - Push Notification Categories

    /// Master toggle for all push notifications
    static var pushNotificationsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: pushNotificationsEnabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: pushNotificationsEnabledKey) }
    }

    /// Push: Combat Alerts
    static var pushCombatAlertsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: pushCombatAlertsKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: pushCombatAlertsKey) }
    }

    /// Push: Enemy Sightings
    static var pushEnemySightingsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: pushEnemySightingsKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: pushEnemySightingsKey) }
    }

    /// Push: Building Updates
    static var pushBuildingUpdatesEnabled: Bool {
        get { UserDefaults.standard.object(forKey: pushBuildingUpdatesKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: pushBuildingUpdatesKey) }
    }

    /// Push: Training Updates
    static var pushTrainingUpdatesEnabled: Bool {
        get { UserDefaults.standard.object(forKey: pushTrainingUpdatesKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: pushTrainingUpdatesKey) }
    }

    /// Push: Research Updates
    static var pushResearchUpdatesEnabled: Bool {
        get { UserDefaults.standard.object(forKey: pushResearchUpdatesKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: pushResearchUpdatesKey) }
    }

    /// Push: Resource Alerts
    static var pushResourceAlertsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: pushResourceAlertsKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: pushResourceAlertsKey) }
    }

    // MARK: - Category Checks

    /// Check if an in-game notification type is enabled based on its category
    static func isEnabled(for type: GameNotificationType) -> Bool {
        switch type {
        case .armyAttacked, .villagerAttacked:
            return combatAlertsEnabled
        case .armySighted:
            return enemySightingsEnabled
        case .buildingCompleted, .upgradeCompleted:
            return buildingUpdatesEnabled
        case .trainingCompleted:
            return trainingUpdatesEnabled
        case .researchCompleted:
            return researchUpdatesEnabled
        case .gatheringCompleted, .resourcesMaxed, .resourcePointDepleted:
            return resourceAlertsEnabled
        case .entrenchmentCompleted:
            return buildingUpdatesEnabled
        }
    }

    /// Check if a push notification type is enabled (master + category)
    static func isPushEnabled(for type: GameNotificationType) -> Bool {
        guard pushNotificationsEnabled else { return false }

        switch type {
        case .armyAttacked, .villagerAttacked:
            return pushCombatAlertsEnabled
        case .armySighted:
            return pushEnemySightingsEnabled
        case .buildingCompleted, .upgradeCompleted:
            return pushBuildingUpdatesEnabled
        case .trainingCompleted:
            return pushTrainingUpdatesEnabled
        case .researchCompleted:
            return pushResearchUpdatesEnabled
        case .gatheringCompleted, .resourcesMaxed, .resourcePointDepleted:
            return pushResourceAlertsEnabled
        case .entrenchmentCompleted:
            return pushBuildingUpdatesEnabled
        }
    }

    /// Set all push notification categories at once
    static func setAllPushCategories(enabled: Bool) {
        pushCombatAlertsEnabled = enabled
        pushEnemySightingsEnabled = enabled
        pushBuildingUpdatesEnabled = enabled
        pushTrainingUpdatesEnabled = enabled
        pushResearchUpdatesEnabled = enabled
        pushResourceAlertsEnabled = enabled
    }
}
