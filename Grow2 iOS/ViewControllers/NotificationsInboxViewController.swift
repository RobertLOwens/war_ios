// ============================================================================
// FILE: NotificationsInboxViewController.swift
// LOCATION: Grow2 iOS/ViewControllers/
// PURPOSE: Shows notification history with tap-to-jump functionality
// ============================================================================

import UIKit

class NotificationsInboxViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    // MARK: - Properties

    weak var gameScene: GameScene?
    private var tableView: UITableView!
    private var emptyStateLabel: UILabel!
    private var notifications: [GameNotification] = []

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadNotifications()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadNotifications()
        observeChanges()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = UIColor(white: 0.15, alpha: 1.0)

        // Header view
        let headerView = UIView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = UIColor(white: 0.1, alpha: 1.0)
        view.addSubview(headerView)

        // Title
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "🔔 Notifications"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 22)
        titleLabel.textColor = .white
        headerView.addSubview(titleLabel)

        // Close button
        let closeButton = UIButton(type: .system)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setTitle("✕", for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        headerView.addSubview(closeButton)

        // Action buttons container
        let actionsStack = UIStackView()
        actionsStack.translatesAutoresizingMaskIntoConstraints = false
        actionsStack.axis = .horizontal
        actionsStack.spacing = 12
        actionsStack.distribution = .fillEqually
        headerView.addSubview(actionsStack)

        // Mark All Read button
        let markReadButton = UIButton(type: .system)
        markReadButton.setTitle("Mark All Read", for: .normal)
        markReadButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        markReadButton.setTitleColor(.systemBlue, for: .normal)
        markReadButton.addTarget(self, action: #selector(markAllReadTapped), for: .touchUpInside)
        actionsStack.addArrangedSubview(markReadButton)

        // Clear All button
        let clearButton = UIButton(type: .system)
        clearButton.setTitle("Clear All", for: .normal)
        clearButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        clearButton.setTitleColor(.systemRed, for: .normal)
        clearButton.addTarget(self, action: #selector(clearAllTapped), for: .touchUpInside)
        actionsStack.addArrangedSubview(clearButton)

        // Table view
        tableView = UITableView(frame: .zero, style: .plain)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = UIColor(white: 0.12, alpha: 1.0)
        tableView.separatorColor = UIColor(white: 0.25, alpha: 1.0)
        tableView.register(NotificationInboxCell.self, forCellReuseIdentifier: "NotificationInboxCell")
        view.addSubview(tableView)

        // Empty state label
        emptyStateLabel = UILabel()
        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyStateLabel.text = "📭 No notifications yet"
        emptyStateLabel.font = UIFont.systemFont(ofSize: 18)
        emptyStateLabel.textColor = UIColor(white: 0.5, alpha: 1.0)
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.isHidden = true
        view.addSubview(emptyStateLabel)

        // Layout constraints
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 90),

            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),

            closeButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),

            actionsStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            actionsStack.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            actionsStack.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),

            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyStateLabel.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor)
        ])
    }

    private func observeChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(historyChanged),
            name: .notificationHistoryChanged,
            object: nil
        )
    }

    @objc private func historyChanged() {
        loadNotifications()
    }

    private func loadNotifications() {
        notifications = NotificationManager.shared.getRecentNotifications()
        tableView.reloadData()
        emptyStateLabel.isHidden = !notifications.isEmpty
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func markAllReadTapped() {
        NotificationManager.shared.markAllAsRead()
        tableView.reloadData()
    }

    @objc private func clearAllTapped() {
        let alert = UIAlertController(
            title: "Clear All Notifications",
            message: "Are you sure you want to clear all notifications?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { [weak self] _ in
            NotificationManager.shared.clearHistory()
            self?.loadNotifications()
        })

        present(alert, animated: true)
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return notifications.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "NotificationInboxCell", for: indexPath) as? NotificationInboxCell else {
            return UITableViewCell()
        }
        let notification = notifications[indexPath.row]
        let isUnread = NotificationManager.shared.isUnread(notification.id)
        cell.configure(with: notification, isUnread: isUnread)
        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let notification = notifications[indexPath.row]

        // Mark as read
        NotificationManager.shared.markAsRead(notification.id)

        // If has coordinate, dismiss and jump to location
        if let coordinate = notification.coordinate {
            dismiss(animated: true) { [weak self] in
                self?.gameScene?.focusCamera(on: coordinate, zoom: 0.7, animated: true)
            }
        } else {
            // Just reload to show read state
            tableView.reloadRows(at: [indexPath], with: .automatic)
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 72
    }

    // MARK: - Cleanup

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Notification Inbox Cell

