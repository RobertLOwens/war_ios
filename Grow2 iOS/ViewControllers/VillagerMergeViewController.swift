import UIKit

class VillagerMergeViewController: UIViewController {
    
    var villagerGroup1: VillagerGroup!
    var villagerGroup2: VillagerGroup!
    var onMergeComplete: ((Int, Int) -> Void)?
    
    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let villager1Label = UILabel()
    private let villager2Label = UILabel()
    private let countSlider = UISlider()
    private let count1Label = UILabel()
    private let count2Label = UILabel()
    private let quickMergeButton = UIButton(type: .system)
    private let confirmButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    
    private var totalVillagers: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateCounts()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
        // Container
        containerView.backgroundColor = UIColor(red: 0.95, green: 0.95, blue: 0.9, alpha: 1.0)
        containerView.layer.cornerRadius = 12
        containerView.layer.borderWidth = 2
        containerView.layer.borderColor = UIColor(red: 0.4, green: 0.3, blue: 0.2, alpha: 1.0).cgColor
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        // Title
        titleLabel.text = "Merge Villagers"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 20)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
        
        totalVillagers = villagerGroup1.villagerCount + villagerGroup2.villagerCount
        
        // Group 1 Label
        villager1Label.text = "Group 1"
        villager1Label.font = UIFont.systemFont(ofSize: 16)
        villager1Label.textAlignment = .center
        villager1Label.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(villager1Label)
        
        // Group 2 Label
        villager2Label.text = "Group 2"
        villager2Label.font = UIFont.systemFont(ofSize: 16)
        villager2Label.textAlignment = .center
        villager2Label.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(villager2Label)
        
        // Count Labels
        count1Label.font = UIFont.boldSystemFont(ofSize: 24)
        count1Label.textAlignment = .center
        count1Label.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(count1Label)
        
        count2Label.font = UIFont.boldSystemFont(ofSize: 24)
        count2Label.textAlignment = .center
        count2Label.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(count2Label)
        
        // Slider
        countSlider.minimumValue = 0
        countSlider.maximumValue = Float(totalVillagers)
        countSlider.value = Float(totalVillagers) / 2.0
        countSlider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        countSlider.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(countSlider)
        
        // Quick Merge Button
        quickMergeButton.setTitle("Quick Merge All", for: .normal)
        quickMergeButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        quickMergeButton.backgroundColor = UIColor.systemGreen
        quickMergeButton.setTitleColor(.white, for: .normal)
        quickMergeButton.layer.cornerRadius = 8
        quickMergeButton.addTarget(self, action: #selector(quickMergeTapped), for: .touchUpInside)
        quickMergeButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(quickMergeButton)
        
        // Confirm Button
        confirmButton.setTitle("Split & Confirm", for: .normal)
        confirmButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        confirmButton.backgroundColor = UIColor.systemBlue
        confirmButton.setTitleColor(.white, for: .normal)
        confirmButton.layer.cornerRadius = 8
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(confirmButton)
        
        // Cancel Button
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        cancelButton.backgroundColor = UIColor.systemGray
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.layer.cornerRadius = 8
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(cancelButton)
        
        // Constraints
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 340),
            containerView.heightAnchor.constraint(equalToConstant: 340),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            villager1Label.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 30),
            villager1Label.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 30),
            villager1Label.widthAnchor.constraint(equalToConstant: 100),
            
            villager2Label.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 30),
            villager2Label.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -30),
            villager2Label.widthAnchor.constraint(equalToConstant: 100),
            
            count1Label.topAnchor.constraint(equalTo: villager1Label.bottomAnchor, constant: 10),
            count1Label.centerXAnchor.constraint(equalTo: villager1Label.centerXAnchor),
            
            count2Label.topAnchor.constraint(equalTo: villager2Label.bottomAnchor, constant: 10),
            count2Label.centerXAnchor.constraint(equalTo: villager2Label.centerXAnchor),
            
            countSlider.topAnchor.constraint(equalTo: count1Label.bottomAnchor, constant: 30),
            countSlider.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 30),
            countSlider.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -30),
            
            quickMergeButton.topAnchor.constraint(equalTo: countSlider.bottomAnchor, constant: 30),
            quickMergeButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 30),
            quickMergeButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -30),
            quickMergeButton.heightAnchor.constraint(equalToConstant: 44),
            
            confirmButton.topAnchor.constraint(equalTo: quickMergeButton.bottomAnchor, constant: 15),
            confirmButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 30),
            confirmButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -30),
            confirmButton.heightAnchor.constraint(equalToConstant: 44),
            
            cancelButton.topAnchor.constraint(equalTo: confirmButton.bottomAnchor, constant: 10),
            cancelButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 30),
            cancelButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -30),
            cancelButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    @objc private func sliderValueChanged() {
        updateCounts()
    }
    
    private func updateCounts() {
        let group1Count = Int(countSlider.value)
        let group2Count = totalVillagers - group1Count
        
        count1Label.text = "\(group1Count)"
        count2Label.text = "\(group2Count)"
    }
    
    @objc private func quickMergeTapped() {
        onMergeComplete?(totalVillagers, 0)
        dismiss(animated: true)
    }
    
    @objc private func confirmTapped() {
        let group1Count = Int(countSlider.value)
        let group2Count = totalVillagers - group1Count
        
        onMergeComplete?(group1Count, group2Count)
        dismiss(animated: true)
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
}
