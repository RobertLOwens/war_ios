// ============================================================================
// FILE: AuthViewController.swift
// LOCATION: Grow2 iOS/ViewControllers/AuthViewController.swift
// PURPOSE: Full-screen sign-in/register screen with Email and Google auth
// ============================================================================

import UIKit
import GoogleSignIn

class AuthViewController: UIViewController {

    // MARK: - UI Elements

    private var scrollView: UIScrollView!
    private var contentView: UIView!
    private var modeSegment: UISegmentedControl!
    private var emailField: UITextField!
    private var passwordField: UITextField!
    private var confirmPasswordField: UITextField!
    private var actionButton: UIButton!
    private var forgotPasswordButton: UIButton!
    private var googleSignInButton: UIButton!
    private var activityIndicator: UIActivityIndicatorView!

    private var isRegisterMode: Bool {
        return modeSegment.selectedSegmentIndex == 1
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // MARK: - Setup UI

    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.1, green: 0.12, blue: 0.1, alpha: 1.0)

        // Dismiss keyboard on tap
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)

        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

        // Container for centered content
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(container)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 40),
            container.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            container.widthAnchor.constraint(lessThanOrEqualToConstant: 340),
            container.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 20),
            container.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -20),
            container.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40)
        ])

        // Title
        let titleLabel = UILabel()
        titleLabel.text = "Hex RTS Game"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 36)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)

        // Mode Segment Control (Sign In / Register)
        modeSegment = UISegmentedControl(items: ["Sign In", "Register"])
        modeSegment.selectedSegmentIndex = 0
        modeSegment.selectedSegmentTintColor = UIColor(red: 0.25, green: 0.35, blue: 0.55, alpha: 1.0)
        modeSegment.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        modeSegment.setTitleTextAttributes([.foregroundColor: UIColor.lightGray], for: .normal)
        modeSegment.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        modeSegment.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(modeSegment)

        // Email Field
        emailField = createTextField(placeholder: "Email", keyboardType: .emailAddress)
        emailField.autocapitalizationType = .none
        emailField.autocorrectionType = .no
        container.addSubview(emailField)

        // Password Field
        passwordField = createTextField(placeholder: "Password", isSecure: true)
        container.addSubview(passwordField)

        // Confirm Password Field (register mode only)
        confirmPasswordField = createTextField(placeholder: "Confirm Password", isSecure: true)
        confirmPasswordField.isHidden = true
        container.addSubview(confirmPasswordField)

        // Action Button
        actionButton = UIButton(type: .system)
        actionButton.setTitle("Sign In", for: .normal)
        actionButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        actionButton.setTitleColor(.white, for: .normal)
        actionButton.backgroundColor = UIColor(red: 0.25, green: 0.35, blue: 0.55, alpha: 1.0)
        actionButton.layer.cornerRadius = 12
        actionButton.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(actionButton)

        // Forgot Password Button
        forgotPasswordButton = UIButton(type: .system)
        forgotPasswordButton.setTitle("Forgot Password?", for: .normal)
        forgotPasswordButton.setTitleColor(UIColor(white: 0.6, alpha: 1.0), for: .normal)
        forgotPasswordButton.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        forgotPasswordButton.addTarget(self, action: #selector(forgotPasswordTapped), for: .touchUpInside)
        forgotPasswordButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(forgotPasswordButton)

        // Divider
        let dividerContainer = UIView()
        dividerContainer.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(dividerContainer)

        let leftLine = UIView()
        leftLine.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
        leftLine.translatesAutoresizingMaskIntoConstraints = false
        dividerContainer.addSubview(leftLine)

        let orLabel = UILabel()
        orLabel.text = "OR"
        orLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        orLabel.textColor = UIColor(white: 0.5, alpha: 1.0)
        orLabel.textAlignment = .center
        orLabel.translatesAutoresizingMaskIntoConstraints = false
        dividerContainer.addSubview(orLabel)

        let rightLine = UIView()
        rightLine.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
        rightLine.translatesAutoresizingMaskIntoConstraints = false
        dividerContainer.addSubview(rightLine)

        NSLayoutConstraint.activate([
            dividerContainer.heightAnchor.constraint(equalToConstant: 20),
            leftLine.leadingAnchor.constraint(equalTo: dividerContainer.leadingAnchor),
            leftLine.centerYAnchor.constraint(equalTo: dividerContainer.centerYAnchor),
            leftLine.heightAnchor.constraint(equalToConstant: 1),
            leftLine.trailingAnchor.constraint(equalTo: orLabel.leadingAnchor, constant: -12),
            orLabel.centerXAnchor.constraint(equalTo: dividerContainer.centerXAnchor),
            orLabel.centerYAnchor.constraint(equalTo: dividerContainer.centerYAnchor),
            rightLine.leadingAnchor.constraint(equalTo: orLabel.trailingAnchor, constant: 12),
            rightLine.centerYAnchor.constraint(equalTo: dividerContainer.centerYAnchor),
            rightLine.heightAnchor.constraint(equalToConstant: 1),
            rightLine.trailingAnchor.constraint(equalTo: dividerContainer.trailingAnchor)
        ])

        // Google Sign In Button (hidden if Google Sign-In not configured)
        let googleConfigured = GIDSignIn.sharedInstance.configuration != nil
        googleSignInButton = UIButton(type: .system)
        googleSignInButton.setTitle("  Sign in with Google", for: .normal)
        googleSignInButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        googleSignInButton.setTitleColor(.white, for: .normal)
        googleSignInButton.backgroundColor = UIColor(red: 0.85, green: 0.33, blue: 0.24, alpha: 1.0)
        googleSignInButton.layer.cornerRadius = 12
        googleSignInButton.addTarget(self, action: #selector(googleSignInTapped), for: .touchUpInside)
        googleSignInButton.translatesAutoresizingMaskIntoConstraints = false
        googleSignInButton.isHidden = !googleConfigured
        container.addSubview(googleSignInButton)
        dividerContainer.isHidden = !googleConfigured

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

        // Layout
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            modeSegment.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 30),
            modeSegment.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            modeSegment.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            modeSegment.heightAnchor.constraint(equalToConstant: 36),

            emailField.topAnchor.constraint(equalTo: modeSegment.bottomAnchor, constant: 24),
            emailField.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            emailField.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            emailField.heightAnchor.constraint(equalToConstant: 50),

            passwordField.topAnchor.constraint(equalTo: emailField.bottomAnchor, constant: 12),
            passwordField.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            passwordField.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            passwordField.heightAnchor.constraint(equalToConstant: 50),

            confirmPasswordField.topAnchor.constraint(equalTo: passwordField.bottomAnchor, constant: 12),
            confirmPasswordField.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            confirmPasswordField.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            confirmPasswordField.heightAnchor.constraint(equalToConstant: 50),

            actionButton.topAnchor.constraint(equalTo: confirmPasswordField.bottomAnchor, constant: 20),
            actionButton.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            actionButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            actionButton.heightAnchor.constraint(equalToConstant: 50),

            forgotPasswordButton.topAnchor.constraint(equalTo: actionButton.bottomAnchor, constant: 8),
            forgotPasswordButton.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            dividerContainer.topAnchor.constraint(equalTo: forgotPasswordButton.bottomAnchor, constant: 20),
            dividerContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            dividerContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            googleSignInButton.topAnchor.constraint(equalTo: dividerContainer.bottomAnchor, constant: 20),
            googleSignInButton.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            googleSignInButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            googleSignInButton.heightAnchor.constraint(equalToConstant: 50),
            googleSignInButton.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }

    private func createTextField(placeholder: String, keyboardType: UIKeyboardType = .default, isSecure: Bool = false) -> UITextField {
        let field = UITextField()
        field.placeholder = placeholder
        field.font = UIFont.systemFont(ofSize: 17)
        field.textColor = .white
        field.keyboardType = keyboardType
        field.isSecureTextEntry = isSecure
        field.backgroundColor = UIColor(white: 0.18, alpha: 1.0)
        field.layer.cornerRadius = 10
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor(white: 0.3, alpha: 1.0).cgColor
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor(white: 0.5, alpha: 1.0)]
        )
        // Left padding
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 50))
        field.leftView = paddingView
        field.leftViewMode = .always
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }

    // MARK: - Actions

    @objc private func modeChanged() {
        let isRegister = isRegisterMode
        confirmPasswordField.isHidden = !isRegister
        actionButton.setTitle(isRegister ? "Register" : "Sign In", for: .normal)
        forgotPasswordButton.isHidden = isRegister
    }

    @objc private func actionButtonTapped() {
        dismissKeyboard()

        guard let email = emailField.text, !email.isEmpty else {
            showError(message: "Please enter your email address.")
            return
        }
        guard let password = passwordField.text, !password.isEmpty else {
            showError(message: "Please enter your password.")
            return
        }

        if isRegisterMode {
            guard let confirmPassword = confirmPasswordField.text, confirmPassword == password else {
                showError(message: "Passwords do not match.")
                return
            }
            if let passwordError = validatePassword(password) {
                showError(message: passwordError)
                return
            }
            setLoading(true)
            AuthService.shared.signUp(email: email, password: password) { [weak self] result in
                DispatchQueue.main.async {
                    self?.setLoading(false)
                    switch result {
                    case .success:
                        debugLog("Auth: Sign up successful")
                    case .failure(let error):
                        self?.showError(message: error.localizedDescription)
                    }
                }
            }
        } else {
            setLoading(true)
            AuthService.shared.signIn(email: email, password: password) { [weak self] result in
                DispatchQueue.main.async {
                    self?.setLoading(false)
                    switch result {
                    case .success:
                        debugLog("Auth: Sign in successful")
                    case .failure(let error):
                        self?.showError(message: error.localizedDescription)
                    }
                }
            }
        }
    }

    @objc private func forgotPasswordTapped() {
        let alert = UIAlertController(title: "Reset Password", message: "Enter your email address to receive a password reset link.", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Email"
            textField.keyboardType = .emailAddress
            textField.text = self.emailField.text
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Send", style: .default) { [weak self] _ in
            guard let email = alert.textFields?.first?.text, !email.isEmpty else { return }
            AuthService.shared.resetPassword(email: email) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self?.showAlert(title: "Email Sent", message: "Check your email for password reset instructions.")
                    case .failure(let error):
                        self?.showError(message: error.localizedDescription)
                    }
                }
            }
        })
        present(alert, animated: true)
    }

    @objc private func googleSignInTapped() {
        setLoading(true)
        AuthService.shared.signInWithGoogle(presenting: self) { [weak self] result in
            DispatchQueue.main.async {
                self?.setLoading(false)
                switch result {
                case .success:
                    debugLog("Auth: Google sign-in successful")
                case .failure(let error):
                    self?.showError(message: error.localizedDescription)
                }
            }
        }
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - Helpers

    private func setLoading(_ loading: Bool) {
        if loading {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
        actionButton.isEnabled = !loading
        googleSignInButton.isEnabled = !loading
        emailField.isEnabled = !loading
        passwordField.isEnabled = !loading
        confirmPasswordField.isEnabled = !loading
    }

    private func validatePassword(_ password: String) -> String? {
        if password.count < 8 {
            return "Password must be at least 8 characters."
        }
        if password.rangeOfCharacter(from: .uppercaseLetters) == nil {
            return "Password must contain at least one uppercase letter."
        }
        if password.rangeOfCharacter(from: .lowercaseLetters) == nil {
            return "Password must contain at least one lowercase letter."
        }
        if password.rangeOfCharacter(from: .decimalDigits) == nil {
            return "Password must contain at least one number."
        }
        return nil
    }

    private func showError(message: String) {
        showAlert(title: "Error", message: message)
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
