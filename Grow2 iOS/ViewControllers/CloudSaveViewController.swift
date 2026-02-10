// ============================================================================
// FILE: CloudSaveViewController.swift
// LOCATION: Grow2 iOS/ViewControllers/CloudSaveViewController.swift
// PURPOSE: Modal screen to browse, upload, download, and delete cloud saves
// ============================================================================

import UIKit

class CloudSaveViewController: UIViewController {

    // MARK: - UI Elements

    private var tableView: UITableView!
    private var activityIndicator: UIActivityIndicatorView!
    private var emptyLabel: UILabel!

    // MARK: - Data

    private var cloudSaves: [CloudSaveMetadata] = []
    private var hasLocalSave: Bool {
        return GameSaveManager.shared.saveExists()
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadCloudSaves()
    }

    // MARK: - Setup UI

    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.1, green: 0.12, blue: 0.1, alpha: 1.0)

        // Header
        let headerView = UIView()
        headerView.backgroundColor = UIColor(red: 0.15, green: 0.18, blue: 0.15, alpha: 1.0)
        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)

        let backButton = UIButton(type: .system)
        backButton.setTitle("Back", for: .normal)
        backButton.setTitleColor(.white, for: .normal)
        backButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(backButton)

        let titleLabel = UILabel()
        titleLabel.text = "Cloud Saves"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 20)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(titleLabel)

        let refreshButton = UIButton(type: .system)
        refreshButton.setTitle("Refresh", for: .normal)
        refreshButton.setTitleColor(.white, for: .normal)
        refreshButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        refreshButton.addTarget(self, action: #selector(refreshTapped), for: .touchUpInside)
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(refreshButton)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 100),

            backButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            backButton.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -12),

            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -12),

            refreshButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            refreshButton.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -12)
        ])

        // Table View
        tableView = UITableView(frame: .zero, style: .grouped)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])

        // Activity Indicator
        activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.color = .white
        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        // Empty Label
        emptyLabel = UILabel()
        emptyLabel.text = "No cloud saves yet.\nUpload your local save to get started."
        emptyLabel.numberOfLines = 0
        emptyLabel.textAlignment = .center
        emptyLabel.textColor = UIColor(white: 0.5, alpha: 1.0)
        emptyLabel.font = UIFont.systemFont(ofSize: 16)
        emptyLabel.isHidden = true
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 60),
            emptyLabel.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.8)
        ])
    }

    // MARK: - Data Loading

    private func loadCloudSaves() {
        activityIndicator.startAnimating()
        emptyLabel.isHidden = true

        CloudSaveService.shared.listSaves { [weak self] result in
            DispatchQueue.main.async {
                self?.activityIndicator.stopAnimating()
                switch result {
                case .success(let saves):
                    self?.cloudSaves = saves
                    self?.emptyLabel.isHidden = !saves.isEmpty || (self?.hasLocalSave == true)
                    self?.tableView.reloadData()
                case .failure(let error):
                    self?.showError(message: error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Actions

    @objc private func backTapped() {
        dismiss(animated: true)
    }

    @objc private func refreshTapped() {
        loadCloudSaves()
    }

    private func uploadLocalSave() {
        guard hasLocalSave else {
            showError(message: "No local save to upload.")
            return
        }

        guard let saveData = GameSaveManager.shared.createSaveData() else {
            showError(message: "Failed to read local save data.")
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        let saveName = "Save - \(dateFormatter.string(from: Date()))"

        activityIndicator.startAnimating()
        CloudSaveService.shared.uploadSave(saveData: saveData, saveName: saveName) { [weak self] result in
            DispatchQueue.main.async {
                self?.activityIndicator.stopAnimating()
                switch result {
                case .success:
                    self?.showTemporaryMessage("Save uploaded to cloud")
                    self?.loadCloudSaves()
                case .failure(let error):
                    self?.showError(message: error.localizedDescription)
                }
            }
        }
    }

    private func downloadSave(at index: Int) {
        let save = cloudSaves[index]

        showDestructiveConfirmation(
            title: "Download Save?",
            message: "This will overwrite your current local save with \"\(save.saveName)\".",
            confirmTitle: "Download"
        ) { [weak self] in
            self?.performDownload(saveID: save.saveID)
        }
    }

    private func performDownload(saveID: String) {
        activityIndicator.startAnimating()
        CloudSaveService.shared.downloadSave(saveID: saveID) { [weak self] result in
            DispatchQueue.main.async {
                self?.activityIndicator.stopAnimating()
                switch result {
                case .success(let saveData):
                    if GameSaveManager.shared.writeFromSaveData(saveData) {
                        self?.showTemporaryMessage("Cloud save downloaded")
                        self?.tableView.reloadData()
                    } else {
                        self?.showError(message: "Failed to write save to disk.")
                    }
                case .failure(let error):
                    self?.showError(message: error.localizedDescription)
                }
            }
        }
    }

    private func deleteCloudSave(at index: Int) {
        let save = cloudSaves[index]

        showDestructiveConfirmation(
            title: "Delete Cloud Save?",
            message: "This will permanently delete \"\(save.saveName)\" from the cloud.",
            confirmTitle: "Delete"
        ) { [weak self] in
            self?.performDelete(saveID: save.saveID, index: index)
        }
    }

    private func performDelete(saveID: String, index: Int) {
        activityIndicator.startAnimating()
        CloudSaveService.shared.deleteSave(saveID: saveID) { [weak self] result in
            DispatchQueue.main.async {
                self?.activityIndicator.stopAnimating()
                switch result {
                case .success:
                    self?.cloudSaves.remove(at: index)
                    self?.tableView.reloadData()
                    self?.showTemporaryMessage("Cloud save deleted")
                case .failure(let error):
                    self?.showError(message: error.localizedDescription)
                }
            }
        }
    }

    private func showError(message: String) {
        showAlert(title: "Error", message: message)
    }

    // MARK: - Helpers

    private func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else {
            return "\(bytes / 1024) KB"
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}

// MARK: - UITableViewDataSource

extension CloudSaveViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2  // Local Save, Cloud Saves
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return hasLocalSave ? 1 : 0
        } else {
            return cloudSaves.count
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return hasLocalSave ? "LOCAL SAVE" : nil
        } else {
            return "CLOUD SAVES (\(cloudSaves.count)/5)"
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        cell.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        cell.textLabel?.textColor = .white
        cell.detailTextLabel?.textColor = UIColor(white: 0.6, alpha: 1.0)
        cell.selectionStyle = .none

        if indexPath.section == 0 {
            // Local save
            let dateFormatter = RelativeDateTimeFormatter()
            dateFormatter.unitsStyle = .full
            let saveDate = GameSaveManager.shared.getSaveDate()
            let dateString = saveDate.map { dateFormatter.localizedString(for: $0, relativeTo: Date()) } ?? "Unknown"

            cell.textLabel?.text = "Current Game"
            cell.detailTextLabel?.text = "Last saved: \(dateString)"

            let uploadButton = UIButton(type: .system)
            uploadButton.setTitle("Upload", for: .normal)
            uploadButton.setTitleColor(UIColor(red: 0.3, green: 0.7, blue: 0.3, alpha: 1.0), for: .normal)
            uploadButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
            uploadButton.sizeToFit()
            uploadButton.addTarget(self, action: #selector(uploadButtonTapped), for: .touchUpInside)
            cell.accessoryView = uploadButton
        } else {
            // Cloud save
            let save = cloudSaves[indexPath.row]
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short

            cell.textLabel?.text = save.saveName
            cell.detailTextLabel?.text = "\(dateFormatter.string(from: save.saveDate)) - \(formatBytes(save.sizeBytes))"
            cell.accessoryType = .disclosureIndicator
            cell.accessoryView = nil
        }

        return cell
    }

    @objc private func uploadButtonTapped() {
        uploadLocalSave()
    }
}

// MARK: - UITableViewDelegate

extension CloudSaveViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section == 1 else { return }

        let save = cloudSaves[indexPath.row]
        let alert = UIAlertController(title: save.saveName, message: nil, preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "Download to Local", style: .default) { [weak self] _ in
            self?.downloadSave(at: indexPath.row)
        })

        alert.addAction(UIAlertAction(title: "Delete from Cloud", style: .destructive) { [weak self] _ in
            self?.deleteCloudSave(at: indexPath.row)
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = tableView
            popover.sourceRect = tableView.rectForRow(at: indexPath)
        }

        present(alert, animated: true)
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        header.textLabel?.textColor = UIColor(red: 0.5, green: 0.7, blue: 0.5, alpha: 1.0)
        header.textLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
    }
}
