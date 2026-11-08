import Cocoa
import Foundation

// Disable stdout buffering for testing
setbuf(stdout, nil)

// Setup JSON decoder structures
struct TelemetryPayload: Codable {
    let battery: Int
    let charging: Bool
}

struct NotificationPayload: Codable {
    let app: String
    let title: String
    let body: String
}

struct GenericPayload: Codable {
    let type: String
}

// MARK: - Notification Log Entry
struct NotificationLogEntry {
    let timestamp: Date
    let appName: String
    let title: String
    let body: String
}

// MARK: - Main Dashboard Window
class DashboardWindow: NSWindow {
    
    // Connection panel
    var connectionDot: NSView!
    var connectionLabel: NSTextField!
    var connectionQualityLabel: NSTextField!
    var ipField: NSTextField!
    var connectButton: NSButton!
    var onConnectRequested: ((String) -> Void)?
    
    // Battery panel
    var batteryBarFill: NSView!
    var batteryPercentLabel: NSTextField!
    var batteryStatusLabel: NSTextField!
    var batteryBarWidth: NSLayoutConstraint!
    
    // Notification feed
    var notificationScrollView: NSScrollView!
    var notificationStackView: NSStackView!
    var emptyStateLabel: NSTextField!
    
    // Event log
    var eventLogScrollView: NSScrollView!
    var eventLogTextView: NSTextView!
    
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        self.title = "OmniFlow — Android Continuity"
        self.minSize = NSSize(width: 480, height: 500)
        self.isReleasedWhenClosed = false
        self.center()
        
