import Cocoa

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var statusMenu: NSMenu!
    private var taps: [Date] = []
    private var idleTimer: Timer?
    // (60/30) = 2; if your heart rate goes lower than 30, go to a doctor
    private let idleThreshold: TimeInterval = 2.0
    private var avgBPM: Int?

    private let ageKey = "UserAge"
    private let defaultAge = 30

    private var userAge: Int {
        let saved = UserDefaults.standard.integer(forKey: ageKey)
        return saved > 0 ? saved : defaultAge
    }

    private var maxHeartRate: Int {
        return 220 - userAge
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )

        setupMenu()

        if let btn = statusItem.button {
            btn.title = "HR"
            btn.target = self
            btn.action = #selector(handleClick(_:))
            btn.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private func setupMenu() {
        let menu = NSMenu()

        // Age menu
        let ageMenu = NSMenuItem(
            title: "Age: \(userAge)",
            action: nil,
            keyEquivalent: ""
        )
        let ageSubmenu = NSMenu()

        // Add common ages
        for age in stride(from: 20, through: 70, by: 5) {
            let ageItem = NSMenuItem(
                title: "\(age)",
                action: #selector(setAge(_:)),
                keyEquivalent: ""
            )
            ageItem.target = self
            ageItem.tag = age
            if age == userAge {
                ageItem.state = .on
            }
            ageSubmenu.addItem(ageItem)
        }

        // Add separator and custom age input option
        ageSubmenu.addItem(NSMenuItem.separator())
        let customAgeItem = NSMenuItem(
            title: "Enter Custom Age...",
            action: #selector(promptForCustomAge(_:)),
            keyEquivalent: ""
        )
        customAgeItem.target = self
        ageSubmenu.addItem(customAgeItem)

        ageMenu.submenu = ageSubmenu
        menu.addItem(ageMenu)

        // Add separator and quit
        menu.addItem(NSMenuItem.separator())
        let quitMenuItem = NSMenuItem(
            title: "Quit",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitMenuItem.target = self
        menu.addItem(quitMenuItem)

        statusMenu = menu
    }

    @objc func setAge(_ sender: NSMenuItem) {
        let age = sender.tag
        UserDefaults.standard.set(age, forKey: ageKey)
        // Update the menu to reflect the new age and checkmarks
        setupMenu()
    }

    @objc func promptForCustomAge(_ sender: NSMenuItem) {
        let alert = NSAlert()
        alert.messageText = "Enter Your Age"
        alert.informativeText =
            "Please enter your current age (1-129) to calculate max heart rate accurately."
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let inputTextField = NSTextField(
            frame: NSRect(x: 0, y: 0, width: 200, height: 24)
        )
        inputTextField.placeholderString = "e.g., 35"
        inputTextField.integerValue = userAge  // Pre-fill with current age
        // For more robust input, you could assign a NumberFormatter
        // inputTextField.formatter = NumberFormatter()...

        alert.accessoryView = inputTextField
        // Ensure the text field is focused when the alert appears
        // This needs to be done after the accessory view is set and the window is available.
        // A common way is to set it on the window before running the modal.
        // NSAlert creates its window lazily. We can try to set it here.
        // If it doesn't work reliably, it might need to be set after alert.layout()
        // or by observing window creation. For most cases, this works:
        alert.window.initialFirstResponder = inputTextField

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {  // OK button
            let ageString = inputTextField.stringValue
            if let newAge = Int(ageString), newAge > 0 && newAge < 130 {  // Basic validation
                UserDefaults.standard.set(newAge, forKey: ageKey)
                setupMenu()  // Rebuild menu to reflect new age and checkmarks
            } else {
                // Optional: Show an error for invalid input
                let errorAlert = NSAlert()
                errorAlert.messageText = "Invalid Age"
                errorAlert.informativeText =
                    "Please enter a valid number for age (e.g., 1-129)."
                errorAlert.addButton(withTitle: "OK")
                errorAlert.runModal()
            }
        }
    }

    @objc func handleClick(_ sender: Any?) {
        if let event = NSApp.currentEvent {
            if event.type == .rightMouseUp {
                // Show menu on right click
                statusItem.menu = statusMenu
                statusItem.button?.performClick(nil)
                statusItem.menu = nil
            } else {
                // Handle left click with the original tap behavior
                didTap()
            }
        }
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }

    func didTap() {
        let now = Date()
        taps.append(now)

        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(
            timeInterval: idleThreshold,
            target: self,
            selector: #selector(endMeasurement),
            userInfo: nil,
            repeats: false
        )

        guard taps.count >= 2 else {
            // I believe there should be some sort of indication that the user has pressed once,
            // not sure what that should be
            setStatusText("HR", color: nil)
            return
        }

        let intervals = zip(taps.dropFirst(), taps)
            .map { $0.timeIntervalSince($1) }
        let avg = intervals.reduce(0, +) / Double(intervals.count)
        avgBPM = Int(round(60.0 / avg))

        if let bpm = avgBPM {
            setStatusText("\(bpm)", color: colorForHeartRate(bpm))
        } else {
            setStatusText("HR", color: nil)
        }
    }

    private func colorForHeartRate(_ bpm: Int) -> NSColor {
        let percentage = Double(bpm) / Double(maxHeartRate)

        switch percentage {
        case 0..<0.65: return NSColor.systemGreen
        case 0.65..<0.85: return NSColor.systemYellow
        case 0.85...: return NSColor.systemRed
        default: return NSColor.labelColor
        }
    }

    private func setStatusText(_ text: String, color: NSColor?) {
        guard let button = statusItem.button else { return }

        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: color ?? NSColor.labelColor,
            .font: NSFont.menuBarFont(ofSize: 0),
        ]

        let attributedTitle = NSAttributedString(
            string: text,
            attributes: attributes
        )
        button.attributedTitle = attributedTitle
    }

    // TODO: Save that average somewhere?
    @objc func endMeasurement() {
        idleTimer?.invalidate()
        taps.removeAll()

        guard let bpm = avgBPM else {
            setStatusText("HR", color: nil)
            return
        }

        let flashes = 4
        let flashInterval = 0.25
        let hrColor = colorForHeartRate(bpm)

        func flash(_ count: Int) {
            if count >= flashes {
                setStatusText("HR", color: nil)
                avgBPM = nil
                return
            }

            if count % 2 == 0 {
                setStatusText("\(bpm)", color: hrColor)
            } else {
                setStatusText(" ", color: nil)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + flashInterval) {
                flash(count + 1)
            }
        }

        flash(0)
    }
}
