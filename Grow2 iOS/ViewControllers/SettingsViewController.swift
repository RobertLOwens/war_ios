// ============================================================================
// FILE: SettingsViewController.swift
// LOCATION: Create as new file
// ============================================================================

import UIKit

class SettingsViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    func setupUI() {
        view.backgroundColor = UIColor(white: 0.1, alpha: 1.0)
        
        // Title
        let titleLabel = UILabel(frame: CGRect(x: 0, y: 60, width: view.bounds.width, height: 50))
        titleLabel.text = "Settings"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 32)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        view.addSubview(titleLabel)
        
        // Back Button
        let backButton = UIButton(frame: CGRect(x: 20, y: 60, width: 80, height: 44))
        backButton.setTitle("← Back", for: .normal)
        backButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        view.addSubview(backButton)
        
        // Placeholder message
        let messageLabel = UILabel(frame: CGRect(x: 40, y: 200, width: view.bounds.width - 80, height: 100))
        messageLabel.text = "⚙️\n\nSettings will be added in a future update"
        messageLabel.font = UIFont.systemFont(ofSize: 18)
        messageLabel.textColor = UIColor(white: 0.6, alpha: 1.0)
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        view.addSubview(messageLabel)
    }
    
    @objc func backTapped() {
        dismiss(animated: true)
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
}
