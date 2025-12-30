import UIKit

class CommandersViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var player: Player?
    var selectedCommander: Commander?
    
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
    var armyLabel: UILabel!
    var locationLabel: UILabel!
    var portraitView: UIView!
    
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
        
        leadershipLabel = UILabel(frame: CGRect(x: 20, y: 325, width: 200, height: 25))
        leadershipLabel.font = UIFont.systemFont(ofSize: 18)
        leadershipLabel.textColor = .white
        leadershipLabel.text = "👑 Leadership: 10"
        detailView.addSubview(leadershipLabel)
        
        tacticsLabel = UILabel(frame: CGRect(x: 20, y: 355, width: 200, height: 25))
        tacticsLabel.font = UIFont.systemFont(ofSize: 18)
        tacticsLabel.textColor = .white
        tacticsLabel.text = "🎯 Tactics: 10"
        detailView.addSubview(tacticsLabel)
        
        // Divider
        let divider3 = UIView(frame: CGRect(x: 20, y: 400, width: detailView.bounds.width - 40, height: 1))
        divider3.backgroundColor = UIColor(white: 0.4, alpha: 1.0)
        detailView.addSubview(divider3)
        
        // Assignment Section
        let assignmentTitleLabel = UILabel(frame: CGRect(x: 20, y: 420, width: 200, height: 25))
        assignmentTitleLabel.text = "Current Assignment"
        assignmentTitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        assignmentTitleLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        detailView.addSubview(assignmentTitleLabel)
        
        armyLabel = UILabel(frame: CGRect(x: 20, y: 455, width: detailView.bounds.width - 40, height: 25))
        armyLabel.font = UIFont.systemFont(ofSize: 18)
        armyLabel.textColor = .white
        armyLabel.text = "🛡️ Army: None"
        armyLabel.numberOfLines = 2
        detailView.addSubview(armyLabel)
        
        locationLabel = UILabel(frame: CGRect(x: 20, y: 485, width: detailView.bounds.width - 40, height: 25))
        locationLabel.font = UIFont.systemFont(ofSize: 16)
        locationLabel.textColor = UIColor(white: 0.8, alpha: 1.0)
        locationLabel.text = "📍 Location: —"
        detailView.addSubview(locationLabel)
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
        
        // Stats
        leadershipLabel.text = "👑 Leadership: \(commander.leadership)"
        tacticsLabel.text = "🎯 Tactics: \(commander.tactics)"
        
        // Find assigned army
        if let army = player?.armies.first(where: { $0.commander?.id == commander.id }) {
            let unitCount = army.getTotalMilitaryUnits() + army.getUnitCount()
            armyLabel.text = "🛡️ Army: \(army.name) (\(unitCount) units)"
            locationLabel.text = "📍 Location: (\(army.coordinate.q), \(army.coordinate.r))"
        } else {
            armyLabel.text = "🛡️ Army: Unassigned"
            locationLabel.text = "📍 Location: —"
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
