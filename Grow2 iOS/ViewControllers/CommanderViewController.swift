import UIKit

class CommandersViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var player: Player?
    var selectedCommander: Commander?
    weak var hexMap: HexMap?
    weak var gameScene: GameScene?
    
    // UI Elements
    var tableView: UITableView!
    var detailView: UIView!
    var closeButton: UIButton!
    
    // Detail View Labels
    var commanderNameLabel: UILabel!
    var rankLabel: UILabel!
    var specialtyLabel: UILabel!
    var levelLabel: UILabel!
    var xpLabel: UILabel!
    var xpProgressBar: UIView!
    var leadershipLabel: UILabel!
    var tacticsLabel: UILabel!
    var logisticsLabel: UILabel!
    var rationingLabel: UILabel!
    var enduranceLabel: UILabel!
    var leadershipBenefitLabel: UILabel!
    var tacticsBenefitLabel: UILabel!
    var logisticsBenefitLabel: UILabel!
    var rationingBenefitLabel: UILabel!
    var enduranceBenefitLabel: UILabel!
    var armyLabel: UILabel!
    var locationLabel: UILabel!
    var homeBaseLabel: UILabel!
    var portraitView: UIView!
    var recruitButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        // Select first commander by default
        if let firstCommander = player?.commanders.first {
            selectedCommander = firstCommander
            updateDetailView()
        }
    }
    
    func setupUI() {
        view.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        
        // Title
        let titleLabel = UILabel(frame: CGRect(x: 20, y: 50, width: view.bounds.width - 40, height: 40))
        titleLabel.text = "👤 Commanders"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 28)
        titleLabel.textColor = .white
        view.addSubview(titleLabel)
        
        // Close button
        closeButton = UIButton(frame: CGRect(x: view.bounds.width - 70, y: 50, width: 50, height: 40))
        closeButton.setTitle("✕", for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 24)
        closeButton.addTarget(self, action: #selector(closeScreen), for: .touchUpInside)
        view.addSubview(closeButton)
        
        recruitButton = UIButton(frame: CGRect(x: 20, y: 50, width: 160, height: 40))
        recruitButton.setTitle("➕ Recruit Commander", for: .normal)
        recruitButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        recruitButton.backgroundColor = UIColor(red: 0.2, green: 0.6, blue: 0.3, alpha: 1.0)
        recruitButton.layer.cornerRadius = 8
        recruitButton.addTarget(self, action: #selector(recruitCommanderTapped), for: .touchUpInside)
        view.addSubview(recruitButton)
        
        // Left sidebar - Commander list
        let sidebarWidth: CGFloat = 280
        let sidebarView = UIView(frame: CGRect(x: 0, y: 100, width: sidebarWidth, height: view.bounds.height - 100))
        sidebarView.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        view.addSubview(sidebarView)
        
        tableView = UITableView(frame: sidebarView.bounds, style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .clear
        tableView.separatorColor = UIColor(white: 0.3, alpha: 1.0)
        tableView.register(CommanderCell.self, forCellReuseIdentifier: "CommanderCell")
        sidebarView.addSubview(tableView)
        
        // Right side - Detail view
        detailView = UIView(frame: CGRect(x: sidebarWidth + 20, y: 100, width: view.bounds.width - sidebarWidth - 40, height: view.bounds.height - 120))
        detailView.backgroundColor = UIColor(white: 0.25, alpha: 1.0)
        detailView.layer.cornerRadius = 12
        view.addSubview(detailView)
        
        setupDetailView()
    }
    
    func setupDetailView() {
        // Portrait
        portraitView = UIView(frame: CGRect(x: 20, y: 20, width: 100, height: 100))
        portraitView.layer.cornerRadius = 50
        portraitView.backgroundColor = .blue
        portraitView.layer.borderWidth = 3
        portraitView.layer.borderColor = UIColor.white.cgColor
        detailView.addSubview(portraitView)
        
        // Commander Name
        commanderNameLabel = UILabel(frame: CGRect(x: 140, y: 20, width: detailView.bounds.width - 160, height: 35))
        commanderNameLabel.font = UIFont.boldSystemFont(ofSize: 28)
        commanderNameLabel.textColor = .white
        commanderNameLabel.text = "Select a Commander"
        detailView.addSubview(commanderNameLabel)
        
        // Rank
        rankLabel = UILabel(frame: CGRect(x: 140, y: 60, width: detailView.bounds.width - 160, height: 25))
        rankLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        rankLabel.textColor = UIColor(white: 0.9, alpha: 1.0)
        rankLabel.text = "⭐ Recruit"
        detailView.addSubview(rankLabel)
        
        // Specialty
        specialtyLabel = UILabel(frame: CGRect(x: 140, y: 90, width: detailView.bounds.width - 160, height: 25))
        specialtyLabel.font = UIFont.systemFont(ofSize: 16)
        specialtyLabel.textColor = UIColor(white: 0.8, alpha: 1.0)
        specialtyLabel.text = "🗡️ Infantry Specialist"
        detailView.addSubview(specialtyLabel)
        
        // Divider
        let divider1 = UIView(frame: CGRect(x: 20, y: 140, width: detailView.bounds.width - 40, height: 1))
        divider1.backgroundColor = UIColor(white: 0.4, alpha: 1.0)
        detailView.addSubview(divider1)
        
        // Level & XP Section
        let levelTitleLabel = UILabel(frame: CGRect(x: 20, y: 160, width: 200, height: 25))
        levelTitleLabel.text = "Level & Experience"
        levelTitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        levelTitleLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        detailView.addSubview(levelTitleLabel)
        
        levelLabel = UILabel(frame: CGRect(x: 20, y: 190, width: 100, height: 30))
        levelLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        levelLabel.textColor = .white
        levelLabel.text = "Level 1"
        detailView.addSubview(levelLabel)
        
        xpLabel = UILabel(frame: CGRect(x: 130, y: 195, width: 200, height: 25))
        xpLabel.font = UIFont.systemFont(ofSize: 16)
        xpLabel.textColor = UIColor(white: 0.8, alpha: 1.0)
        xpLabel.text = "0 / 100 XP"
        detailView.addSubview(xpLabel)
        
        // XP Progress Bar
        let progressBarBg = UIView(frame: CGRect(x: 20, y: 230, width: detailView.bounds.width - 40, height: 20))
        progressBarBg.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        progressBarBg.layer.cornerRadius = 10
        detailView.addSubview(progressBarBg)
        
        xpProgressBar = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 20))
        xpProgressBar.backgroundColor = UIColor(red: 0.3, green: 0.7, blue: 0.3, alpha: 1.0)
        xpProgressBar.layer.cornerRadius = 10
        progressBarBg.addSubview(xpProgressBar)
        
        // Divider
        let divider2 = UIView(frame: CGRect(x: 20, y: 270, width: detailView.bounds.width - 40, height: 1))
        divider2.backgroundColor = UIColor(white: 0.4, alpha: 1.0)
        detailView.addSubview(divider2)
        
        // Stats Section
        let statsTitleLabel = UILabel(frame: CGRect(x: 20, y: 290, width: 200, height: 25))
        statsTitleLabel.text = "Commander Stats"
        statsTitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        statsTitleLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        detailView.addSubview(statsTitleLabel)
        
        let benefitX: CGFloat = 220
        let benefitWidth: CGFloat = detailView.bounds.width - benefitX - 20
        let benefitColor = UIColor(red: 0.5, green: 0.85, blue: 0.5, alpha: 1.0)

        leadershipLabel = UILabel(frame: CGRect(x: 20, y: 325, width: 200, height: 25))
        leadershipLabel.font = UIFont.systemFont(ofSize: 18)
        leadershipLabel.textColor = .white
        leadershipLabel.text = "👑 Leadership: 10"
        detailView.addSubview(leadershipLabel)

        leadershipBenefitLabel = UILabel(frame: CGRect(x: benefitX, y: 325, width: benefitWidth, height: 25))
        leadershipBenefitLabel.font = UIFont.systemFont(ofSize: 14)
        leadershipBenefitLabel.textColor = benefitColor
        detailView.addSubview(leadershipBenefitLabel)

        tacticsLabel = UILabel(frame: CGRect(x: 20, y: 355, width: 200, height: 25))
        tacticsLabel.font = UIFont.systemFont(ofSize: 18)
        tacticsLabel.textColor = .white
        tacticsLabel.text = "🎯 Tactics: 10"
        detailView.addSubview(tacticsLabel)

        tacticsBenefitLabel = UILabel(frame: CGRect(x: benefitX, y: 355, width: benefitWidth, height: 25))
        tacticsBenefitLabel.font = UIFont.systemFont(ofSize: 14)
        tacticsBenefitLabel.textColor = benefitColor
        detailView.addSubview(tacticsBenefitLabel)

        logisticsLabel = UILabel(frame: CGRect(x: 20, y: 385, width: 200, height: 25))
        logisticsLabel.font = UIFont.systemFont(ofSize: 18)
        logisticsLabel.textColor = .white
        logisticsLabel.text = "📦 Logistics: 10"
        detailView.addSubview(logisticsLabel)

        logisticsBenefitLabel = UILabel(frame: CGRect(x: benefitX, y: 385, width: benefitWidth, height: 25))
        logisticsBenefitLabel.font = UIFont.systemFont(ofSize: 14)
        logisticsBenefitLabel.textColor = benefitColor
        detailView.addSubview(logisticsBenefitLabel)

        rationingLabel = UILabel(frame: CGRect(x: 20, y: 415, width: 200, height: 25))
        rationingLabel.font = UIFont.systemFont(ofSize: 18)
        rationingLabel.textColor = .white
        rationingLabel.text = "🍞 Rationing: 10"
        detailView.addSubview(rationingLabel)

        rationingBenefitLabel = UILabel(frame: CGRect(x: benefitX, y: 415, width: benefitWidth, height: 25))
        rationingBenefitLabel.font = UIFont.systemFont(ofSize: 14)
        rationingBenefitLabel.textColor = benefitColor
        detailView.addSubview(rationingBenefitLabel)

        enduranceLabel = UILabel(frame: CGRect(x: 20, y: 445, width: 200, height: 25))
        enduranceLabel.font = UIFont.systemFont(ofSize: 18)
        enduranceLabel.textColor = .white
        enduranceLabel.text = "💪 Endurance: 10"
        detailView.addSubview(enduranceLabel)

        enduranceBenefitLabel = UILabel(frame: CGRect(x: benefitX, y: 445, width: benefitWidth, height: 25))
        enduranceBenefitLabel.font = UIFont.systemFont(ofSize: 14)
        enduranceBenefitLabel.textColor = benefitColor
        detailView.addSubview(enduranceBenefitLabel)

        // Divider
        let divider3 = UIView(frame: CGRect(x: 20, y: 490, width: detailView.bounds.width - 40, height: 1))
        divider3.backgroundColor = UIColor(white: 0.4, alpha: 1.0)
        detailView.addSubview(divider3)

        // Assignment Section
        let assignmentTitleLabel = UILabel(frame: CGRect(x: 20, y: 510, width: 200, height: 25))
        assignmentTitleLabel.text = "Current Assignment"
        assignmentTitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        assignmentTitleLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        detailView.addSubview(assignmentTitleLabel)
        
        armyLabel = UILabel(frame: CGRect(x: 20, y: 545, width: detailView.bounds.width - 40, height: 25))
        armyLabel.font = UIFont.systemFont(ofSize: 18)
        armyLabel.textColor = .white
        armyLabel.text = "🛡️ Army: None"
        armyLabel.numberOfLines = 2
        detailView.addSubview(armyLabel)

        locationLabel = UILabel(frame: CGRect(x: 20, y: 575, width: detailView.bounds.width - 40, height: 25))
        locationLabel.font = UIFont.systemFont(ofSize: 16)
        locationLabel.textColor = UIColor(white: 0.8, alpha: 1.0)
        locationLabel.text = "📍 Location: —"
        detailView.addSubview(locationLabel)

        homeBaseLabel = UILabel(frame: CGRect(x: 20, y: 605, width: detailView.bounds.width - 40, height: 25))
        homeBaseLabel.font = UIFont.systemFont(ofSize: 16)
        homeBaseLabel.textColor = UIColor(white: 0.8, alpha: 1.0)
        homeBaseLabel.text = "🏠 Home Base: —"
        detailView.addSubview(homeBaseLabel)
    }
    
    func updateDetailView() {
        guard let commander = selectedCommander else {
            commanderNameLabel.text = "Select a Commander"
            return
        }
        
        // Update portrait color
        portraitView.backgroundColor = commander.portraitColor
        
        // Basic info
        commanderNameLabel.text = commander.name
        rankLabel.text = "\(commander.rank.icon) \(commander.rank.displayName)"
        specialtyLabel.text = "\(commander.specialty.icon) \(commander.specialty.displayName)"
        
        // Level & XP
        levelLabel.text = "Level \(commander.level)"
        let requiredXP = commander.level * 100
        xpLabel.text = "\(commander.experience) / \(requiredXP) XP"
        
        // Update XP progress bar
        let xpProgress = Double(commander.experience) / Double(requiredXP)
        let maxBarWidth = detailView.bounds.width - 40
        xpProgressBar.frame.size.width = maxBarWidth * CGFloat(xpProgress)
        
        // Stats with gameplay benefits
        leadershipLabel.text = "👑 Leadership: \(commander.leadership)"
        let maxArmy = GameConfig.Commander.leadershipToArmySizeBase + commander.leadership * GameConfig.Commander.leadershipToArmySizePerPoint
        leadershipBenefitLabel.text = "Max Army: \(maxArmy) units"

        tacticsLabel.text = "🎯 Tactics: \(commander.tactics)"
        let terrainBonus = Double(commander.tactics) * GameConfig.Commander.tacticsTerrainScaling * 100
        tacticsBenefitLabel.text = "+\(Int(terrainBonus))% terrain bonus"

        logisticsLabel.text = "📦 Logistics: \(commander.logistics)"
        let speedBonus = Double(commander.logistics) * GameConfig.Commander.logisticsSpeedScaling * 100
        logisticsBenefitLabel.text = String(format: "+%.1f%% move speed", speedBonus)

        rationingLabel.text = "🍞 Rationing: \(commander.rationing)"
        let foodReduction = min(GameConfig.Commander.rationingReductionCap, Double(commander.rationing) * GameConfig.Commander.rationingReductionScaling) * 100
        rationingBenefitLabel.text = String(format: "-%.1f%% food cost", foodReduction)

        enduranceLabel.text = "💪 Endurance: \(commander.endurance)"
        let staminaBonus = Double(commander.endurance) * GameConfig.Commander.enduranceRegenScaling * 100
        enduranceBenefitLabel.text = "+\(Int(staminaBonus))% stamina regen"
        
        // Find assigned army
        if let army = player?.armies.first(where: { $0.commander?.id == commander.id }) {
            let unitCount = army.getTotalMilitaryUnits()
            armyLabel.text = "🛡️ Army: \(army.name) (\(unitCount) units)"
            locationLabel.text = "📍 Location: (\(army.coordinate.q), \(army.coordinate.r))"

            // Show home base
            if let homeBaseID = army.homeBaseID,
               let homeBase = hexMap?.buildings.first(where: { $0.data.id == homeBaseID }) {
                homeBaseLabel.text = "🏠 Home Base: \(homeBase.buildingType.icon) \(homeBase.buildingType.displayName) (\(homeBase.coordinate.q), \(homeBase.coordinate.r))"
            } else {
                homeBaseLabel.text = "🏠 Home Base: None"
            }
        } else {
            armyLabel.text = "🛡️ Army: Unassigned"
            locationLabel.text = "📍 Location: —"
            homeBaseLabel.text = "🏠 Home Base: —"
        }
    }
    
    // MARK: - TableView DataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return player?.commanders.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CommanderCell", for: indexPath) as! CommanderCell
        
        if let commander = player?.commanders[indexPath.row] {
            cell.configure(with: commander, isSelected: commander.id == selectedCommander?.id)
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let commander = player?.commanders[indexPath.row] {
            selectedCommander = commander
            updateDetailView()
            tableView.reloadData()
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
    
    @objc func closeScreen() {
        dismiss(animated: true)
    }
    
    @objc func recruitCommanderTapped() {
        guard let player = player else { return }
        
        // Calculate recruitment cost
        let baseCost: [ResourceType: Int] = [.food: 100, .ore: 50]
        let commanderCount = player.commanders.count
        let multiplier = 1.0 + (Double(commanderCount) * 0.5)
        
        var recruitmentCost: [ResourceType: Int] = [:]
        for (resource, amount) in baseCost {
            recruitmentCost[resource] = Int(Double(amount) * multiplier)
        }
        
        // Check if can afford
        var canAfford = true
        var costMessage = "Recruitment Cost:\n\n"
        
        for (resourceType, amount) in recruitmentCost {
            let current = player.getResource(resourceType)
            let statusIcon = current >= amount ? "✅" : "❌"
            costMessage += "\(statusIcon) \(resourceType.icon) \(resourceType.displayName): \(amount) (You have: \(current))\n"
            if current < amount { canAfford = false }
        }
        
        if !canAfford {
            showAlert(title: "Insufficient Resources", message: costMessage)
            return
        }
        
        showSpecialtySelection(recruitmentCost: recruitmentCost)
    }

    func showSpecialtySelection(recruitmentCost: [ResourceType: Int]) {
        let selectionVC = SpecialtySelectionViewController()
        selectionVC.recruitmentCost = recruitmentCost
        selectionVC.onSpecialtySelected = { [weak self] specialty in
            self?.recruitCommander(specialty: specialty)
        }
        selectionVC.modalPresentationStyle = .pageSheet
        if let sheet = selectionVC.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(selectionVC, animated: true)
    }

    func recruitCommander(specialty: CommanderSpecialty) {
        guard let player = player else {
            showError(message: "No player reference")
            return
        }
        
        let command = RecruitCommanderCommand(
            playerID: player.id,
            specialty: specialty
        )

        let result = CommandExecutor.shared.execute(command)

        if result.succeeded {
            // Refresh the selected commander reference
            selectedCommander = player.commanders.last
            tableView.reloadData()
            updateDetailView()
            let commanderName = player.commanders.last?.name ?? "Commander"
            showSuccess(message: "✅ Commander \(commanderName) recruited!\n\nDeployed at your City Center with home base set.")
        } else if let reason = result.failureReason {
            showError(message: reason)
        }
    }

    func deployCommanderAtCityCenter(commander: Commander) {
        
        guard let player = player,
              let hexMap = hexMap,
              let gameScene = gameScene else {
            debugLog("⚠️ Missing game references - commander not deployed")
            showError(message: "Cannot deploy commander - missing game references")
            return
        }
        
        // Find player's city center
        let cityCenters = player.buildings.filter {
            $0.buildingType == .cityCenter &&
            $0.state == .completed &&
            $0.owner?.id == player.id
        }
        
        guard let cityCenter = cityCenters.first else {
            debugLog("⚠️ No city center found - commander not deployed")
            showError(message: "No City Center found. Build one first!")
            return
        }
        
        // ✅ Spawn directly ON the city center coordinate
        let spawnCoord = cityCenter.coordinate
        
        // ✅ Check if there's already an entity on the city center
        if let existingEntity = hexMap.getEntity(at: spawnCoord) {
            debugLog("❌ City center occupied by entity: \(existingEntity.entityType)")
            showError(message: "City Center is occupied. Move units away first.")
            return
        }
        
        // Create new army with this commander (no units)
        let army = Army(
            name: "\(commander.name)'s Army",
            coordinate: spawnCoord,
            commander: commander,
            owner: player
        )

        // Set the city center as the army's home base
        army.setHomeBase(cityCenter.data.id)

        // Create entity node
        let armyNode = EntityNode(
            coordinate: spawnCoord,
            entityType: .army,
            entity: army,
            currentPlayer: player
        )

        let position = HexMap.hexToPixel(q: spawnCoord.q, r: spawnCoord.r)
        armyNode.position = position

        // Add to game
        hexMap.addEntity(armyNode)
        gameScene.entitiesNode.addChild(armyNode)
        player.addArmy(army)
        player.addEntity(army)

        debugLog("✅ Deployed \(commander.name)'s Army at City Center (\(spawnCoord.q), \(spawnCoord.r))")
    }

}

class CommanderCell: UITableViewCell {
    
    let portraitView = UIView()
    let nameLabel = UILabel()
    let rankLabel = UILabel()
    let levelLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        // Portrait
        portraitView.frame = CGRect(x: 15, y: 10, width: 60, height: 60)
        portraitView.layer.cornerRadius = 30
        portraitView.layer.borderWidth = 2
        portraitView.layer.borderColor = UIColor.white.cgColor
        contentView.addSubview(portraitView)
        
        // Name
        nameLabel.frame = CGRect(x: 85, y: 12, width: 180, height: 22)
        nameLabel.font = UIFont.boldSystemFont(ofSize: 16)
        nameLabel.textColor = .white
        contentView.addSubview(nameLabel)
        
        // Rank
        rankLabel.frame = CGRect(x: 85, y: 35, width: 180, height: 18)
        rankLabel.font = UIFont.systemFont(ofSize: 13)
        rankLabel.textColor = UIColor(white: 0.8, alpha: 1.0)
        contentView.addSubview(rankLabel)
        
        // Level
        levelLabel.frame = CGRect(x: 85, y: 55, width: 180, height: 18)
        levelLabel.font = UIFont.systemFont(ofSize: 12)
        levelLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        contentView.addSubview(levelLabel)
    }
    
    func configure(with commander: Commander, isSelected: Bool) {
        portraitView.backgroundColor = commander.portraitColor
        nameLabel.text = commander.name
        rankLabel.text = "\(commander.rank.icon) \(commander.rank.displayName)"
        levelLabel.text = "Level \(commander.level) • \(commander.specialty.icon) \(commander.specialty.displayName)"

        contentView.backgroundColor = isSelected ? UIColor(white: 0.3, alpha: 1.0) : .clear
    }
}

