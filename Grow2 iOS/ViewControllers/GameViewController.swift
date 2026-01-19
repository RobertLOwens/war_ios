import UIKit
import SpriteKit

class GameViewController: UIViewController {
    
    var skView: SKView!
    var gameScene: GameScene!
    var player: Player!
    var mapSize: MapSize = .medium
    var resourceDensity: ResourceDensity = .normal
    var autoSaveTimer: Timer?
    let autoSaveInterval: TimeInterval = 60.0 // Auto-save every 60 seconds
    var shouldLoadGame: Bool = false
    var populationLabel: UILabel!
    var storageLabel: UILabel?

    private var menuCoordinator: MenuCoordinator!
    private var entityActionHandler: EntityActionHandler!
    
    // UI Elements
    var resourcePanel: UIView!
    var resourceLabels: [ResourceType: UILabel] = [:]
    var commanderButton: UIButton!
    var combatHistoryButton: UIButton!
    var researchButton: UIButton!
    
    private struct AssociatedKeys {
        static var unitLabels: UInt8 = 0
        static var garrisonData: UInt8 = 1
        static var villagerCountLabel: UInt8 = 2
        static var splitLabels: UInt8 = 3
        static var trainingLabels: UInt8 = 4  // ✅ Unified training slider labels
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        // Initialize player
        player = Player(name: "Player 1", color: .blue)
    
        setupSKView()
        setupUI()
    
        menuCoordinator = MenuCoordinator(viewController: self, delegate: self)
        entityActionHandler = EntityActionHandler(viewController: self, delegate: self)
        ResearchManager.shared.setup(player: player)
    
        setupAutoSave()
    
