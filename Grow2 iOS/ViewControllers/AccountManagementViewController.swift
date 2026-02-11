// ============================================================================
// FILE: AccountManagementViewController.swift
// LOCATION: Grow2 iOS/ViewControllers/AccountManagementViewController.swift
// PURPOSE: Dedicated account management screen - details, password change,
//          and account deletion
// ============================================================================

import UIKit
import FirebaseAuth

class AccountManagementViewController: UIViewController {

    private var scrollView: UIScrollView!
    private var contentView: UIView!

    // Change password fields (only for email/password users)
    private var currentPasswordField: UITextField?
    private var newPasswordField: UITextField?
    private var confirmPasswordField: UITextField?
    private var updatePasswordButton: UIButton?

    private var usernameObserver: NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()

        usernameObserver = NotificationCenter.default.addObserver(
            forName: AuthService.usernameDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.rebuildUI()
        }
    }

    deinit {
        if let observer = usernameObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func rebuildUI() {
        contentView.subviews.forEach { $0.removeFromSuperview() }
        // Remove all constraints from contentView
        contentView.constraints.forEach { contentView.removeConstraint($0) }
        buildContent()
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.1, green: 0.12, blue: 0.1, alpha: 1.0)

        let headerView = createHeader()

        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        scrollView.keyboardDismissMode = .onDrag
        view.addSubview(scrollView)

        contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

        buildContent()
    }

    private func buildContent() {
        var yOffset: CGFloat = 20

        // Account Details Section
        yOffset = addSectionHeader("Account Details", at: yOffset)
        yOffset = addAccountDetails(at: yOffset)

        // Change Display Name Button
        yOffset += 4
        yOffset = addButton(
            title: "Change Display Name",
            titleColor: .white,
            action: #selector(changeDisplayNameTapped),
            at: yOffset
        )

        // My Statistics Button
        yOffset += 4
        yOffset = addButton(
            title: "My Statistics",
            titleColor: .white,
            action: #selector(myStatisticsTapped),
            at: yOffset
        )

        // Change Password Section (email/password users only)
        if AuthService.shared.isEmailPasswordUser {
            yOffset += 12
            yOffset = addSectionHeader("Change Password", at: yOffset)
            yOffset = addChangePasswordSection(at: yOffset)
        }

        // Danger Zone Section
        yOffset += 12
        yOffset = addSectionHeader("Danger Zone", at: yOffset)
        yOffset = addButton(
            title: "Delete Account",
            titleColor: .red,
            action: #selector(deleteAccountTapped),
            at: yOffset
        )

        yOffset += 40
        contentView.heightAnchor.constraint(equalToConstant: yOffset).isActive = true
    }

    private func createHeader() -> UIView {
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
        titleLabel.text = "Account"
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

            backButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            backButton.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -12),

            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -12)
        ])

        return headerView
    }

    // MARK: - Account Details

    private func addAccountDetails(at yOffset: CGFloat) -> CGFloat {
        let firebaseUser = Auth.auth().currentUser
        let containerView = UIView()
        containerView.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        containerView.layer.cornerRadius = 10
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: yOffset),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])

        var rows: [(String, String)] = []

        // Display name — prefer cached username
        let displayName = AuthService.shared.cachedUsername ?? firebaseUser?.displayName ?? "No display name"
        rows.append(("Name", displayName))

        // Email
        let email = firebaseUser?.email ?? "No email"
        rows.append(("Email", email))

        // Sign-in method
        let signInMethod: String
        if let providerData = firebaseUser?.providerData {
            if providerData.contains(where: { $0.providerID == "apple.com" }) {
                signInMethod = "Apple"
            } else if providerData.contains(where: { $0.providerID == "google.com" }) {
                signInMethod = "Google"
            } else if providerData.contains(where: { $0.providerID == "password" }) {
                signInMethod = "Email / Password"
            } else {
                signInMethod = "Unknown"
            }
        } else {
            signInMethod = "Unknown"
        }
        rows.append(("Sign-in", signInMethod))

        // Account creation date
        if let creationDate = firebaseUser?.metadata.creationDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            rows.append(("Created", formatter.string(from: creationDate)))
        }

        var lastAnchor = containerView.topAnchor
        let rowHeight: CGFloat = 36

        for (index, row) in rows.enumerated() {
            let labelKey = UILabel()
            labelKey.text = row.0
            labelKey.font = UIFont.systemFont(ofSize: 14, weight: .regular)
            labelKey.textColor = UIColor(white: 0.55, alpha: 1.0)
            labelKey.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(labelKey)

            let labelValue = UILabel()
            labelValue.text = row.1
            labelValue.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            labelValue.textColor = .white
            labelValue.textAlignment = .right
            labelValue.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(labelValue)

            let topPadding: CGFloat = index == 0 ? 14 : 0

            NSLayoutConstraint.activate([
                labelKey.topAnchor.constraint(equalTo: lastAnchor, constant: topPadding),
                labelKey.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
                labelKey.heightAnchor.constraint(equalToConstant: rowHeight),

                labelValue.topAnchor.constraint(equalTo: labelKey.topAnchor),
                labelValue.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
                labelValue.leadingAnchor.constraint(equalTo: labelKey.trailingAnchor, constant: 8),
                labelValue.heightAnchor.constraint(equalToConstant: rowHeight)
            ])

            labelKey.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            labelValue.setContentHuggingPriority(.defaultLow, for: .horizontal)

            lastAnchor = labelKey.bottomAnchor
        }

        containerView.bottomAnchor.constraint(equalTo: lastAnchor, constant: 14).isActive = true

        let totalHeight = CGFloat(rows.count) * rowHeight + 28 + 14 // rows + top/bottom padding + first row extra
        return yOffset + totalHeight + 8
    }

    // MARK: - Change Password Section

    private func addChangePasswordSection(at yOffset: CGFloat) -> CGFloat {
        let containerView = UIView()
        containerView.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        containerView.layer.cornerRadius = 10
        containerView.frame = CGRect(x: 16, y: yOffset, width: view.bounds.width - 32, height: 220)
        contentView.addSubview(containerView)

        let currentPwd = createPasswordField(placeholder: "Current Password", yPosition: 14)
        containerView.addSubview(currentPwd)
        self.currentPasswordField = currentPwd

        let newPwd = createPasswordField(placeholder: "New Password", yPosition: 62)
        containerView.addSubview(newPwd)
        self.newPasswordField = newPwd

        let confirmPwd = createPasswordField(placeholder: "Confirm New Password", yPosition: 110)
        containerView.addSubview(confirmPwd)
        self.confirmPasswordField = confirmPwd

        let button = UIButton(type: .system)
        button.setTitle("Update Password", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 0.2, green: 0.5, blue: 0.2, alpha: 1.0)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        button.layer.cornerRadius = 8
        button.frame = CGRect(x: 16, y: 164, width: containerView.bounds.width - 32, height: 42)
        button.addTarget(self, action: #selector(updatePasswordTapped), for: .touchUpInside)
        containerView.addSubview(button)
        self.updatePasswordButton = button

        return yOffset + 220 + 8
    }

    private func createPasswordField(placeholder: String, yPosition: CGFloat) -> UITextField {
        let field = UITextField()
        field.placeholder = placeholder
        field.isSecureTextEntry = true
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.textColor = .white
        field.font = UIFont.systemFont(ofSize: 16)
        field.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        field.layer.cornerRadius = 8
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor(white: 0.45, alpha: 1.0)]
        )
        // Left padding
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 40))
        field.leftView = paddingView
        field.leftViewMode = .always
        field.frame = CGRect(x: 16, y: yPosition, width: view.bounds.width - 64, height: 40)
        return field
    }

    // MARK: - Helpers

    private func addSectionHeader(_ title: String, at yOffset: CGFloat) -> CGFloat {
        let label = UILabel()
        label.text = title.uppercased()
        label.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        label.textColor = UIColor(red: 0.5, green: 0.7, blue: 0.5, alpha: 1.0)
        label.frame = CGRect(x: 20, y: yOffset, width: view.bounds.width - 40, height: 20)
        contentView.addSubview(label)
        return yOffset + 30
    }

    private func addButton(title: String, titleColor: UIColor, action: Selector, at yOffset: CGFloat) -> CGFloat {
        let rowHeight: CGFloat = 50

        let containerView = UIView()
        containerView.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        containerView.layer.cornerRadius = 10
        containerView.frame = CGRect(x: 16, y: yOffset, width: view.bounds.width - 32, height: rowHeight)
        contentView.addSubview(containerView)

        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(titleColor, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        button.frame = containerView.bounds
        button.addTarget(self, action: action, for: .touchUpInside)
        containerView.addSubview(button)

        return yOffset + rowHeight + 8
    }

    // MARK: - Actions

    @objc private func updatePasswordTapped() {
        guard let currentPwd = currentPasswordField?.text, !currentPwd.isEmpty,
              let newPwd = newPasswordField?.text, !newPwd.isEmpty,
              let confirmPwd = confirmPasswordField?.text, !confirmPwd.isEmpty else {
            showError(message: "Please fill in all password fields.")
            return
        }

        guard newPwd == confirmPwd else {
            showError(message: "New passwords do not match.")
            return
        }

        guard newPwd.count >= 6 else {
            showError(message: "New password must be at least 6 characters.")
            return
        }

        updatePasswordButton?.isEnabled = false

        AuthService.shared.changePassword(currentPassword: currentPwd, newPassword: newPwd) { [weak self] result in
            DispatchQueue.main.async {
                self?.updatePasswordButton?.isEnabled = true
                switch result {
                case .success:
                    self?.currentPasswordField?.text = ""
                    self?.newPasswordField?.text = ""
                    self?.confirmPasswordField?.text = ""
                    self?.showSuccess(message: "Password updated successfully.")
                case .failure(let error):
                    self?.showError(message: error.localizedDescription)
                }
            }
        }
    }

    @objc private func deleteAccountTapped() {
        showDestructiveConfirmation(
            title: "Delete Account?",
            message: "This will permanently delete your account. This cannot be undone.",
            confirmTitle: "Delete Account"
        ) { [weak self] in
            self?.showDestructiveConfirmation(
                title: "Are you absolutely sure?",
                message: "All data will be lost permanently.",
                confirmTitle: "Yes, Delete Everything"
            ) {
                AuthService.shared.deleteAccount { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success:
                            debugLog("Account deleted")
                        case .failure(let error):
                            self?.showError(message: error.localizedDescription)
                        }
                    }
                }
            }
        }
    }

    @objc private func changeDisplayNameTapped() {
        let displayNameVC = DisplayNameViewController()
        displayNameVC.isChangingName = true
        displayNameVC.modalPresentationStyle = .fullScreen
        present(displayNameVC, animated: true)
    }

    @objc private func myStatisticsTapped() {
        let statsVC = UserStatsViewController()
        statsVC.modalPresentationStyle = .fullScreen
        present(statsVC, animated: true)
    }

    @objc private func backTapped() {
        dismiss(animated: true)
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