// MARK: - Specialty Selection View Controller

class SpecialtySelectionViewController: UIViewController {

    var recruitmentCost: [ResourceType: Int] = [:]
    var onSpecialtySelected: ((CommanderSpecialty) -> Void)?

    private var scrollView: UIScrollView!

    /// Category groupings for the two-phase selection
    enum SpecialtyCategory: String, CaseIterable {
        case infantry = "Infantry"
        case cavalry = "Cavalry"
        case ranged = "Ranged"
        case siege = "Siege"
        case defensive = "Defensive"
        case logistics = "Logistics"

        var icon: String {
            switch self {
            case .infantry: return "🗡️"
            case .cavalry: return "🐴"
            case .ranged: return "🏹"
            case .siege: return "🎯"
            case .defensive: return "🛡️"
            case .logistics: return "📦"
            }
        }

        var description: String {
            switch self {
            case .infantry: return "Infantry-focused commander"
            case .cavalry: return "Cavalry-focused commander"
            case .ranged: return "Ranged-focused commander"
            case .siege: return "Siege-focused commander"
            case .defensive: return "Strong tactics and rationing, better leadership"
            case .logistics: return "Strong leadership and logistics"
            }
        }

        /// Returns the specialties available for this category
        var specialties: [CommanderSpecialty] {
            switch self {
            case .infantry: return [.infantryAggressive, .infantryDefensive]
            case .cavalry: return [.cavalryAggressive, .cavalryDefensive]
            case .ranged: return [.rangedAggressive, .rangedDefensive]
            case .siege: return [.siegeAggressive, .siegeDefensive]
            case .defensive: return [.defensive]
            case .logistics: return [.logistics]
            }
        }

