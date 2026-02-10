import UIKit
import SpriteKit

class GameViewController: UIViewController {
    
    var skView: SKView!
    var gameScene: GameScene!
    var player: Player!
    var mapType: MapType = .arabia  // Arabia is default
    var mapSize: MapSize = .medium
    var resourceDensity: ResourceDensity = .normal
    var visibilityMode: VisibilityMode = .normal
    var arenaArmyConfig: ArenaArmyConfiguration?
    var arenaScenarioConfig: ArenaScenarioConfig?
    var autoSimMode: Bool = false
    var simRunCount: Int = 1
    var mapSeed: UInt64?
    var onlineGameID: String?
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

    // Rotation Preview UI
    var rotationPreviewOverlay: UIView?
    var rotationBuildingLabel: UILabel?
    var rotationDirectionLabel: UILabel?

    // Entities button and badge
    private var entitiesButton: UIButton?
    private var entitiesBadgeView: UIView?
    private var entitiesBadgeLabel: UILabel?

    // Starvation countdown UI
    private var starvationCountdownLabel: UILabel?
    private var starvationCountdownTimer: Timer?

    // Notification banner
    private var notificationBannerContainer: NotificationBannerContainer?

    // Notification bell icon
    private var notificationBellButton: UIButton?
    private var notificationBellBadge: UIView?
    private var notificationBellBadgeLabel: UILabel?

    // Gear menu button (top-right, next to bell)
    private var menuGearButton: UIButton?

    // Top-right button container
    private var topButtonStack: UIStackView?
    private var resourcePanelBottomConstraint: NSLayoutConstraint?

    private struct AssociatedKeys {
        static var villagerCountLabel: UInt8 = 2
        static var splitLabels: UInt8 = 3
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
        player = Player(name: "Rob", color: .blue)
    
        setupSKView()
        setupUI()
    
        menuCoordinator = MenuCoordinator(viewController: self, delegate: self)
        entityActionHandler = EntityActionHandler(viewController: self, delegate: self)
        ResearchManager.shared.setup(player: player)
        NotificationManager.shared.setup(localPlayerID: player.id)

        setupNotificationBanner()
        setupNotificationBell()
        setupMenuGearButton()
        setupAutoSave()
    
        // ✅ FIX: Only setup a new scene if NOT loading a saved game
        if shouldLoadGame {
            // Create an empty scene shell - loadGame() will populate it
            // Use completion-based flow instead of hardcoded delays
            setupEmptyScene { [weak self] in
                guard let self = self else { return }

                self.loadGame()

                // Setup CommandExecutor AFTER game is loaded (hexMap is now available)
                self.setupCommandExecutor()

                // Process background time AFTER loading
                // Use a small delay to ensure all visual updates are complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.processBackgroundTime()
                }
            }
        } else {
            // New game - setup scene normally (this generates the map)
            setupScene()
            updateResourceDisplay()

            // Setup CommandExecutor for new game (hexMap is ready)
            setupCommandExecutor()
        }
        
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

