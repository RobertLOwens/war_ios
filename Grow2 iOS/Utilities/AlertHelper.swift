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

    // MARK: - Temporary Messages

    /// Shows a temporary message banner that auto-dismisses
    func showTemporaryMessage(_ message: String, duration: TimeInterval = 3.0) {
        let banner = UIView()
        banner.backgroundColor = UIColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 0.95)
        banner.layer.cornerRadius = 10
        banner.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false

        banner.addSubview(label)
        view.addSubview(banner)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: banner.topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: banner.bottomAnchor, constant: -12),
            label.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -16),

            banner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            banner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            banner.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.9)
        ])

        banner.alpha = 0
        banner.transform = CGAffineTransform(translationX: 0, y: -20)

        UIView.animate(withDuration: 0.3) {
            banner.alpha = 1
            banner.transform = .identity
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            UIView.animate(withDuration: 0.3, animations: {
                banner.alpha = 0
                banner.transform = CGAffineTransform(translationX: 0, y: -20)
            }) { _ in
                banner.removeFromSuperview()
            }
        }
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

