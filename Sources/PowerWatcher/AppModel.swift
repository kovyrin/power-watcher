import AppKit
import Observation
import PowerWatcherCore
import ServiceManagement

@MainActor
@Observable
final class AppModel {
    private(set) var battery: BatteryStatus = .unavailable
    private(set) var previewLevel: AlertLevel?
    private(set) var loginStatus = SMAppService.mainApp.status
    private(set) var loginError: String?
    private(set) var systemReduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

    var monitoringEnabled: Bool {
        didSet {
            defaults.set(monitoringEnabled, forKey: "monitoringEnabled")
            if !monitoringEnabled { stopPreview() }
            onChange?()
        }
    }

    var steadyGlow: Bool {
        didSet {
            defaults.set(steadyGlow, forKey: "steadyGlow")
            onChange?()
        }
    }

    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private var previewTask: Task<Void, Never>?
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        monitoringEnabled = defaults.object(forKey: "monitoringEnabled") as? Bool ?? true
        steadyGlow = defaults.bool(forKey: "steadyGlow")
    }

    var liveLevel: AlertLevel? { AlertPolicy.level(for: battery, monitoringEnabled: monitoringEnabled) }
    var visibleLevel: AlertLevel? { AlertPolicy.visibleLevel(live: liveLevel, preview: previewLevel) }
    var usesSteadyGlow: Bool { steadyGlow || systemReduceMotion }
    var launchAtLogin: Bool { loginStatus == .enabled || loginStatus == .requiresApproval }

    var statusTitle: String {
        if !monitoringEnabled { return "Monitoring paused" }
        switch battery {
        case .noBattery: return "No internal battery"
        case .unavailable: return "Battery reading unavailable"
        case let .ready(reading):
            if reading.isOnExternalPower { return "Connected to power" }
            return liveLevel == nil ? "Watching your battery" : "Time to plug in"
        }
    }

    var statusDetail: String {
        switch battery {
        case .noBattery: "Previews still work on this Mac."
        case .unavailable: "Will retry automatically."
        case let .ready(reading):
            "\(reading.percent)% remaining · \(reading.isOnExternalPower ? "external power" : "on battery")"
        }
    }

    func receive(_ status: BatteryStatus) {
        let justConnected = battery.reading?.isOnExternalPower == false
            && status.reading?.isOnExternalPower == true
        battery = status
        if justConnected { stopPreview() }
        onChange?()
    }

    func refreshAccessibility() {
        systemReduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        onChange?()
    }

    func refreshLoginStatus() { loginStatus = SMAppService.mainApp.status }

    func setLaunchAtLogin(_ enabled: Bool) {
        loginError = nil
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            loginError = error.localizedDescription
        }
        refreshLoginStatus()
    }

    func preview(_ level: AlertLevel) { runPreview(levels: [level], secondsPerLevel: 6) }
    func previewSequence() { runPreview(levels: AlertLevel.allCases, secondsPerLevel: 3) }

    private func runPreview(levels: [AlertLevel], secondsPerLevel: Int) {
        previewTask?.cancel()
        guard let first = levels.first else { return }
        previewLevel = first
        onChange?()
        previewTask = Task { [weak self] in
            for (index, level) in levels.enumerated() {
                guard !Task.isCancelled else { return }
                if index > 0 {
                    self?.previewLevel = level
                    self?.onChange?()
                }
                do { try await Task.sleep(for: .seconds(secondsPerLevel)) }
                catch { return }
            }
            self?.previewLevel = nil
            self?.previewTask = nil
            self?.onChange?()
        }
    }

    func stopPreview() {
        previewTask?.cancel()
        previewTask = nil
        previewLevel = nil
        onChange?()
    }
}
