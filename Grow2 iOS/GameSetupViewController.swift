// ============================================================================
// FILE: GameSetupViewController.swift
// LOCATION: Create as new file
// ============================================================================

import UIKit

enum MapSize: Int {
    case small = 15
    case medium = 20
    case large = 25
    case huge = 30
    
    var displayName: String {
        switch self {
        case .small: return "Small (15x15)"
        case .medium: return "Medium (20x20)"
        case .large: return "Large (25x25)"
        case .huge: return "Huge (30x30)"
        }
    }
}

enum ResourceDensity: String {
    case sparse = "Sparse"
    case normal = "Normal"
    case abundant = "Abundant"
    
    var multiplier: Double {
        switch self {
        case .sparse: return 0.5
        case .normal: return 1.0
        case .abundant: return 1.5
        }
    }
}

class GameSetupViewController: UIViewController {
    
    var selectedMapSize: MapSize = .medium
    var selectedResourceDensity: ResourceDensity = .normal
    
    var mapSizeSegmentedControl: UISegmentedControl!
    var resourceDensitySegmentedControl: UISegmentedControl!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    func setupUI() {
        view.backgroundColor = UIColor(white: 0.1, alpha: 1.0)
        
        // Title
        let titleLabel = UILabel(frame: CGRect(x: 0, y: 60, width: view.bounds.width, height: 50))
        titleLabel.text = "Game Setup"
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
        
        let startY: CGFloat = 150
        let sectionSpacing: CGFloat = 120
        
        // Map Size Section
        createSection(
            title: "🗺️ Map Size",
            yPosition: startY,
            options: [MapSize.small.displayName, MapSize.medium.displayName, MapSize.large.displayName, MapSize.huge.displayName],
            selectedIndex: 1
        ) { [weak self] control in
            guard let self = self else { return }
            self.selectedMapSize = [MapSize.small, MapSize.medium, MapSize.large, MapSize.huge][control.selectedSegmentIndex]
            self.mapSizeSegmentedControl = control
        }
        
        // Resource Density Section
        createSection(
            title: "💎 Resource Density",
            yPosition: startY + sectionSpacing,
            options: [ResourceDensity.sparse.rawValue, ResourceDensity.normal.rawValue, ResourceDensity.abundant.rawValue],
            selectedIndex: 1
        ) { [weak self] control in
            guard let self = self else { return }
            self.selectedResourceDensity = [ResourceDensity.sparse, ResourceDensity.normal, ResourceDensity.abundant][control.selectedSegmentIndex]
            self.resourceDensitySegmentedControl = control
        }
        
        // Game Info
        let infoView = UIView(frame: CGRect(x: 20, y: startY + sectionSpacing * 2, width: view.bounds.width - 40, height: 120))
        infoView.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        infoView.layer.cornerRadius = 12
        view.addSubview(infoView)
        
        let infoLabel = UILabel(frame: CGRect(x: 20, y: 15, width: infoView.bounds.width - 40, height: 90))
        infoLabel.text = "🎮 Two Player Game\n\n• You vs AI Opponent\n• Start with 5 villagers each\n• City Center included\n• Opposite map spawn points"
        infoLabel.font = UIFont.systemFont(ofSize: 14)
        infoLabel.textColor = UIColor(white: 0.9, alpha: 1.0)
        infoLabel.numberOfLines = 0
        infoView.addSubview(infoLabel)
        
        // Start Game Button
        let startButton = UIButton(frame: CGRect(x: (view.bounds.width - 280) / 2, y: view.bounds.height - 120, width: 280, height: 60))
        startButton.setTitle("🚀 Start Game", for: .normal)
        startButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 22)
        startButton.backgroundColor = UIColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
        startButton.layer.cornerRadius = 12
        startButton.layer.shadowColor = UIColor.black.cgColor
        startButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        startButton.layer.shadowOpacity = 0.3
        startButton.layer.shadowRadius = 8
        startButton.addTarget(self, action: #selector(startGameTapped), for: .touchUpInside)
        view.addSubview(startButton)
    }
    
    func createSection(title: String, yPosition: CGFloat, options: [String], selectedIndex: Int, onChange: @escaping (UISegmentedControl) -> Void) {
        let sectionLabel = UILabel(frame: CGRect(x: 40, y: yPosition, width: view.bounds.width - 80, height: 30))
        sectionLabel.text = title
        sectionLabel.font = UIFont.boldSystemFont(ofSize: 18)
        sectionLabel.textColor = .white
        view.addSubview(sectionLabel)
        
        let segmentedControl = UISegmentedControl(items: options)
        segmentedControl.frame = CGRect(x: 40, y: yPosition + 40, width: view.bounds.width - 80, height: 40)
        segmentedControl.selectedSegmentIndex = selectedIndex
        segmentedControl.addTarget(self, action: #selector(segmentChanged(_:)), for: .valueChanged)
        view.addSubview(segmentedControl)
        
        onChange(segmentedControl)
    }
    
    @objc func segmentChanged(_ sender: UISegmentedControl) {
        // Update selected values
        if sender == mapSizeSegmentedControl {
            selectedMapSize = [MapSize.small, MapSize.medium, MapSize.large, MapSize.huge][sender.selectedSegmentIndex]
        } else if sender == resourceDensitySegmentedControl {
            selectedResourceDensity = [ResourceDensity.sparse, ResourceDensity.normal, ResourceDensity.abundant][sender.selectedSegmentIndex]
        }
    }
    
    @objc func backTapped() {
        dismiss(animated: true)
    }
    
    @objc func startGameTapped() {
        let gameVC = GameViewController()
        gameVC.mapSize = selectedMapSize
        gameVC.resourceDensity = selectedResourceDensity
        gameVC.modalPresentationStyle = .fullScreen
        present(gameVC, animated: true)
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
}
