// ============================================================================
// FILE: VillagerTaskWarningHelper.swift
// LOCATION: Grow2 iOS/Helpers/VillagerTaskWarningHelper.swift
// PURPOSE: Shared warning logic for villager task cancellation dialogs.
//          Used by multiple panel view controllers.
// ============================================================================

import UIKit

/// Helper for generating warning messages and showing confirmation dialogs
/// when villagers need to cancel their current task.
struct VillagerTaskWarningHelper {

    // MARK: - Warning Message Generation

    /// Generates a warning message for the given villager task.
    /// Returns empty string if the task is idle.
    /// - Parameter task: The villager's current task
    /// - Returns: A user-friendly warning message
    static func warningMessage(for task: VillagerTask) -> String {
        switch task {
        case .building(let building):
            return "Will cancel: Building \(building.buildingType.displayName)"
        case .gatheringResource(let resourcePoint):
            return "Will cancel: Gathering \(resourcePoint.resourceType.displayName)"
        case .gathering(let resource):
            return "Will cancel: Gathering \(resource.displayName)"
        case .hunting(let resourcePoint):
            return "Will cancel: Hunting \(resourcePoint.resourceType.displayName)"
        case .repairing(let building):
            return "Will cancel: Repairing \(building.buildingType.displayName)"
        case .upgrading(let building):
            return "Will cancel: Upgrading \(building.buildingType.displayName)"
        case .demolishing(let building):
            return "Will cancel: Demolishing \(building.buildingType.displayName)"
        case .moving:
            return "Will cancel: Current movement"
        case .idle:
            return ""
        }
    }

    /// Generates a shorter warning message prefixed with "Moving will cancel:"
    /// Used specifically for move panels.
    /// - Parameter task: The villager's current task
    /// - Returns: A user-friendly warning message for move operations
    static func moveWarningMessage(for task: VillagerTask) -> String {
        switch task {
        case .building(let building):
            return "Moving will cancel: Building \(building.buildingType.displayName)"
        case .gatheringResource(let resourcePoint):
            return "Moving will cancel: Gathering \(resourcePoint.resourceType.displayName)"
        case .gathering(let resource):
            return "Moving will cancel: Gathering \(resource.displayName)"
        case .hunting(let resourcePoint):
            return "Moving will cancel: Hunting \(resourcePoint.resourceType.displayName)"
        case .repairing(let building):
            return "Moving will cancel: Repairing \(building.buildingType.displayName)"
        case .upgrading(let building):
            return "Moving will cancel: Upgrading \(building.buildingType.displayName)"
        case .demolishing(let building):
            return "Moving will cancel: Demolishing \(building.buildingType.displayName)"
        case .moving:
            return "Moving will cancel: Current movement"
        case .idle:
            return ""
        }
    }

    // MARK: - Confirmation Dialogs

    /// Shows a confirmation dialog when a busy villager needs to cancel their task.
    /// - Parameters:
    ///   - villagers: The villager group with an active task
    ///   - actionName: The name of the new action (e.g., "move", "build", "gather")
    ///   - actionButtonTitle: The title for the confirm button (e.g., "Move Anyway", "Build Anyway")
    ///   - presenter: The view controller to present the alert from
    ///   - onConfirm: Called when the user confirms cancelling the task
    static func showBusyVillagerConfirmation(
        villagers: VillagerGroup,
        actionName: String,
        actionButtonTitle: String,
        presenter: UIViewController,
        onConfirm: @escaping () -> Void
    ) {
        let taskName = villagers.currentTask.displayName
        let alert = UIAlertController(
            title: "Cancel Current Task?",
            message: "These villagers are currently: \(taskName)\n\nStarting to \(actionName) will cancel their current task.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: actionButtonTitle, style: .destructive) { _ in
            villagers.clearTask()
            onConfirm()
        })

        presenter.present(alert, animated: true)
    }

    /// Shows a simpler confirmation dialog for move operations.
    /// - Parameters:
    ///   - villagers: The villager group with an active task
    ///   - presenter: The view controller to present the alert from
    ///   - onConfirm: Called when the user confirms cancelling the task
    static func showMoveConfirmation(
        villagers: VillagerGroup,
        presenter: UIViewController,
        onConfirm: @escaping () -> Void
    ) {
        let taskName = villagers.currentTask.displayName
        let alert = UIAlertController(
            title: "Cancel Task?",
            message: "Moving will cancel: \(taskName)",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Move Anyway", style: .destructive) { _ in
            villagers.clearTask()
            onConfirm()
        })

        presenter.present(alert, animated: true)
    }

    // MARK: - Task Status Helpers

    /// Checks if the villager group has an active (non-idle) task.
    /// - Parameter villagers: The villager group to check
    /// - Returns: true if the villagers are busy with a task
    static func isBusy(_ villagers: VillagerGroup) -> Bool {
        return villagers.currentTask != .idle
    }

    /// Checks if the entity is a villager group with an active task.
    /// - Parameter entity: The entity to check
    /// - Returns: true if the entity is a busy villager group
    static func isBusyVillager(_ entity: Any) -> Bool {
        guard let villagers = entity as? VillagerGroup else { return false }
        return isBusy(villagers)
    }
}
