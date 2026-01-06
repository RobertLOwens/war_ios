// ============================================================================
// FILE: AboutViewController.swift
// LOCATION: Create as new file
// ============================================================================

import UIKit

class AboutViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    func setupUI() {
        view.backgroundColor = UIColor(white: 0.1, alpha: 1.0)
        
        // Title
        let titleLabel = UILabel(frame: CGRect(x: 0, y: 60, width: view.bounds.width, height: 50))
        titleLabel.text = "About the Game"
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
        
        // Game info container
        let infoView = UIView(frame: CGRect(x: 40, y: 150, width: view.bounds.width - 80, height: 400))
        infoView.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        infoView.layer.cornerRadius = 12
        view.addSubview(infoView)
        
        let aboutText = """
        🎮 HEX RTS
        
        A hexagonal real-time strategy game featuring:
        
        • Hexagonal grid-based map
        • Resource gathering system
        • Building construction
        • Military units and combat
        • Commander system
        • Fog of War
        • Diplomacy system
        
        Build your empire, train your army, and conquer your enemies!
        
        Version 1.0.0
        """
        
        let aboutLabel = UILabel(frame: CGRect(x: 20, y: 20, width: infoView.bounds.width - 40, height: 360))
        aboutLabel.text = aboutText
        aboutLabel.font = UIFont.systemFont(ofSize: 16)
        aboutLabel.textColor = .white
        aboutLabel.numberOfLines = 0
        aboutLabel.textAlignment = .center
        infoView.addSubview(aboutLabel)
    }
    
    @objc func backTapped() {
        dismiss(animated: true)
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
}
