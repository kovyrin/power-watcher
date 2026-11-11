import AppKit
import SwiftUI

@main
@MainActor
enum PowerWatcherApp {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        if CommandLine.arguments.contains("--self-check") {
            Task {
                let result = await SelfCheck.run()
                exit(result)
            }
            app.run()
            return
        }
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private let monitor = BatteryMonitor()
    private let overlay = OverlayController()
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var isSleeping = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Reopening a second copy should show the running app, not duplicate its overlays.
        if let bundleID = Bundle.main.bundleIdentifier,
           let other = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            other.activate(options: [])
            NSApp.terminate(nil)
            return
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem = item
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "bolt.shield", accessibilityDescription: "Power Watcher")
            button.target = self
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: ControlsView(model: model))

        model.onChange = { [weak self] in self?.render() }
        monitor.onChange = { [weak model] status in model?.receive(status) }
        monitor.start()

        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(willSleep), name: NSWorkspace.willSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
        workspace.addObserver(self, selector: #selector(accessibilityChanged),
                              name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)

        if !UserDefaults.standard.bool(forKey: "hasLaunched") {
            UserDefaults.standard.set(true, forKey: "hasLaunched")
            showPopover()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPopover()
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) { model.refreshLoginStatus() }

    func applicationWillTerminate(_ notification: Notification) {
        model.onChange = nil
        model.stopPreview()
        monitor.stop()
        overlay.hide()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    private func render(rebuild: Bool = false) {
        overlay.update(level: isSleeping ? nil : model.visibleLevel, steady: model.usesSteadyGlow, rebuild: rebuild)
        statusItem?.button?.toolTip = "Power Watcher — \(model.statusTitle). \(model.statusDetail)"
        statusItem?.button?.appearsDisabled = !model.monitoringEnabled
    }

    @objc private func togglePopover() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(withTitle: "Open Power Watcher", action: #selector(openControls), keyEquivalent: "")
                .target = self
            menu.addItem(.separator())
            menu.addItem(withTitle: "Quit Power Watcher", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            statusItem?.menu = menu
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil
        } else if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    @objc private func openControls() { showPopover() }

    private func showPopover() {
        guard let button = statusItem?.button,
              let contentView = popover.contentViewController?.view else { return }
        model.refreshLoginStatus()
        NSApp.activate(ignoringOtherApps: true)
        // Use the SwiftUI layout size before AppKit positions the popover.
        popover.contentSize = contentView.fittingSize
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        contentView.window?.makeKey()
    }

    @objc private func screensChanged() { render(rebuild: true) }
    @objc private func accessibilityChanged() { model.refreshAccessibility() }
    @objc private func willSleep() {
        isSleeping = true
        model.stopPreview()
        overlay.hide()
    }
    @objc private func didWake() {
        isSleeping = false
        monitor.refresh()
        render(rebuild: true)
    }
}