        /// Whether this category has sub-choices (aggressive/defensive)
        var hasVariants: Bool {
            return specialties.count > 1
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = UIColor(white: 0.15, alpha: 1.0)

        let contentWidth = view.bounds.width - 40

        // Header
        let titleLabel = UILabel(frame: CGRect(x: 20, y: 20, width: contentWidth - 60, height: 30))
        titleLabel.text = "Choose Commander Specialty"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 22)
        titleLabel.textColor = .white
        view.addSubview(titleLabel)

        let cancelButton = UIButton(frame: CGRect(x: view.bounds.width - 70, y: 15, width: 50, height: 40))
        cancelButton.setTitle("✕", for: .normal)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 24)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        view.addSubview(cancelButton)

        // Cost banner
        let costBanner = UIView(frame: CGRect(x: 20, y: 60, width: contentWidth, height: 35))
        costBanner.backgroundColor = UIColor(white: 0.22, alpha: 1.0)
        costBanner.layer.cornerRadius = 8
        view.addSubview(costBanner)

        var costText = "Recruitment Cost:"
        let sortedCost = recruitmentCost.sorted { $0.key.rawValue < $1.key.rawValue }
        for (resource, amount) in sortedCost {
            costText += "  \(resource.icon) \(amount)"
        }
        let costLabel = UILabel(frame: CGRect(x: 12, y: 0, width: contentWidth - 24, height: 35))
        costLabel.text = costText
        costLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        costLabel.textColor = UIColor(red: 1.0, green: 0.85, blue: 0.4, alpha: 1.0)
        costBanner.addSubview(costLabel)

