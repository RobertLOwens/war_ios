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

// MARK: - Arena Scenario Configuration

struct ArenaScenarioConfig {
    var enemyTerrain: TerrainData = .plains
    var enemyBuilding: BuildingType? = nil
    var enemyEntrenched: Bool = false
    var enemyArmyCount: Int = 1       // 1=single, 2-5=stacked same tile, -2 to -5=adjacent tiles
    var playerArmyCount: Int = 1      // 1=single, 2-5=stacked same tile, -2 to -5=adjacent tiles
    var playerCommanderSpecialty: CommanderSpecialtyData = .infantryAggressive
    var enemyCommanderSpecialty: CommanderSpecialtyData = .infantryAggressive
    var playerUnitTiers: [MilitaryUnitTypeData: Int] = [:]  // per-unit: 0=base, 1, 2
    var enemyUnitTiers: [MilitaryUnitTypeData: Int] = [:]   // per-unit: 0=base, 1, 2
    var playerCommanderLevel: Int = 1  // 1, 5, 10, 15, 20, 25
    var enemyCommanderLevel: Int = 1   // 1, 5, 10, 15, 20, 25
    var garrisonArchers: Int = 0      // 0-20
    var enemyAIEnabled: Bool = true

    static var `default`: ArenaScenarioConfig { ArenaScenarioConfig() }
}

enum ArenaPreset: String, CaseIterable {
    case custom = "Custom"
    case plains = "Plains"
    case hill = "Hill"
    case mountain = "Mountain"
    case entrenched = "Entrenched"
    case entrenchedHill = "Entrenched Hill"
    case level2Units = "Level 2 Units"
    case infantryCommander = "Infantry Cmdr"
    case cavalryCommander = "Cavalry Cmdr"
    case tower = "Tower"
    case fort = "Fort"
    case castle = "Castle"
    case entrenchedTower = "Entrenched Tower"
    case entrenchedFort = "Entrenched Fort"
    case entrenchedCastle = "Entrenched Castle"
    case stacked = "Stacked"
    case stackedEntrenched = "Stacked Entrenched"
    case overlapEntrench = "Overlap Entrench"

    func toConfig() -> ArenaScenarioConfig {
        var c = ArenaScenarioConfig()
        switch self {
        case .custom:
            break
        case .plains:
            break // all defaults
        case .hill:
            c.enemyTerrain = .hill
        case .mountain:
            c.enemyTerrain = .mountain
        case .entrenched:
            c.enemyEntrenched = true
        case .entrenchedHill:
            c.enemyTerrain = .hill
            c.enemyEntrenched = true
        case .level2Units:
            for unitType in MilitaryUnitTypeData.allCases {
                c.enemyUnitTiers[unitType] = 2
            }
        case .infantryCommander:
            c.enemyCommanderSpecialty = .infantryAggressive
        case .cavalryCommander:
            c.enemyCommanderSpecialty = .cavalryAggressive
        case .tower:
            c.enemyBuilding = .tower
            c.garrisonArchers = 5
        case .fort:
            c.enemyBuilding = .woodenFort
            c.garrisonArchers = 5
        case .castle:
            c.enemyBuilding = .castle
            c.garrisonArchers = 5
        case .entrenchedTower:
            c.enemyBuilding = .tower
            c.enemyEntrenched = true
            c.garrisonArchers = 5
        case .entrenchedFort:
            c.enemyBuilding = .woodenFort
            c.enemyEntrenched = true
            c.garrisonArchers = 5
        case .entrenchedCastle:
            c.enemyBuilding = .castle
            c.enemyEntrenched = true
            c.garrisonArchers = 5
        case .stacked:
            c.enemyArmyCount = 2
            c.playerArmyCount = 2
        case .stackedEntrenched:
            c.enemyArmyCount = 2
            c.playerArmyCount = 2
            c.enemyEntrenched = true
        case .overlapEntrench:
            c.enemyArmyCount = -2
            c.playerArmyCount = -2
            c.enemyEntrenched = true
        }
        return c
    }
}

enum GameMode: String {
    case offline = "Offline"
    case online = "Online"
}

enum MapType: String {
    case arabia = "Arabia"
    case random = "Random"
    case arena = "Arena"

