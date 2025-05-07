import Cocoa

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var taps: [Date] = []
    private var idleTimer: Timer?
    private let idleThreshold: TimeInterval = 5.0

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )
        if let btn = statusItem.button {
            btn.title = "HR"
            btn.target = self
            btn.action = #selector(didTap(_:))
        }
    }

    @objc func didTap(_ sender: Any?) {
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

        guard taps.count >= 2 else { return }

        let intervals = zip(taps.dropFirst(), taps)
            .map { $0.timeIntervalSince($1) }
        let avg = intervals.reduce(0, +) / Double(intervals.count)
        let bpm = Int(round(60.0 / avg))

        statusItem.button?.title = "\(bpm)"
    }

    @objc func endMeasurement() {
        taps.removeAll()
    }
}
