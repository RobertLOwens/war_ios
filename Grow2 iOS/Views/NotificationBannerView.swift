// ============================================================================
// FILE: NotificationBannerView.swift
// LOCATION: Grow2 iOS/Views/NotificationBannerView.swift
// PURPOSE: Toast-style banner view for game notifications
// ============================================================================

import UIKit

// MARK: - Notification Banner Delegate

protocol NotificationBannerDelegate: AnyObject {
    /// Called when a notification banner is tapped (for jump-to-location)
    func notificationBannerTapped(notification: GameNotification)
}

// MARK: - Notification Banner View

/// A toast-style banner view that displays game notifications
class NotificationBannerView: UIView {

    // MARK: - UI Components

    private let iconLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 24)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = .white
        label.textAlignment = .left
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let dismissButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        button.tintColor = .white.withAlphaComponent(0.6)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let locationIndicator: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "location.fill")
        imageView.tintColor = .white.withAlphaComponent(0.6)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isHidden = true
        return imageView
    }()

    // MARK: - Properties

    weak var delegate: NotificationBannerDelegate?

    private var currentNotification: GameNotification?
    private var notificationQueue: [GameNotification] = []
    private var isAnimating = false
    private var displayTimer: Timer?

    /// Duration to display each notification (seconds)
    private let displayDuration: TimeInterval = 4.0

    /// Animation duration
    private let animationDuration: TimeInterval = 0.3

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    // MARK: - Setup

    private func setupView() {
        // Style the container
        backgroundColor = UIColor(red: 0.15, green: 0.15, blue: 0.2, alpha: 0.95)
        layer.cornerRadius = 12
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 8
        layer.shadowOpacity = 0.3

        // Add border for visibility
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor

        // Add subviews
        addSubview(iconLabel)
        addSubview(messageLabel)
        addSubview(dismissButton)
        addSubview(locationIndicator)

        // Layout constraints
        NSLayoutConstraint.activate([
            // Icon
            iconLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            iconLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconLabel.widthAnchor.constraint(equalToConstant: 32),
            iconLabel.heightAnchor.constraint(equalToConstant: 32),

            // Message
            messageLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 8),
            messageLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            messageLabel.trailingAnchor.constraint(equalTo: locationIndicator.leadingAnchor, constant: -8),

            // Location indicator
            locationIndicator.trailingAnchor.constraint(equalTo: dismissButton.leadingAnchor, constant: -8),
            locationIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),
            locationIndicator.widthAnchor.constraint(equalToConstant: 16),
            locationIndicator.heightAnchor.constraint(equalToConstant: 16),

            // Dismiss button
            dismissButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            dismissButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            dismissButton.widthAnchor.constraint(equalToConstant: 28),
            dismissButton.heightAnchor.constraint(equalToConstant: 28),
        ])

        // Add gestures
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)

        dismissButton.addTarget(self, action: #selector(handleDismiss), for: .touchUpInside)

        // Initially hidden
        alpha = 0
        transform = CGAffineTransform(translationX: 0, y: -20)
    }

    // MARK: - Notification Queue Management

    /// Queue a notification for display
    func queueNotification(_ notification: GameNotification) {
        // Insert based on priority (higher priority first)
        let insertIndex = notificationQueue.firstIndex { $0.priority < notification.priority } ?? notificationQueue.endIndex
        notificationQueue.insert(notification, at: insertIndex)

        // Start showing if not already
        if currentNotification == nil && !isAnimating {
            showNextNotification()
        }
    }

    /// Show the next notification in the queue
    private func showNextNotification() {
        guard !notificationQueue.isEmpty else {
            currentNotification = nil
            return
        }

        let notification = notificationQueue.removeFirst()
        showNotification(notification)
    }

    /// Display a specific notification
    private func showNotification(_ notification: GameNotification) {
        currentNotification = notification

        // Update UI
        iconLabel.text = notification.icon
        messageLabel.text = notification.message
        locationIndicator.isHidden = notification.coordinate == nil

        // Animate in
        isAnimating = true
        UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseOut) {
            self.alpha = 1
            self.transform = .identity
        } completion: { _ in
            self.isAnimating = false
            self.startDisplayTimer()
        }
    }

    /// Start the auto-dismiss timer
    private func startDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = Timer.scheduledTimer(withTimeInterval: displayDuration, repeats: false) { [weak self] _ in
            self?.dismissCurrentNotification()
        }
    }

    /// Dismiss the current notification
    private func dismissCurrentNotification() {
        displayTimer?.invalidate()
        displayTimer = nil

        isAnimating = true
        UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseIn) {
            self.alpha = 0
            self.transform = CGAffineTransform(translationX: 0, y: -20)
        } completion: { _ in
            self.isAnimating = false
            self.currentNotification = nil
            self.showNextNotification()
        }
    }

    // MARK: - Gesture Handlers

    @objc private func handleTap() {
        guard let notification = currentNotification else { return }

        // If notification has a coordinate, trigger navigation
        if notification.coordinate != nil {
            delegate?.notificationBannerTapped(notification: notification)
        }

        // Dismiss after tap
        dismissCurrentNotification()
    }

    @objc private func handleDismiss() {
        dismissCurrentNotification()
    }

    // MARK: - Cleanup

    func clearQueue() {
        notificationQueue.removeAll()
        displayTimer?.invalidate()
        displayTimer = nil
    }
}

// MARK: - Notification Banner Container

/// A container view that manages the notification banner and its positioning
class NotificationBannerContainer: UIView {

    // MARK: - Properties

    private let bannerView = NotificationBannerView()
    weak var delegate: NotificationBannerDelegate? {
        didSet {
            bannerView.delegate = delegate
        }
    }

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        setupNotificationObserver()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        setupNotificationObserver()
    }

    // MARK: - Setup

    private func setupView() {
        isUserInteractionEnabled = true
        backgroundColor = .clear

        bannerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bannerView)

        NSLayoutConstraint.activate([
            bannerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            bannerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            bannerView.topAnchor.constraint(equalTo: topAnchor),
            bannerView.heightAnchor.constraint(equalToConstant: 56),
        ])
    }

    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleGameNotification),
            name: .gameNotificationReceived,
            object: nil
        )
    }

    @objc private func handleGameNotification(_ notification: Notification) {
        guard let gameNotification = notification.userInfo?["notification"] as? GameNotification else {
            return
        }

        bannerView.queueNotification(gameNotification)
    }

    // MARK: - Cleanup

    func clearNotifications() {
        bannerView.clearQueue()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
