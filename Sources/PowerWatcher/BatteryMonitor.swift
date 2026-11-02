import AppKit
import IOKit.ps
import PowerWatcherCore

@MainActor
final class BatteryMonitor {
    var onChange: ((BatteryStatus) -> Void)?
    private var source: CFRunLoopSource?
    private var fallbackTimer: Timer?

    func start() {
        guard source == nil, fallbackTimer == nil else { return }
        let context = Unmanaged.passUnretained(self).toOpaque()
        source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            // This source is installed exclusively on the main run loop.
            MainActor.assumeIsolated {
                Unmanaged<BatteryMonitor>.fromOpaque(context).takeUnretainedValue().refresh()
            }
        }, context)?.takeRetainedValue()
        if let source {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }
        // Also recover from missed notifications, including after sleep/wake.
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        fallbackTimer = timer
        refresh()
    }

    func stop() {
        if let source { CFRunLoopSourceInvalidate(source) }
        source = nil
        fallbackTimer?.invalidate()
        fallbackTimer = nil
    }

    func refresh() { onChange?(Self.read()) }

    static func read() -> BatteryStatus {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            return .unavailable
        }
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue()
                    as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  description[kIOPSIsPresentKey] as? Bool != false else { continue }
            guard let current = description[kIOPSCurrentCapacityKey] as? Int,
                  let maximum = description[kIOPSMaxCapacityKey] as? Int,
                  let powerState = description[kIOPSPowerSourceStateKey] as? String,
                  powerState == kIOPSACPowerValue || powerState == kIOPSBatteryPowerValue,
                  let reading = BatteryReading(currentCapacity: current, maximumCapacity: maximum,
                                               isOnExternalPower: powerState == kIOPSACPowerValue) else {
                return .unavailable
            }
            return .ready(reading)
        }
        return .noBattery
    }
}
