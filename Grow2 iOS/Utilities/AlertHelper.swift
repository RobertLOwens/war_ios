// ============================================================================
// FILE: AlertHelper.swift
// LOCATION: Grow2 iOS/Utilities/AlertHelper.swift
// PURPOSE: Utility extension for common alert patterns to reduce boilerplate
// ============================================================================

import UIKit

// MARK: - Alert Configuration

struct AlertAction {
    let title: String
    let style: UIAlertAction.Style
    let handler: (() -> Void)?
    
    init(title: String, style: UIAlertAction.Style = .default, handler: (() -> Void)? = nil) {
        self.title = title
        self.style = style
        self.handler = handler
    }
    
    static func cancel(_ handler: (() -> Void)? = nil) -> AlertAction {
        AlertAction(title: "Cancel", style: .cancel, handler: handler)
    }
    
    static func ok(_ handler: (() -> Void)? = nil) -> AlertAction {
        AlertAction(title: "OK", style: .default, handler: handler)
    }
    
    static func destructive(_ title: String, handler: (() -> Void)? = nil) -> AlertAction {
        AlertAction(title: title, style: .destructive, handler: handler)
    }
}

// MARK: - Alert Helper Extension

extension UIViewController {
    
    // MARK: - Simple Alerts
    
    /// Shows a simple alert with OK button
    func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completion?()
        })
        present(alert, animated: true)
    }
    
    /// Shows a success alert with checkmark
    func showSuccess(title: String = "✅ Success", message: String) {
        showAlert(title: title, message: message)
    }
    
    /// Shows an error alert with X mark
    func showError(title: String = "❌ Error", message: String) {
        showAlert(title: title, message: message)
    }
    
    // MARK: - Confirmation Dialogs
    
    /// Shows a confirmation dialog with Cancel and Confirm actions
    func showConfirmation(
        title: String,
        message: String,
        confirmTitle: String = "Confirm",
        confirmStyle: UIAlertAction.Style = .default,
        onConfirm: @escaping () -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            onCancel?()
        })
        
        alert.addAction(UIAlertAction(title: confirmTitle, style: confirmStyle) { _ in
            onConfirm()
        })
        
        present(alert, animated: true)
    }
    
    /// Shows a destructive confirmation (red confirm button)
    func showDestructiveConfirmation(
        title: String,
        message: String,
        confirmTitle: String = "Delete",
        onConfirm: @escaping () -> Void
    ) {
        showConfirmation(
            title: title,
            message: message,
            confirmTitle: confirmTitle,
            confirmStyle: .destructive,
            onConfirm: onConfirm
        )
    }
    
    // MARK: - Action Sheets
    
    /// Shows an action sheet with multiple options
    /// - Parameters:
    ///   - title: Sheet title
    ///   - message: Optional message
    ///   - actions: Array of AlertAction items
    ///   - sourceView: View for iPad popover (defaults to center of screen)
    ///   - sourceRect: Rect for iPad popover
    func showActionSheet(
        title: String?,
        message: String? = nil,
        actions: [AlertAction],
        sourceView: UIView? = nil,
        sourceRect: CGRect? = nil,
        includeCancel: Bool = true,
        onCancel: (() -> Void)? = nil
    ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        
        for action in actions {
            alert.addAction(UIAlertAction(title: action.title, style: action.style) { _ in
                action.handler?()
            })
        }
        
        if includeCancel {
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                onCancel?()
            })
        }
        
        configurePopover(for: alert, sourceView: sourceView, sourceRect: sourceRect)
        present(alert, animated: true)
    }
    
    // MARK: - Custom Content Alerts
    
    /// Shows an alert with a custom view controller embedded
    func showAlertWithCustomContent(
        title: String?,
        message: String? = nil,
        contentViewController: UIViewController,
        actions: [AlertAction]
    ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.setValue(contentViewController, forKey: "contentViewController")
        
        for action in actions {
            alert.addAction(UIAlertAction(title: action.title, style: action.style) { _ in
                action.handler?()
            })
        }
        
        present(alert, animated: true)
    }
    
    // MARK: - Text Input Alerts
    
    /// Shows an alert with a text field
    func showTextInput(
        title: String,
        message: String? = nil,
        placeholder: String? = nil,
        initialValue: String? = nil,
        keyboardType: UIKeyboardType = .default,
        onSubmit: @escaping (String) -> Void
    ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = placeholder
            textField.text = initialValue
            textField.keyboardType = keyboardType
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            if let text = alert.textFields?.first?.text {
                onSubmit(text)
            }
        })
        
        present(alert, animated: true)
    }
    
    // MARK: - Private Helpers
    
    private func configurePopover(
        for alert: UIAlertController,
        sourceView: UIView?,
        sourceRect: CGRect?
    ) {
        if let popover = alert.popoverPresentationController {
            let targetView = sourceView ?? view
            popover.sourceView = targetView
            popover.sourceRect = sourceRect ?? CGRect(
                x: targetView?.bounds.midX ?? 0,
                y: targetView?.bounds.midY ?? 0,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = sourceRect != nil ? .any : []
        }
    }
}

// MARK: - Sheet Presentation Helper

extension UIViewController {
    
    /// Presents a view controller as a sheet with common configuration
    func presentSheet(
        _ viewController: UIViewController,
        detents: [UISheetPresentationController.Detent] = [.large()],
        prefersGrabber: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        viewController.modalPresentationStyle = .pageSheet
        
        if let sheet = viewController.sheetPresentationController {
            sheet.detents = detents
            sheet.prefersGrabberVisible = prefersGrabber
            sheet.selectedDetentIdentifier = detents.last == .large() ? .large : .medium
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            sheet.prefersEdgeAttachedInCompactHeight = true
            sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = true
        }
        
        present(viewController, animated: true, completion: completion)
    }
    
    /// Presents a view controller fullscreen
    func presentFullScreen(_ viewController: UIViewController, completion: (() -> Void)? = nil) {
        viewController.modalPresentationStyle = .fullScreen
        present(viewController, animated: true, completion: completion)
    }
}