        setupUI()
    }
    
    func setupUI() {
        let contentView = NSView(frame: self.contentRect(forFrameRect: self.frame))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor(white: 0.12, alpha: 1.0).cgColor
        self.contentView = contentView
        
        // Main vertical stack
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.spacing = 16
        mainStack.alignment = .leading
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
        ])
        
        // === HEADER ===
        let headerLabel = makeLabel("OmniFlow", size: 22, bold: true, color: .white)
        let subtitleLabel = makeLabel("Android ↔ Mac Continuity Bridge", size: 12, bold: false, color: NSColor(white: 0.55, alpha: 1.0))
        mainStack.addArrangedSubview(headerLabel)
        mainStack.addArrangedSubview(subtitleLabel)
        mainStack.setCustomSpacing(4, after: headerLabel)
        mainStack.setCustomSpacing(20, after: subtitleLabel)
        
        // === CONNECTION + BATTERY ROW ===
        let topRow = NSStackView()
        topRow.orientation = .horizontal
        topRow.spacing = 12
        topRow.distribution = .fillEqually
        topRow.translatesAutoresizingMaskIntoConstraints = false
        mainStack.addArrangedSubview(topRow)
        topRow.widthAnchor.constraint(equalTo: mainStack.widthAnchor).isActive = true
        
        topRow.addArrangedSubview(buildConnectionCard())
        topRow.addArrangedSubview(buildBatteryCard())
        
        // === NOTIFICATION FEED ===
        let notifHeader = makeLabel("📬  Notification Feed", size: 14, bold: true, color: .white)
        mainStack.addArrangedSubview(notifHeader)
        mainStack.setCustomSpacing(8, after: notifHeader)
        
        let notifCard = makeCard()
        mainStack.addArrangedSubview(notifCard)
        notifCard.widthAnchor.constraint(equalTo: mainStack.widthAnchor).isActive = true
        notifCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true
        
        // Empty state
        emptyStateLabel = makeLabel("Waiting for notifications from Android…", size: 12, bold: false, color: NSColor(white: 0.45, alpha: 1.0))
        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
        notifCard.addSubview(emptyStateLabel)
        NSLayoutConstraint.activate([
            emptyStateLabel.centerXAnchor.constraint(equalTo: notifCard.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: notifCard.centerYAnchor),
        ])
        
        // Scroll view for notifications
        notificationScrollView = NSScrollView()
        notificationScrollView.translatesAutoresizingMaskIntoConstraints = false
        notificationScrollView.hasVerticalScroller = true
        notificationScrollView.drawsBackground = false
        notificationScrollView.borderType = .noBorder
        notifCard.addSubview(notificationScrollView)
        
        NSLayoutConstraint.activate([
            notificationScrollView.topAnchor.constraint(equalTo: notifCard.topAnchor, constant: 8),
            notificationScrollView.leadingAnchor.constraint(equalTo: notifCard.leadingAnchor, constant: 8),
            notificationScrollView.trailingAnchor.constraint(equalTo: notifCard.trailingAnchor, constant: -8),
            notificationScrollView.bottomAnchor.constraint(equalTo: notifCard.bottomAnchor, constant: -8),
        ])
        
        notificationStackView = NSStackView()
        notificationStackView.orientation = .vertical
        notificationStackView.spacing = 8
        notificationStackView.alignment = .leading
        notificationStackView.translatesAutoresizingMaskIntoConstraints = false
        
        let clipView = NSClipView()
        clipView.documentView = notificationStackView
        clipView.drawsBackground = false
        notificationScrollView.contentView = clipView
        
        notificationStackView.widthAnchor.constraint(equalTo: notificationScrollView.widthAnchor).isActive = true
        
        // === EVENT LOG ===
        let logHeader = makeLabel("📋  Event Log", size: 14, bold: true, color: .white)
        mainStack.addArrangedSubview(logHeader)
        mainStack.setCustomSpacing(8, after: logHeader)
        
        let logCard = makeCard()
        mainStack.addArrangedSubview(logCard)
        logCard.widthAnchor.constraint(equalTo: mainStack.widthAnchor).isActive = true
        
        // Make the notification feed and event log share remaining space
        let notifHeight = notifCard.heightAnchor.constraint(equalToConstant: 180)
        notifHeight.priority = .defaultLow
        notifHeight.isActive = true
        
        let logHeight = logCard.heightAnchor.constraint(equalToConstant: 140)
        logHeight.priority = .defaultLow
        logHeight.isActive = true
        
        eventLogScrollView = NSScrollView()
        eventLogScrollView.translatesAutoresizingMaskIntoConstraints = false
        eventLogScrollView.hasVerticalScroller = true
        eventLogScrollView.drawsBackground = false
        eventLogScrollView.borderType = .noBorder
        logCard.addSubview(eventLogScrollView)
        
        NSLayoutConstraint.activate([
            eventLogScrollView.topAnchor.constraint(equalTo: logCard.topAnchor, constant: 8),
            eventLogScrollView.leadingAnchor.constraint(equalTo: logCard.leadingAnchor, constant: 8),
            eventLogScrollView.trailingAnchor.constraint(equalTo: logCard.trailingAnchor, constant: -8),
            eventLogScrollView.bottomAnchor.constraint(equalTo: logCard.bottomAnchor, constant: -8),
        ])
        
        eventLogTextView = NSTextView()
        eventLogTextView.isEditable = false
        eventLogTextView.isSelectable = true
        eventLogTextView.drawsBackground = false
        eventLogTextView.textColor = NSColor(white: 0.6, alpha: 1.0)
        eventLogTextView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        eventLogTextView.isVerticallyResizable = true
        eventLogTextView.isHorizontallyResizable = false
        eventLogTextView.textContainer?.widthTracksTextView = true
        eventLogScrollView.documentView = eventLogTextView
    }
    
    // MARK: - Card Builders
    
    func buildConnectionCard() -> NSView {
        let card = makeCard()
        card.heightAnchor.constraint(equalToConstant: 140).isActive = true
        
        let titleLabel = makeLabel("Connection", size: 11, bold: true, color: NSColor(white: 0.5, alpha: 1.0))
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLabel)
        
        // Status dot
        connectionDot = NSView()
        connectionDot.wantsLayer = true
        connectionDot.layer?.backgroundColor = NSColor.systemRed.cgColor
        connectionDot.layer?.cornerRadius = 6
        connectionDot.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(connectionDot)
        
        connectionLabel = makeLabel("Disconnected", size: 14, bold: true, color: .white)
        connectionLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(connectionLabel)
        
        connectionQualityLabel = makeLabel("", size: 11, bold: false, color: NSColor(white: 0.5, alpha: 1.0))
        connectionQualityLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(connectionQualityLabel)
        
        // IP Address input
        let savedIP = UserDefaults.standard.string(forKey: "omniflow_target_ip") ?? "127.0.0.1"
        
        ipField = NSTextField(string: savedIP)
        ipField.placeholderString = "Phone IP (e.g. 192.168.1.42)"
        ipField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        ipField.textColor = .white
        ipField.backgroundColor = NSColor(white: 0.12, alpha: 1.0)
        ipField.isBordered = true
        ipField.bezelStyle = .roundedBezel
        ipField.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(ipField)
        
        connectButton = NSButton(title: "Connect", target: self, action: #selector(connectTapped))
        connectButton.bezelStyle = .rounded
        connectButton.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(connectButton)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            
            connectionDot.widthAnchor.constraint(equalToConstant: 12),
            connectionDot.heightAnchor.constraint(equalToConstant: 12),
            connectionDot.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            connectionDot.centerYAnchor.constraint(equalTo: connectionLabel.centerYAnchor),
            
            connectionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            connectionLabel.leadingAnchor.constraint(equalTo: connectionDot.trailingAnchor, constant: 8),
            
            connectionQualityLabel.topAnchor.constraint(equalTo: connectionLabel.bottomAnchor, constant: 2),
            connectionQualityLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            
            ipField.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            ipField.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            ipField.heightAnchor.constraint(equalToConstant: 24),
            
            connectButton.leadingAnchor.constraint(equalTo: ipField.trailingAnchor, constant: 6),
            connectButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            connectButton.centerYAnchor.constraint(equalTo: ipField.centerYAnchor),
            connectButton.widthAnchor.constraint(equalToConstant: 72),
        ])
        
        return card
    }
    
    @objc func connectTapped() {
        let ip = ipField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !ip.isEmpty else { return }
        UserDefaults.standard.set(ip, forKey: "omniflow_target_ip")
        onConnectRequested?(ip)
    }
    
    func buildBatteryCard() -> NSView {
        let card = makeCard()
        card.heightAnchor.constraint(equalToConstant: 100).isActive = true
        
        let titleLabel = makeLabel("Battery", size: 11, bold: true, color: NSColor(white: 0.5, alpha: 1.0))
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLabel)
        
        batteryPercentLabel = makeLabel("--%", size: 26, bold: true, color: .white)
        batteryPercentLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(batteryPercentLabel)
        
        batteryStatusLabel = makeLabel("No device", size: 11, bold: false, color: NSColor(white: 0.5, alpha: 1.0))
        batteryStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(batteryStatusLabel)
        
        // Battery bar background
        let barBg = NSView()
        barBg.wantsLayer = true
        barBg.layer?.backgroundColor = NSColor(white: 0.25, alpha: 1.0).cgColor
        barBg.layer?.cornerRadius = 3
        barBg.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(barBg)
        
        // Battery bar fill
        batteryBarFill = NSView()
        batteryBarFill.wantsLayer = true
        batteryBarFill.layer?.backgroundColor = NSColor.systemGreen.cgColor
        batteryBarFill.layer?.cornerRadius = 3
        batteryBarFill.translatesAutoresizingMaskIntoConstraints = false
        barBg.addSubview(batteryBarFill)
        
        batteryBarWidth = batteryBarFill.widthAnchor.constraint(equalToConstant: 0)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            
            batteryPercentLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            batteryPercentLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            
            batteryStatusLabel.leadingAnchor.constraint(equalTo: batteryPercentLabel.trailingAnchor, constant: 6),
            batteryStatusLabel.bottomAnchor.constraint(equalTo: batteryPercentLabel.bottomAnchor, constant: -4),
            
            barBg.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            barBg.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            barBg.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            barBg.heightAnchor.constraint(equalToConstant: 6),
            
            batteryBarFill.leadingAnchor.constraint(equalTo: barBg.leadingAnchor),
            batteryBarFill.topAnchor.constraint(equalTo: barBg.topAnchor),
            batteryBarFill.bottomAnchor.constraint(equalTo: barBg.bottomAnchor),
            batteryBarWidth,
        ])
        
        return card
    }
    
    // MARK: - UI Helpers
    
    func makeCard() -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(white: 0.18, alpha: 1.0).cgColor
        view.layer?.cornerRadius = 10
        view.layer?.borderWidth = 1
        view.layer?.borderColor = NSColor(white: 0.25, alpha: 1.0).cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }
    
    func makeLabel(_ text: String, size: CGFloat, bold: Bool, color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = bold ? NSFont.systemFont(ofSize: size, weight: .bold) : NSFont.systemFont(ofSize: size, weight: .regular)
        label.textColor = color
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        return label
    }
    
    // MARK: - Update Methods
    
    func updateConnection(connected: Bool, quality: String) {
        DispatchQueue.main.async {
            if connected {
                self.connectionDot.layer?.backgroundColor = NSColor.systemGreen.cgColor
                self.connectionLabel.stringValue = "Connected"
                self.connectionQualityLabel.stringValue = "Signal: \(quality)"
                self.connectButton.title = "Reconnect"
                self.connectButton.isEnabled = true
                self.ipField.isEnabled = true
            } else {
                self.connectionDot.layer?.backgroundColor = NSColor.systemRed.cgColor
                self.connectionLabel.stringValue = "Disconnected"
                self.connectionQualityLabel.stringValue = ""
                self.connectButton.title = "Connect"
                self.connectButton.isEnabled = true
                self.ipField.isEnabled = true
            }
        }
    }
    
    func showConnecting(to host: String) {
        DispatchQueue.main.async {
            self.connectionDot.layer?.backgroundColor = NSColor.systemYellow.cgColor
            self.connectionLabel.stringValue = "Connecting…"
            self.connectionQualityLabel.stringValue = host
            self.connectButton.title = "…"
            self.connectButton.isEnabled = false
            self.ipField.isEnabled = false
        }
    }
    
    func updateBattery(percent: Int, charging: Bool) {
        DispatchQueue.main.async {
            self.batteryPercentLabel.stringValue = "\(percent)%"
            self.batteryStatusLabel.stringValue = charging ? "⚡ Charging" : "On battery"
            
            // Color based on level
            let color: NSColor
            if percent > 50 {
                color = NSColor.systemGreen
            } else if percent > 20 {
                color = NSColor.systemOrange
            } else {
                color = NSColor.systemRed
            }
            self.batteryBarFill.layer?.backgroundColor = color.cgColor
            
            // Animate bar width — calculate as proportion of the bar background
            if let barBg = self.batteryBarFill.superview {
                let maxWidth = barBg.bounds.width
                let targetWidth = maxWidth * CGFloat(percent) / 100.0
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.4
                    ctx.allowsImplicitAnimation = true
                    self.batteryBarWidth.constant = targetWidth
                    self.batteryBarFill.superview?.layoutSubtreeIfNeeded()
                }
            }
        }
    }
    
    func addNotification(appName: String, title: String, body: String) {
        DispatchQueue.main.async {
            self.emptyStateLabel.isHidden = true
            
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm:ss a"
            let timeStr = formatter.string(from: Date())
            
            // Build notification row
            let row = NSView()
            row.wantsLayer = true
            row.layer?.backgroundColor = NSColor(white: 0.14, alpha: 1.0).cgColor
            row.layer?.cornerRadius = 8
            row.translatesAutoresizingMaskIntoConstraints = false
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true
            
            // App icon circle
            let iconView = NSTextField(labelWithString: String(appName.prefix(1)))
            iconView.font = NSFont.systemFont(ofSize: 14, weight: .bold)
            iconView.textColor = .white
            iconView.alignment = .center
            iconView.wantsLayer = true
            iconView.layer?.backgroundColor = self.appColor(for: appName).cgColor
            iconView.layer?.cornerRadius = 16
            iconView.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(iconView)
            
            let appLabel = self.makeLabel(appName, size: 10, bold: false, color: NSColor(white: 0.5, alpha: 1.0))
            appLabel.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(appLabel)
            
            let titleLabel = self.makeLabel(title, size: 13, bold: true, color: .white)
            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(titleLabel)
            
            let bodyLabel = self.makeLabel(body, size: 12, bold: false, color: NSColor(white: 0.7, alpha: 1.0))
            bodyLabel.translatesAutoresizingMaskIntoConstraints = false
            bodyLabel.lineBreakMode = .byTruncatingTail
            row.addSubview(bodyLabel)
            
            let timeLabel = self.makeLabel(timeStr, size: 10, bold: false, color: NSColor(white: 0.4, alpha: 1.0))
            timeLabel.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(timeLabel)
            
            NSLayoutConstraint.activate([
                iconView.widthAnchor.constraint(equalToConstant: 32),
                iconView.heightAnchor.constraint(equalToConstant: 32),
                iconView.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 10),
                iconView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                
                appLabel.topAnchor.constraint(equalTo: row.topAnchor, constant: 8),
                appLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
                
                titleLabel.topAnchor.constraint(equalTo: appLabel.bottomAnchor, constant: 2),
                titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
                titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: timeLabel.leadingAnchor, constant: -8),
                
                bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 1),
                bodyLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
                bodyLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -10),
                bodyLabel.bottomAnchor.constraint(lessThanOrEqualTo: row.bottomAnchor, constant: -8),
                
                timeLabel.topAnchor.constraint(equalTo: row.topAnchor, constant: 8),
                timeLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -10),
            ])
            
            // Insert at top of stack
            self.notificationStackView.insertArrangedSubview(row, at: 0)
            row.widthAnchor.constraint(equalTo: self.notificationStackView.widthAnchor).isActive = true
            
            // Flash animation
            row.alphaValue = 0
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.3
                row.animator().alphaValue = 1.0
            }
        }
    }
    
    func appendEventLog(_ message: String) {
        DispatchQueue.main.async {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            let timeStr = formatter.string(from: Date())
            
            let entry = "[\(timeStr)] \(message)\n"
            let attrStr = NSAttributedString(string: entry, attributes: [
                .foregroundColor: NSColor(white: 0.55, alpha: 1.0),
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
            ])
            self.eventLogTextView.textStorage?.append(attrStr)
            
            // Auto-scroll to bottom
            self.eventLogTextView.scrollToEndOfDocument(nil)
        }
    }
    
    func appColor(for name: String) -> NSColor {
        switch name.lowercased() {
        case "whatsapp": return NSColor(red: 0.15, green: 0.68, blue: 0.38, alpha: 1.0)
        case "messages", "sms": return NSColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1.0)
        case "telegram": return NSColor(red: 0.16, green: 0.63, blue: 0.87, alpha: 1.0)
        case "instagram": return NSColor(red: 0.83, green: 0.18, blue: 0.42, alpha: 1.0)
        case "gmail", "email": return NSColor(red: 0.85, green: 0.26, blue: 0.22, alpha: 1.0)
        case "slack": return NSColor(red: 0.31, green: 0.13, blue: 0.47, alpha: 1.0)
        default: return NSColor(red: 0.4, green: 0.4, blue: 0.5, alpha: 1.0)
        }
    }
}


// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var keepConnecting = true
    var isConnected = false
    var currentBattery: Int?
    var isCharging: Bool = false
    var connectionQuality: String = "--"
    var lastPingSent: Date?
    var currentClient: TCPClient?
    var dashboard: DashboardWindow!
    var targetHost: String = "127.0.0.1"
    let targetPort: Int = 8080
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("[Mac App] Application started.")
        
        // Load saved target IP
        targetHost = UserDefaults.standard.string(forKey: "omniflow_target_ip") ?? "127.0.0.1"
        
        // 1. Create and show the dashboard window
        dashboard = DashboardWindow()
        dashboard.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        dashboard.appendEventLog("OmniFlow started. Target: \(targetHost):\(targetPort)")
        
        // Wire up the connect button callback
        dashboard.onConnectRequested = { [weak self] ip in
            guard let self = self else { return }
            self.targetHost = ip
            self.dashboard.appendEventLog("Target changed to \(ip):\(self.targetPort)")
            // Disconnect current and reconnect with new IP
            self.currentClient = nil
            self.isConnected = false
        }
        
        // 2. Setup Status Bar Item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusItem()
        
        // 3. Start Connection Loop in Background (critical path)
        Thread.detachNewThread {
            self.connectionLoop()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        keepConnecting = false
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false  // Keep running in menu bar even if window is closed
    }
    
    func updateStatusItem() {
        DispatchQueue.main.async {
            guard let button = self.statusItem?.button else { return }
            
            if self.isConnected {
                let batteryIcon = self.isCharging ? "⚡" : "🔋"
                let pct = self.currentBattery != nil ? "\(self.currentBattery!)%" : "--%"
                let qualityIcon: String
                switch self.connectionQuality {
                case "Strong": qualityIcon = "●"
                case "Fair": qualityIcon = "◐"
                case "Weak": qualityIcon = "○"
                default: qualityIcon = "◌"
                }
                button.title = "\(batteryIcon) \(pct) \(qualityIcon)"
            } else {
                button.title = "📱 (Searching...)"
            }
            
            // Build Context Menu
            let menu = NSMenu()
            
            if self.isConnected {
                menu.addItem(NSMenuItem(title: "Status: Connected to Android", action: nil, keyEquivalent: ""))
                let battStr = self.currentBattery != nil ? "Battery: \(self.currentBattery!)%" : "Battery: --%"
                menu.addItem(NSMenuItem(title: battStr, action: nil, keyEquivalent: ""))
                menu.addItem(NSMenuItem(title: "Charging: \(self.isCharging ? "Yes" : "No")", action: nil, keyEquivalent: ""))
                menu.addItem(NSMenuItem(title: "Connection: \(self.connectionQuality)", action: nil, keyEquivalent: ""))
            } else {
                menu.addItem(NSMenuItem(title: "Status: Disconnected", action: nil, keyEquivalent: ""))
                menu.addItem(NSMenuItem(title: "Searching for companion on 127.0.0.1:8080...", action: nil, keyEquivalent: ""))
            }
            
            menu.addItem(NSMenuItem.separator())
            
            let showItem = NSMenuItem(title: "Show Dashboard", action: #selector(self.showDashboard), keyEquivalent: "d")
            showItem.target = self
            menu.addItem(showItem)
            
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit OmniFlow", action: #selector(self.quitApp), keyEquivalent: "q"))
            
            self.statusItem?.menu = menu
        }
    }
    
    @objc func showDashboard() {
        dashboard.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(self)
    }
    
    // MARK: - Connection & Protocol Logic
    
    func connectionLoop() {
        while keepConnecting {
            let host = self.targetHost
            print("[Mac App] Attempting to connect to Android device/simulator at \(host):\(targetPort)...")
            dashboard.appendEventLog("Connecting to \(host):\(targetPort)…")
            dashboard.showConnecting(to: "\(host):\(targetPort)")
            
            let client = TCPClient()
            if client.connect(host: host, port: targetPort) {
                print("[Mac App] Successfully connected!")
                self.isConnected = true
                self.currentClient = client
                self.updateStatusItem()
                dashboard.updateConnection(connected: true, quality: "--")
                dashboard.appendEventLog("✅ Connected to \(host)")
                
                // Start ping timer in background
                Thread.detachNewThread {
                    self.pingLoop()
                }
                
                // Read loop
                var buffer = ""
                while self.keepConnecting && self.isConnected {
                    if let chunk = client.read() {
                        buffer += chunk
                        while let lineEndIndex = buffer.firstIndex(of: "\n") {
                            let line = String(buffer[..<lineEndIndex])
                            buffer = String(buffer[buffer.index(after: lineEndIndex)...])
                            self.handleLine(line)
                        }
                    } else {
                        // Connection lost
                        print("[Mac App] Connection lost.")
                        dashboard.appendEventLog("❌ Connection lost")
                        break
                    }
                }
            } else {
                print("[Mac App] Connection to \(host) failed. Retrying in 3 seconds...")
            }
            
            self.isConnected = false
            self.currentClient = nil
            self.currentBattery = nil
            self.isCharging = false
            self.connectionQuality = "--"
            self.updateStatusItem()
            dashboard.updateConnection(connected: false, quality: "--")
            dashboard.updateBattery(percent: 0, charging: false)
            
            Thread.sleep(forTimeInterval: 3.0)
        }
    }
    
    func pingLoop() {
        while self.isConnected && self.keepConnecting {
            if let client = self.currentClient {
                self.lastPingSent = Date()
                let pingJson = "{\"type\":\"ping\"}\n"
                client.write(pingJson)
            }
            Thread.sleep(forTimeInterval: 5.0)
        }
    }
    
    func handleLine(_ line: String) {
        guard let data = line.data(using: .utf8) else { return }
        do {
            let decoder = JSONDecoder()
            let generic = try decoder.decode(GenericPayload.self, from: data)
            
            if generic.type == "telemetry" {
                let telemetry = try decoder.decode(TelemetryPayload.self, from: data)
                self.currentBattery = telemetry.battery
                self.isCharging = telemetry.charging
                print("[Mac App] Telemetry update: battery=\(telemetry.battery)%, charging=\(telemetry.charging)")
                self.updateStatusItem()
                dashboard.updateBattery(percent: telemetry.battery, charging: telemetry.charging)
                let chargingStr = telemetry.charging ? " (charging)" : ""
                dashboard.appendEventLog("🔋 Battery: \(telemetry.battery)%\(chargingStr)")
            } else if generic.type == "notification" {
                let notif = try decoder.decode(NotificationPayload.self, from: data)
                print("[Mac App] Received Notification: \(notif.title) - \(notif.body) (App: \(notif.app))")
                self.showNotification(appName: notif.app, title: notif.title, body: notif.body)
                dashboard.addNotification(appName: notif.app, title: notif.title, body: notif.body)
                dashboard.appendEventLog("📬 \(notif.app): \(notif.title) — \(notif.body)")
            } else if generic.type == "pong" {
                if let sentTime = self.lastPingSent {
                    let latencyMs = Date().timeIntervalSince(sentTime) * 1000
                    if latencyMs < 100 {
                        self.connectionQuality = "Strong"
                    } else if latencyMs < 500 {
                        self.connectionQuality = "Fair"
                    } else {
                        self.connectionQuality = "Weak"
                    }
                    print("[Mac App] Connection quality: \(self.connectionQuality) (\(Int(latencyMs))ms)")
                    self.updateStatusItem()
                    dashboard.updateConnection(connected: true, quality: "\(self.connectionQuality) (\(Int(latencyMs))ms)")
                }
            }
        } catch {
            print("[Mac App] Error decoding payload: \(error)")
        }
    }
    
    func showNotification(appName: String, title: String, body: String) {
        let titleStr = escapeForAppleScript("\(appName): \(title)")
        let bodyStr = escapeForAppleScript(body)
        let scriptSource = "display notification \(bodyStr) with title \(titleStr)"
        
        DispatchQueue.main.async {
            if let appleScript = NSAppleScript(source: scriptSource) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
                if let error = error {
                    print("[Mac App] AppleScript Notification error: \(error)")
                }
            }
        }
    }
    
    private func escapeForAppleScript(_ str: String) -> String {
        let escaped = str.replacingOccurrences(of: "\\", with: "\\\\")
                         .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}