        // Scroll view for category cards
        scrollView = UIScrollView(frame: CGRect(x: 0, y: 105, width: view.bounds.width, height: view.bounds.height - 105))
        scrollView.showsVerticalScrollIndicator = true
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        var yOffset: CGFloat = 10
        let cardHeight: CGFloat = 120

        for (index, category) in SpecialtyCategory.allCases.enumerated() {
            let card = createCategoryCard(
                category: category,
                tag: index,
                yOffset: yOffset,
                width: contentWidth,
                height: cardHeight
            )
            scrollView.addSubview(card)
            yOffset += cardHeight + 10
        }

        scrollView.contentSize = CGSize(width: view.bounds.width, height: yOffset + 20)
    }

    private func createCategoryCard(category: SpecialtyCategory, tag: Int, yOffset: CGFloat, width: CGFloat, height: CGFloat) -> UIView {
        let card = UIView(frame: CGRect(x: 20, y: yOffset, width: width, height: height))
        card.backgroundColor = UIColor(white: 0.22, alpha: 1.0)
        card.layer.cornerRadius = 12

        // Row 1: Icon + name
        let nameLabel = UILabel(frame: CGRect(x: 15, y: 10, width: width - 30, height: 24))
        nameLabel.text = "\(category.icon) \(category.rawValue)"
        nameLabel.font = UIFont.boldSystemFont(ofSize: 18)
        nameLabel.textColor = .white
        card.addSubview(nameLabel)

        // Row 2: Description
        let descLabel = UILabel(frame: CGRect(x: 15, y: 38, width: width - 30, height: 20))
        descLabel.text = category.description
        descLabel.font = UIFont.systemFont(ofSize: 14)
        descLabel.textColor = UIColor(red: 0.4, green: 0.9, blue: 0.4, alpha: 1.0)
        card.addSubview(descLabel)

        // Row 3: Variant info or stat preview
        let infoLabel = UILabel(frame: CGRect(x: 15, y: 62, width: width - 30, height: 18))
        if category.hasVariants {
            infoLabel.text = "Choose Aggressive or Defensive variant"
        } else {
            infoLabel.text = category.specialties.first?.detailedDescription ?? ""
        }
        infoLabel.font = UIFont.systemFont(ofSize: 12)
        infoLabel.textColor = UIColor(white: 0.55, alpha: 1.0)
        card.addSubview(infoLabel)

        // Row 4: Stat preview
        if let specialty = category.specialties.first {
            let profile = specialty.statProfile
            let statsLabel = UILabel(frame: CGRect(x: 15, y: 84, width: width - 30, height: 18))
            statsLabel.text = "Lead \(profile.baseLeadership) | Tac \(profile.baseTactics) | Log \(profile.baseLogistics) | Rat \(profile.baseRationing) | End \(profile.baseEndurance)"
            statsLabel.font = UIFont.systemFont(ofSize: 12)
            statsLabel.textColor = UIColor(white: 0.45, alpha: 1.0)
            card.addSubview(statsLabel)
        }

        // Tap gesture
        card.tag = tag
        card.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(categoryCardTapped(_:)))
        card.addGestureRecognizer(tap)

        return card
    }

    @objc private func categoryCardTapped(_ gesture: UITapGestureRecognizer) {
        guard let tag = gesture.view?.tag else { return }
        let allCategories = SpecialtyCategory.allCases
        guard tag < allCategories.count else { return }

        let category = allCategories[allCategories.index(allCategories.startIndex, offsetBy: tag)]

        if category.hasVariants {
            // Show sub-choice for aggressive/defensive
            showVariantSelection(for: category)
        } else {
            // Standalone specialty - select immediately
            guard let specialty = category.specialties.first else { return }
            dismiss(animated: true) { [weak self] in
                self?.onSpecialtySelected?(specialty)
            }
        }
    }

    private func showVariantSelection(for category: SpecialtyCategory) {
        let variantVC = VariantSelectionViewController()
        variantVC.category = category
        variantVC.onSpecialtySelected = { [weak self] specialty in
            self?.dismiss(animated: true) {
                self?.onSpecialtySelected?(specialty)
            }
        }
        variantVC.modalPresentationStyle = .pageSheet
        if let sheet = variantVC.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
        present(variantVC, animated: true)
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
}

