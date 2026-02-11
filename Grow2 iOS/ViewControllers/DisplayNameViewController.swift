// ============================================================================
// FILE: DisplayNameViewController.swift
// LOCATION: Grow2 iOS/ViewControllers/DisplayNameViewController.swift
// PURPOSE: Full-screen VC for choosing or changing a unique display name
// ============================================================================

import UIKit

class DisplayNameViewController: UIViewController {

    /// If true, shows back button and pre-fills current name (change mode).
    var isChangingName: Bool = false

    /// Callback for first-time flow — called with the chosen username.
    var onUsernameChosen: ((String) -> Void)?

    private var nameField: UITextField!
    private var validationLabel: UILabel!
    private var charCountLabel: UILabel!
    private var confirmButton: UIButton!
    private var activityIndicator: UIActivityIndicatorView!

    private var debounceTimer: Timer?
    private var lastCheckedName: String = ""
    private var isNameAvailable: Bool = false
    private var isChecking: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()

        if isChangingName, let currentName = AuthService.shared.cachedUsername {
            nameField.text = currentName
        }
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.1, green: 0.12, blue: 0.1, alpha: 1.0)

        // Header
        let headerView = UIView()
        headerView.backgroundColor = UIColor(red: 0.15, green: 0.18, blue: 0.15, alpha: 1.0)
        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)

        let titleLabel = UILabel()
        titleLabel.text = isChangingName ? "Change Display Name" : "Choose Display Name"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 20)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 100),
            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -12)
        ])

        if isChangingName {
            let backButton = UIButton(type: .system)
            backButton.setTitle("Back", for: .normal)
            backButton.setTitleColor(.white, for: .normal)
            backButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .medium)
            backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
            backButton.translatesAutoresizingMaskIntoConstraints = false
            headerView.addSubview(backButton)

            NSLayoutConstraint.activate([
                backButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
                backButton.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -12)
            ])
        }

        // Content container
        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentView)

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 40),
            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])

        // Instructions
        let instructionLabel = UILabel()
        instructionLabel.text = isChangingName
            ? "Enter a new display name. It must be unique."
            : "Choose a unique display name to get started."
        instructionLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        instructionLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        instructionLabel.textAlignment = .center
        instructionLabel.numberOfLines = 0
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(instructionLabel)

        // Name text field
        nameField = UITextField()
        nameField.placeholder = "Display Name"
        nameField.autocapitalizationType = .none
        nameField.autocorrectionType = .no
        nameField.spellCheckingType = .no
        nameField.textColor = .white
        nameField.font = UIFont.systemFont(ofSize: 18)
        nameField.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        nameField.layer.cornerRadius = 10
        nameField.attributedPlaceholder = NSAttributedString(
            string: "Display Name",
            attributes: [.foregroundColor: UIColor(white: 0.45, alpha: 1.0)]
        )
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 48))
        nameField.leftView = paddingView
        nameField.leftViewMode = .always
        nameField.addTarget(self, action: #selector(nameFieldChanged), for: .editingChanged)
        nameField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameField)

        // Char count label
        charCountLabel = UILabel()
        charCountLabel.text = "0/20"
        charCountLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        charCountLabel.textColor = UIColor(white: 0.5, alpha: 1.0)
        charCountLabel.textAlignment = .right
        charCountLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(charCountLabel)

        // Validation label
        validationLabel = UILabel()
        validationLabel.text = "3-20 characters, letters, numbers, underscores"
        validationLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        validationLabel.textColor = UIColor(white: 0.5, alpha: 1.0)
        validationLabel.textAlignment = .center
        validationLabel.numberOfLines = 0
        validationLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(validationLabel)

        // Activity indicator
        activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.color = .white
        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(activityIndicator)

        // Confirm button
        confirmButton = UIButton(type: .system)
        confirmButton.setTitle(isChangingName ? "Change Name" : "Continue", for: .normal)
        confirmButton.setTitleColor(.white, for: .normal)
        confirmButton.setTitleColor(UIColor(white: 0.5, alpha: 1.0), for: .disabled)
        confirmButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        confirmButton.backgroundColor = UIColor(red: 0.2, green: 0.5, blue: 0.2, alpha: 1.0)
        confirmButton.layer.cornerRadius = 12
        confirmButton.isEnabled = false
        confirmButton.alpha = 0.5
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(confirmButton)

        NSLayoutConstraint.activate([
            instructionLabel.topAnchor.constraint(equalTo: contentView.topAnchor),
            instructionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            instructionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            nameField.topAnchor.constraint(equalTo: instructionLabel.bottomAnchor, constant: 24),
            nameField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            nameField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            nameField.heightAnchor.constraint(equalToConstant: 48),

            charCountLabel.topAnchor.constraint(equalTo: nameField.bottomAnchor, constant: 4),
            charCountLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            validationLabel.topAnchor.constraint(equalTo: nameField.bottomAnchor, constant: 4),
            validationLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            validationLabel.trailingAnchor.constraint(equalTo: charCountLabel.leadingAnchor, constant: -8),

            activityIndicator.centerYAnchor.constraint(equalTo: validationLabel.centerYAnchor),
            activityIndicator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            confirmButton.topAnchor.constraint(equalTo: validationLabel.bottomAnchor, constant: 30),
            confirmButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            confirmButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            confirmButton.heightAnchor.constraint(equalToConstant: 50)
        ])

        // Tap to dismiss keyboard
        let tapGesture = UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing))
        view.addGestureRecognizer(tapGesture)
    }

    // MARK: - Validation

    @objc private func nameFieldChanged() {
        let text = nameField.text ?? ""
        charCountLabel.text = "\(text.count)/20"

        // Reset state
        isNameAvailable = false
        updateConfirmButton()

        // Client-side validation
        if text.isEmpty {
            validationLabel.text = "3-20 characters, letters, numbers, underscores"
            validationLabel.textColor = UIColor(white: 0.5, alpha: 1.0)
            debounceTimer?.invalidate()
            return
        }

        if text.count < 3 {
            validationLabel.text = "Too short — minimum 3 characters"
            validationLabel.textColor = UIColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1.0)
            debounceTimer?.invalidate()
            return
        }

        if text.count > 20 {
            validationLabel.text = "Too long — maximum 20 characters"
            validationLabel.textColor = UIColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1.0)
            debounceTimer?.invalidate()
            return
        }

        if !AuthService.isValidUsername(text) {
            validationLabel.text = "Only letters, numbers, and underscores"
            validationLabel.textColor = UIColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1.0)
            debounceTimer?.invalidate()
            return
        }

        // If same as current name in change mode, skip availability check
        if isChangingName, text.lowercased() == AuthService.shared.cachedUsername?.lowercased() {
            validationLabel.text = "This is your current name"
            validationLabel.textColor = UIColor(white: 0.5, alpha: 1.0)
            debounceTimer?.invalidate()
            return
        }

        // Debounced server-side check
        validationLabel.text = "Checking availability..."
        validationLabel.textColor = UIColor(white: 0.5, alpha: 1.0)
        isChecking = true
        activityIndicator.startAnimating()

        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.checkAvailability(text)
        }
    }

    private func checkAvailability(_ username: String) {
        lastCheckedName = username

        AuthService.shared.checkUsernameAvailability(username) { [weak self] available in
            DispatchQueue.main.async {
                guard let self = self else { return }
                // Ensure field hasn't changed since we started checking
                guard self.nameField.text == self.lastCheckedName else { return }

                self.isChecking = false
                self.activityIndicator.stopAnimating()

                if available {
                    self.validationLabel.text = "Available!"
                    self.validationLabel.textColor = UIColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1.0)
                    self.isNameAvailable = true
                } else {
                    self.validationLabel.text = "Already taken"
                    self.validationLabel.textColor = UIColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1.0)
                    self.isNameAvailable = false
                }
                self.updateConfirmButton()
            }
        }
    }

    private func updateConfirmButton() {
        let enabled = isNameAvailable && !isChecking
        confirmButton.isEnabled = enabled
        confirmButton.alpha = enabled ? 1.0 : 0.5
    }

    // MARK: - Actions

    @objc private func confirmTapped() {
        guard let username = nameField.text, AuthService.isValidUsername(username), isNameAvailable else { return }

        confirmButton.isEnabled = false
        confirmButton.alpha = 0.5
        activityIndicator.startAnimating()

        if isChangingName {
            AuthService.shared.changeUsername(to: username) { [weak self] result in
                DispatchQueue.main.async {
                    self?.activityIndicator.stopAnimating()
                    switch result {
                    case .success:
                        self?.dismiss(animated: true)
                    case .failure(let error):
                        self?.validationLabel.text = error.localizedDescription
                        self?.validationLabel.textColor = UIColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1.0)
                        self?.isNameAvailable = false
                        self?.updateConfirmButton()
                    }
                }
            }
        } else {
            AuthService.shared.claimUsername(username) { [weak self] result in
                DispatchQueue.main.async {
                    self?.activityIndicator.stopAnimating()
                    switch result {
                    case .success:
                        self?.onUsernameChosen?(username)
                    case .failure(let error):
                        self?.validationLabel.text = error.localizedDescription
                        self?.validationLabel.textColor = UIColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1.0)
                        self?.isNameAvailable = false
                        self?.updateConfirmButton()
                    }
                }
            }
        }
    }

    @objc private func backTapped() {
        dismiss(animated: true)
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