        // Listen for combat end notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePhasedCombatEnded),
            name: .phasedCombatEnded,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBuildingCombatEnded),
            name: .buildingCombatEnded,
            object: nil
        )

        // Listen for jump to coordinate (from push notification taps)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleJumpToCoordinate),
            name: .jumpToCoordinate,
            object: nil
        )

        // Listen for starvation start to immediately show countdown
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStarvationStarted),
            name: .starvationStarted,
            object: nil
        )

    }
    
    @objc func handleAppWillEnterForeground() {
        debugLog("📱 App returning to foreground - processing background time")
        processBackgroundTime()
    }

    @objc func handleJumpToCoordinate(_ notification: Notification) {
        guard let coordinate = notification.userInfo?["coordinate"] as? HexCoordinate else { return }
        debugLog("📍 Push notification tap - jumping to coordinate: \(coordinate)")
        gameScene.focusCamera(on: coordinate, zoom: 0.7, animated: true)
    }

    @objc func handlePhasedCombatEnded(_ notification: Notification) {
        guard let combat = notification.object as? ActiveCombat else { return }

        // Check if player was involved
        let playerID = player?.id

        // Get owner IDs from the army state (which was captured when combat started)
        var attackerOwnerID: UUID?
        var defenderOwnerID: UUID?

        if let attackerArmyID = combat.attackerArmies.first?.armyID {
            attackerOwnerID = GameEngine.shared.gameState?.getArmy(id: attackerArmyID)?.ownerID
        }
        if let defenderArmyID = combat.defenderArmies.first?.armyID {
            defenderOwnerID = GameEngine.shared.gameState?.getArmy(id: defenderArmyID)?.ownerID
        }

        let playerWasAttacker = attackerOwnerID == playerID
        let playerWasDefender = defenderOwnerID == playerID

        // Only show notification if player was involved
        guard playerWasAttacker || playerWasDefender else { return }

        // Determine if player won
        let isVictory: Bool
        switch combat.winner {
        case .attackerVictory:
            isVictory = playerWasAttacker
        case .defenderVictory:
            isVictory = playerWasDefender
        case .draw:
            isVictory = false
        }

        // Build message
        let attackerName = combat.attackerArmies.first?.armyName ?? "Unknown"
        let defenderName = combat.defenderArmies.first?.armyName ?? "Unknown"
        let attackerCasualties = combat.attackerState.initialUnitCount - combat.attackerState.totalUnits
        let defenderCasualties = combat.defenderState.initialUnitCount - combat.defenderState.totalUnits

        var message = "\(attackerName) vs \(defenderName)"
        message += "\n\nYour casualties: \(playerWasAttacker ? attackerCasualties : defenderCasualties)"
        message += "\nEnemy casualties: \(playerWasAttacker ? defenderCasualties : attackerCasualties)"

        let title = isVictory ? "Battle Won!" : "Battle Lost"

        showBattleEndNotification(title: title, message: message, isVictory: isVictory, buildingDamage: nil)
    }

    @objc func handleBuildingCombatEnded(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let attackerArmyID = userInfo["attackerArmyID"] as? UUID,
              let result = userInfo["result"] as? CombatResultData else { return }

        // Check if player was the attacker
        let playerID = player?.id
        let attackerOwnerID = GameEngine.shared.gameState?.getArmy(id: attackerArmyID)?.ownerID

        let playerWasAttacker = attackerOwnerID == playerID

        // Only show notification if player was the attacker (buildings don't attack)
        guard playerWasAttacker else { return }

        // Player attacking a building is always a "victory" if they dealt damage
        let isVictory = true

        let message = "Building assault complete!"

        let title = result.buildingDamage?.wasDestroyed == true ? "Building Destroyed!" : "Building Damaged"

        showBattleEndNotification(title: title, message: message, isVictory: isVictory, buildingDamage: result.buildingDamage)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        starvationCountdownTimer?.invalidate()
        starvationCountdownTimer = nil
    }
    
    @objc func handleAppWillSave() {
        debugLog("📱 Received app save notification")
        autoSaveGame()
    }
    
    func setupEmptyScene(completion: @escaping () -> Void) {
        gameScene = GameScene(size: skView.bounds.size)
        gameScene.scaleMode = .resizeFill
        gameScene.player = player
        gameScene.gameDelegate = self

        // ✅ Set a flag to tell GameScene NOT to generate a new map
        gameScene.skipInitialSetup = true

        // ✅ FIX: Set up completion callback BEFORE presenting scene
        gameScene.onSceneReady = { [weak self] in
            guard let self = self else { return }
            // Verify all critical nodes are initialized
            guard self.gameScene.isSceneReady,
                  self.gameScene.mapNode != nil,
                  self.gameScene.buildingsNode != nil,
                  self.gameScene.entitiesNode != nil else {
                debugLog("⚠️ Scene not fully ready, waiting...")
                // Retry after a short delay if nodes aren't ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.gameScene.onSceneReady?()
                }
                return
            }
            debugLog("✅ Scene ready - proceeding with game load")
            completion()
        }

        skView.presentScene(gameScene)
    }
    
    func initializePlayers() {
        // Create human player
        player = Player(name: "Rob", color: .blue)

        // Create AI opponent
        let aiPlayer = Player(name: "Enemy", color: .red, isAI: true)
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

    func setupCommandExecutor() {
        guard gameScene.hexMap != nil else {
            debugLog("⚠️ Cannot setup CommandExecutor - hexMap is nil")
            return
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
    }
    
    func setupScene() {
        gameScene = GameScene(size: skView.bounds.size)
        gameScene.scaleMode = .resizeFill
        gameScene.player = player
        gameScene.gameDelegate = self

        if mapType == .arabia {
            // Use Arabia map generator for competitive 1v1 maps
            gameScene.skipInitialSetup = true
            skView.presentScene(gameScene)

            // Create AI opponent
            let aiPlayer = Player(name: "Enemy", color: .red, isAI: true)

            // Setup map with Arabia generator (use seed for reproducible maps)
            let seed = mapSeed ?? GameSessionService.shared.currentSession?.mapConfig.seed
            let arabiaConfig: ArabiaMapGenerator.Config
            if let sessionConfig = GameSessionService.shared.currentSession?.mapConfig {
                arabiaConfig = sessionConfig.toArabiaConfig()
            } else {
                arabiaConfig = ArabiaMapGenerator.Config()
            }
            let generator = ArabiaMapGenerator(seed: seed, config: arabiaConfig)
            gameScene.setupMapWithGenerator(generator, players: [player, aiPlayer])

            // Initialize fog of war after map is ready
            let fullyVisible = visibilityMode == .fullyVisible
            gameScene.initializeFogOfWar(fullyVisible: fullyVisible)

            debugLog("Arabia map generated!")
        } else if mapType == .arena {
            // Use Arena map generator for combat testing
            gameScene.skipInitialSetup = true
            skView.presentScene(gameScene)

            // AI always off in arena for now
            let aiPlayer = Player(name: "Enemy", color: .red, isAI: false)

            // Setup arena with ArenaMapGenerator (configurable terrain)
            let generator = ArenaMapGenerator(enemyTerrain: arenaScenarioConfig?.enemyTerrain ?? .plains)
            gameScene.autoSimMode = autoSimMode
            gameScene.setupArenaWithGenerator(generator, players: [player, aiPlayer], armyConfig: arenaArmyConfig, scenarioConfig: arenaScenarioConfig)

            // Always fully visible for testing
            gameScene.initializeFogOfWar(fullyVisible: true)

            debugLog("Arena map generated!")
        } else {
            // Use random map generation (legacy)
            gameScene.mapSize = mapSize.rawValue
            gameScene.resourceDensity = resourceDensity.multiplier
            skView.presentScene(gameScene)

            debugLog("Random map generated!")
        }

        // Initialize game start time for statistics
        gameScene.gameStartTime = Date().timeIntervalSince1970

        // Setup game over callback
        gameScene.onGameOver = { [weak self] isVictory, reason in
            DispatchQueue.main.async {
                self?.handleGameOver(isVictory: isVictory, reason: reason)
            }
        }

        // Initialize the engine architecture for state management
        // This must be called after the map is set up and players are configured
        gameScene.initializeEngineArchitecture()

        // Start online session heartbeat and update status if in a session
        if GameSessionService.shared.currentSession != nil {
            GameSessionService.shared.updateGameStatus(.playing)
            GameSessionService.shared.startHeartbeat()
        }

        // Auto-sim: set fast speed and auto-initiate combat
        if autoSimMode && mapType == .arena {
            GameEngine.shared.setGameSpeed(10.0)

            // Listen for combat end to show results
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleAutoSimCombatEnded(_:)),
                name: .phasedCombatEnded,
                object: nil
            )

            // Auto-issue attack command after a brief delay for setup to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.initiateAutoSimAttack()
            }
        }
    }

    // MARK: - Auto-Sim

    private func initiateAutoSimAttack() {
        guard let gameState = GameEngine.shared.gameState else { return }
        let playerArmies = gameState.getArmiesForPlayer(id: player.id)
        guard let attackerArmy = playerArmies.first else { return }

        // Find enemy army position
        let enemyArmies = gameScene.allGamePlayers
            .filter { $0.id != player.id }
            .flatMap { gameState.getArmiesForPlayer(id: $0.id) }
        guard let targetArmy = enemyArmies.first else { return }

        // Use coordinate-only attack (no targetEntityID) to avoid entrenchment check on entity branch
        let command = AttackCommand(
            playerID: player.id,
            attackerEntityID: attackerArmy.id,
            targetCoordinate: targetArmy.coordinate
        )
        let result = CommandExecutor.shared.execute(command)

        // If attack failed (e.g. entrenched), directly start stack combat
        if case .failure = result {
            debugLog("Auto-sim: Attack command failed, starting stack combat directly")
            let combatTime = gameState.currentTime
            _ = GameEngine.shared.combatEngine.startStackCombat(
                attackerArmyIDs: [attackerArmy.id],
                at: targetArmy.coordinate,
                currentTime: combatTime
            )
        }
        debugLog("Auto-sim: Attack command issued")
    }

    @objc func handleAutoSimCombatEnded(_ notification: Notification) {
        guard autoSimMode else { return }

        // Small delay to let combat history be recorded
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            // Check if any combats still active
            let engine = GameEngine.shared
            if engine.combatEngine.activeCombats.isEmpty && engine.combatEngine.stackCombats.isEmpty {
                self.showAutoSimResults()
            }
        }
    }

    private func showAutoSimResults() {
        // Remove observer
        NotificationCenter.default.removeObserver(self, name: .phasedCombatEnded, object: nil)

        let records = GameEngine.shared.combatEngine.getDetailedCombatHistory()
        let resultsVC = ArenaResultsViewController()
        resultsVC.detailedRecords = records
        resultsVC.scenarioConfig = arenaScenarioConfig
        resultsVC.modalPresentationStyle = .fullScreen
        present(resultsVC, animated: true)
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

        // Calculate combat outcome using new combat stats
        let attackerStats = attacker.getAggregatedCombatStats()
        let defenderStats = targetEntity.getAggregatedCombatStats()
        let effectiveDamage = attackerStats.calculateEffectiveDamage(against: defenderStats, targetCategory: targetEntity.getPrimaryCategory())
        let defenderEffectiveDamage = defenderStats.calculateEffectiveDamage(against: attackerStats, targetCategory: attacker.getPrimaryCategory())

        var resultMessage = "⚔️ Battle Report\n\n"
        resultMessage += "Attacker: \(attacker.name)\n"
        resultMessage += "Effective Damage: \(Int(effectiveDamage))\n\n"
        resultMessage += "Defender: \(targetEntity.name)\n"
        resultMessage += "Effective Damage: \(Int(defenderEffectiveDamage))\n\n"
        
        // Simple combat calculation using effective damage
        if effectiveDamage > defenderEffectiveDamage {
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

        // Show combat stats using new system
        let stats = army.getAggregatedCombatStats()
        message += "💪 Combat Stats:\n"
        message += "⚔️ Damage: M:\(Int(stats.meleeDamage)) P:\(Int(stats.pierceDamage)) B:\(Int(stats.bludgeonDamage))\n"
        message += "🛡️ Armor: M:\(Int(stats.meleeArmor)) P:\(Int(stats.pierceArmor)) B:\(Int(stats.bludgeonArmor))\n"
        message += "❤️ Total HP: \(Int(army.getTotalHP()))"

        return message
    }
    
    func formatBuildingCost(_ buildingType: BuildingType) -> String {
        let costs = buildingType.buildCost.sorted(by: { $0.key.rawValue < $1.key.rawValue })
        return costs.map { "\($0.key.icon)\($0.value)" }.joined(separator: " ")
    }
    
    func updateResourceDisplay() {
        guard let player = player else { return }
        
        for (resourceType, label) in resourceLabels {
            let amount = player.getResource(resourceType)
            let cap = player.getStorageCapacity(for: resourceType)
            let rate = player.getCollectionRate(resourceType)
            let storagePercent = player.getStoragePercent(for: resourceType)

            // Color based on how full this resource's storage is
            let textColor: UIColor
            if storagePercent >= 1.0 {
                textColor = .systemRed
            } else if storagePercent >= 0.9 {
                textColor = .systemOrange
            } else {
                textColor = .white
            }

            if resourceType == .food {
                // Show net food rate (production minus population consumption)
                let consumptionRate = player.getFoodConsumptionRate()
                let netRate = rate - consumptionRate
                let sign = netRate >= 0 ? "+" : ""
                label.text = "\(resourceType.icon) \(amount)/\(cap) (\(sign)\(String(format: "%.1f", netRate))/s)"
                if netRate < 0 {
                    label.textColor = .systemRed
                } else if storagePercent >= 1.0 {
                    label.textColor = .systemRed
                } else {
                    label.textColor = .systemGreen
                }
            } else {
                let sign = rate >= 0 ? "+" : ""
                if rate < 0 {
                    label.textColor = .systemRed
                } else {
                    label.textColor = textColor
                }
                label.text = "\(resourceType.icon) \(amount)/\(cap) (\(sign)\(String(format: "%.1f", rate))/s)"
            }
        }
        
        // Population display
        let currentPop = player.getCurrentPopulation()
        let maxPop = player.getPopulationCapacity()
        let consumptionRate = player.getFoodConsumptionRate()
        
        let popColor: UIColor = currentPop >= maxPop ? .systemOrange : .white
        populationLabel.textColor = popColor
        populationLabel.text = "👥 \(currentPop)/\(maxPop) (-\(String(format: "%.1f", consumptionRate))/s 🌾)"
        
        // Storage label now shows summary info (optional)
        if let storageLabel = storageLabel {
            // Count how many resources are near capacity
            var nearCapCount = 0
            var fullCount = 0
            
            for type in ResourceType.allCases {
                let percent = player.getStoragePercent(for: type)
                if percent >= 1.0 {
                    fullCount += 1
                } else if percent >= 0.9 {
                    nearCapCount += 1
                }
            }
            
            if fullCount > 0 {
                storageLabel.textColor = .systemRed
                storageLabel.text = "⚠️ \(fullCount) resource(s) FULL!"
            } else if nearCapCount > 0 {
                storageLabel.textColor = .systemOrange
                storageLabel.text = "⚠️ \(nearCapCount) resource(s) near cap"
            } else {
                storageLabel.textColor = .white
                storageLabel.text = ""  // Hide when storage is fine
            }
        }

        // Update idle villager badge
        updateEntitiesBadge()

        // Check starvation countdown status
        updateStarvationStatus()
    }
    
    func setupUI() {
        // Resource Panel (Top) - Auto Layout, height determined by content
        resourcePanel = UIView()
        resourcePanel.backgroundColor = UIColor(white: 0.1, alpha: 0.9)
        resourcePanel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(resourcePanel)

        // Resource panel: full-width bar across the top
        NSLayoutConstraint.activate([
            resourcePanel.topAnchor.constraint(equalTo: view.topAnchor),
            resourcePanel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            resourcePanel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        // Top-right button stack (menu + mailbox) inside the resource panel
        let buttonStack = UIStackView()
        buttonStack.axis = .horizontal
        buttonStack.spacing = 4
        buttonStack.alignment = .center
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        resourcePanel.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            buttonStack.trailingAnchor.constraint(equalTo: resourcePanel.trailingAnchor, constant: -8),
            buttonStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
        ])
        topButtonStack = buttonStack

        // Resource labels - horizontal row across top
        let resourceTypes: [ResourceType] = [.wood, .food, .stone, .ore]
        let resourceStack = UIStackView()
        resourceStack.axis = .horizontal
        resourceStack.distribution = .fillEqually
        resourceStack.spacing = 8
        resourceStack.translatesAutoresizingMaskIntoConstraints = false
        resourcePanel.addSubview(resourceStack)

        NSLayoutConstraint.activate([
            resourceStack.leadingAnchor.constraint(equalTo: resourcePanel.leadingAnchor, constant: 12),
            resourceStack.trailingAnchor.constraint(equalTo: buttonStack.leadingAnchor, constant: -8),
            resourceStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 6),
            resourceStack.heightAnchor.constraint(equalToConstant: 24)
        ])

        for resourceType in resourceTypes {
            let label = UILabel()
            label.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            label.textColor = .white
            label.textAlignment = .center
            label.text = "\(resourceType.icon) 0/0 (+0.0)"
            resourceStack.addArrangedSubview(label)
            resourceLabels[resourceType] = label
        }

        // Bottom row: Population + Storage warning
        let bottomStack = UIStackView()
        bottomStack.axis = .horizontal
        bottomStack.distribution = .fill
        bottomStack.spacing = 8
        bottomStack.translatesAutoresizingMaskIntoConstraints = false
        resourcePanel.addSubview(bottomStack)

        NSLayoutConstraint.activate([
            bottomStack.leadingAnchor.constraint(equalTo: resourcePanel.leadingAnchor, constant: 12),
            bottomStack.trailingAnchor.constraint(equalTo: buttonStack.leadingAnchor, constant: -8),
            bottomStack.topAnchor.constraint(equalTo: resourceStack.bottomAnchor, constant: 4),
            bottomStack.heightAnchor.constraint(equalToConstant: 24)
        ])

        // Population label (centered)
        populationLabel = UILabel()
        populationLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        populationLabel.textColor = .white
        populationLabel.textAlignment = .center
        populationLabel.text = "👥 0/0 (-0.0 🌾/s)"
        bottomStack.addArrangedSubview(populationLabel)

        // Storage warning label (right side)
        storageLabel = UILabel()
        storageLabel?.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        storageLabel?.textColor = .white
        storageLabel?.textAlignment = .right
        storageLabel?.setContentHuggingPriority(.defaultLow, for: .horizontal)
        if let storageLabel = storageLabel {
            bottomStack.addArrangedSubview(storageLabel)
        }

        // Panel bottom = bottomStack bottom + 8 (compact height)
        resourcePanelBottomConstraint = resourcePanel.bottomAnchor.constraint(equalTo: bottomStack.bottomAnchor, constant: 8)
        resourcePanelBottomConstraint?.isActive = true

        // Starvation countdown label (appears below bottom stack when food is 0)
        let starvationLabel = UILabel()
        starvationLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .bold)
        starvationLabel.textColor = .systemRed
        starvationLabel.textAlignment = .center
        starvationLabel.text = ""
        starvationLabel.isHidden = true
        starvationLabel.translatesAutoresizingMaskIntoConstraints = false
        resourcePanel.addSubview(starvationLabel)

        NSLayoutConstraint.activate([
            starvationLabel.leadingAnchor.constraint(equalTo: resourcePanel.leadingAnchor, constant: 12),
            starvationLabel.trailingAnchor.constraint(equalTo: buttonStack.leadingAnchor, constant: -8),
            starvationLabel.topAnchor.constraint(equalTo: bottomStack.bottomAnchor, constant: 4),
            starvationLabel.heightAnchor.constraint(equalToConstant: 20)
        ])
        starvationCountdownLabel = starvationLabel

        // Bottom Button Bar
        let bottomBar = UIView(frame: CGRect(x: 0, y: view.bounds.height - 60, width: view.bounds.width, height: 60))
        bottomBar.backgroundColor = UIColor(white: 0.1, alpha: 0.9)
        bottomBar.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]

        // Button stack view
        let bottomButtonStack = UIStackView()
        bottomButtonStack.axis = .horizontal
        bottomButtonStack.distribution = .fillEqually
        bottomButtonStack.spacing = 4
        bottomButtonStack.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(bottomButtonStack)

        NSLayoutConstraint.activate([
            bottomButtonStack.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 8),
            bottomButtonStack.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -8),
            bottomButtonStack.topAnchor.constraint(equalTo: bottomBar.topAnchor, constant: 8),
            bottomButtonStack.bottomAnchor.constraint(equalTo: bottomBar.bottomAnchor, constant: -8)
        ])

        // Create buttons for bottom bar
        let buttonConfigs: [(title: String, action: Selector, color: UIColor)] = [
            ("Commanders", #selector(showCommandersScreen), UIColor(red: 0.3, green: 0.4, blue: 0.8, alpha: 1.0)),
            ("Battles", #selector(showCombatHistoryScreen), UIColor(red: 0.8, green: 0.3, blue: 0.3, alpha: 1.0)),
            ("Research", #selector(showResearchScreen), UIColor(red: 0.4, green: 0.6, blue: 0.3, alpha: 1.0)),
            ("Training", #selector(showTrainingOverview), UIColor(red: 0.5, green: 0.5, blue: 0.3, alpha: 1.0)),
            ("Military", #selector(showMilitaryOverview), UIColor(red: 0.7, green: 0.3, blue: 0.3, alpha: 1.0)),
            ("Buildings", #selector(showBuildingsOverview), UIColor(red: 0.5, green: 0.4, blue: 0.6, alpha: 1.0)),
            ("Resources", #selector(showResourcesOverview), UIColor(red: 0.6, green: 0.5, blue: 0.2, alpha: 1.0)),
            ("Entities", #selector(showEntitiesOverview), UIColor(red: 0.3, green: 0.5, blue: 0.5, alpha: 1.0))
        ]

        for config in buttonConfigs {
            let button = UIButton(type: .system)
            button.setTitle(config.title, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
            button.backgroundColor = config.color
            button.setTitleColor(.white, for: .normal)
            button.layer.cornerRadius = 6
            button.addTarget(self, action: config.action, for: .touchUpInside)
            bottomButtonStack.addArrangedSubview(button)

            // Store reference to Entities button for badge
            if config.title == "Entities" {
                entitiesButton = button
            }
        }

        // Create idle villager badge for Entities button
        setupEntitiesBadge()

        view.addSubview(bottomBar)
    }

    // MARK: - Notification Banner

    func setupNotificationBanner() {
        let bannerContainer = NotificationBannerContainer()
        bannerContainer.translatesAutoresizingMaskIntoConstraints = false
        bannerContainer.delegate = self
        view.addSubview(bannerContainer)

        // Position below the resource panel
        NSLayoutConstraint.activate([
            bannerContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bannerContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bannerContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 100),
            bannerContainer.heightAnchor.constraint(equalToConstant: 60)
        ])

        notificationBannerContainer = bannerContainer
    }

    // MARK: - Notification Bell

    func setupNotificationBell() {
        guard let buttonStack = topButtonStack else { return }

        // Menu button (left) - SF Symbol hamburger icon
        let menuButton = UIButton(type: .system)
        menuButton.translatesAutoresizingMaskIntoConstraints = false
        let menuImage = UIImage(systemName: "line.3.horizontal")?.withConfiguration(
            UIImage.SymbolConfiguration(pointSize: 16, weight: .medium))
        menuButton.setImage(menuImage, for: .normal)
        menuButton.tintColor = .white
        menuButton.addTarget(self, action: #selector(showGameMenu), for: .touchUpInside)
        buttonStack.addArrangedSubview(menuButton)

        NSLayoutConstraint.activate([
            menuButton.widthAnchor.constraint(equalToConstant: 36),
            menuButton.heightAnchor.constraint(equalToConstant: 36)
        ])
        menuGearButton = menuButton

        // Notification button (right) - SF Symbol envelope icon
        let bellButton = UIButton(type: .system)
        bellButton.translatesAutoresizingMaskIntoConstraints = false
        let envelopeImage = UIImage(systemName: "envelope")?.withConfiguration(
            UIImage.SymbolConfiguration(pointSize: 16, weight: .medium))
        bellButton.setImage(envelopeImage, for: .normal)
        bellButton.tintColor = .white
        bellButton.addTarget(self, action: #selector(showNotificationsInbox), for: .touchUpInside)
        buttonStack.addArrangedSubview(bellButton)

        NSLayoutConstraint.activate([
            bellButton.widthAnchor.constraint(equalToConstant: 36),
            bellButton.heightAnchor.constraint(equalToConstant: 36)
        ])
        notificationBellButton = bellButton

        // Create badge on envelope button
        let badge = UIView()
        badge.backgroundColor = .systemRed
        badge.layer.cornerRadius = 8
        badge.clipsToBounds = true
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.isHidden = true
        badge.isUserInteractionEnabled = false
        bellButton.addSubview(badge)

        // Badge label
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(label)

        // Position badge at top-right of button
        NSLayoutConstraint.activate([
            badge.topAnchor.constraint(equalTo: bellButton.topAnchor, constant: -3),
            badge.trailingAnchor.constraint(equalTo: bellButton.trailingAnchor, constant: 3),
            badge.widthAnchor.constraint(greaterThanOrEqualToConstant: 16),
            badge.heightAnchor.constraint(equalToConstant: 16),

            label.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: badge.leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(lessThanOrEqualTo: badge.trailingAnchor, constant: -4)
        ])

        notificationBellBadge = badge
        notificationBellBadgeLabel = label

        // Observe history changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateNotificationBellBadge),
            name: .notificationHistoryChanged,
            object: nil
        )

        // Initial badge update
        updateNotificationBellBadge()
    }

    // MARK: - Menu Gear Button

    func setupMenuGearButton() {
        // Menu button is now created inside setupNotificationBell() as part of the button container
    }

    func showSettings() {
        let settingsVC = SettingsViewController()
        settingsVC.modalPresentationStyle = .fullScreen
        present(settingsVC, animated: true)
    }

    @objc func updateNotificationBellBadge() {
        guard let badge = notificationBellBadge,
              let label = notificationBellBadgeLabel else { return }

        let unreadCount = NotificationManager.shared.unreadCount

        if unreadCount > 0 {
            label.text = unreadCount > 99 ? "99+" : "\(unreadCount)"
            badge.isHidden = false
        } else {
            badge.isHidden = true
        }
    }

    @objc func showNotificationsInbox() {
        let inboxVC = NotificationsInboxViewController()
        inboxVC.gameScene = gameScene
        inboxVC.modalPresentationStyle = .pageSheet

        if let sheet = inboxVC.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }

        present(inboxVC, animated: true)
    }

    func setupEntitiesBadge() {
        guard let button = entitiesButton else { return }

        // Create badge view
        let badge = UIView()
        badge.backgroundColor = .systemRed
        badge.layer.cornerRadius = 9
        badge.clipsToBounds = true
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.isHidden = true  // Hidden by default
        badge.isUserInteractionEnabled = false
        button.addSubview(badge)

        // Badge label
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(label)

        // Position badge at top-right of button
        NSLayoutConstraint.activate([
            badge.topAnchor.constraint(equalTo: button.topAnchor, constant: -4),
            badge.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: 4),
            badge.widthAnchor.constraint(greaterThanOrEqualToConstant: 18),
            badge.heightAnchor.constraint(equalToConstant: 18),

            label.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: badge.leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(lessThanOrEqualTo: badge.trailingAnchor, constant: -4)
        ])

        entitiesBadgeView = badge
        entitiesBadgeLabel = label
    }

    func updateEntitiesBadge() {
        guard let badge = entitiesBadgeView,
              let label = entitiesBadgeLabel,
              let player = player else { return }

        let idleCount = player.getIdleVillagerCount()

        if idleCount > 0 {
            label.text = "\(idleCount)"
            badge.isHidden = false
        } else {
            badge.isHidden = true
        }
    }

    // MARK: - Starvation Countdown

    /// Starts the starvation countdown timer when food reaches 0
    func startStarvationCountdown() {
        // Avoid duplicate timers
        guard starvationCountdownTimer == nil else { return }

        starvationCountdownLabel?.isHidden = false
        // Expand panel to fit starvation label (bottomStack + 4 gap + 20 height + 4 padding)
        resourcePanelBottomConstraint?.constant = 28
        UIView.animate(withDuration: 0.2) { self.view.layoutIfNeeded() }
        updateStarvationCountdownLabel()

        starvationCountdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateStarvationCountdownLabel()
        }

        debugLog("⚠️ Starvation countdown started")
    }

    /// Stops the starvation countdown timer when food is restored
    func stopStarvationCountdown() {
        starvationCountdownTimer?.invalidate()
        starvationCountdownTimer = nil
        starvationCountdownLabel?.isHidden = true
        starvationCountdownLabel?.text = ""
        // Shrink panel back to compact height
        resourcePanelBottomConstraint?.constant = 8
        UIView.animate(withDuration: 0.2) { self.view.layoutIfNeeded() }

        debugLog("✅ Starvation countdown stopped - food restored")
    }

    /// Updates the starvation countdown label with remaining time
    @objc func updateStarvationCountdownLabel() {
        guard let gameScene = gameScene,
              let remaining = gameScene.getStarvationTimeRemaining() else {
            // zeroFoodStartTime not set yet - show generic warning while waiting
            // Don't call stopStarvationCountdown() here: it causes a race condition
            // where the label is hidden before checkStarvationCondition() sets zeroFoodStartTime.
            // Stopping is handled by updateStarvationStatus() when food > 0.
            starvationCountdownLabel?.text = "☠️ STARVATION WARNING - GATHER FOOD!"
            return
        }

        let seconds = Int(remaining)
        starvationCountdownLabel?.text = "☠️ STARVATION IN \(seconds)s - GATHER FOOD!"

        // Pulse effect for urgency when time is low
        if seconds <= 10 {
            UIView.animate(withDuration: 0.3, animations: {
                self.starvationCountdownLabel?.alpha = 0.5
            }) { _ in
                UIView.animate(withDuration: 0.3) {
                    self.starvationCountdownLabel?.alpha = 1.0
                }
            }
        }
    }

    @objc func handleStarvationStarted() {
        startStarvationCountdown()
    }

    /// Checks if starvation countdown should be running and starts/stops accordingly
    func updateStarvationStatus() {
        guard let player = player else { return }

        let currentFood = player.getResource(.food)

        if currentFood <= 0 {
            // Food is at 0, ensure countdown is running
            if starvationCountdownTimer == nil {
                startStarvationCountdown()
            }
        } else {
            // Food is above 0, stop countdown if running
            if starvationCountdownTimer != nil {
                stopStarvationCountdown()
            }
        }
    }

    @objc func showResearchScreen() {
        let researchVC = ResearchViewController()
        researchVC.player = player
        researchVC.modalPresentationStyle = .fullScreen
        present(researchVC, animated: true)
        debugLog("🔬 Opening Research screen")
    }
    
    @objc func showBuildingsOverview() {
        let buildingsVC = BuildingsOverviewViewController()
        buildingsVC.player = player
        buildingsVC.hexMap = gameScene.hexMap
        buildingsVC.gameScene = gameScene
        buildingsVC.gameViewController = self  // ✅ ADD THIS LINE
        buildingsVC.modalPresentationStyle = .fullScreen
        present(buildingsVC, animated: true)
        debugLog("🏛️ Opening Buildings Overview screen")
    }

    @objc func showEntitiesOverview() {
        let entitiesVC = EntitiesOverviewViewController()
        entitiesVC.player = player
        entitiesVC.hexMap = gameScene.hexMap
        entitiesVC.gameScene = gameScene
        entitiesVC.gameViewController = self
        entitiesVC.modalPresentationStyle = .fullScreen
        present(entitiesVC, animated: true)
        debugLog("👥 Opening Entities Overview screen")
    }

    @objc func showResourcesOverview() {
        let resourceVC = ResourceOverviewViewController()
        resourceVC.player = player
        resourceVC.hexMap = gameScene.hexMap
        resourceVC.gameScene = gameScene
        resourceVC.gameViewController = self
        resourceVC.modalPresentationStyle = .pageSheet

        if let sheet = resourceVC.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }

        present(resourceVC, animated: true)
        debugLog("📦 Opening Resources Overview screen")
    }

    @objc func showGameMenu() {
        showActionSheet(
            title: "⚙️ Game Menu",
            actions: [
                AlertAction(title: "⚙️ Settings") { [weak self] in self?.showSettings() },
                AlertAction(title: "🏠 Main Menu") { [weak self] in self?.returnToMainMenu() },
                AlertAction(title: "🏳️ Resign", style: .destructive) { [weak self] in self?.confirmResign() }
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
        debugLog("🎓 Opening Training Overview screen")
    }

    @objc func showMilitaryOverview() {
        let militaryVC = MilitaryOverviewViewController()
        militaryVC.player = player
        militaryVC.hexMap = gameScene.hexMap
        militaryVC.gameScene = gameScene
        militaryVC.gameViewController = self
        militaryVC.modalPresentationStyle = .fullScreen
        present(militaryVC, animated: true)
        debugLog("⚔️ Opening Military Overview screen")
    }

    func confirmLoad() {
        showConfirmation(
            title: "⚠️ Load Game?",
            message: "Any unsaved progress will be lost. Continue?",
            confirmTitle: "Load",
            onConfirm: { [weak self] in self?.loadGame() }
        )
    }

    func confirmResign() {
        showDestructiveConfirmation(
            title: "🏳️ Resign Game?",
            message: "Are you sure you want to resign? This will end the game and count as a defeat.",
            confirmTitle: "Resign",
            onConfirm: { [weak self] in
                self?.gameScene?.resignGame()
            }
        )
    }

    func handleGameOver(isVictory: Bool, reason: GameOverReason) {
        // Stop auto-save
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil

        // Delete save immediately so a lost game can't be loaded
        _ = GameSaveManager.shared.deleteSave()

        // Clean up online session if this was an online game
        if let gameID = onlineGameID {
            GameSessionService.shared.deleteGame(gameID: gameID) { result in
                switch result {
                case .success:
                    debugLog("Online game session deleted: \(gameID)")
                case .failure(let error):
                    debugLog("Failed to delete online game session: \(error)")
                }
            }
            GameSessionService.shared.leaveSession()
            onlineGameID = nil
        }

        // Gather statistics
        let stats = GameStatistics.gather(from: player, gameStartTime: gameScene.gameStartTime)

        // Present game over screen
        let gameOverVC = GameOverViewController()
        gameOverVC.isVictory = isVictory
        gameOverVC.gameOverReason = reason
        gameOverVC.statistics = stats
        gameOverVC.modalPresentationStyle = .fullScreen

        present(gameOverVC, animated: true)
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
            debugLog("No valid location to deploy army")
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
        
        // Create EntityNode with actual Army object so armyReference is set correctly
        let armyNode = EntityNode(coordinate: spawnCoord, entityType: .army, entity: army, currentPlayer: player)
        let position = HexMap.hexToPixel(q: spawnCoord.q, r: spawnCoord.r)
        armyNode.position = position

        gameScene.hexMap.addEntity(armyNode)
        gameScene.entitiesNode.addChild(armyNode)

        // Register in visual layer
        gameScene.visualLayer?.registerEntityNode(id: army.id, node: armyNode)

        player.addArmy(army)

        // Add to player's entity list
        player.addEntity(army)

        debugLog("✅ Deployed army led by \(commander.name) with \(army.getTotalMilitaryUnits()) units")
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
    
    @objc func showCommandersScreen() {
        let commandersVC = CommandersViewController()
        commandersVC.player = player
        commandersVC.hexMap = gameScene.hexMap  // ✅ ADD THIS
        commandersVC.gameScene = gameScene      // ✅ ADD THIS
        commandersVC.modalPresentationStyle = .fullScreen
        present(commandersVC, animated: true)
        debugLog("👤 Opening Commanders screen")
    }

    /// Focuses the camera on a specific coordinate, optionally zooming in
    func focusOnCoordinate(_ coordinate: HexCoordinate, zoomIn: Bool = true) {
        let targetZoom: CGFloat? = zoomIn ? 0.7 : nil  // 0.7 is a good close-up zoom
        gameScene.focusCamera(on: coordinate, zoom: targetZoom)
    }

    @objc func showCombatHistoryScreen() {
        let combatHistoryVC = CombatHistoryViewController()
        combatHistoryVC.modalPresentationStyle = .fullScreen
        present(combatHistoryVC, animated: true)
        debugLog("⚔️ Opening Combat History screen")
    }
    
    func setupAutoSave() {
        // Start auto-save timer
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: autoSaveInterval, repeats: true) { [weak self] _ in
            self?.autoSaveGame()
        }
        debugLog("⏰ Auto-save enabled (every \(Int(autoSaveInterval))s)")
    }

    func autoSaveGame() {
        // Don't save if game is over (defeat/victory)
        guard !gameScene.isGameOver else { return }

        guard let player = player,
              let hexMap = gameScene.hexMap,
              !gameScene.allGamePlayers.isEmpty else {
            debugLog("⚠️ Cannot auto-save - game not ready")
            return
        }

        // Collect reinforcement groups from nodes
        let reinforcements = gameScene.reinforcementNodes.map { $0.reinforcement }

        let success = GameSaveManager.shared.saveGame(
            hexMap: hexMap,
            player: player,
            allPlayers: gameScene.allGamePlayers,
            reinforcements: reinforcements
        )

        if success {
            debugLog("Auto-save complete")

            // Create online snapshot if in an active session
            if let gameState = GameEngine.shared.getGameState(),
               GameSessionService.shared.currentSession != nil,
               GameSessionService.shared.shouldCreateSnapshot() {
                GameSessionService.shared.createSnapshot(gameState: gameState)
            }
        } else {
            debugLog("Auto-save failed")
        }
    }

    func manualSave() {
        guard let player = player,
              let hexMap = gameScene.hexMap,
              !gameScene.allGamePlayers.isEmpty else {
            showSimpleAlert(title: "Cannot Save", message: "Game is not ready to be saved.")
            return
        }

        // Collect reinforcement groups from nodes
        let reinforcements = gameScene.reinforcementNodes.map { $0.reinforcement }

        let success = GameSaveManager.shared.saveGame(
            hexMap: hexMap,
            player: player,
            allPlayers: gameScene.allGamePlayers,
            reinforcements: reinforcements
        )

        if success {
            showSimpleAlert(title: "✅ Game Saved", message: "Your progress has been saved successfully.")
        } else {
            showSimpleAlert(title: "❌ Save Failed", message: "Could not save the game. Please try again.")
        }
    }

    func loadGame() {
        // ✅ FIX: Ensure we're on the main thread for SpriteKit operations
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.loadGame()
            }
            return
        }

        // ✅ FIX: Verify scene is ready before loading
        guard gameScene != nil else {
            debugLog("❌ Cannot load game - gameScene is nil")
            showSimpleAlert(title: "Load Error", message: "Game scene not initialized.")
            return
        }

        guard gameScene.isSceneReady else {
            debugLog("❌ Cannot load game - scene not ready")
            showSimpleAlert(title: "Load Error", message: "Please wait for scene to initialize.")
            return
        }

        // ✅ FIX: Set loading flag to pause update() loop
        gameScene.isLoading = true

        // Disable engine updates to prevent stale state access during rebuild
        gameScene.isEngineEnabled = false

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
        gameScene.updateBuildingPlacementControllerReferences()  // Update building placement controller
        gameScene.updateReinforcementManagerReferences()  // Update reinforcement manager
        gameScene.updateVillagerJoinManagerReferences()  // Update villager join manager
        gameScene.allGamePlayers = loadedData.allPlayers

        // Rebuild the scene
        rebuildSceneWithLoadedData(hexMap: loadedData.hexMap, player: loadedData.player, allPlayers: loadedData.allPlayers)

        // Restore reinforcements
        restoreReinforcements(loadedData.reinforcements, hexMap: loadedData.hexMap, allPlayers: loadedData.allPlayers)
        
        // ✅ FIX: Clear loading flag AFTER everything is rebuilt
        gameScene.isLoading = false
        
        // ✅ DEBUG: Check fog stats after everything is loaded
        if let fogOfWar = player.fogOfWar {
            debugLog("\n🔍 POST-LOAD FOG CHECK:")
            fogOfWar.printFogStats()
            
            // Check a few specific tiles
            let testCoords = [
                HexCoordinate(q: 3, r: 3),
                HexCoordinate(q: 5, r: 5),
                HexCoordinate(q: 10, r: 10)
            ]
            
            for coord in testCoords {
                let vis = player.getVisibilityLevel(at: coord)
                debugLog("  Tile (\(coord.q), \(coord.r)): \(vis)")
            }
        }
        
        // Set game start time (approximate from save date or use current time)
        if gameScene.gameStartTime == 0 {
            gameScene.gameStartTime = Date().timeIntervalSince1970 - 300  // Assume 5 min played before save
        }

        // Setup game over callback
        gameScene.onGameOver = { [weak self] isVictory, reason in
            DispatchQueue.main.async {
                self?.handleGameOver(isVictory: isVictory, reason: reason)
            }
        }

        // Initialize the engine architecture for state management
        // This must be called after the map is rebuilt and players are configured
        gameScene.initializeEngineArchitecture()

        debugLog("✅ Game loaded successfully")
        showSimpleAlert(title: "✅ Game Loaded", message: "Your saved game has been restored.")
    }

    func rebuildSceneWithLoadedData(hexMap: HexMap, player: Player, allPlayers: [Player]) {
        // ✅ FIX: Ensure we're on the main thread for SpriteKit operations
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.rebuildSceneWithLoadedData(hexMap: hexMap, player: player, allPlayers: allPlayers)
            }
            return
        }

        // ✅ Guard: Ensure scene and critical nodes are ready
        guard gameScene != nil else {
            debugLog("❌ Cannot rebuild scene - gameScene is nil")
            showSimpleAlert(title: "Load Error", message: "Game scene not ready. Please try again.")
            return
        }

        guard gameScene.mapNode != nil,
              gameScene.buildingsNode != nil,
              gameScene.entitiesNode != nil else {
            debugLog("❌ Cannot rebuild scene - critical nodes are nil")
            debugLog("   mapNode: \(gameScene.mapNode != nil)")
            debugLog("   buildingsNode: \(gameScene.buildingsNode != nil)")
            debugLog("   entitiesNode: \(gameScene.entitiesNode != nil)")
            showSimpleAlert(title: "Load Error", message: "Scene not fully initialized. Please try again.")
            return
        }

        // Cancel running actions on old buildings to prevent stale closure execution
        if let oldHexMap = gameScene.hexMap {
            for building in oldHexMap.buildings {
                building.removeAllActions()
            }
        }

        // Clear old visual layer's node references before removing children
        gameScene.visualLayer?.cleanup()

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

            // Create per-tile visual overlays for multi-tile buildings
            if building.buildingType.hexSize > 1 {
                building.createTileOverlays(in: gameScene)
            }

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

        // ✅ FIX: Reconnect villager tasks to resource points (handles both gathering AND hunting)
        debugLog("🔗 Reconnecting villager tasks to resources...")
        for entity in hexMap.entities {
            if let villagerGroup = entity.entity as? VillagerGroup,
               let targetCoord = villagerGroup.taskTarget {

                // Find resource at the target coordinate
                if let resourcePoint = hexMap.resourcePoints.first(where: {
                    $0.coordinate == targetCoord
                }) {
                    // Check if the resource is huntable vs gatherable
                    if resourcePoint.resourceType.isHuntable {
                        // Re-establish hunting task
                        villagerGroup.currentTask = .hunting(resourcePoint)
                        villagerGroup.taskTarget = nil
                        entity.isMoving = true
                        debugLog("🏹 Reconnected \(villagerGroup.name) (\(villagerGroup.villagerCount) villagers) to hunt \(resourcePoint.resourceType.displayName)")
                    } else if resourcePoint.resourceType.isGatherable {
                        // Re-establish the gathering relationship
                        resourcePoint.startGathering(by: villagerGroup)
                        villagerGroup.currentTask = .gatheringResource(resourcePoint)
                        villagerGroup.taskTarget = nil
                        entity.isMoving = true
                        debugLog("⛏️ Reconnected \(villagerGroup.name) (\(villagerGroup.villagerCount) villagers) to gather \(resourcePoint.resourceType.displayName)")
                    } else {
                        // Resource can't be gathered or hunted (shouldn't happen)
                        villagerGroup.currentTask = .idle
                        villagerGroup.taskTarget = nil
                        entity.isMoving = false
                        debugLog("⚠️ Resource at (\(targetCoord.q), \(targetCoord.r)) cannot be gathered or hunted, \(villagerGroup.name) is now idle")
                    }
                } else {
                    // Resource no longer exists (depleted), clear the task
                    villagerGroup.currentTask = .idle
                    villagerGroup.taskTarget = nil
                    entity.isMoving = false
                    debugLog("⚠️ Resource at (\(targetCoord.q), \(targetCoord.r)) no longer exists, \(villagerGroup.name) is now idle")
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
            debugLog("🔍 After updateVision - Explored: \(fogOfWar.getExploredCount()), Visible: \(fogOfWar.getVisibleCount())")
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
        
        // Recalculate map bounds for camera constraints
        gameScene.calculateMapBounds()

        // Update resource display
        updateResourceDisplay()

        debugLog("🔄 Scene rebuilt with loaded data")
        debugLog("   Tiles: \(hexMap.tiles.count)")
        debugLog("   Buildings: \(hexMap.buildings.count)")
        debugLog("   Entities: \(hexMap.entities.count)")
        debugLog("   Resources: \(hexMap.resourcePoints.count)")
        debugLog("   Explored tiles: \(player.fogOfWar?.getExploredCount() ?? 0)")
    }

    func restoreReinforcements(_ reinforcements: [ReinforcementGroup.SaveData], hexMap: HexMap, allPlayers: [Player]) {
        guard !reinforcements.isEmpty else { return }

        debugLog("🚶 Restoring \(reinforcements.count) reinforcements...")

        for saveData in reinforcements {
            // Reconstruct reinforcement group
            guard let reinforcement = ReinforcementGroup.fromSaveData(saveData) else {
                debugLog("❌ Failed to restore reinforcement \(saveData.id)")
                continue
            }

            // Find and reconnect the owner
            if let ownerID = saveData.ownerID,
               let ownerUUID = UUID(uuidString: ownerID),
               let owner = allPlayers.first(where: { $0.id == ownerUUID }) {
                reinforcement.owner = owner
            }

            // Find and reconnect the target army
            for player in allPlayers {
                if let army = player.getArmies().first(where: { $0.id == reinforcement.targetArmyID }) {
                    reinforcement.targetArmy = army
                    break
                }
            }

            // Find and reconnect the source building
            if let building = hexMap.buildings.first(where: { $0.data.id == reinforcement.sourceBuildingID }) {
                reinforcement.sourceBuilding = building
            }

            // Calculate remaining path from current position to target
            guard let targetArmy = reinforcement.targetArmy,
                  let remainingPath = hexMap.findPath(from: reinforcement.coordinate, to: targetArmy.coordinate) else {
                debugLog("⚠️ No path for reinforcement \(saveData.id) - units will be lost")
                continue
            }

            // Spawn the reinforcement node and continue movement
            gameScene.spawnReinforcementNode(reinforcement: reinforcement, path: remainingPath) { success in
                debugLog("✅ Restored reinforcement arrived: \(success)")
            }

            debugLog("   ✅ Restored reinforcement to \(reinforcement.targetArmy?.name ?? "unknown army")")
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Stop auto-save timer
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil

        // Stop starvation countdown timer
        starvationCountdownTimer?.invalidate()
        starvationCountdownTimer = nil

        // Final save before leaving
        autoSaveGame()

        // Save background time
        BackgroundTimeManager.shared.saveExitTime()
        NotificationCenter.default.removeObserver(self, name: .appWillSaveGame, object: nil)

        // Stop online session heartbeat
        GameSessionService.shared.stopHeartbeat()
        GameSessionService.shared.stopCommandListener()
    }
    
    func processBackgroundTime() {
        guard let player = player,
              let hexMap = gameScene.hexMap,
              !gameScene.allGamePlayers.isEmpty else {
            debugLog("⚠️ Cannot process background time - game not ready")
            return
        }
        
        // Get elapsed time
        guard let elapsedSeconds = BackgroundTimeManager.shared.getElapsedTime() else {
            debugLog("⏰ No background time to process")
            return
        }
        
        // Cap offline time (e.g., max 8 hours)
        let maxOfflineSeconds: TimeInterval = 8 * 60 * 60
        let cappedElapsed = min(elapsedSeconds, maxOfflineSeconds)
        
        guard cappedElapsed > 1 else {
            debugLog("⏰ Less than 1 second elapsed, skipping")
            return
        }
        
        debugLog("⏰ Processing background time: \(Int(cappedElapsed)) seconds...")
        
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
                
                debugLog("   ⛏️ \(villagerGroup.name): depleted \(actualGathered) from \(resourcePoint.resourceType.displayName)")
                debugLog("      \(resourcePoint.remainingAmount) → \(newRemaining)")
                
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
                    
                    debugLog("   ⚠️ Resource depleted! \(villagerGroup.name) is now idle")
                }
            }
        }
        
        // Step 2: Apply resource accumulation from collection rates
        debugLog("   💰 Resource accumulation:")
        for type in ResourceType.allCases {
            let rate = player.getCollectionRate(type)
            let accumulated = Int(rate * cappedElapsed)
            
            if accumulated > 0 {
                player.addResource(type, amount: accumulated)
                debugLog("      \(type.displayName): +\(accumulated)")
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
        
        debugLog("✅ Background time processed")
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
        
        debugLog("✅ Split villager group: \(splitCount) → new group, \(villagerGroup.villagerCount) → original")
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
        
        debugLog("✅ Deployed \(removed) villagers from \(building.buildingType.displayName) at (\(coordinate.q), \(coordinate.r))")
        
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

    // MARK: - Rotation Preview UI

    func showRotationPreviewUI(buildingType: BuildingType, at anchor: HexCoordinate) {
        // Remove any existing overlay
        hideRotationPreviewUI()

        // Create overlay container
        let overlay = UIView()
        overlay.backgroundColor = UIColor(white: 0.1, alpha: 0.95)
        overlay.layer.cornerRadius = 16
        overlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlay)

        // Position at bottom of screen
        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            overlay.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            overlay.heightAnchor.constraint(equalToConstant: 140)
        ])

        // Building name label
        let buildingLabel = UILabel()
        buildingLabel.text = "\(buildingType.icon) Place \(buildingType.displayName)"
        buildingLabel.font = UIFont.boldSystemFont(ofSize: 18)
        buildingLabel.textColor = .white
        buildingLabel.textAlignment = .center
        buildingLabel.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(buildingLabel)

        NSLayoutConstraint.activate([
            buildingLabel.topAnchor.constraint(equalTo: overlay.topAnchor, constant: 12),
            buildingLabel.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 16),
            buildingLabel.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -16)
        ])
        rotationBuildingLabel = buildingLabel

        // Direction label
        let directionLabel = UILabel()
        directionLabel.text = "Facing: East ➡️"
        directionLabel.font = UIFont.systemFont(ofSize: 14)
        directionLabel.textColor = .lightGray
        directionLabel.textAlignment = .center
        directionLabel.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(directionLabel)

        NSLayoutConstraint.activate([
            directionLabel.topAnchor.constraint(equalTo: buildingLabel.bottomAnchor, constant: 4),
            directionLabel.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 16),
            directionLabel.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -16)
        ])
        rotationDirectionLabel = directionLabel

        // Button stack
        let buttonStack = UIStackView()
        buttonStack.axis = .horizontal
        buttonStack.distribution = .fillEqually
        buttonStack.spacing = 12
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            buttonStack.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 16),
            buttonStack.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -16),
            buttonStack.bottomAnchor.constraint(equalTo: overlay.bottomAnchor, constant: -16),
            buttonStack.heightAnchor.constraint(equalToConstant: 50)
        ])

        // Cancel button
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        cancelButton.backgroundColor = UIColor(red: 0.6, green: 0.3, blue: 0.3, alpha: 1.0)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.layer.cornerRadius = 10
        cancelButton.addTarget(self, action: #selector(rotationCancelTapped), for: .touchUpInside)
        buttonStack.addArrangedSubview(cancelButton)

        // Rotate button
        let rotateButton = UIButton(type: .system)
        rotateButton.setTitle("🔄 Rotate", for: .normal)
        rotateButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        rotateButton.backgroundColor = UIColor(red: 0.3, green: 0.5, blue: 0.7, alpha: 1.0)
        rotateButton.setTitleColor(.white, for: .normal)
        rotateButton.layer.cornerRadius = 10
        rotateButton.addTarget(self, action: #selector(rotationRotateTapped), for: .touchUpInside)
        buttonStack.addArrangedSubview(rotateButton)

        // Build button
        let buildButton = UIButton(type: .system)
        buildButton.setTitle("✅ Build", for: .normal)
        buildButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        buildButton.backgroundColor = UIColor(red: 0.3, green: 0.7, blue: 0.3, alpha: 1.0)
        buildButton.setTitleColor(.white, for: .normal)
        buildButton.layer.cornerRadius = 10
        buildButton.addTarget(self, action: #selector(rotationBuildTapped), for: .touchUpInside)
        buttonStack.addArrangedSubview(buildButton)

        rotationPreviewOverlay = overlay

        // Animate in
        overlay.alpha = 0
        overlay.transform = CGAffineTransform(translationX: 0, y: 50)
        UIView.animate(withDuration: 0.3) {
            overlay.alpha = 1
            overlay.transform = .identity
        }

        debugLog("🔄 Rotation preview UI shown for \(buildingType.displayName)")
    }

    func hideRotationPreviewUI() {
        guard let overlay = rotationPreviewOverlay else { return }

        UIView.animate(withDuration: 0.2, animations: {
            overlay.alpha = 0
            overlay.transform = CGAffineTransform(translationX: 0, y: 50)
        }) { _ in
            overlay.removeFromSuperview()
        }

        rotationPreviewOverlay = nil
        rotationBuildingLabel = nil
        rotationDirectionLabel = nil

        debugLog("🔄 Rotation preview UI hidden")
    }

    func updateRotationDirectionLabel() {
        let directions = ["East ➡️", "Northeast ↗️", "Northwest ↖️", "West ⬅️", "Southwest ↙️", "Southeast ↘️"]
        let rotation = gameScene.rotationPreviewRotation
        let isValid = gameScene.isCurrentRotationValid()

        rotationDirectionLabel?.text = "Facing: \(directions[rotation])" + (isValid ? "" : " ⚠️ Blocked")
        rotationDirectionLabel?.textColor = isValid ? .lightGray : .systemRed
    }

    @objc func rotationCancelTapped() {
        gameScene.exitRotationPreviewMode()
    }

    @objc func rotationRotateTapped() {
        gameScene.cycleRotationPreview()
        updateRotationDirectionLabel()
    }

    @objc func rotationBuildTapped() {
        _ = gameScene.confirmRotationPreview()
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

// MARK: - Notification Banner Delegate

extension GameViewController: NotificationBannerDelegate {
    func notificationBannerTapped(notification: GameNotification) {
        // Jump to the notification's coordinate if available
        if let coordinate = notification.coordinate {
            gameScene.focusCamera(on: coordinate, zoom: 0.7, animated: true)
            debugLog("📍 Jumped to coordinate: \(coordinate)")
        }
    }
}

extension GameViewController: GameSceneDelegate {
    
    func gameScene(_ scene: GameScene, villagerArrivedForHunt villagerGroup: VillagerGroup, target: ResourcePointNode, entityNode: EntityNode) {
        // Execute the hunt through the menu coordinator
        menuCoordinator?.executeHunt(villagerGroup: villagerGroup, target: target, entityNode: entityNode)
    }
    
    func gameScene(_ scene: GameScene, didRequestMenuForTile coordinate: HexCoordinate) {
        menuCoordinator.showTileActionMenu(for: coordinate)
    }

    func gameScene(_ scene: GameScene, didRequestEntityPicker entities: [EntityNode], at coordinate: HexCoordinate) {
        menuCoordinator.showEntityPickerMenu(entities: entities, at: coordinate)
    }

    func gameScene(_ scene: GameScene, didRequestUnexploredTileMenu coordinate: HexCoordinate) {
        menuCoordinator.showUnexploredTileMenu(for: coordinate)
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

    func gameScene(_ scene: GameScene, didSelectArmy entity: EntityNode, at coordinate: HexCoordinate) {
        showArmyDetailScreen(for: entity)
    }

    func showArmyDetailScreen(for entityNode: EntityNode) {
        guard let army = entityNode.armyReference else {
            debugLog("❌ No army reference found in entity node")
            return
        }

        let armyDetailVC = ArmyDetailViewController()
        armyDetailVC.army = army
        armyDetailVC.player = player
        armyDetailVC.hexMap = gameScene?.hexMap
        armyDetailVC.gameScene = gameScene
        armyDetailVC.modalPresentationStyle = .pageSheet

        if let sheet = armyDetailVC.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }

        present(armyDetailVC, animated: true)
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

    func gameScene(_ scene: GameScene, showConfirmation title: String, message: String,
                   confirmTitle: String, onConfirm: @escaping () -> Void) {
        showConfirmation(
            title: title,
            message: message,
            confirmTitle: confirmTitle,
            onConfirm: onConfirm
        )
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

    func gameScene(_ scene: GameScene, didEnterRotationPreviewForBuilding buildingType: BuildingType, at anchor: HexCoordinate) {
        showRotationPreviewUI(buildingType: buildingType, at: anchor)
    }

    func gameSceneDidExitRotationPreview(_ scene: GameScene) {
        hideRotationPreviewUI()
    }

    func showBattleEndNotification(title: String, message: String, isVictory: Bool, buildingDamage: BuildingDamageRecord?) {
        let icon = isVictory ? "🏆" : "💀"

        // Build the full message, including building damage if present
        var fullMessage = message
        if let damage = buildingDamage {
            fullMessage += "\n\n🏰 Building Damage:"
            fullMessage += "\n\(damage.buildingType): \(Int(damage.damageDealt)) damage dealt"
            if damage.wasDestroyed {
                fullMessage += "\n💥 Building Destroyed!"
            } else {
                let healthPercent = Int((damage.healthAfter / damage.healthBefore) * 100)
                fullMessage += "\nRemaining HP: \(healthPercent)%"
            }
        }

        let alert = UIAlertController(
            title: "\(icon) \(title)",
            message: fullMessage,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "View Battle Report", style: .default) { [weak self] _ in
            self?.showCombatHistoryScreen()
        })

        alert.addAction(UIAlertAction(title: "OK", style: .cancel))

        present(alert, animated: true)
    }
}