class NotificationInboxCell: UITableViewCell {

    private let unreadDot = UIView()
    private let iconLabel = UILabel()
    private let messageLabel = UILabel()
    private let timeLabel = UILabel()
    private let locationIndicator = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .default

        // Unread dot
        unreadDot.translatesAutoresizingMaskIntoConstraints = false
        unreadDot.backgroundColor = .systemBlue
        unreadDot.layer.cornerRadius = 5
        contentView.addSubview(unreadDot)

        // Icon
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        iconLabel.font = UIFont.systemFont(ofSize: 28)
        iconLabel.textAlignment = .center
        contentView.addSubview(iconLabel)

        // Message
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.font = UIFont.systemFont(ofSize: 15)
        messageLabel.textColor = .white
        messageLabel.numberOfLines = 2
        contentView.addSubview(messageLabel)

        // Time label
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.font = UIFont.systemFont(ofSize: 12)
        timeLabel.textColor = UIColor(white: 0.5, alpha: 1.0)
        timeLabel.textAlignment = .right
        contentView.addSubview(timeLabel)

        // Location indicator
        locationIndicator.translatesAutoresizingMaskIntoConstraints = false
        locationIndicator.font = UIFont.systemFont(ofSize: 12)
        locationIndicator.textColor = UIColor(white: 0.6, alpha: 1.0)
        locationIndicator.text = "📍"
        locationIndicator.isHidden = true
        contentView.addSubview(locationIndicator)

        // Layout
        NSLayoutConstraint.activate([
            unreadDot.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            unreadDot.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            unreadDot.widthAnchor.constraint(equalToConstant: 10),
            unreadDot.heightAnchor.constraint(equalToConstant: 10),

            iconLabel.leadingAnchor.constraint(equalTo: unreadDot.trailingAnchor, constant: 10),
            iconLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconLabel.widthAnchor.constraint(equalToConstant: 36),

            messageLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 10),
            messageLabel.trailingAnchor.constraint(equalTo: timeLabel.leadingAnchor, constant: -8),
            messageLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            timeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            timeLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            timeLabel.widthAnchor.constraint(equalToConstant: 60),

            locationIndicator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            locationIndicator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14)
        ])
    }

    func configure(with notification: GameNotification, isUnread: Bool) {
        iconLabel.text = notification.icon
        messageLabel.text = notification.message
        timeLabel.text = formatRelativeTime(notification.timestamp)
        unreadDot.isHidden = !isUnread
        locationIndicator.isHidden = notification.coordinate == nil

        // Adjust message opacity based on read state
        messageLabel.alpha = isUnread ? 1.0 : 0.7
    }

    private func formatRelativeTime(_ date: Date) -> String {
        let elapsed = Date().timeIntervalSince(date)

        if elapsed < 60 {
            return "Just now"
        } else if elapsed < 3600 {
            let mins = Int(elapsed / 60)
            return "\(mins)m ago"
        } else if elapsed < 86400 {
            let hours = Int(elapsed / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(elapsed / 86400)
            return "\(days)d ago"
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        iconLabel.text = nil
        messageLabel.text = nil
        timeLabel.text = nil
        unreadDot.isHidden = true
        locationIndicator.isHidden = true
        messageLabel.alpha = 1.0
    }
}