    var displayName: String {
        switch self {
        case .arabia: return "Arabia (35x35)"
        case .random: return "Random"
        case .arena: return "Arena (7x7)"
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

    var selectedGameMode: GameMode = .offline
    var selectedMapType: MapType = .arabia
    var selectedMapSize: MapSize = .medium
    var selectedResourceDensity: ResourceDensity = .normal
    var selectedVisibilityMode: VisibilityMode = .normal
    var arenaArmyConfig: ArenaArmyConfiguration = .default
    var scenarioConfig: ArenaScenarioConfig = .default
    var selectedPreset: ArenaPreset = .plains
    var simRunCount: Int = 1

    // Game mode controls
    var gameModeSegmentedControl: UISegmentedControl!
    var gameModeSection: UIView?
    var gameModeSignInLabel: UILabel?

    // Map option controls
    var mapTypeSegmentedControl: UISegmentedControl!
    var mapSizeSegmentedControl: UISegmentedControl!
    var resourceDensitySegmentedControl: UISegmentedControl!
    var visibilityModeSegmentedControl: UISegmentedControl!
    var mapSizeSection: UIView?
    var resourceDensitySection: UIView?
    var visibilityModeSection: UIView?
    var arenaConfigSection: UIView?

    // Army sliders
    var playerArmySliders: [MilitaryUnitTypeData: UISlider] = [:]
    var enemyArmySliders: [MilitaryUnitTypeData: UISlider] = [:]
    var playerArmyLabels: [MilitaryUnitTypeData: UILabel] = [:]
    var enemyArmyLabels: [MilitaryUnitTypeData: UILabel] = [:]
    var playerTierControls: [MilitaryUnitTypeData: UISegmentedControl] = [:]
    var enemyTierControls: [MilitaryUnitTypeData: UISegmentedControl] = [:]
    var playerTotalLabel: UILabel?
    var enemyTotalLabel: UILabel?

    // Scenario builder controls
    var terrainControl: UISegmentedControl!
    var buildingControl: UISegmentedControl!
    var entrenchmentControl: UISegmentedControl!
    var stackingControl: UISegmentedControl!
    var playerStackingControl: UISegmentedControl!
    var playerCommanderButton: UIButton!
    var enemyCommanderButton: UIButton!
    var playerCommanderLevelControl: UISegmentedControl!
    var enemyCommanderLevelControl: UISegmentedControl!
    var armyCountControl: UISegmentedControl!
    var playerArmyCountControl: UISegmentedControl!
    var enemyAIControl: UISegmentedControl!
    var garrisonSlider: UISlider!
    var garrisonLabel: UILabel!
    var runCountSlider: UISlider!
    var runCountLabel: UILabel!
    var presetButtons: [UIButton] = []

    // Launch buttons
    var playButton: UIButton!
    var autoSimButton: UIButton!
    var startButton: UIButton!

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

        // Game Mode Section (Offline / Online)
        let modeSection = UIView(frame: CGRect(x: 0, y: currentY, width: view.bounds.width, height: 80))
        contentView.addSubview(modeSection)
        gameModeSection = modeSection

        let modeLabel = UILabel(frame: CGRect(x: 40, y: 0, width: view.bounds.width - 80, height: 30))
        modeLabel.text = "Game Mode"
        modeLabel.font = UIFont.boldSystemFont(ofSize: 18)
        modeLabel.textColor = .white
        modeSection.addSubview(modeLabel)

        gameModeSegmentedControl = UISegmentedControl(items: ["Offline", "Online"])
        gameModeSegmentedControl.frame = CGRect(x: 40, y: 35, width: view.bounds.width - 80, height: 40)
        gameModeSegmentedControl.selectedSegmentIndex = 0
        gameModeSegmentedControl.addTarget(self, action: #selector(gameModeTapped(_:)), for: .valueChanged)
        modeSection.addSubview(gameModeSegmentedControl)

        // "Sign in required" label (shown when not authenticated)
        let signInLabel = UILabel(frame: CGRect(x: 40, y: 78, width: view.bounds.width - 80, height: 18))
        signInLabel.text = "Sign in required for online mode"
        signInLabel.font = UIFont.systemFont(ofSize: 12)
        signInLabel.textColor = UIColor(red: 1.0, green: 0.6, blue: 0.3, alpha: 1.0)
        signInLabel.textAlignment = .center
        signInLabel.isHidden = AuthService.shared.currentUser != nil
        modeSection.addSubview(signInLabel)
        gameModeSignInLabel = signInLabel

        // Disable online segment if not signed in
        if AuthService.shared.currentUser == nil {
            gameModeSegmentedControl.setEnabled(false, forSegmentAt: 1)
        }

        currentY += sectionSpacing

        // Map Type Section
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

        // Arena Config Section (scenario builder + army sliders)
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

        contentView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: currentY)
        scrollView.contentSize = CGSize(width: view.bounds.width, height: currentY)

        updateMapOptionsVisibility()

        // Standard Start Game Button (non-arena modes)
        startButton = UIButton(frame: CGRect(x: (view.bounds.width - 280) / 2, y: view.bounds.height - 80, width: 280, height: 60))
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

    // MARK: - Scenario Builder

    func createArenaConfigSection(container: UIView, yPosition: CGFloat) -> UIView {
        let unitTypes = ArenaArmyConfiguration.availableUnitTypes
        let rowHeight: CGFloat = 50
        let headerHeight: CGFloat = 40
        let totalLabelHeight: CGFloat = 30
        let sectionPadding: CGFloat = 20
        let segmentRowHeight: CGFloat = 70

        // Pre-calculate heights
        let presetRowHeight: CGFloat = 50
        let commanderButtonRowHeight: CGFloat = 38
        let scenarioSettingsHeight = segmentRowHeight * 5 + 80 // 5 controls + garrison slider (commander moved to army sections)
        let armySectionHeight = headerHeight + commanderButtonRowHeight + (CGFloat(unitTypes.count) * rowHeight) + totalLabelHeight + sectionPadding
        let totalHeight = presetRowHeight + scenarioSettingsHeight + (armySectionHeight * 2) + sectionPadding * 3

        let sectionView = UIView(frame: CGRect(x: 20, y: yPosition, width: view.bounds.width - 40, height: totalHeight))
        sectionView.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        sectionView.layer.cornerRadius = 12
        container.addSubview(sectionView)

        let contentWidth = sectionView.bounds.width - 40
        var currentY: CGFloat = 10

        // ── SCENARIO PRESETS ──
        let presetHeader = UILabel(frame: CGRect(x: 20, y: currentY, width: contentWidth, height: 25))
        presetHeader.text = "SCENARIO PRESETS"
        presetHeader.font = UIFont.boldSystemFont(ofSize: 13)
        presetHeader.textColor = UIColor(white: 0.6, alpha: 1.0)
        sectionView.addSubview(presetHeader)
        currentY += 25

        let presetScroll = UIScrollView(frame: CGRect(x: 20, y: currentY, width: contentWidth, height: 36))
        presetScroll.showsHorizontalScrollIndicator = false
        sectionView.addSubview(presetScroll)

        var presetX: CGFloat = 0
        let presets = ArenaPreset.allCases.filter { $0 != .custom }
        for preset in presets {
            let btn = UIButton(frame: CGRect(x: presetX, y: 0, width: 0, height: 32))
            btn.setTitle(preset.rawValue, for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .medium)
            btn.backgroundColor = UIColor(white: 0.25, alpha: 1.0)
            btn.layer.cornerRadius = 8
            btn.contentEdgeInsets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
            btn.sizeToFit()
            btn.frame = CGRect(x: presetX, y: 0, width: btn.bounds.width + 20, height: 32)
            btn.addTarget(self, action: #selector(presetTapped(_:)), for: .touchUpInside)
            presetScroll.addSubview(btn)
            presetButtons.append(btn)
            presetX += btn.bounds.width + 8
        }
        presetScroll.contentSize = CGSize(width: presetX, height: 36)
        currentY += presetRowHeight - 10

        // ── SCENARIO SETTINGS ──
        let settingsHeader = UILabel(frame: CGRect(x: 20, y: currentY, width: contentWidth, height: 25))
        settingsHeader.text = "SCENARIO SETTINGS"
        settingsHeader.font = UIFont.boldSystemFont(ofSize: 13)
        settingsHeader.textColor = UIColor(white: 0.6, alpha: 1.0)
        sectionView.addSubview(settingsHeader)
        currentY += 30

        // Terrain
        currentY = addSegmentedRow(to: sectionView, y: currentY, label: "Terrain:",
                                   items: ["Plains", "Hill", "Mountain"], tag: 100)
        terrainControl = sectionView.viewWithTag(100) as? UISegmentedControl

        // Building
        currentY = addSegmentedRow(to: sectionView, y: currentY, label: "Building:",
                                   items: ["None", "Tower", "Fort", "Castle"], tag: 101)
        buildingControl = sectionView.viewWithTag(101) as? UISegmentedControl

        // Entrenchment
        currentY = addSegmentedRow(to: sectionView, y: currentY, label: "Entrench:",
                                   items: ["Off", "On"], tag: 102)
        entrenchmentControl = sectionView.viewWithTag(102) as? UISegmentedControl

        // Player Stacking
        currentY = addSegmentedRow(to: sectionView, y: currentY, label: "P. Stack:",
                                   items: ["Single", "Stacked", "Adjacent"], tag: 106)
        playerStackingControl = sectionView.viewWithTag(106) as? UISegmentedControl

        // Player army count (visible only when stacking is Stacked or Adjacent)
        let playerArmyCountLabel = UILabel(frame: CGRect(x: 20, y: currentY, width: 90, height: 30))
        playerArmyCountLabel.text = "P. Armies:"
        playerArmyCountLabel.font = UIFont.systemFont(ofSize: 14)
        playerArmyCountLabel.textColor = .white
        sectionView.addSubview(playerArmyCountLabel)

        playerArmyCountControl = UISegmentedControl(items: ["2", "3", "4", "5"])
        playerArmyCountControl.frame = CGRect(x: 110, y: currentY, width: contentWidth - 90, height: 30)
        playerArmyCountControl.selectedSegmentIndex = 0
        playerArmyCountControl.isHidden = true
        playerArmyCountControl.addTarget(self, action: #selector(scenarioControlChanged(_:)), for: .valueChanged)
        sectionView.addSubview(playerArmyCountControl)
        playerArmyCountLabel.tag = 201 // tag for show/hide with player army count control
        currentY += 42

        // Enemy Stacking
        currentY = addSegmentedRow(to: sectionView, y: currentY, label: "E. Stack:",
                                   items: ["Single", "Stacked", "Adjacent"], tag: 103)
        stackingControl = sectionView.viewWithTag(103) as? UISegmentedControl

        // Enemy army count (visible only when stacking is Stacked or Adjacent)
        let armyCountLabel = UILabel(frame: CGRect(x: 20, y: currentY, width: 90, height: 30))
        armyCountLabel.text = "E. Armies:"
        armyCountLabel.font = UIFont.systemFont(ofSize: 14)
        armyCountLabel.textColor = .white
        sectionView.addSubview(armyCountLabel)

        armyCountControl = UISegmentedControl(items: ["2", "3", "4", "5"])
        armyCountControl.frame = CGRect(x: 110, y: currentY, width: contentWidth - 90, height: 30)
        armyCountControl.selectedSegmentIndex = 0
        armyCountControl.isHidden = true
        armyCountControl.addTarget(self, action: #selector(scenarioControlChanged(_:)), for: .valueChanged)
        sectionView.addSubview(armyCountControl)
        armyCountLabel.tag = 200 // tag for show/hide with army count control
        currentY += 42

        // Garrison slider
        let garrisonLabelView = UILabel(frame: CGRect(x: 20, y: currentY, width: 80, height: 30))
        garrisonLabelView.text = "Garrison:"
        garrisonLabelView.font = UIFont.systemFont(ofSize: 14)
        garrisonLabelView.textColor = .white
        sectionView.addSubview(garrisonLabelView)

        garrisonSlider = UISlider(frame: CGRect(x: 100, y: currentY, width: contentWidth - 130, height: 30))
        garrisonSlider.minimumValue = 0
        garrisonSlider.maximumValue = 20
        garrisonSlider.value = 0
        garrisonSlider.isEnabled = false
        garrisonSlider.addTarget(self, action: #selector(garrisonSliderChanged(_:)), for: .valueChanged)
        sectionView.addSubview(garrisonSlider)

        garrisonLabel = UILabel(frame: CGRect(x: contentWidth - 20, y: currentY, width: 40, height: 30))
        garrisonLabel.text = "0"
        garrisonLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .bold)
        garrisonLabel.textColor = .white
        garrisonLabel.textAlignment = .right
        sectionView.addSubview(garrisonLabel)
        currentY += 45

        // Enemy AI
        currentY = addSegmentedRow(to: sectionView, y: currentY, label: "Enemy AI:",
                                   items: ["Off", "On"], tag: 106)
        enemyAIControl = sectionView.viewWithTag(106) as? UISegmentedControl
        enemyAIControl?.selectedSegmentIndex = 1  // default On

        // ── YOUR ARMY ──
        let playerHeader = UILabel(frame: CGRect(x: 20, y: currentY, width: contentWidth, height: headerHeight))
        playerHeader.text = "YOUR ARMY"
        playerHeader.font = UIFont.boldSystemFont(ofSize: 16)
        playerHeader.textColor = UIColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1.0)
        sectionView.addSubview(playerHeader)
        currentY += headerHeight

        // Player commander button
        currentY = addCommanderButtonRow(to: sectionView, y: currentY, label: "Commander:", isPlayer: true)

        for unitType in unitTypes {
            let row = createUnitSliderRow(in: sectionView, yPosition: currentY, unitType: unitType,
                                          initialValue: arenaArmyConfig.playerArmy[unitType] ?? 0, isPlayer: true)
            playerArmySliders[unitType] = row.slider
            playerArmyLabels[unitType] = row.countLabel
            playerTierControls[unitType] = row.tierControl
            currentY += rowHeight
        }

        let playerTotal = UILabel(frame: CGRect(x: 20, y: currentY, width: contentWidth, height: totalLabelHeight))
        playerTotal.font = UIFont.boldSystemFont(ofSize: 14)
        playerTotal.textColor = .white
        sectionView.addSubview(playerTotal)
        playerTotalLabel = playerTotal
        currentY += totalLabelHeight + sectionPadding

        // ── ENEMY ARMY ──
        let enemyHeader = UILabel(frame: CGRect(x: 20, y: currentY, width: contentWidth, height: headerHeight))
        enemyHeader.text = "ENEMY ARMY"
        enemyHeader.font = UIFont.boldSystemFont(ofSize: 16)
        enemyHeader.textColor = UIColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1.0)
        sectionView.addSubview(enemyHeader)
        currentY += headerHeight

        // Enemy commander button
        currentY = addCommanderButtonRow(to: sectionView, y: currentY, label: "Commander:", isPlayer: false)

        for unitType in unitTypes {
            let row = createUnitSliderRow(in: sectionView, yPosition: currentY, unitType: unitType,
                                          initialValue: arenaArmyConfig.enemyArmy[unitType] ?? 0, isPlayer: false)
            enemyArmySliders[unitType] = row.slider
            enemyArmyLabels[unitType] = row.countLabel
            enemyTierControls[unitType] = row.tierControl
            currentY += rowHeight
        }

        let enemyTotal = UILabel(frame: CGRect(x: 20, y: currentY, width: contentWidth, height: totalLabelHeight))
        enemyTotal.font = UIFont.boldSystemFont(ofSize: 14)
        enemyTotal.textColor = .white
        sectionView.addSubview(enemyTotal)
        enemyTotalLabel = enemyTotal
        currentY += totalLabelHeight + sectionPadding

        // ── RUN COUNT + LAUNCH BUTTONS ──
        let rcLabel = UILabel(frame: CGRect(x: 20, y: currentY, width: 55, height: 30))
        rcLabel.text = "Runs:"
        rcLabel.font = UIFont.boldSystemFont(ofSize: 14)
        rcLabel.textColor = .white
        sectionView.addSubview(rcLabel)

        runCountSlider = UISlider(frame: CGRect(x: 75, y: currentY, width: contentWidth - 100, height: 30))
        runCountSlider.minimumValue = 1
        runCountSlider.maximumValue = 50
        runCountSlider.value = 1
        runCountSlider.minimumTrackTintColor = UIColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 1.0)
        runCountSlider.addTarget(self, action: #selector(runCountChanged(_:)), for: .valueChanged)
        sectionView.addSubview(runCountSlider)

        runCountLabel = UILabel(frame: CGRect(x: contentWidth - 15, y: currentY, width: 50, height: 30))
        runCountLabel.text = "1"
        runCountLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .bold)
        runCountLabel.textColor = .white
        runCountLabel.textAlignment = .right
        sectionView.addSubview(runCountLabel)
        currentY += 40

        let buttonWidth = (contentWidth - 10) / 2
        playButton = UIButton(frame: CGRect(x: 20, y: currentY, width: buttonWidth, height: 50))
        playButton.setTitle("Play", for: .normal)
        playButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 20)
        playButton.backgroundColor = UIColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
        playButton.layer.cornerRadius = 12
        playButton.addTarget(self, action: #selector(playTapped), for: .touchUpInside)
        sectionView.addSubview(playButton)

        autoSimButton = UIButton(frame: CGRect(x: 30 + buttonWidth, y: currentY, width: buttonWidth, height: 50))
        autoSimButton.setTitle("Auto-Sim", for: .normal)
        autoSimButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 20)
        autoSimButton.backgroundColor = UIColor(red: 0.2, green: 0.5, blue: 0.9, alpha: 1.0)
        autoSimButton.layer.cornerRadius = 12
        autoSimButton.addTarget(self, action: #selector(autoSimTapped), for: .touchUpInside)
        sectionView.addSubview(autoSimButton)
        currentY += 70

        // Resize section to actual content
        sectionView.frame = CGRect(x: 20, y: yPosition, width: view.bounds.width - 40, height: currentY)

        updateArmyTotals()
        applyPreset(.plains)

        return sectionView
    }

    func addSegmentedRow(to container: UIView, y: CGFloat, label: String, items: [String], tag: Int) -> CGFloat {
        let contentWidth = container.bounds.width - 40
        let lbl = UILabel(frame: CGRect(x: 20, y: y, width: 90, height: 30))
        lbl.text = label
        lbl.font = UIFont.systemFont(ofSize: 14)
        lbl.textColor = .white
        container.addSubview(lbl)

        let seg = UISegmentedControl(items: items)
        seg.frame = CGRect(x: 110, y: y, width: contentWidth - 90, height: 30)
        seg.selectedSegmentIndex = 0
        seg.tag = tag
        seg.addTarget(self, action: #selector(scenarioControlChanged(_:)), for: .valueChanged)
        container.addSubview(seg)

        return y + 42
    }

    // MARK: - Unit Slider Row

    func createUnitSliderRow(in container: UIView, yPosition: CGFloat, unitType: MilitaryUnitTypeData, initialValue: Int, isPlayer: Bool) -> (slider: UISlider, countLabel: UILabel, tierControl: UISegmentedControl) {
        let padding: CGFloat = 20
        let labelWidth: CGFloat = 100
        let tierWidth: CGFloat = 65
        let countWidth: CGFloat = 30
        let gapSmall: CGFloat = 6
        let sliderWidth = container.bounds.width - labelWidth - tierWidth - countWidth - (padding * 2) - (gapSmall * 3)

        let nameLabel = UILabel(frame: CGRect(x: padding, y: yPosition, width: labelWidth, height: 40))
        nameLabel.text = "\(unitType.icon) \(unitType.displayName)"
        nameLabel.font = UIFont.systemFont(ofSize: 13)
        nameLabel.textColor = .white
        container.addSubview(nameLabel)

        let tierControl = UISegmentedControl(items: ["0", "1", "2"])
        tierControl.frame = CGRect(x: padding + labelWidth + gapSmall, y: yPosition + 5, width: tierWidth, height: 28)
        tierControl.selectedSegmentIndex = 0
        let tierFont = UIFont.systemFont(ofSize: 11)
        tierControl.setTitleTextAttributes([.font: tierFont], for: .normal)
        tierControl.selectedSegmentTintColor = isPlayer
            ? UIColor(red: 0.2, green: 0.6, blue: 0.2, alpha: 1.0)
            : UIColor(red: 0.7, green: 0.2, blue: 0.2, alpha: 1.0)
        tierControl.addTarget(self, action: #selector(tierControlChanged(_:)), for: .valueChanged)
        container.addSubview(tierControl)

        let sliderX = padding + labelWidth + gapSmall + tierWidth + gapSmall
        let slider = UISlider(frame: CGRect(x: sliderX, y: yPosition + 5, width: sliderWidth, height: 30))
        slider.minimumValue = 0
        slider.maximumValue = Float(ArenaArmyConfiguration.maxUnitsPerType)
        slider.value = Float(initialValue)
        slider.minimumTrackTintColor = isPlayer ? UIColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1.0) : UIColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1.0)
        slider.addTarget(self, action: #selector(armySliderChanged(_:)), for: .valueChanged)
        container.addSubview(slider)

        let countLabel = UILabel(frame: CGRect(x: container.bounds.width - countWidth - padding, y: yPosition, width: countWidth, height: 40))
        countLabel.text = "\(initialValue)"
        countLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .bold)
        countLabel.textColor = .white
        countLabel.textAlignment = .right
        container.addSubview(countLabel)

        return (slider, countLabel, tierControl)
    }

    // MARK: - Section Helper

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

    // MARK: - Commander Button

    func addCommanderButtonRow(to container: UIView, y: CGFloat, label: String, isPlayer: Bool) -> CGFloat {
        let contentWidth = container.bounds.width - 40
        let lbl = UILabel(frame: CGRect(x: 20, y: y, width: 90, height: 30))
        lbl.text = label
        lbl.font = UIFont.systemFont(ofSize: 14)
        lbl.textColor = .white
        container.addSubview(lbl)

        let btn = UIButton(type: .system)
        btn.frame = CGRect(x: 110, y: y, width: contentWidth - 90, height: 30)
        let specialty: CommanderSpecialtyData = isPlayer ? scenarioConfig.playerCommanderSpecialty : scenarioConfig.enemyCommanderSpecialty
        btn.setTitle(shortName(for: specialty), for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        btn.setTitleColor(.white, for: .normal)
        btn.backgroundColor = UIColor(white: 0.25, alpha: 1.0)
        btn.layer.cornerRadius = 6
        btn.contentHorizontalAlignment = .center
        if isPlayer {
            playerCommanderButton = btn
            btn.addTarget(self, action: #selector(playerCommanderTapped), for: .touchUpInside)
        } else {
            enemyCommanderButton = btn
            btn.addTarget(self, action: #selector(enemyCommanderTapped), for: .touchUpInside)
        }
        container.addSubview(btn)

        // Commander level row
        let lvlY = y + 34
        let lvlLabel = UILabel(frame: CGRect(x: 20, y: lvlY, width: 70, height: 30))
        lvlLabel.text = "Cmdr Lvl:"
        lvlLabel.font = UIFont.systemFont(ofSize: 13)
        lvlLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        container.addSubview(lvlLabel)

        let levelItems = ["1 Rec", "5 Sgt", "10 Cpt", "15 Maj", "20 Col", "25 Gen"]
        let lvlControl = UISegmentedControl(items: levelItems)
        lvlControl.frame = CGRect(x: 90, y: lvlY, width: contentWidth - 70, height: 28)
        lvlControl.selectedSegmentIndex = 0
        let lvlFont = UIFont.systemFont(ofSize: 10)
        lvlControl.setTitleTextAttributes([.font: lvlFont, .foregroundColor: UIColor.lightGray], for: .normal)
        lvlControl.setTitleTextAttributes([.font: lvlFont, .foregroundColor: UIColor.white], for: .selected)
        lvlControl.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        lvlControl.selectedSegmentTintColor = UIColor(white: 0.35, alpha: 1.0)
        lvlControl.addTarget(self, action: #selector(commanderLevelChanged(_:)), for: .valueChanged)
        container.addSubview(lvlControl)

        if isPlayer {
            playerCommanderLevelControl = lvlControl
        } else {
            enemyCommanderLevelControl = lvlControl
        }

        return y + 68
    }

    private static let commanderLevelValues = [1, 5, 10, 15, 20, 25]

    @objc func commanderLevelChanged(_ sender: UISegmentedControl) {
        let levels = GameSetupViewController.commanderLevelValues
        let level = levels[sender.selectedSegmentIndex]
        if sender === playerCommanderLevelControl {
            scenarioConfig.playerCommanderLevel = level
        } else if sender === enemyCommanderLevelControl {
            scenarioConfig.enemyCommanderLevel = level
        }
        selectedPreset = .custom
        highlightPresetButton(.custom)
    }

    func shortName(for specialty: CommanderSpecialtyData) -> String {
        switch specialty {
        case .infantryAggressive: return "Inf Aggressive"
        case .infantryDefensive: return "Inf Defensive"
        case .cavalryAggressive: return "Cav Aggressive"
        case .cavalryDefensive: return "Cav Defensive"
        case .rangedAggressive: return "Rng Aggressive"
        case .rangedDefensive: return "Rng Defensive"
        case .siegeAggressive: return "Siege Aggressive"
        case .siegeDefensive: return "Siege Defensive"
        case .defensive: return "Defensive"
        case .logistics: return "Logistics"
        }
    }

    @objc func playerCommanderTapped() {
        showCommanderPicker(isPlayer: true)
    }

    @objc func enemyCommanderTapped() {
        showCommanderPicker(isPlayer: false)
    }

    func showCommanderPicker(isPlayer: Bool) {
        let alert = UIAlertController(title: isPlayer ? "Player Commander" : "Enemy Commander", message: nil, preferredStyle: .actionSheet)
        for specialty in CommanderSpecialtyData.allCases {
            alert.addAction(UIAlertAction(title: "\(specialty.icon) \(shortName(for: specialty))", style: .default) { [weak self] _ in
                guard let self = self else { return }
                if isPlayer {
                    self.scenarioConfig.playerCommanderSpecialty = specialty
                    self.playerCommanderButton?.setTitle(self.shortName(for: specialty), for: .normal)
                } else {
                    self.scenarioConfig.enemyCommanderSpecialty = specialty
                    self.enemyCommanderButton?.setTitle(self.shortName(for: specialty), for: .normal)
                }
                self.selectedPreset = .custom
                self.highlightPresetButton(.custom)
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            let button = isPlayer ? playerCommanderButton! : enemyCommanderButton!
            popover.sourceView = button
            popover.sourceRect = button.bounds
        }

        present(alert, animated: true)
    }

    // MARK: - Actions

    @objc func armySliderChanged(_ sender: UISlider) {
        let value = Int(sender.value.rounded())

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

    @objc func tierControlChanged(_ sender: UISegmentedControl) {
        // Read all tier controls into config
        scenarioConfig.playerUnitTiers = [:]
        for (unitType, control) in playerTierControls {
            let tier = control.selectedSegmentIndex
            if tier > 0 { scenarioConfig.playerUnitTiers[unitType] = tier }
        }
        scenarioConfig.enemyUnitTiers = [:]
        for (unitType, control) in enemyTierControls {
            let tier = control.selectedSegmentIndex
            if tier > 0 { scenarioConfig.enemyUnitTiers[unitType] = tier }
        }
        selectedPreset = .custom
        highlightPresetButton(.custom)
    }

    func updateArmyTotals() {
        let playerTotal = arenaArmyConfig.playerArmy.values.reduce(0, +)
        let enemyTotal = arenaArmyConfig.enemyArmy.values.reduce(0, +)

        playerTotalLabel?.text = "Total: \(playerTotal) units"
        enemyTotalLabel?.text = "Total: \(enemyTotal) units"
    }

    @objc func presetTapped(_ sender: UIButton) {
        guard let title = sender.title(for: .normal),
              let preset = ArenaPreset.allCases.first(where: { $0.rawValue == title }) else { return }
        applyPreset(preset)
    }

    func applyPreset(_ preset: ArenaPreset) {
        selectedPreset = preset
        scenarioConfig = preset.toConfig()
        syncControlsToConfig()
        highlightPresetButton(preset)
    }

    func highlightPresetButton(_ preset: ArenaPreset) {
        for btn in presetButtons {
            let isSelected = btn.title(for: .normal) == preset.rawValue
            btn.backgroundColor = isSelected ? UIColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 1.0) : UIColor(white: 0.25, alpha: 1.0)
        }
    }

    func syncControlsToConfig() {
        // Terrain
        switch scenarioConfig.enemyTerrain {
        case .plains: terrainControl?.selectedSegmentIndex = 0
        case .hill: terrainControl?.selectedSegmentIndex = 1
        case .mountain: terrainControl?.selectedSegmentIndex = 2
        default: terrainControl?.selectedSegmentIndex = 0
        }

        // Building
        switch scenarioConfig.enemyBuilding {
        case nil: buildingControl?.selectedSegmentIndex = 0
        case .tower: buildingControl?.selectedSegmentIndex = 1
        case .woodenFort: buildingControl?.selectedSegmentIndex = 2
        case .castle: buildingControl?.selectedSegmentIndex = 3
        default: buildingControl?.selectedSegmentIndex = 0
        }

        // Entrenchment
        entrenchmentControl?.selectedSegmentIndex = scenarioConfig.enemyEntrenched ? 1 : 0

        // Enemy AI
        enemyAIControl?.selectedSegmentIndex = scenarioConfig.enemyAIEnabled ? 1 : 0

        // Player stacking + army count
        let playerArmyCountLabelView = arenaConfigSection?.viewWithTag(201)
        switch scenarioConfig.playerArmyCount {
        case 1:
            playerStackingControl?.selectedSegmentIndex = 0
            playerArmyCountControl?.isHidden = true
            playerArmyCountLabelView?.isHidden = true
        case 2...5:
            playerStackingControl?.selectedSegmentIndex = 1
            playerArmyCountControl?.selectedSegmentIndex = abs(scenarioConfig.playerArmyCount) - 2
            playerArmyCountControl?.isHidden = false
            playerArmyCountLabelView?.isHidden = false
        case -5...(-2):
            playerStackingControl?.selectedSegmentIndex = 2
            playerArmyCountControl?.selectedSegmentIndex = abs(scenarioConfig.playerArmyCount) - 2
            playerArmyCountControl?.isHidden = false
            playerArmyCountLabelView?.isHidden = false
        default:
            playerStackingControl?.selectedSegmentIndex = 0
            playerArmyCountControl?.isHidden = true
            playerArmyCountLabelView?.isHidden = true
        }

        // Enemy stacking + army count
        let armyCountLabelView = arenaConfigSection?.viewWithTag(200)
        switch scenarioConfig.enemyArmyCount {
        case 1:
            stackingControl?.selectedSegmentIndex = 0
            armyCountControl?.isHidden = true
            armyCountLabelView?.isHidden = true
        case 2...5:
            stackingControl?.selectedSegmentIndex = 1
            armyCountControl?.selectedSegmentIndex = abs(scenarioConfig.enemyArmyCount) - 2
            armyCountControl?.isHidden = false
            armyCountLabelView?.isHidden = false
        case -5...(-2):
            stackingControl?.selectedSegmentIndex = 2
            armyCountControl?.selectedSegmentIndex = abs(scenarioConfig.enemyArmyCount) - 2
            armyCountControl?.isHidden = false
            armyCountLabelView?.isHidden = false
        default:
            stackingControl?.selectedSegmentIndex = 0
            armyCountControl?.isHidden = true
            armyCountLabelView?.isHidden = true
        }

        // Commander buttons
        playerCommanderButton?.setTitle(shortName(for: scenarioConfig.playerCommanderSpecialty), for: .normal)
        enemyCommanderButton?.setTitle(shortName(for: scenarioConfig.enemyCommanderSpecialty), for: .normal)

        // Commander levels
        let levels = GameSetupViewController.commanderLevelValues
        playerCommanderLevelControl?.selectedSegmentIndex = levels.firstIndex(of: scenarioConfig.playerCommanderLevel) ?? 0
        enemyCommanderLevelControl?.selectedSegmentIndex = levels.firstIndex(of: scenarioConfig.enemyCommanderLevel) ?? 0

        // Per-unit tiers
        for (unitType, control) in playerTierControls {
            control.selectedSegmentIndex = scenarioConfig.playerUnitTiers[unitType] ?? 0
        }
        for (unitType, control) in enemyTierControls {
            control.selectedSegmentIndex = scenarioConfig.enemyUnitTiers[unitType] ?? 0
        }

        // Garrison
        garrisonSlider?.value = Float(scenarioConfig.garrisonArchers)
        garrisonLabel?.text = "\(scenarioConfig.garrisonArchers)"
        garrisonSlider?.isEnabled = scenarioConfig.enemyBuilding != nil
    }

    @objc func scenarioControlChanged(_ sender: UISegmentedControl) {
        // Update config from controls
        readConfigFromControls()
        selectedPreset = .custom
        highlightPresetButton(.custom)
    }

    func readConfigFromControls() {
        // Terrain
        switch terrainControl?.selectedSegmentIndex {
        case 0: scenarioConfig.enemyTerrain = .plains
        case 1: scenarioConfig.enemyTerrain = .hill
        case 2: scenarioConfig.enemyTerrain = .mountain
        default: scenarioConfig.enemyTerrain = .plains
        }

        // Building
        switch buildingControl?.selectedSegmentIndex {
        case 0: scenarioConfig.enemyBuilding = nil
        case 1: scenarioConfig.enemyBuilding = .tower
        case 2: scenarioConfig.enemyBuilding = .woodenFort
        case 3: scenarioConfig.enemyBuilding = .castle
        default: scenarioConfig.enemyBuilding = nil
        }

        // Entrenchment
        scenarioConfig.enemyEntrenched = entrenchmentControl?.selectedSegmentIndex == 1

        // Enemy AI
        scenarioConfig.enemyAIEnabled = enemyAIControl?.selectedSegmentIndex == 1

        // Player stacking + army count
        let playerArmyCountLabelView = arenaConfigSection?.viewWithTag(201)
        switch playerStackingControl?.selectedSegmentIndex {
        case 0:
            scenarioConfig.playerArmyCount = 1
            playerArmyCountControl?.isHidden = true
            playerArmyCountLabelView?.isHidden = true
        case 1:
            scenarioConfig.playerArmyCount = (playerArmyCountControl?.selectedSegmentIndex ?? 0) + 2
            playerArmyCountControl?.isHidden = false
            playerArmyCountLabelView?.isHidden = false
        case 2:
            scenarioConfig.playerArmyCount = -((playerArmyCountControl?.selectedSegmentIndex ?? 0) + 2)
            playerArmyCountControl?.isHidden = false
            playerArmyCountLabelView?.isHidden = false
        default:
            scenarioConfig.playerArmyCount = 1
            playerArmyCountControl?.isHidden = true
            playerArmyCountLabelView?.isHidden = true
        }

        // Enemy stacking + army count
        let armyCountLabelView = arenaConfigSection?.viewWithTag(200)
        switch stackingControl?.selectedSegmentIndex {
        case 0:
            scenarioConfig.enemyArmyCount = 1
            armyCountControl?.isHidden = true
            armyCountLabelView?.isHidden = true
        case 1:
            scenarioConfig.enemyArmyCount = (armyCountControl?.selectedSegmentIndex ?? 0) + 2
            armyCountControl?.isHidden = false
            armyCountLabelView?.isHidden = false
        case 2:
            scenarioConfig.enemyArmyCount = -((armyCountControl?.selectedSegmentIndex ?? 0) + 2)
            armyCountControl?.isHidden = false
            armyCountLabelView?.isHidden = false
        default:
            scenarioConfig.enemyArmyCount = 1
            armyCountControl?.isHidden = true
            armyCountLabelView?.isHidden = true
        }

        // Commander: buttons update config directly via action sheet callbacks
        // Commander levels: segment controls update config directly via commanderLevelChanged

        // Per-unit tiers
        scenarioConfig.playerUnitTiers = [:]
        for (unitType, control) in playerTierControls {
            let tier = control.selectedSegmentIndex
            if tier > 0 { scenarioConfig.playerUnitTiers[unitType] = tier }
        }
        scenarioConfig.enemyUnitTiers = [:]
        for (unitType, control) in enemyTierControls {
            let tier = control.selectedSegmentIndex
            if tier > 0 { scenarioConfig.enemyUnitTiers[unitType] = tier }
        }

        // Garrison enable/disable
        garrisonSlider?.isEnabled = scenarioConfig.enemyBuilding != nil
        if scenarioConfig.enemyBuilding == nil {
            scenarioConfig.garrisonArchers = 0
            garrisonSlider?.value = 0
            garrisonLabel?.text = "0"
        }
    }

    @objc func garrisonSliderChanged(_ sender: UISlider) {
        let value = Int(sender.value.rounded())
        scenarioConfig.garrisonArchers = value
        garrisonLabel?.text = "\(value)"
        selectedPreset = .custom
        highlightPresetButton(.custom)
    }

    @objc func runCountChanged(_ sender: UISlider) {
        simRunCount = Int(sender.value.rounded())
        runCountLabel?.text = "\(simRunCount)"
    }

    @objc func gameModeTapped(_ sender: UISegmentedControl) {
        selectedGameMode = sender.selectedSegmentIndex == 0 ? .offline : .online
    }

    @objc func segmentChanged(_ sender: UISegmentedControl) {
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
        let showRandomOptions = selectedMapType == .random
        let showArenaOptions = selectedMapType == .arena

        UIView.animate(withDuration: 0.3) {
            self.mapSizeSection?.alpha = showRandomOptions ? 1.0 : 0.3
            self.resourceDensitySection?.alpha = showRandomOptions ? 1.0 : 0.3
            self.arenaConfigSection?.alpha = showArenaOptions ? 1.0 : 0.0
            self.arenaConfigSection?.isHidden = !showArenaOptions
            // Hide game mode toggle for arena (always offline)
            self.gameModeSection?.alpha = showArenaOptions ? 0.3 : 1.0
        }
        mapSizeSegmentedControl?.isEnabled = showRandomOptions
        resourceDensitySegmentedControl?.isEnabled = showRandomOptions
        gameModeSegmentedControl?.isEnabled = !showArenaOptions

        // Force offline for arena
        if showArenaOptions {
            selectedGameMode = .offline
            gameModeSegmentedControl?.selectedSegmentIndex = 0
        }

        for slider in playerArmySliders.values { slider.isEnabled = showArenaOptions }
        for slider in enemyArmySliders.values { slider.isEnabled = showArenaOptions }

        // Toggle bottom button
        startButton?.isHidden = showArenaOptions
    }

    // MARK: - Launch Actions

    @objc func startGameTapped() {
        let gameVC = GameViewController()
        gameVC.mapType = selectedMapType
        gameVC.mapSize = selectedMapSize
        gameVC.resourceDensity = selectedResourceDensity
        gameVC.visibilityMode = selectedVisibilityMode
        if selectedMapType == .arena {
            gameVC.arenaArmyConfig = arenaArmyConfig
            gameVC.arenaScenarioConfig = scenarioConfig
        }

        // Set game mode on GameViewController
        gameVC.isOnlineMode = (selectedGameMode == .online)

        // Only create online session when explicitly in online mode
        if selectedGameMode == .online, AuthService.shared.currentUser != nil {
            let seed = UInt64.random(in: 1...UInt64.max)
            gameVC.mapSeed = seed
            let mapConfig = MapGenerationConfig.fromArabia(seed: seed)
            let hostPlayerID = UUID()
            let aiPlayerID = UUID()

            GameSessionService.shared.createGame(
                mapConfig: mapConfig,
                aiPlayers: [(displayName: "Enemy", playerID: aiPlayerID, colorHex: "FF0000")],
                hostPlayerID: hostPlayerID,
                hostColorHex: "0000FF"
            ) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let session):
                        debugLog("Online session created: \(session.gameID)")
                        gameVC.onlineGameID = session.gameID
                    case .failure(let error):
                        debugLog("Failed to create online session: \(error.localizedDescription)")
                        gameVC.isOnlineMode = false
                    }
                    gameVC.modalPresentationStyle = .fullScreen
                    self.present(gameVC, animated: true)
                }
            }
        } else {
            gameVC.modalPresentationStyle = .fullScreen
            present(gameVC, animated: true)
        }
    }

    @objc func playTapped() {
        let gameVC = GameViewController()
        gameVC.mapType = .arena
        gameVC.mapSize = selectedMapSize
        gameVC.resourceDensity = selectedResourceDensity
        gameVC.visibilityMode = selectedVisibilityMode
        gameVC.arenaArmyConfig = arenaArmyConfig
        gameVC.arenaScenarioConfig = scenarioConfig
        gameVC.modalPresentationStyle = .fullScreen
        present(gameVC, animated: true)
    }

    @objc func autoSimTapped() {
        if simRunCount > 1 {
            // Batch simulation — headless
            let loadingAlert = UIAlertController(title: "Simulating...", message: "Running \(simRunCount) battles", preferredStyle: .alert)
            present(loadingAlert, animated: true)

            ArenaSimulator.runBatch(armyConfig: arenaArmyConfig, scenarioConfig: scenarioConfig, runs: simRunCount) { [weak self] results in
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        guard let self = self else { return }
                        let resultsVC = ArenaResultsViewController()
                        resultsVC.batchResults = results
                        resultsVC.scenarioConfig = self.scenarioConfig
                        resultsVC.modalPresentationStyle = .fullScreen
                        self.present(resultsVC, animated: true)
                    }
                }
            }
        } else {
            // Single auto-sim — visual with fast speed
            let gameVC = GameViewController()
            gameVC.mapType = .arena
            gameVC.mapSize = selectedMapSize
            gameVC.resourceDensity = selectedResourceDensity
            gameVC.visibilityMode = selectedVisibilityMode
            gameVC.arenaArmyConfig = arenaArmyConfig
            gameVC.arenaScenarioConfig = scenarioConfig
            gameVC.autoSimMode = true
            gameVC.simRunCount = 1
            gameVC.modalPresentationStyle = .fullScreen
            present(gameVC, animated: true)
        }
    }

    @objc func backTapped() {
        dismiss(animated: true)
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
