// ============================================================================
// FILE: GameSetupViewController.swift
// LOCATION: Create as new file
// ============================================================================

import UIKit

// MARK: - Arena Army Configuration

struct ArenaArmyConfiguration {
    var playerArmy: [MilitaryUnitTypeData: Int] = [:]
    var enemyArmy: [MilitaryUnitTypeData: Int] = [:]

    static var `default`: ArenaArmyConfiguration {
        var config = ArenaArmyConfiguration()
        config.playerArmy[.swordsman] = 5
        config.playerArmy[.archer] = 4
        config.enemyArmy[.swordsman] = 5
        config.enemyArmy[.archer] = 2
        return config
    }

    static let availableUnitTypes: [MilitaryUnitTypeData] = MilitaryUnitTypeData.allCases
    static let maxUnitsPerType: Int = 20
}

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
    var arenaArmyConfig: ArenaArmyConfiguration = .default

    var mapTypeSegmentedControl: UISegmentedControl!
    var mapSizeSegmentedControl: UISegmentedControl!
    var resourceDensitySegmentedControl: UISegmentedControl!
    var visibilityModeSegmentedControl: UISegmentedControl!
    var mapSizeSection: UIView?
    var resourceDensitySection: UIView?
    var visibilityModeSection: UIView?
    var arenaConfigSection: UIView?
    var playerArmySliders: [MilitaryUnitTypeData: UISlider] = [:]
    var enemyArmySliders: [MilitaryUnitTypeData: UISlider] = [:]
    var playerArmyLabels: [MilitaryUnitTypeData: UILabel] = [:]
    var enemyArmyLabels: [MilitaryUnitTypeData: UILabel] = [:]
    var playerTotalLabel: UILabel?
    var enemyTotalLabel: UILabel?
    
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

        // Create scroll view for content
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 120, width: view.bounds.width, height: view.bounds.height - 200))
        scrollView.showsVerticalScrollIndicator = true
        view.addSubview(scrollView)

        let contentView = UIView()
        scrollView.addSubview(contentView)

        var currentY: CGFloat = 30
        let sectionSpacing: CGFloat = 100

        // Map Type Section (Arabia vs Random vs Arena)
        let mapTypeSection = createSectionViewInContainer(
            container: contentView,
            title: "Map Type",
            yPosition: currentY,
            options: [MapType.arabia.displayName, MapType.random.displayName, MapType.arena.displayName],
            selectedIndex: 0
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
        _ = mapTypeSection
        currentY += sectionSpacing

        // Map Size Section (only for Random maps)
        let sizeSection = createSectionViewInContainer(
            container: contentView,
            title: "Map Size",
            yPosition: currentY,
            options: [MapSize.small.displayName, MapSize.medium.displayName, MapSize.large.displayName, MapSize.huge.displayName],
            selectedIndex: 1
        ) { [weak self] control in
            guard let self = self else { return }
            self.selectedMapSize = [MapSize.small, MapSize.medium, MapSize.large, MapSize.huge][control.selectedSegmentIndex]
            self.mapSizeSegmentedControl = control
        }
        mapSizeSection = sizeSection
        currentY += sectionSpacing

        // Resource Density Section (only for Random maps)
        let densitySection = createSectionViewInContainer(
            container: contentView,
            title: "Resource Density",
            yPosition: currentY,
            options: [ResourceDensity.sparse.rawValue, ResourceDensity.normal.rawValue, ResourceDensity.abundant.rawValue],
            selectedIndex: 1
        ) { [weak self] control in
            guard let self = self else { return }
            self.selectedResourceDensity = [ResourceDensity.sparse, ResourceDensity.normal, ResourceDensity.abundant][control.selectedSegmentIndex]
            self.resourceDensitySegmentedControl = control
        }
        resourceDensitySection = densitySection
        currentY += sectionSpacing

        // Visibility Mode Section
        let visibilitySection = createSectionViewInContainer(
            container: contentView,
            title: "Visibility Mode",
            yPosition: currentY,
            options: [VisibilityMode.normal.displayName, VisibilityMode.fullyVisible.displayName],
            selectedIndex: 0
        ) { [weak self] control in
            guard let self = self else { return }
            self.selectedVisibilityMode = control.selectedSegmentIndex == 0 ? .normal : .fullyVisible
            self.visibilityModeSegmentedControl = control
        }
        visibilityModeSection = visibilitySection
        currentY += sectionSpacing

        // Arena Army Configuration Section (only for Arena mode)
        let arenaSection = createArenaConfigSection(container: contentView, yPosition: currentY)
        arenaConfigSection = arenaSection
        currentY += arenaSection.frame.height + 20

        // Game Info
        let infoView = UIView(frame: CGRect(x: 20, y: currentY, width: view.bounds.width - 40, height: 120))
        infoView.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        infoView.layer.cornerRadius = 12
        contentView.addSubview(infoView)

        let infoLabel = UILabel(frame: CGRect(x: 20, y: 15, width: infoView.bounds.width - 40, height: 90))
        infoLabel.text = "Two Player Game\n\n• You vs AI Opponent\n• Start with 5 villagers each\n• City Center included\n• Opposite map spawn points"
        infoLabel.font = UIFont.systemFont(ofSize: 14)
        infoLabel.textColor = UIColor(white: 0.9, alpha: 1.0)
        infoLabel.numberOfLines = 0
        infoView.addSubview(infoLabel)
        currentY += 140

        // Set content view frame and scroll view content size
        contentView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: currentY)
        scrollView.contentSize = CGSize(width: view.bounds.width, height: currentY)

        // Initially hide size/density for Arabia (default)
        updateMapOptionsVisibility()

        // Start Game Button (fixed at bottom)
        let startButton = UIButton(frame: CGRect(x: (view.bounds.width - 280) / 2, y: view.bounds.height - 80, width: 280, height: 60))
        startButton.setTitle("Start Game", for: .normal)
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

    func createSectionViewInContainer(container: UIView, title: String, yPosition: CGFloat, options: [String], selectedIndex: Int, onChange: @escaping (UISegmentedControl) -> Void) -> UIView {
        let sectionView = UIView(frame: CGRect(x: 0, y: yPosition, width: view.bounds.width, height: 80))
        container.addSubview(sectionView)

        let sectionLabel = UILabel(frame: CGRect(x: 40, y: 0, width: view.bounds.width - 80, height: 30))
        sectionLabel.text = title
        sectionLabel.font = UIFont.boldSystemFont(ofSize: 18)
        sectionLabel.textColor = .white
        sectionView.addSubview(sectionLabel)

        let segmentedControl = UISegmentedControl(items: options)
        segmentedControl.frame = CGRect(x: 40, y: 35, width: view.bounds.width - 80, height: 40)
        segmentedControl.selectedSegmentIndex = selectedIndex
        segmentedControl.addTarget(self, action: #selector(segmentChanged(_:)), for: .valueChanged)
        sectionView.addSubview(segmentedControl)

        onChange(segmentedControl)
        return sectionView
    }

    func createArenaConfigSection(container: UIView, yPosition: CGFloat) -> UIView {
        let unitTypes = ArenaArmyConfiguration.availableUnitTypes
        let rowHeight: CGFloat = 50
        let headerHeight: CGFloat = 40
        let totalLabelHeight: CGFloat = 30
        let sectionPadding: CGFloat = 20

        // Calculate total height for one army section
        let armySectionHeight = headerHeight + (CGFloat(unitTypes.count) * rowHeight) + totalLabelHeight + sectionPadding
        let totalHeight = armySectionHeight * 2 + sectionPadding

        let sectionView = UIView(frame: CGRect(x: 20, y: yPosition, width: view.bounds.width - 40, height: totalHeight))
        sectionView.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        sectionView.layer.cornerRadius = 12
        container.addSubview(sectionView)

        var currentY: CGFloat = 10

        // YOUR ARMY header
        let playerHeader = UILabel(frame: CGRect(x: 20, y: currentY, width: sectionView.bounds.width - 40, height: headerHeight))
        playerHeader.text = "YOUR ARMY"
        playerHeader.font = UIFont.boldSystemFont(ofSize: 16)
        playerHeader.textColor = UIColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1.0)
        sectionView.addSubview(playerHeader)
        currentY += headerHeight

        // Player army sliders
        for unitType in unitTypes {
            let row = createUnitSliderRow(
                in: sectionView,
                yPosition: currentY,
                unitType: unitType,
                initialValue: arenaArmyConfig.playerArmy[unitType] ?? 0,
                isPlayer: true
            )
            playerArmySliders[unitType] = row.slider
            playerArmyLabels[unitType] = row.countLabel
            currentY += rowHeight
        }

        // Player total
        let playerTotal = UILabel(frame: CGRect(x: 20, y: currentY, width: sectionView.bounds.width - 40, height: totalLabelHeight))
        playerTotal.font = UIFont.boldSystemFont(ofSize: 14)
        playerTotal.textColor = .white
        sectionView.addSubview(playerTotal)
        playerTotalLabel = playerTotal
        currentY += totalLabelHeight + sectionPadding

        // ENEMY ARMY header
        let enemyHeader = UILabel(frame: CGRect(x: 20, y: currentY, width: sectionView.bounds.width - 40, height: headerHeight))
        enemyHeader.text = "ENEMY ARMY"
        enemyHeader.font = UIFont.boldSystemFont(ofSize: 16)
        enemyHeader.textColor = UIColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1.0)
        sectionView.addSubview(enemyHeader)
        currentY += headerHeight

        // Enemy army sliders
        for unitType in unitTypes {
            let row = createUnitSliderRow(
                in: sectionView,
                yPosition: currentY,
                unitType: unitType,
                initialValue: arenaArmyConfig.enemyArmy[unitType] ?? 0,
                isPlayer: false
            )
            enemyArmySliders[unitType] = row.slider
            enemyArmyLabels[unitType] = row.countLabel
            currentY += rowHeight
        }

        // Enemy total
        let enemyTotal = UILabel(frame: CGRect(x: 20, y: currentY, width: sectionView.bounds.width - 40, height: totalLabelHeight))
        enemyTotal.font = UIFont.boldSystemFont(ofSize: 14)
        enemyTotal.textColor = .white
        sectionView.addSubview(enemyTotal)
        enemyTotalLabel = enemyTotal

        // Update totals
        updateArmyTotals()

        return sectionView
    }

    func createUnitSliderRow(in container: UIView, yPosition: CGFloat, unitType: MilitaryUnitTypeData, initialValue: Int, isPlayer: Bool) -> (slider: UISlider, countLabel: UILabel) {
        let labelWidth: CGFloat = 120
        let countWidth: CGFloat = 40
        let padding: CGFloat = 20
        let sliderWidth = container.bounds.width - labelWidth - countWidth - (padding * 3)

        // Unit icon and name label
        let nameLabel = UILabel(frame: CGRect(x: padding, y: yPosition, width: labelWidth, height: 40))
        nameLabel.text = "\(unitType.icon) \(unitType.displayName)"
        nameLabel.font = UIFont.systemFont(ofSize: 14)
        nameLabel.textColor = .white
        container.addSubview(nameLabel)

        // Slider
        let slider = UISlider(frame: CGRect(x: padding + labelWidth, y: yPosition + 5, width: sliderWidth, height: 30))
        slider.minimumValue = 0
        slider.maximumValue = Float(ArenaArmyConfiguration.maxUnitsPerType)
        slider.value = Float(initialValue)
        slider.minimumTrackTintColor = isPlayer ? UIColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1.0) : UIColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1.0)
        slider.addTarget(self, action: #selector(armySliderChanged(_:)), for: .valueChanged)
        container.addSubview(slider)

        // Count label
        let countLabel = UILabel(frame: CGRect(x: container.bounds.width - countWidth - padding, y: yPosition, width: countWidth, height: 40))
        countLabel.text = "\(initialValue)"
        countLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .bold)
        countLabel.textColor = .white
        countLabel.textAlignment = .right
        container.addSubview(countLabel)

        return (slider, countLabel)
    }

    @objc func armySliderChanged(_ sender: UISlider) {
        let value = Int(sender.value.rounded())

        // Find which slider changed and update config
        for (unitType, slider) in playerArmySliders {
            if slider === sender {
                arenaArmyConfig.playerArmy[unitType] = value
                playerArmyLabels[unitType]?.text = "\(value)"
                break
            }
        }

        for (unitType, slider) in enemyArmySliders {
            if slider === sender {
                arenaArmyConfig.enemyArmy[unitType] = value
                enemyArmyLabels[unitType]?.text = "\(value)"
                break
            }
        }

        updateArmyTotals()
    }

    func updateArmyTotals() {
        let playerTotal = arenaArmyConfig.playerArmy.values.reduce(0, +)
        let enemyTotal = arenaArmyConfig.enemyArmy.values.reduce(0, +)

        playerTotalLabel?.text = "Total: \(playerTotal) units"
        enemyTotalLabel?.text = "Total: \(enemyTotal) units"
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
        let showArenaOptions = selectedMapType == .arena

        UIView.animate(withDuration: 0.3) {
            self.mapSizeSection?.alpha = showRandomOptions ? 1.0 : 0.3
            self.resourceDensitySection?.alpha = showRandomOptions ? 1.0 : 0.3
            self.arenaConfigSection?.alpha = showArenaOptions ? 1.0 : 0.0
            self.arenaConfigSection?.isHidden = !showArenaOptions
        }
        mapSizeSegmentedControl?.isEnabled = showRandomOptions
        resourceDensitySegmentedControl?.isEnabled = showRandomOptions

        // Enable/disable arena sliders
        for slider in playerArmySliders.values {
            slider.isEnabled = showArenaOptions
        }
        for slider in enemyArmySliders.values {
            slider.isEnabled = showArenaOptions
        }
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
        if selectedMapType == .arena {
            gameVC.arenaArmyConfig = arenaArmyConfig
        }
        gameVC.modalPresentationStyle = .fullScreen
        present(gameVC, animated: true)
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
}
