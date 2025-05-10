import Cocoa

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var taps: [Date] = []
    private var idleTimer: Timer?
    // (60/30) = 2; if your heart rate goes lower than 30, go to a doctor
    private let idleThreshold: TimeInterval = 2.0
    private var avgBPM: Int?
    private var statusMenu: NSMenu!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )

        // Create the menu
        let menu = NSMenu()
        let quitMenuItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitMenuItem.target = self
        menu.addItem(quitMenuItem)

        if let btn = statusItem.button {
            btn.title = "HR"
            btn.target = self
            btn.action = #selector(handleClick(_:))
            btn.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        statusMenu = menu
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
            statusItem.button?.title = "HR"
            return
        }

        let intervals = zip(taps.dropFirst(), taps)
            .map { $0.timeIntervalSince($1) }
        let avg = intervals.reduce(0, +) / Double(intervals.count)
        avgBPM = Int(round(60.0 / avg))
        if let bpm = avgBPM {
            statusItem.button?.title = "\(bpm)"
        } else {
            statusItem.button?.title = "HR"
        }
    }

    // TODO: Save that average somewhere?
    @objc func endMeasurement() {
        idleTimer?.invalidate()
        taps.removeAll()

        guard let bpm = avgBPM else {
            statusItem.button?.title = "HR"
            return
        }

        let flashes = 4
        let flashInterval = 0.25

        func flash(_ count: Int) {
            if count >= flashes {
                statusItem.button?.title = "HR"
                avgBPM = nil
                return
            }
            statusItem.button?.title = (count % 2 == 0) ? "\(bpm)" : " "
            DispatchQueue.main.asyncAfter(deadline: .now() + flashInterval) {
                flash(count + 1)
            }
        }

        flash(0)
    }
}