// MARK: - Variant Selection (Aggressive/Defensive sub-choice)

class VariantSelectionViewController: UIViewController {

    var category: SpecialtySelectionViewController.SpecialtyCategory!
    var onSpecialtySelected: ((CommanderSpecialty) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = UIColor(white: 0.15, alpha: 1.0)

        let contentWidth = view.bounds.width - 40

        // Header
        let titleLabel = UILabel(frame: CGRect(x: 20, y: 20, width: contentWidth - 60, height: 30))
        titleLabel.text = "\(category.icon) \(category.rawValue) - Choose Style"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 22)
        titleLabel.textColor = .white
        view.addSubview(titleLabel)

        let cancelButton = UIButton(frame: CGRect(x: view.bounds.width - 70, y: 15, width: 50, height: 40))
        cancelButton.setTitle("✕", for: .normal)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 24)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        view.addSubview(cancelButton)

        var yOffset: CGFloat = 70
        let cardHeight: CGFloat = 140

        for (index, specialty) in category.specialties.enumerated() {
            let card = createVariantCard(
                specialty: specialty,
                tag: index,
                yOffset: yOffset,
                width: contentWidth,
                height: cardHeight
            )
            view.addSubview(card)
            yOffset += cardHeight + 15
        }
    }

    private func createVariantCard(specialty: CommanderSpecialty, tag: Int, yOffset: CGFloat, width: CGFloat, height: CGFloat) -> UIView {
        let card = UIView(frame: CGRect(x: 20, y: yOffset, width: width, height: height))
        card.backgroundColor = UIColor(white: 0.22, alpha: 1.0)
        card.layer.cornerRadius = 12

        let variantName = specialty.isAggressive ? "Aggressive" : "Defensive"
        let variantIcon = specialty.isAggressive ? "⚔️" : "🛡️"

        // Row 1: Icon + variant name
        let nameLabel = UILabel(frame: CGRect(x: 15, y: 10, width: width - 30, height: 24))
        nameLabel.text = "\(variantIcon) \(variantName)"
        nameLabel.font = UIFont.boldSystemFont(ofSize: 18)
        nameLabel.textColor = .white
        card.addSubview(nameLabel)

        // Row 2: Bonus
        let bonusLabel = UILabel(frame: CGRect(x: 15, y: 38, width: width - 30, height: 20))
        bonusLabel.text = specialty.detailedDescription
        bonusLabel.font = UIFont.systemFont(ofSize: 14)
        bonusLabel.textColor = specialty.isAggressive
            ? UIColor(red: 1.0, green: 0.5, blue: 0.3, alpha: 1.0)
            : UIColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0)
        card.addSubview(bonusLabel)

        // Row 3: Description
        let descLabel = UILabel(frame: CGRect(x: 15, y: 62, width: width - 30, height: 36))
        descLabel.text = specialty.description
        descLabel.font = UIFont.systemFont(ofSize: 12)
        descLabel.textColor = UIColor(white: 0.6, alpha: 1.0)
        descLabel.numberOfLines = 2
        card.addSubview(descLabel)

        // Row 4: Stat profile
        let profile = specialty.statProfile
        let statsLabel = UILabel(frame: CGRect(x: 15, y: 102, width: width - 30, height: 18))
        statsLabel.text = "Lead \(profile.baseLeadership) | Tac \(profile.baseTactics) | Log \(profile.baseLogistics) | Rat \(profile.baseRationing) | End \(profile.baseEndurance)"
        statsLabel.font = UIFont.systemFont(ofSize: 12)
        statsLabel.textColor = UIColor(white: 0.45, alpha: 1.0)
        card.addSubview(statsLabel)

        // Tap gesture
        card.tag = tag
        card.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(variantCardTapped(_:)))
        card.addGestureRecognizer(tap)

        return card
    }

    @objc private func variantCardTapped(_ gesture: UITapGestureRecognizer) {
        guard let tag = gesture.view?.tag else { return }
        let specialties = category.specialties
        guard tag < specialties.count else { return }

        let specialty = specialties[tag]
        dismiss(animated: true) { [weak self] in
            self?.onSpecialtySelected?(specialty)
        }
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
}