// Simple Socket Client Wrapper using standard POSIX APIs for portability
class TCPClient {
    private var sockfd: Int32 = -1
    
    func connect(host: String, port: Int) -> Bool {
        sockfd = socket(AF_INET, SOCK_STREAM, 0)
        if sockfd < 0 {
            return false
        }
        
        var serverAddr = sockaddr_in()
        serverAddr.sin_family = sa_family_t(AF_INET)
        serverAddr.sin_port = UInt16(port).bigEndian
        
        if inet_pton(AF_INET, host, &serverAddr.sin_addr) <= 0 {
            close(sockfd)
            return false
        }
        
        let connectResult = withUnsafePointer(to: &serverAddr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(self.sockfd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        if connectResult < 0 {
            close(sockfd)
            return false
        }
        
        return true
    }
    
    func read() -> String? {
        var buffer = [UInt8](repeating: 0, count: 1024)
        let bytesRead = Darwin.recv(sockfd, &buffer, buffer.count - 1, 0)
        if bytesRead <= 0 {
            return nil
        }
        buffer[bytesRead] = 0
        return String(cString: buffer)
    }
    
    func write(_ string: String) {
        guard sockfd >= 0 else { return }
        let data = Array(string.utf8)
        _ = data.withUnsafeBufferPointer { ptr in
            Darwin.send(sockfd, ptr.baseAddress!, ptr.count, 0)
        }
    }
    
    deinit {
        if sockfd >= 0 {
            close(sockfd)
        }
    }
}

// Custom main to bootstrap NSApplication
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
