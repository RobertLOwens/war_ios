// ============================================================================
// FILE: GameSetupViewController.swift
// LOCATION: Create as new file
// ============================================================================

import UIKit

enum MapType: String {
    case arabia = "Arabia"
    case random = "Random"
    case arena = "Arena"

    var displayName: String {
        switch self {
        case .arabia: return "Arabia (35x35)"
        case .random: return "Random"
        case .arena: return "Arena (5x5)"
        }
    }

    var description: String {
        switch self {
        case .arabia: return "Competitive 1v1 map with balanced resources and opposite corner spawns"
        case .random: return "Randomly generated terrain and resources"
        case .arena: return "Small combat test arena with two armies"
        }
    }
}

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

enum VisibilityMode: String {
    case normal = "Normal"
    case fullyVisible = "Fully Visible"

    var displayName: String {
        switch self {
        case .normal: return "Normal (Fog of War)"
        case .fullyVisible: return "Fully Visible"
        }
    }

    var description: String {
        switch self {
        case .normal: return "Explore the map to reveal new areas"
        case .fullyVisible: return "See the entire map from the start"
        }
    }
}

class GameSetupViewController: UIViewController {

    var selectedMapType: MapType = .arabia  // Arabia is default
    var selectedMapSize: MapSize = .medium
    var selectedResourceDensity: ResourceDensity = .normal
    var selectedVisibilityMode: VisibilityMode = .normal

    var mapTypeSegmentedControl: UISegmentedControl!
    var mapSizeSegmentedControl: UISegmentedControl!
    var resourceDensitySegmentedControl: UISegmentedControl!
    var visibilityModeSegmentedControl: UISegmentedControl!
    var mapSizeSection: UIView?
    var resourceDensitySection: UIView?
    var visibilityModeSection: UIView?
    
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
        let sectionSpacing: CGFloat = 100

        // Map Type Section (Arabia vs Random vs Arena)
        createSection(
            title: "🗺️ Map Type",
            yPosition: startY,
            options: [MapType.arabia.displayName, MapType.random.displayName, MapType.arena.displayName],
            selectedIndex: 0  // Arabia is default
        ) { [weak self] control in
            guard let self = self else { return }
            switch control.selectedSegmentIndex {
            case 0: self.selectedMapType = .arabia
            case 1: self.selectedMapType = .random
            case 2: self.selectedMapType = .arena
            default: self.selectedMapType = .arabia
            }
            self.mapTypeSegmentedControl = control
            self.updateMapOptionsVisibility()
        }

        // Map Size Section (only for Random maps)
        let sizeSection = createSectionView(
            title: "📐 Map Size",
            yPosition: startY + sectionSpacing,
            options: [MapSize.small.displayName, MapSize.medium.displayName, MapSize.large.displayName, MapSize.huge.displayName],
            selectedIndex: 1
        ) { [weak self] control in
            guard let self = self else { return }
            self.selectedMapSize = [MapSize.small, MapSize.medium, MapSize.large, MapSize.huge][control.selectedSegmentIndex]
            self.mapSizeSegmentedControl = control
        }
        mapSizeSection = sizeSection

        // Resource Density Section (only for Random maps)
        let densitySection = createSectionView(
            title: "💎 Resource Density",
            yPosition: startY + sectionSpacing * 2,
            options: [ResourceDensity.sparse.rawValue, ResourceDensity.normal.rawValue, ResourceDensity.abundant.rawValue],
            selectedIndex: 1
        ) { [weak self] control in
            guard let self = self else { return }
            self.selectedResourceDensity = [ResourceDensity.sparse, ResourceDensity.normal, ResourceDensity.abundant][control.selectedSegmentIndex]
            self.resourceDensitySegmentedControl = control
        }
        resourceDensitySection = densitySection

        // Visibility Mode Section
        let visibilitySection = createSectionView(
            title: "👁️ Visibility Mode",
            yPosition: startY + sectionSpacing * 3,
            options: [VisibilityMode.normal.displayName, VisibilityMode.fullyVisible.displayName],
            selectedIndex: 0
        ) { [weak self] control in
            guard let self = self else { return }
            self.selectedVisibilityMode = control.selectedSegmentIndex == 0 ? .normal : .fullyVisible
            self.visibilityModeSegmentedControl = control
        }
        visibilityModeSection = visibilitySection

        // Initially hide size/density for Arabia (default)
        updateMapOptionsVisibility()

        // Game Info
        let infoView = UIView(frame: CGRect(x: 20, y: startY + sectionSpacing * 4, width: view.bounds.width - 40, height: 120))
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
        if sender == mapTypeSegmentedControl {
            switch sender.selectedSegmentIndex {
            case 0: selectedMapType = .arabia
            case 1: selectedMapType = .random
            case 2: selectedMapType = .arena
            default: selectedMapType = .arabia
            }
            updateMapOptionsVisibility()
        } else if sender == mapSizeSegmentedControl {
            selectedMapSize = [MapSize.small, MapSize.medium, MapSize.large, MapSize.huge][sender.selectedSegmentIndex]
        } else if sender == resourceDensitySegmentedControl {
            selectedResourceDensity = [ResourceDensity.sparse, ResourceDensity.normal, ResourceDensity.abundant][sender.selectedSegmentIndex]
        } else if sender == visibilityModeSegmentedControl {
            selectedVisibilityMode = sender.selectedSegmentIndex == 0 ? .normal : .fullyVisible
        }
    }

    func updateMapOptionsVisibility() {
        // Only show size/density options for random maps
        let showRandomOptions = selectedMapType == .random
        UIView.animate(withDuration: 0.3) {
            self.mapSizeSection?.alpha = showRandomOptions ? 1.0 : 0.3
            self.resourceDensitySection?.alpha = showRandomOptions ? 1.0 : 0.3
        }
        mapSizeSegmentedControl?.isEnabled = showRandomOptions
        resourceDensitySegmentedControl?.isEnabled = showRandomOptions
    }

    func createSectionView(title: String, yPosition: CGFloat, options: [String], selectedIndex: Int, onChange: @escaping (UISegmentedControl) -> Void) -> UIView {
        let container = UIView(frame: CGRect(x: 0, y: yPosition, width: view.bounds.width, height: 80))
        view.addSubview(container)

        let sectionLabel = UILabel(frame: CGRect(x: 40, y: 0, width: view.bounds.width - 80, height: 30))
        sectionLabel.text = title
        sectionLabel.font = UIFont.boldSystemFont(ofSize: 18)
        sectionLabel.textColor = .white
        container.addSubview(sectionLabel)

        let segmentedControl = UISegmentedControl(items: options)
        segmentedControl.frame = CGRect(x: 40, y: 35, width: view.bounds.width - 80, height: 40)
        segmentedControl.selectedSegmentIndex = selectedIndex
        segmentedControl.addTarget(self, action: #selector(segmentChanged(_:)), for: .valueChanged)
        container.addSubview(segmentedControl)

        onChange(segmentedControl)
        return container
    }
    
    @objc func backTapped() {
        dismiss(animated: true)
    }
    
    @objc func startGameTapped() {
        let gameVC = GameViewController()
        gameVC.mapType = selectedMapType
        gameVC.mapSize = selectedMapSize
        gameVC.resourceDensity = selectedResourceDensity
        gameVC.visibilityMode = selectedVisibilityMode
        gameVC.modalPresentationStyle = .fullScreen
        present(gameVC, animated: true)
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
}
