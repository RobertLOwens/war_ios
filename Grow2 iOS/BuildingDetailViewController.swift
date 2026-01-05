import UIKit

class BuildingDetailViewController: UIViewController {
    
    var building: BuildingNode!
    var player: Player!
    weak var gameViewController: GameViewController?
    
    var scrollView: UIScrollView!
    var contentView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    func setupUI() {
        view.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        
        // Scroll view for content
        scrollView = UIScrollView(frame: view.bounds)
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(scrollView)
        
        contentView = UIView()
        scrollView.addSubview(contentView)
        
        var yOffset: CGFloat = 20
        
        // Title
        let titleLabel = UILabel(frame: CGRect(x: 20, y: yOffset, width: view.bounds.width - 40, height: 40))
        titleLabel.text = "\(building.buildingType.icon) \(building.buildingType.displayName)"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 28)
        titleLabel.textColor = .white
        contentView.addSubview(titleLabel)
        yOffset += 50
        
        // Close button
        let closeButton = UIButton(frame: CGRect(x: view.bounds.width - 70, y: 20, width: 50, height: 40))
        closeButton.setTitle("✕", for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 24)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        contentView.addSubview(closeButton)
        
        // Status
        let statusLabel = UILabel(frame: CGRect(x: 20, y: yOffset, width: view.bounds.width - 40, height: 25))
        statusLabel.text = "Status: Completed ✅"
        statusLabel.font = UIFont.systemFont(ofSize: 16)
        statusLabel.textColor = UIColor(white: 0.9, alpha: 1.0)
        contentView.addSubview(statusLabel)
        yOffset += 30
        
        // Health
        let healthLabel = UILabel(frame: CGRect(x: 20, y: yOffset, width: view.bounds.width - 40, height: 25))
        healthLabel.text = "Health: \(Int(building.health))/\(Int(building.maxHealth))"
        healthLabel.font = UIFont.systemFont(ofSize: 16)
        healthLabel.textColor = UIColor(white: 0.9, alpha: 1.0)
        contentView.addSubview(healthLabel)
        yOffset += 30
        
        // Location
        let locationLabel = UILabel(frame: CGRect(x: 20, y: yOffset, width: view.bounds.width - 40, height: 25))
        locationLabel.text = "📍 Location: (\(building.coordinate.q), \(building.coordinate.r))"
        locationLabel.font = UIFont.systemFont(ofSize: 14)
        locationLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        contentView.addSubview(locationLabel)
        yOffset += 40
        
        // Garrison info
        if building.getTotalGarrisonCount() > 0 {
            let garrisonLabel = UILabel(frame: CGRect(x: 20, y: yOffset, width: view.bounds.width - 40, height: 25))
            garrisonLabel.text = "🏰 Garrison: \(building.getTotalGarrisonCount())/\(building.getGarrisonCapacity()) units"
            garrisonLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
            garrisonLabel.textColor = .white
            contentView.addSubview(garrisonLabel)
            yOffset += 35
            
            // Show garrison composition
            let garrisonDesc = building.getGarrisonDescription()
            let garrisonDetailLabel = UILabel(frame: CGRect(x: 20, y: yOffset, width: view.bounds.width - 40, height: 0))
            garrisonDetailLabel.text = garrisonDesc
            garrisonDetailLabel.font = UIFont.systemFont(ofSize: 14)
            garrisonDetailLabel.textColor = UIColor(white: 0.8, alpha: 1.0)
            garrisonDetailLabel.numberOfLines = 0
            garrisonDetailLabel.sizeToFit()
            contentView.addSubview(garrisonDetailLabel)
            yOffset += garrisonDetailLabel.frame.height + 20
        }
        
        // Divider
        let divider = UIView(frame: CGRect(x: 20, y: yOffset, width: view.bounds.width - 40, height: 1))
        divider.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
        contentView.addSubview(divider)
        yOffset += 20
        
        // Action buttons
        if building.buildingType.category == .military {
            let trainButton = createActionButton(
                title: "🎖️ Train Units",
                y: yOffset,
                color: UIColor(red: 0.3, green: 0.5, blue: 0.8, alpha: 1.0),
                action: #selector(trainUnitsTapped)
            )
            contentView.addSubview(trainButton)
            yOffset += 70
        }
        
        if building.getTotalGarrisonCount() > 0 {
            let reinforceButton = createActionButton(
                title: "⚔️ Reinforce Army",
                y: yOffset,
                color: UIColor(red: 0.8, green: 0.4, blue: 0.2, alpha: 1.0),
                action: #selector(reinforceArmyTapped)
            )
            contentView.addSubview(reinforceButton)
            yOffset += 70
        }
        
        // Set content size
        contentView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: yOffset + 20)
        scrollView.contentSize = CGSize(width: view.bounds.width, height: yOffset + 20)
    }
    
    func createActionButton(title: String, y: CGFloat, color: UIColor, action: Selector) -> UIButton {
        let button = UIButton(frame: CGRect(x: 20, y: y, width: view.bounds.width - 40, height: 55))
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.backgroundColor = color
        button.layer.cornerRadius = 12
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowOpacity = 0.3
        button.layer.shadowRadius = 4
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }
    
    @objc func trainUnitsTapped() {
        dismiss(animated: true) { [weak self] in
            guard let self = self, let gameVC = self.gameViewController else { return }
            gameVC.showTrainingMenu(for: self.building)
        }
    }
    
    @objc func reinforceArmyTapped() {
        dismiss(animated: true) { [weak self] in
            guard let self = self, let gameVC = self.gameViewController else { return }
            gameVC.showReinforcementTargetSelection(from: self.building)
        }
    }
    
    @objc func closeTapped() {
        dismiss(animated: true)
    }
}