        // ✅ FIX: Only setup a new scene if NOT loading a saved game
        if shouldLoadGame {
            // Create an empty scene shell - loadGame() will populate it
            setupEmptyScene()
    
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.loadGame()
    
                // Process background time AFTER loading
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.processBackgroundTime()
                }
            }
        } else {
            // New game - setup scene normally (this generates the map)
            setupScene()
            updateResourceDisplay()
        }
        
        CommandExecutor.shared.setup(
            hexMap: gameScene.hexMap,
            player: player,
            allPlayers: gameScene.allGamePlayers,
            gameScene: gameScene 
        )

        CommandExecutor.shared.setCallbacks(
            onResourcesChanged: { [weak self] in
                self?.updateResourceDisplay()
            },
            onAlert: { [weak self] title, message in
                self?.showSimpleAlert(title: title, message: message)
            }
        )
        
        // Listen for app returning from background
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillSave),
            name: .appWillSaveGame,
            object: nil
        )
        
    }
    
    @objc func handleAppWillEnterForeground() {
        print("📱 App returning to foreground - processing background time")
        processBackgroundTime()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func handleAppWillSave() {
        print("📱 Received app save notification")
        autoSaveGame()
    }
    
    func setupEmptyScene() {
        gameScene = GameScene(size: skView.bounds.size)
        gameScene.scaleMode = .resizeFill
        gameScene.player = player
        gameScene.gameDelegate = self
    
        // ✅ Set a flag to tell GameScene NOT to generate a new map
        gameScene.skipInitialSetup = true
    
        skView.presentScene(gameScene)
    }
    
    func initializePlayers() {
        // Create human player
        player = Player(name: "Player 1", color: .blue)
        
        // Create AI opponent
        let aiPlayer = Player(name: "AI Opponent", color: .red)
        player.setDiplomacyStatus(with: aiPlayer, status: .enemy)
        
        // Store for later use in game setup
        // We'll pass this to the scene in setupScene()
    }

    func setupSKView() {
        skView = SKView(frame: view.bounds)
        skView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(skView)
        
        skView.showsFPS = true
        skView.showsNodeCount = true
        skView.ignoresSiblingOrder = true
    }
    
    func setupScene() {
        gameScene = GameScene(size: skView.bounds.size)
        gameScene.scaleMode = .resizeFill
        gameScene.player = player
        gameScene.mapSize = mapSize.rawValue
        gameScene.resourceDensity = resourceDensity.multiplier
        gameScene.gameDelegate = self  // ADD THIS LINE
        skView.presentScene(gameScene)
    }
    
    // MARK: - Combat System
    
    /// Shows a menu to select which army to use for attacking a target
    func showAttackerSelection(target: EntityNode, at coordinate: HexCoordinate) {
        let playerArmies = player.getArmies().filter { $0.hasMilitaryUnits() }
        
        let targetName: String
        if let army = target.entity as? Army {
            targetName = army.name
        } else if let villagers = target.entity as? VillagerGroup {
            targetName = villagers.name
        } else {
            targetName = "Target"
        }
        
        let alert = UIAlertController(
            title: "⚔️ Select Attacking Army",
            message: "Choose which army to attack \(targetName) with:",
            preferredStyle: .actionSheet
        )
        
        for army in playerArmies {
            let unitCount = army.getTotalMilitaryUnits()
            let distance = army.coordinate.distance(to: coordinate)
            let title = "\(army.name) (\(unitCount) units) - Distance: \(distance)"
            
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.initiateAttack(attacker: army, target: target, at: coordinate)
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(alert, animated: true)
    }
    
    /// Initiates an attack from one army to another entity
    func initiateAttack(attacker: Army, target: EntityNode, at coordinate: HexCoordinate) {
        // Check if target is still valid
        guard let targetEntity = target.entity as? Army else {
            showSimpleAlert(title: "Invalid Target", message: "Target is not an army or no longer exists.")
            return
        }
        
        // Calculate combat outcome
        let attackerStrength = attacker.getModifiedStrength()
        let defenderStrength = targetEntity.getModifiedDefense()
        
        var resultMessage = "⚔️ Battle Report\n\n"
        resultMessage += "Attacker: \(attacker.name)\n"
        resultMessage += "Attack Power: \(attackerStrength)\n\n"
        resultMessage += "Defender: \(targetEntity.name)\n"
        resultMessage += "Defense Power: \(defenderStrength)\n\n"
        
        // Simple combat calculation
        if attackerStrength > defenderStrength {
            let casualties = calculateCasualties(army: attacker, lossPercent: 0.2)
            let defenderCasualties = calculateCasualties(army: targetEntity, lossPercent: 0.8)
            
            applyCasualties(to: attacker, casualties: casualties)
            applyCasualties(to: targetEntity, casualties: defenderCasualties)
            
            resultMessage += "Result: Victory! 🎉\n\n"
            resultMessage += "Your losses: \(casualties.values.reduce(0, +)) units\n"
            resultMessage += "Enemy losses: \(defenderCasualties.values.reduce(0, +)) units"
            
            // If defender is wiped out, remove from map
            if targetEntity.getTotalMilitaryUnits() == 0 {
                gameScene.hexMap.removeEntity(target)
                target.removeFromParent()
                targetEntity.owner?.removeArmy(targetEntity)
                resultMessage += "\n\n💀 Enemy army destroyed!"
            }
        } else {
            let casualties = calculateCasualties(army: attacker, lossPercent: 0.6)
            let defenderCasualties = calculateCasualties(army: targetEntity, lossPercent: 0.3)
            
            applyCasualties(to: attacker, casualties: casualties)
            applyCasualties(to: targetEntity, casualties: defenderCasualties)
            
            resultMessage += "Result: Defeat 😞\n\n"
            resultMessage += "Your losses: \(casualties.values.reduce(0, +)) units\n"
            resultMessage += "Enemy losses: \(defenderCasualties.values.reduce(0, +)) units"
            
            // If attacker is wiped out, remove from map
            if attacker.getTotalMilitaryUnits() == 0 {
                if let attackerNode = gameScene.hexMap.entities.first(where: { ($0.entity as? Army)?.id == attacker.id }) {
                    gameScene.hexMap.removeEntity(attackerNode)
                    attackerNode.removeFromParent()
                }
                player.removeArmy(attacker)
                resultMessage += "\n\n💀 Your army was destroyed!"
            }
        }
        
        showCombatResult(message: resultMessage)
    }
    
    /// Calculate casualties for an army based on loss percentage
    func calculateCasualties(army: Army, lossPercent: Double) -> [MilitaryUnitType: Int] {
        var casualties: [MilitaryUnitType: Int] = [:]
        
        for (unitType, count) in army.militaryComposition {
            let losses = Int(Double(count) * lossPercent)
            if losses > 0 {
                casualties[unitType] = losses
            }
        }
        
        return casualties
    }
    
    /// Apply casualties to an army
    func applyCasualties(to army: Army, casualties: [MilitaryUnitType: Int]) {
        for (unitType, count) in casualties {
            army.removeMilitaryUnits(unitType, count: count)
        }
    }
    
    /// Show combat result dialog
    func showCombatResult(message: String) {
        let alert = UIAlertController(
            title: "⚔️ Combat Complete",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    func formatArmyComposition(_ army: Army) -> String {
        var message = ""
        
        // Get total counts
        let totalUnits = army.getTotalMilitaryUnits()
        
        message += "Total Units: \(totalUnits)\n\n"
        
        if totalUnits > 0 {
            message += "⚔️ Military Units:\n"
            for (unitType, count) in army.militaryComposition.sorted(by: { $0.key.displayName < $1.key.displayName }) {
                let percentage = totalUnits > 0 ? Int((Double(count) / Double(totalUnits)) * 100) : 0
                message += "\(unitType.icon) \(unitType.displayName): \(count) (\(percentage)%)\n"
            }
            message += "\n"
        }
        
        // Show combat stats
        message += "💪 Combat Stats:\n"
        message += "⚔️ Total Attack: \(army.getTotalStrength())\n"
        message += "🛡️ Total Defense: \(army.getTotalDefense())"
        
        return message
    }
    
    func formatBuildingCost(_ buildingType: BuildingType) -> String {
        let costs = buildingType.buildCost.sorted(by: { $0.key.rawValue < $1.key.rawValue })
        return costs.map { "\($0.key.icon)\($0.value)" }.joined(separator: " ")
    }
    
    func updateResourceDisplay() {
        let capacity = player.getStorageCapacity()
        let totalStored = ResourceType.allCases.reduce(0) { $0 + player.getResource($1) }
        let storagePercent = capacity > 0 ? (Double(totalStored) / Double(capacity)) * 100 : 0
        
        for (resourceType, label) in resourceLabels {
            let amount = player.getResource(resourceType)
            let rate = player.getCollectionRate(resourceType)
            
            // Show warning color if storage is nearly full
            if storagePercent >= 90 {
                label.textColor = .systemOrange
            } else if storagePercent >= 100 {
                label.textColor = .systemRed
            } else {
                label.textColor = .white
            }
            
            label.text = "\(resourceType.icon) \(amount) (+\(String(format: "%.1f", rate))/s)"
        }
        
        let currentPop = player.getCurrentPopulation()
        let maxPop = player.getPopulationCapacity()
        let consumptionRate = player.getFoodConsumptionRate()
        
        let popColor: UIColor = currentPop >= maxPop ? .systemOrange : .white
        populationLabel.textColor = popColor
        populationLabel.text = "👥 \(currentPop)/\(maxPop) (-\(String(format: "%.1f", consumptionRate))/s)"
        
        // Update storage label if it exists (see below for adding it)
        if let storageLabel = storageLabel {
            let storageColor: UIColor
            if storagePercent >= 100 {
                storageColor = .systemRed
            } else if storagePercent >= 90 {
                storageColor = .systemOrange
            } else {
                storageColor = .white
            }
            storageLabel.textColor = storageColor
            storageLabel.text = "📦 \(totalStored)/\(capacity)"
        }
    }
    
    func setupStorageLabel() {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = .white
        label.text = "📦 0/500"
        // Position this label where appropriate in your UI
        // For example, below the population label
        storageLabel = label
        // Add to your resource display stack or container
        // resourceStackView.addArrangedSubview(label)  // Uncomment and adjust as needed
    }
    
    func setupUI() {
        // Resource Panel
        resourcePanel = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 140))
        resourcePanel.backgroundColor = UIColor(white: 0.1, alpha: 0.9)
        resourcePanel.autoresizingMask = [.flexibleWidth]
        
        let titleLabel = UILabel(frame: CGRect(x: 20, y: 10, width: 250, height: 30))
        titleLabel.text = "Hex RTS Game"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 20)
        titleLabel.textColor = .white
        resourcePanel.addSubview(titleLabel)
        
        // ✅ ADD: Commander Button (top right)
        commanderButton = UIButton(frame: CGRect(x: view.bounds.width - 160, y: 10, width: 140, height: 35))
        commanderButton.setTitle("👤 Commanders", for: .normal)
        commanderButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        commanderButton.backgroundColor = UIColor(red: 0.3, green: 0.4, blue: 0.8, alpha: 1.0)
        commanderButton.layer.cornerRadius = 8
        commanderButton.addTarget(self, action: #selector(showCommandersScreen), for: .touchUpInside)
        commanderButton.autoresizingMask = [.flexibleLeftMargin]
        resourcePanel.addSubview(commanderButton)
        
        // ✅ ADD: Combat History Button (below commander button)
        combatHistoryButton = UIButton(frame: CGRect(x: view.bounds.width - 160, y: 55, width: 140, height: 35))
        combatHistoryButton.setTitle("⚔️ Battles", for: .normal)
        combatHistoryButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        combatHistoryButton.backgroundColor = UIColor(red: 0.8, green: 0.3, blue: 0.3, alpha: 1.0)
        combatHistoryButton.layer.cornerRadius = 8
        combatHistoryButton.addTarget(self, action: #selector(showCombatHistoryScreen), for: .touchUpInside)
        combatHistoryButton.autoresizingMask = [.flexibleLeftMargin]
        resourcePanel.addSubview(combatHistoryButton)
        
        researchButton = UIButton(frame: CGRect(x: view.bounds.width - 160, y: 95, width: 140, height: 35))
        researchButton.setTitle("🔬 Research", for: .normal)
        researchButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        researchButton.backgroundColor = UIColor(red: 0.4, green: 0.6, blue: 0.3, alpha: 1.0)
        researchButton.layer.cornerRadius = 8
        researchButton.addTarget(self, action: #selector(showResearchScreen), for: .touchUpInside)
        researchButton.autoresizingMask = [.flexibleLeftMargin]
        resourcePanel.addSubview(researchButton)

        
        // Resource labels (2x2 grid)
        let resourceTypes: [ResourceType] = [.wood, .food, .stone, .ore]
        let labelWidth: CGFloat = 150
        let labelHeight: CGFloat = 25
        let startY: CGFloat = 45
        let horizontalSpacing: CGFloat = 160
        let verticalSpacing: CGFloat = 30
        
        for (index, resourceType) in resourceTypes.enumerated() {
            let row = index / 2
            let col = index % 2
            let x: CGFloat = 20 + CGFloat(col) * horizontalSpacing
            let y: CGFloat = startY + CGFloat(row) * verticalSpacing
            
            let label = UILabel(frame: CGRect(x: x, y: y, width: labelWidth, height: labelHeight))
            label.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            label.textColor = .white
            label.text = "\(resourceType.icon) 0 (+0.0/s)"
            resourcePanel.addSubview(label)
            resourceLabels[resourceType] = label
        }
        
        populationLabel = UILabel(frame: CGRect(x: 20, y: startY + CGFloat(2) * verticalSpacing + 10, width: 300, height: 25))
        populationLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .medium)
        populationLabel.textColor = .white
        populationLabel.text = "👥 0/0 (-0.0 🌾/s)"
        resourcePanel.addSubview(populationLabel)
        
        view.addSubview(resourcePanel)
        
        // Bottom instruction panel
        let bottomView = UIView(frame: CGRect(x: 0, y: view.bounds.height - 60, width: view.bounds.width, height: 60))
        bottomView.backgroundColor = UIColor(white: 0.1, alpha: 0.9)
        bottomView.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
        
        let instructionLabel = UILabel(frame: CGRect(x: 20, y: 15, width: view.bounds.width - 40, height: 30))
        instructionLabel.text = "Tap villager → Build | Tap tile → Move"
        instructionLabel.textColor = .white
        instructionLabel.font = UIFont.systemFont(ofSize: 16)
        instructionLabel.textAlignment = .center
        instructionLabel.autoresizingMask = [.flexibleWidth]
        bottomView.addSubview(instructionLabel)
        
        view.addSubview(bottomView)
        
        let menuButton = UIButton(frame: CGRect(x: view.bounds.width - 120, y: 30, width: 100, height: 40))
        menuButton.setTitle("☰ Menu", for: .normal)
        menuButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        menuButton.backgroundColor = UIColor(white: 0.2, alpha: 0.9)
        menuButton.layer.cornerRadius = 8
        menuButton.addTarget(self, action: #selector(showGameMenu), for: .touchUpInside)
        view.addSubview(menuButton)
        
        let trainingButton = UIButton(frame: CGRect(x: view.bounds.width - 310, y: 10, width: 140, height: 35))
        trainingButton.setTitle("🎓 Training", for: .normal)
        trainingButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        trainingButton.backgroundColor = UIColor(red: 0.4, green: 0.6, blue: 0.3, alpha: 1.0)
        trainingButton.layer.cornerRadius = 8
        trainingButton.addTarget(self, action: #selector(showTrainingOverview), for: .touchUpInside)
        trainingButton.autoresizingMask = [.flexibleLeftMargin]
        resourcePanel.addSubview(trainingButton)
        
        let buildingsButton = UIButton(frame: CGRect(x: view.bounds.width - 460, y: 10, width: 140, height: 35))
        buildingsButton.setTitle("🏛️ Buildings", for: .normal)
        buildingsButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        buildingsButton.backgroundColor = UIColor(red: 0.5, green: 0.4, blue: 0.6, alpha: 1.0)
        buildingsButton.layer.cornerRadius = 8
        buildingsButton.addTarget(self, action: #selector(showBuildingsOverview), for: .touchUpInside)
        buildingsButton.autoresizingMask = [.flexibleLeftMargin]
        resourcePanel.addSubview(buildingsButton)
    }
    
    @objc func showResearchScreen() {
        let researchVC = ResearchViewController()
        researchVC.player = player
        researchVC.modalPresentationStyle = .fullScreen
        present(researchVC, animated: true)
        print("🔬 Opening Research screen")
    }
    
    @objc func showBuildingsOverview() {
        let buildingsVC = BuildingsOverviewViewController()
        buildingsVC.player = player
        buildingsVC.hexMap = gameScene.hexMap
        buildingsVC.gameScene = gameScene
        buildingsVC.gameViewController = self  // ✅ ADD THIS LINE
        buildingsVC.modalPresentationStyle = .fullScreen
        present(buildingsVC, animated: true)
        print("🏛️ Opening Buildings Overview screen")
    }
    
    @objc func showGameMenu() {
        showActionSheet(
            title: "⚙️ Game Menu",
            actions: [
                AlertAction(title: "💾 Save Game") { [weak self] in self?.manualSave() },
                AlertAction(title: "📂 Load Game") { [weak self] in self?.confirmLoad() },
                AlertAction(title: "🏠 Main Menu") { [weak self] in self?.returnToMainMenu() }
            ],
            sourceRect: CGRect(x: view.bounds.width - 70, y: 50, width: 0, height: 0)
        )
    }
    
    @objc func showTrainingOverview() {
        let trainingVC = TrainingOverviewViewController()
        trainingVC.player = player
        trainingVC.hexMap = gameScene.hexMap
        trainingVC.modalPresentationStyle = .fullScreen
        present(trainingVC, animated: true)
        print("🎓 Opening Training Overview screen")
    }

    func confirmLoad() {
        showConfirmation(
            title: "⚠️ Load Game?",
            message: "Any unsaved progress will be lost. Continue?",
            confirmTitle: "Load",
            onConfirm: { [weak self] in self?.loadGame() }
        )
    }

    func returnToMainMenu() {
        // Save before returning
        autoSaveGame()
        
        dismiss(animated: true)
    }
    
    func formatUnitCost(_ unitType: MilitaryUnitType, quantity: Int) -> String {
        let costs = unitType.trainingCost.sorted(by: { $0.key.rawValue < $1.key.rawValue })
        return costs.map { "\($0.key.icon)\($0.value * quantity)" }.joined(separator: " ")
    }
    
    
    func deployArmy(from building: BuildingNode, units: [MilitaryUnitType: Int]) {
        guard let spawnCoord = gameScene.hexMap.findNearestWalkable(to: building.coordinate) else {
            print("No valid location to deploy army")
            return
        }
        
        // ✅ Create commander for new army
        let commander = Commander.createRandom()
        
        // ✅ Pass commander to Army init
        let army = Army(name: "Army", coordinate: spawnCoord, commander: commander, owner: player)
        
        // Transfer units from garrison
        for (unitType, count) in units {
            let removed = building.removeFromGarrison(unitType: unitType, quantity: count)
            if removed > 0 {
                army.addMilitaryUnits(unitType, count: removed)
            }
        }
        
        // Rest of function remains the same...
        let armyEntity = MapEntity(id: army.id, name: army.name, entityType: .army)
        let armyNode = EntityNode(coordinate: spawnCoord, entityType: .army, entity: armyEntity)
        let position = HexMap.hexToPixel(q: spawnCoord.q, r: spawnCoord.r)
        armyNode.position = position
        
        gameScene.hexMap.addEntity(armyNode)
        gameScene.entitiesNode.addChild(armyNode)
        player.addArmy(army)
        
        print("✅ Deployed army led by \(commander.name) with \(army.getTotalMilitaryUnits()) units")
    }
    
    // MARK: - Garrison Management
    
    func showGarrisonMenu(for building: BuildingNode) {
        let militaryCount = building.getTotalGarrisonedUnits()
        let villagerCount = building.villagerGarrison
        let totalCount = militaryCount + villagerCount
        let capacity = building.getGarrisonCapacity()
        
        var message = "Garrisoned Units: \(totalCount)/\(capacity)\n\n"
        
        if villagerCount > 0 {
            message += "👷 Villagers: \(villagerCount)\n"
        }
        
        if militaryCount > 0 {
            message += "\n⚔️ Military Units:\n"
            for (unitType, count) in building.garrison.sorted(by: { $0.key.displayName < $1.key.displayName }) {
                message += "\(unitType.icon) \(unitType.displayName): \(count)\n"
            }
            message += "\n💡 Use 'Reinforce Army' to add these units to an existing army."
        }
        
        if totalCount == 0 {
            message = "No units garrisoned."
        }
        
        showAlert(title: "🏰 Garrison", message: message)
    }
    
    func showArmyDetails(_ army: Army, at coordinate: HexCoordinate) {
        let message = formatArmyComposition(army)
        
        showActionSheet(
            title: "🛡️ \(army.name)",
            message: message,
            actions: [
                AlertAction(title: "🚶 Select to Move") { [weak self] in
                    guard let self = self else { return }
                    if let entityNode = self.gameScene.hexMap.entities.first(where: {
                        ($0.entity as? Army)?.id == army.id
                    }) {
                        self.gameScene.selectEntity(entityNode)
                    }
                }
            ],
            onCancel: { [weak self] in self?.gameScene.deselectAll() }
        )
    }
    
    // Add this helper method too:
    func showSimpleAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @objc func sliderValueChanged(_ slider: UISlider) {
        // Get the stored labels dictionary
        guard let labelsDict = objc_getAssociatedObject(self, &AssociatedKeys.unitLabels) as? [MilitaryUnitType: UILabel],
              let garrisonDict = objc_getAssociatedObject(self, &AssociatedKeys.garrisonData) as? [MilitaryUnitType: Int] else {
            return
        }
        
        // Find which unit type this slider corresponds to
        for (unitType, label) in labelsDict {
            let available = garrisonDict[unitType] ?? 0
            let sliderValue = Int(slider.value)
            label.text = "\(sliderValue) / \(available) units"
        }
    }
    
    /// Actually performs the reinforcement transfer
    func reinforceArmy(_ army: Army, from building: BuildingNode, with units: [MilitaryUnitType: Int]) {
        var totalTransferred = 0
        for (unitType, count) in units {
            let removed = building.removeFromGarrison(unitType: unitType, quantity: count)
            if removed > 0 {
                army.addMilitaryUnits(unitType, count: removed)
                totalTransferred += removed
            }
        }
        
        if totalTransferred > 0 {
            showAlert(
                title: "✅ Reinforcement Complete",
                message: "Transferred \(totalTransferred) units to \(army.name)\nNew Army Size: \(army.getTotalMilitaryUnits()) units"
            )
            print("✅ Reinforced \(army.name) with \(totalTransferred) units from \(building.buildingType.displayName)")
        }
    }
    
    @objc func showCommandersScreen() {
        let commandersVC = CommandersViewController()
        commandersVC.player = player
        commandersVC.hexMap = gameScene.hexMap  // ✅ ADD THIS
        commandersVC.gameScene = gameScene      // ✅ ADD THIS
        commandersVC.modalPresentationStyle = .fullScreen
        present(commandersVC, animated: true)
        print("👤 Opening Commanders screen")
    }

    @objc func showCombatHistoryScreen() {
        let combatHistoryVC = CombatHistoryViewController()
        combatHistoryVC.modalPresentationStyle = .fullScreen
        present(combatHistoryVC, animated: true)
        print("⚔️ Opening Combat History screen")
    }
    
    func setupAutoSave() {
        // Start auto-save timer
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: autoSaveInterval, repeats: true) { [weak self] _ in
            self?.autoSaveGame()
        }
        print("⏰ Auto-save enabled (every \(Int(autoSaveInterval))s)")
    }

    func autoSaveGame() {
        guard let player = player,
              let hexMap = gameScene.hexMap,
              !gameScene.allGamePlayers.isEmpty else {
            print("⚠️ Cannot auto-save - game not ready")
            return
        }
        
        let success = GameSaveManager.shared.saveGame(
            hexMap: hexMap,
            player: player,
            allPlayers: gameScene.allGamePlayers
        )
        
        if success {
            print("✅ Auto-save complete")
        } else {
            print("❌ Auto-save failed")
        }
    }

    func manualSave() {
        guard let player = player,
              let hexMap = gameScene.hexMap,
              !gameScene.allGamePlayers.isEmpty else {
            showSimpleAlert(title: "Cannot Save", message: "Game is not ready to be saved.")
            return
        }
        
        let success = GameSaveManager.shared.saveGame(
            hexMap: hexMap,
            player: player,
            allPlayers: gameScene.allGamePlayers
        )
        
        if success {
            showSimpleAlert(title: "✅ Game Saved", message: "Your progress has been saved successfully.")
        } else {
            showSimpleAlert(title: "❌ Save Failed", message: "Could not save the game. Please try again.")
        }
    }

    func loadGame() {
        // ✅ FIX: Set loading flag to pause update() loop
        gameScene.isLoading = true
        
        guard let loadedData = GameSaveManager.shared.loadGame() else {
            gameScene.isLoading = false
            showSimpleAlert(title: "❌ Load Failed", message: "Could not load the saved game.")
            return
        }
        
        // Update references
        player = loadedData.player
        gameScene.player = loadedData.player
        ResearchManager.shared.setup(player: loadedData.player)
        gameScene.hexMap = loadedData.hexMap
        gameScene.allGamePlayers = loadedData.allPlayers
        
        // Rebuild the scene
        rebuildSceneWithLoadedData(hexMap: loadedData.hexMap, player: loadedData.player, allPlayers: loadedData.allPlayers)
        
        // ✅ FIX: Clear loading flag AFTER everything is rebuilt
        gameScene.isLoading = false
        
        // ✅ DEBUG: Check fog stats after everything is loaded
        if let fogOfWar = player.fogOfWar {
            print("\n🔍 POST-LOAD FOG CHECK:")
            fogOfWar.printFogStats()
            
            // Check a few specific tiles
            let testCoords = [
                HexCoordinate(q: 3, r: 3),
                HexCoordinate(q: 5, r: 5),
                HexCoordinate(q: 10, r: 10)
            ]
            
            for coord in testCoords {
                let vis = player.getVisibilityLevel(at: coord)
                print("  Tile (\(coord.q), \(coord.r)): \(vis)")
            }
        }
        
        print("✅ Game loaded successfully")
        showSimpleAlert(title: "✅ Game Loaded", message: "Your saved game has been restored.")
    }

    func rebuildSceneWithLoadedData(hexMap: HexMap, player: Player, allPlayers: [Player]) {
        // ✅ Ensure hexMap is assigned to scene first
        gameScene.hexMap = hexMap
        
        // Clear existing scene
        gameScene.mapNode.removeAllChildren()
        gameScene.buildingsNode.removeAllChildren()
        gameScene.entitiesNode.removeAllChildren()
        
        // Remove old fog node
        gameScene.childNode(withName: "fogNode")?.removeFromParent()
        
        // Remove old resources node and recreate
        gameScene.childNode(withName: "resourcesNode")?.removeFromParent()
        let resourcesNode = SKNode()
        resourcesNode.name = "resourcesNode"
        resourcesNode.zPosition = 2
        gameScene.addChild(resourcesNode)
        
        // Rebuild map tiles
        for (coord, tile) in hexMap.tiles {
            let position = HexMap.hexToPixel(q: coord.q, r: coord.r)
            tile.position = position
            gameScene.mapNode.addChild(tile)
        }
        
        // Rebuild resource points
        for resource in hexMap.resourcePoints {
            let position = HexMap.hexToPixel(q: resource.coordinate.q, r: resource.coordinate.r)
            resource.position = position
            resourcesNode.addChild(resource)
        }
        
        // Rebuild buildings
        for building in hexMap.buildings {
            let position = HexMap.hexToPixel(q: building.coordinate.q, r: building.coordinate.r)
            building.position = position
            gameScene.buildingsNode.addChild(building)
            
            // Update appearance to match current state
            building.updateAppearance()
            building.updateLevelLabel()
        }
        
        // Clear existing entities from hexMap to avoid duplicates
        hexMap.entities.removeAll()
        
        // Rebuild entities
        for playerData in allPlayers {
            for entity in playerData.entities {
                let coord: HexCoordinate
                let entityType: EntityType
                
                if let army = entity as? Army {
                    coord = army.coordinate
                    entityType = .army
                } else if let villagers = entity as? VillagerGroup {
                    coord = villagers.coordinate
                    entityType = .villagerGroup
                } else {
                    continue
                }
                
                let entityNode = EntityNode(
                    coordinate: coord,
                    entityType: entityType,
                    entity: entity,
                    currentPlayer: player
                )
                
                let position = HexMap.hexToPixel(q: coord.q, r: coord.r)
                entityNode.position = position
                gameScene.entitiesNode.addChild(entityNode)
                hexMap.addEntity(entityNode)
            }
        }

        // ✅ FIX: Reconnect villager gathering tasks to resource points
        print("🔗 Reconnecting villager tasks to resources...")
        for entity in hexMap.entities {
            if let villagerGroup = entity.entity as? VillagerGroup,
               let targetCoord = villagerGroup.taskTarget {
                
                // Find resource at the target coordinate
                if let resourcePoint = hexMap.resourcePoints.first(where: {
                    $0.coordinate == targetCoord
                }) {
                    // Re-establish the gathering relationship
                    resourcePoint.startGathering(by: villagerGroup)
                    villagerGroup.currentTask = .gatheringResource(resourcePoint)
                    villagerGroup.taskTarget = nil  // Clear temporary storage
                    entity.isMoving = true  // Mark as busy
                
                    
                    print("✅ Reconnected \(villagerGroup.name) (\(villagerGroup.villagerCount) villagers) to \(resourcePoint.resourceType.displayName)")
                } else {
                    // Resource no longer exists (depleted), clear the task
                    villagerGroup.currentTask = .idle
                    villagerGroup.taskTarget = nil
                    entity.isMoving = false
                    print("⚠️ Resource at (\(targetCoord.q), \(targetCoord.r)) no longer exists, \(villagerGroup.name) is now idle")
                }
            }
        }


        let fogNode = SKNode()
        fogNode.name = "fogNode"
        fogNode.zPosition = 100
        gameScene.addChild(fogNode)
        
        // Setup fog overlays (visual only)
        hexMap.setupFogOverlays(in: fogNode)
        
        // Update vision to reveal visible tiles (but keep explored tiles)
        player.updateVision(allPlayers: allPlayers)
        
        if let fogOfWar = player.fogOfWar {
            print("🔍 After updateVision - Explored: \(fogOfWar.getExploredCount()), Visible: \(fogOfWar.getVisibleCount())")
        }
        
        // Apply fog overlay visuals
        hexMap.updateFogOverlays(for: player)
        
        // Update entity visibility
        for entity in hexMap.entities {
            entity.updateVisibility(for: player)
        }
        
        // Update building visibility
        for building in hexMap.buildings {
            let displayMode = player.fogOfWar?.shouldShowBuilding(building, at: building.coordinate) ?? .hidden
            building.updateVisibility(displayMode: displayMode)
        }
        
        // Update resource display
        updateResourceDisplay()
        
        print("🔄 Scene rebuilt with loaded data")
        print("   Tiles: \(hexMap.tiles.count)")
        print("   Buildings: \(hexMap.buildings.count)")
        print("   Entities: \(hexMap.entities.count)")
        print("   Resources: \(hexMap.resourcePoints.count)")
        print("   Explored tiles: \(player.fogOfWar?.getExploredCount() ?? 0)")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Stop auto-save timer
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
        
        // Final save before leaving
        autoSaveGame()
        
        // Save background time
        BackgroundTimeManager.shared.saveExitTime()
        NotificationCenter.default.removeObserver(self, name: .appWillSaveGame, object: nil)

    }
    
    func processBackgroundTime() {
        guard let player = player,
              let hexMap = gameScene.hexMap,
              !gameScene.allGamePlayers.isEmpty else {
            print("⚠️ Cannot process background time - game not ready")
            return
        }
        
        // Get elapsed time
        guard let elapsedSeconds = BackgroundTimeManager.shared.getElapsedTime() else {
            print("⏰ No background time to process")
            return
        }
        
        // Cap offline time (e.g., max 8 hours)
        let maxOfflineSeconds: TimeInterval = 8 * 60 * 60
        let cappedElapsed = min(elapsedSeconds, maxOfflineSeconds)
        
        guard cappedElapsed > 1 else {
            print("⏰ Less than 1 second elapsed, skipping")
            return
        }
        
        print("⏰ Processing background time: \(Int(cappedElapsed)) seconds...")
        
        // Track changes for summary
        var resourcesGathered: [ResourceType: Int] = [:]
        var resourcesDepleted: [String] = []
        
        // Step 1: Deplete resources from active villagers
        for entity in hexMap.entities {
            guard let villagerGroup = entity.entity as? VillagerGroup else { continue }
            
            // Check if gathering
            if case .gatheringResource(let resourcePoint) = villagerGroup.currentTask {
                // Verify resource still exists
                guard resourcePoint.parent != nil, !resourcePoint.isDepleted() else {
                    continue
                }
                
                // Calculate depletion
                let gatherRatePerSecond = 0.2 * Double(villagerGroup.villagerCount)
                let wouldGather = Int(gatherRatePerSecond * cappedElapsed)
                let actualGathered = min(wouldGather, resourcePoint.remainingAmount)
                let newRemaining = resourcePoint.remainingAmount - actualGathered
                
                print("   ⛏️ \(villagerGroup.name): depleted \(actualGathered) from \(resourcePoint.resourceType.displayName)")
                print("      \(resourcePoint.remainingAmount) → \(newRemaining)")
                
                // Apply depletion
                resourcePoint.setRemainingAmount(newRemaining)
                
                // Track for summary
                let resourceType = resourcePoint.resourceType.resourceYield
                resourcesGathered[resourceType, default: 0] += actualGathered
                
                // Check if depleted
                if newRemaining <= 0 {
                    resourcesDepleted.append(resourcePoint.resourceType.displayName)
                    
                    // Clear villager task
                    let rateContribution = gatherRatePerSecond
                    player.decreaseCollectionRate(resourceType, amount: rateContribution)
                    villagerGroup.clearTask()
                    entity.isMoving = false
                    
                    // Remove resource visually
                    resourcePoint.removeFromParent()
                    hexMap.resourcePoints.removeAll { $0.coordinate == resourcePoint.coordinate }
                    
                    print("   ⚠️ Resource depleted! \(villagerGroup.name) is now idle")
                }
            }
        }
        
        // Step 2: Apply resource accumulation from collection rates
        print("   💰 Resource accumulation:")
        for type in ResourceType.allCases {
            let rate = player.getCollectionRate(type)
            let accumulated = Int(rate * cappedElapsed)
            
            if accumulated > 0 {
                player.addResource(type, amount: accumulated)
                print("      \(type.displayName): +\(accumulated)")
            }
        }
        
        // Step 3: Clear the saved exit time
        BackgroundTimeManager.shared.clearExitTime()
        
        // Step 4: Update displays
        updateResourceDisplay()
        
        // Step 5: Show summary to user
        var summaryParts: [String] = []
        summaryParts.append("Time away: \(formatDuration(cappedElapsed))")
        
        for (type, amount) in resourcesGathered where amount > 0 {
            summaryParts.append("\(type.icon) +\(amount) \(type.displayName)")
        }
        
        if !resourcesDepleted.isEmpty {
            summaryParts.append("⚠️ Depleted: \(resourcesDepleted.joined(separator: ", "))")
        }
        
        let summary = summaryParts.joined(separator: "\n")
        showSimpleAlert(title: "Welcome Back!", message: summary)
        
        print("✅ Background time processed")
    }

    // Helper to format duration nicely
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
    
    func showDeployVillagersMenu(from building: BuildingNode) {
        let villagerCount = building.villagerGarrison
        
        guard villagerCount > 0 else {
            showSimpleAlert(title: "No Villagers", message: "This building has no villagers to deploy.")
            return
        }
        
        guard let spawnCoord = gameScene.hexMap.findNearestWalkable(to: building.coordinate) else {
            showSimpleAlert(title: "Cannot Deploy", message: "No valid location near building to deploy villagers.")
            return
        }
        
        // Create custom alert with slider
        let alert = UIAlertController(
            title: "👷 Deploy Villagers",
            message: "Select how many villagers to deploy from \(building.buildingType.displayName)\n\nAvailable: \(villagerCount) villagers",
            preferredStyle: .alert
        )
        
        // Create container for slider
        let containerVC = UIViewController()
        containerVC.preferredContentSize = CGSize(width: 270, height: 120)
        
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 270, height: 120))
        
        // Slider
        let slider = UISlider(frame: CGRect(x: 20, y: 20, width: 230, height: 30))
        slider.minimumValue = 1
        slider.maximumValue = Float(villagerCount)
        slider.value = Float(min(5, villagerCount))
        slider.isContinuous = true
        containerView.addSubview(slider)
        
        // Count label
        let countLabel = UILabel(frame: CGRect(x: 20, y: 60, width: 230, height: 30))
        countLabel.text = "\(Int(slider.value)) villagers"
        countLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        countLabel.textColor = .label
        countLabel.textAlignment = .center
        containerView.addSubview(countLabel)
        
        // Update label when slider moves
        slider.addTarget(self, action: #selector(villagerSliderChanged(_:)), for: .valueChanged)
        objc_setAssociatedObject(self, &AssociatedKeys.villagerCountLabel, countLabel, .OBJC_ASSOCIATION_RETAIN)
        
        containerVC.view.addSubview(containerView)
        alert.setValue(containerVC, forKey: "contentViewController")
        
        // Deploy action
        alert.addAction(UIAlertAction(title: "Deploy", style: .default) { [weak self] _ in
            let deployCount = Int(slider.value)
            self?.deployVillagers(count: deployCount, from: building, at: spawnCoord)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }

    @objc func villagerSliderChanged(_ slider: UISlider) {
        if let label = objc_getAssociatedObject(self, &AssociatedKeys.villagerCountLabel) as? UILabel {
            label.text = "\(Int(slider.value)) villagers"
        }
    }
    
    func showSplitVillagerGroupMenu(villagerGroup: VillagerGroup, entity: EntityNode) {
        let totalVillagers = villagerGroup.villagerCount
        
        guard totalVillagers > 1 else {
            showSimpleAlert(title: "Cannot Split", message: "Need at least 2 villagers to split the group.")
            return
        }
        
        // Create custom alert with slider
        let alert = UIAlertController(
            title: "✂️ Split Villager Group",
            message: "Select how many villagers to move to a new group\n\nTotal: \(totalVillagers) villagers",
            preferredStyle: .alert
        )
        
        // Create container for slider
        let containerVC = UIViewController()
        containerVC.preferredContentSize = CGSize(width: 270, height: 150)
        
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 270, height: 150))
        
        // Info label
        let infoLabel = UILabel(frame: CGRect(x: 20, y: 10, width: 230, height: 40))
        infoLabel.text = "Original group will keep the rest"
        infoLabel.font = UIFont.systemFont(ofSize: 12)
        infoLabel.textColor = .secondaryLabel
        infoLabel.textAlignment = .center
        infoLabel.numberOfLines = 2
        containerView.addSubview(infoLabel)
        
        // Slider
        let slider = UISlider(frame: CGRect(x: 20, y: 50, width: 230, height: 30))
        slider.minimumValue = 1
        slider.maximumValue = Float(totalVillagers - 1)
        slider.value = Float(totalVillagers / 2)
        slider.isContinuous = true
        containerView.addSubview(slider)
        
        // Count labels
        let splitLabel = UILabel(frame: CGRect(x: 20, y: 90, width: 230, height: 25))
        splitLabel.text = "New group: \(Int(slider.value)) villagers"
        splitLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        splitLabel.textColor = .label
        splitLabel.textAlignment = .center
        containerView.addSubview(splitLabel)
        
        let remainLabel = UILabel(frame: CGRect(x: 20, y: 115, width: 230, height: 25))
        remainLabel.text = "Original: \(totalVillagers - Int(slider.value)) villagers"
        remainLabel.font = UIFont.systemFont(ofSize: 14)
        remainLabel.textColor = .secondaryLabel
        remainLabel.textAlignment = .center
        containerView.addSubview(remainLabel)
        
        // Update labels when slider moves
        slider.addTarget(self, action: #selector(splitSliderChanged(_:)), for: .valueChanged)
        
        // Store both labels
        let labelDict: [String: Any] = [
            "splitLabel": splitLabel,
            "remainLabel": remainLabel,
            "totalVillagers": totalVillagers
        ]
        objc_setAssociatedObject(self, &AssociatedKeys.splitLabels, labelDict, .OBJC_ASSOCIATION_RETAIN)
        
        containerVC.view.addSubview(containerView)
        alert.setValue(containerVC, forKey: "contentViewController")
        
        // Split action
        alert.addAction(UIAlertAction(title: "Split", style: .default) { [weak self] _ in
            let splitCount = Int(slider.value)
            self?.splitVillagerGroup(villagerGroup: villagerGroup, entity: entity, splitCount: splitCount)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }

    @objc func splitSliderChanged(_ slider: UISlider) {
        if let labelDict = objc_getAssociatedObject(self, &AssociatedKeys.splitLabels) as? [String: Any],
           let splitLabel = labelDict["splitLabel"] as? UILabel,
           let remainLabel = labelDict["remainLabel"] as? UILabel,
           let totalVillagers = labelDict["totalVillagers"] as? Int {
            
            let splitValue = Int(slider.value)
            splitLabel.text = "New group: \(splitValue) villagers"
            remainLabel.text = "Original: \(totalVillagers - splitValue) villagers"
        }
    }

    func splitVillagerGroup(villagerGroup: VillagerGroup, entity: EntityNode, splitCount: Int) {
        guard let newGroup = villagerGroup.split(count: splitCount) else {
            showSimpleAlert(title: "Split Failed", message: "Could not split villager group.")
            return
        }
        
        // Create entity node for new group
        let newEntityNode = EntityNode(
            coordinate: villagerGroup.coordinate,
            entityType: .villagerGroup,
            entity: newGroup,
            currentPlayer: player
        )
        
        let position = HexMap.hexToPixel(q: newGroup.coordinate.q, r: newGroup.coordinate.r)
        newEntityNode.position = position
        
        gameScene.hexMap.addEntity(newEntityNode)
        gameScene.entitiesNode.addChild(newEntityNode)
        player.addEntity(newGroup)
        
        showSimpleAlert(
            title: "✅ Group Split",
            message: "Created new group with \(splitCount) villagers\nOriginal group has \(villagerGroup.villagerCount) villagers remaining"
        )
        
        print("✅ Split villager group: \(splitCount) → new group, \(villagerGroup.villagerCount) → original")
    }
    
    func deployVillagersFromBuilding(_ building: BuildingNode) {
        let villagerCount = building.getTotalGarrisonCount()
        
        guard villagerCount > 0 else {
            showSimpleAlert(title: "No Villagers", message: "There are no villagers in the garrison to deploy.")
            return
        }
        
        guard let spawnCoord = gameScene.hexMap.findNearestWalkable(to: building.coordinate, maxDistance: 3) else {
            showSimpleAlert(title: "Cannot Deploy", message: "No walkable location near \(building.buildingType.displayName) to deploy villagers.")
            return
        }
        
        // Create custom alert with slider
        let alert = UIAlertController(
            title: "👷 Deploy Villagers",
            message: "Select how many villagers to deploy from \(building.buildingType.displayName)\n\nAvailable: \(villagerCount) villagers",
            preferredStyle: .alert
        )
        
        // Create container for slider
        let containerVC = UIViewController()
        containerVC.preferredContentSize = CGSize(width: 270, height: 120)
        
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 270, height: 120))
        
        // Slider
        let slider = UISlider(frame: CGRect(x: 20, y: 20, width: 230, height: 30))
        slider.minimumValue = 1
        slider.maximumValue = Float(villagerCount)
        slider.value = Float(min(5, villagerCount))
        slider.isContinuous = true
        containerView.addSubview(slider)
        
        // Count label
        let countLabel = UILabel(frame: CGRect(x: 20, y: 60, width: 230, height: 30))
        countLabel.text = "\(Int(slider.value)) villagers"
        countLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        countLabel.textColor = .label
        countLabel.textAlignment = .center
        containerView.addSubview(countLabel)
        
        // Update label when slider moves
        slider.addTarget(self, action: #selector(villagerSliderChanged(_:)), for: .valueChanged)
        objc_setAssociatedObject(self, &AssociatedKeys.villagerCountLabel, countLabel, .OBJC_ASSOCIATION_RETAIN)
        
        containerVC.view.addSubview(containerView)
        alert.setValue(containerVC, forKey: "contentViewController")
        
        // Deploy action
        alert.addAction(UIAlertAction(title: "Deploy", style: .default) { [weak self] _ in
            let deployCount = Int(slider.value)
            self?.deployVillagers(count: deployCount, from: building, at: spawnCoord)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }

    func deployVillagers(count: Int, from building: BuildingNode, at coordinate: HexCoordinate) {
        // Remove villagers from garrison
        let removed = building.removeVillagersFromGarrison(quantity: count)
        
        guard removed > 0 else {
            showSimpleAlert(title: "Deploy Failed", message: "Could not remove villagers from garrison.")
            return
        }
        
        // Create villager group
        let villagerGroup = VillagerGroup(name: "Villagers", coordinate: coordinate, villagerCount: removed, owner: player)
        
        // Create entity node
        let entityNode = EntityNode(coordinate: coordinate, entityType: .villagerGroup, entity: villagerGroup, currentPlayer: player)
        let position = HexMap.hexToPixel(q: coordinate.q, r: coordinate.r)
        entityNode.position = position
        
        // Add to game
        gameScene.hexMap.addEntity(entityNode)
        gameScene.entitiesNode.addChild(entityNode)
        player.addEntity(villagerGroup)
        
        print("✅ Deployed \(removed) villagers from \(building.buildingType.displayName) at (\(coordinate.q), \(coordinate.r))")
        
        showSimpleAlert(
            title: "✅ Villagers Deployed",
            message: "Deployed \(removed) villagers at (\(coordinate.q), \(coordinate.r))"
        )
    }
    
    func showMergeOption(for group1: EntityNode, and group2: EntityNode) {
        guard let villagers1 = group1.entity as? VillagerGroup,
              let villagers2 = group2.entity as? VillagerGroup else {
            return
        }
        
        let totalCount = villagers1.villagerCount + villagers2.villagerCount
        
        let alert = UIAlertController(
            title: "Merge Villagers?",
            message: "Two villager groups are on the same tile.\n\nGroup 1: \(villagers1.villagerCount) villagers\nGroup 2: \(villagers2.villagerCount) villagers\n\nTotal: \(totalCount) villagers",
            preferredStyle: .alert
        )
        
        // Quick Merge - combines all into group 1
        alert.addAction(UIAlertAction(title: "⚡️ Quick Merge All", style: .default) { [weak self] _ in
            self?.gameScene.performMerge(group1: group1, group2: group2, newCount1: totalCount, newCount2: 0)
        })
        
        // Custom Split - shows slider interface
        alert.addAction(UIAlertAction(title: "🔀 Split & Merge", style: .default) { [weak self] _ in
            self?.showMergeViewController(for: group1, and: group2)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }

    func showMergeViewController(for group1: EntityNode, and group2: EntityNode) {
        guard let villagers1 = group1.entity as? VillagerGroup,
              let villagers2 = group2.entity as? VillagerGroup else {
            return
        }
        
        let mergeVC = VillagerMergeViewController()
        mergeVC.villagerGroup1 = villagers1
        mergeVC.villagerGroup2 = villagers2
        mergeVC.modalPresentationStyle = .overFullScreen
        mergeVC.modalTransitionStyle = .crossDissolve
        
        mergeVC.onMergeComplete = { [weak self] count1, count2 in
            self?.gameScene.performMerge(group1: group1, group2: group2, newCount1: count1, newCount2: count2)
        }
        
        present(mergeVC, animated: true)
    }

}

extension GameViewController: MenuCoordinatorDelegate {
    // player and gameScene already exist as properties
    
    func deselectAll() {
        gameScene.deselectAll()
    }
}

extension GameViewController: EntityActionHandlerDelegate {
    // player and gameScene already exist as properties
    // updateResourceDisplay() already exists
    // showSimpleAlert() already exists
}

extension GameViewController: GameSceneDelegate {
    
    func gameScene(_ scene: GameScene, villagerArrivedForHunt villagerGroup: VillagerGroup, target: ResourcePointNode, entityNode: EntityNode) {
        // Execute the hunt through the menu coordinator
        menuCoordinator?.executeHunt(villagerGroup: villagerGroup, target: target, entityNode: entityNode)
    }
    
    func gameScene(_ scene: GameScene, didRequestMenuForTile coordinate: HexCoordinate) {
        menuCoordinator.showTileActionMenu(for: coordinate)
    }
    
    func gameScene(_ scene: GameScene, didRequestMoveSelection destination: HexCoordinate, availableEntities: [EntityNode]) {
        menuCoordinator.showMoveSelectionMenu(to: destination, from: availableEntities)
    }
    
    func gameScene(_ scene: GameScene, didSelectEntity entity: EntityNode, at coordinate: HexCoordinate) {
        menuCoordinator.showEntityActionMenu(for: entity, at: coordinate)
    }
    
    func gameScene(_ scene: GameScene, didSelectVillagerGroup entity: EntityNode, at coordinate: HexCoordinate) {
        menuCoordinator.showVillagerMenu(at: coordinate, villagerGroup: entity)
    }
    
    func gameScene(_ scene: GameScene, didRequestBuildMenu coordinate: HexCoordinate, builder: EntityNode) {
        menuCoordinator.showBuildingMenu(at: coordinate, villagerGroup: builder)
    }
    
    func gameScene(_ scene: GameScene, didStartCombat record: CombatRecord, completion: @escaping () -> Void) {
        // Your existing combat timer UI logic
        // showCombatTimer?(record, completion)
    }
    
    func gameScene(_ scene: GameScene, showAlertWithTitle title: String, message: String) {
        showSimpleAlert(title: title, message: message)
    }
    
    func gameSceneDidUpdateResources(_ scene: GameScene) {
        updateResourceDisplay()
    }
    
    func showSplitVillagerMenu(villagerGroup: VillagerGroup, entityNode: EntityNode) {
        showSplitVillagerGroupMenu(villagerGroup: villagerGroup, entity: entityNode)
    }
    
    func showMergeMenu(group1: EntityNode, group2: EntityNode) {
        showMergeOption(for: group1, and: group2)
    }
}
