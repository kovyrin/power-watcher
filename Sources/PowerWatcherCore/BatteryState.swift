import Foundation

public struct BatteryReading: Equatable, Sendable {
    public let percent: Int
    public let isOnExternalPower: Bool

    public init?(currentCapacity: Int, maximumCapacity: Int, isOnExternalPower: Bool) {
        guard maximumCapacity > 0, currentCapacity >= 0 else { return nil }
        // Round down so fractional readings never delay a critical warning.
        percent = Int(min(100, floor(Double(currentCapacity) * 100 / Double(maximumCapacity))))
        self.isOnExternalPower = isOnExternalPower
    }
}

public enum BatteryStatus: Equatable, Sendable {
    case ready(BatteryReading)
    case noBattery
    case unavailable

    public var reading: BatteryReading? {
        guard case let .ready(reading) = self else { return nil }
        return reading
    }
}

public enum AlertLevel: Int, CaseIterable, Identifiable, Sendable {
    case gentle = 3
    case strong = 2
    case urgent = 1

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .gentle: "Gentle"
        case .strong: "Strong"
        case .urgent: "Urgent"
        }
    }

    public var style: GlowStyle {
        switch self {
        case .gentle:
            GlowStyle(width: 20, period: 3.2, minimumOpacity: 0.25, maximumOpacity: 0.80,
                      red: 1, green: 0.66, blue: 0.08)
        case .strong:
            GlowStyle(width: 36, period: 2.5, minimumOpacity: 0.45, maximumOpacity: 0.95,
                      red: 1, green: 0.34, blue: 0.05)
        case .urgent:
            GlowStyle(width: 56, period: 1.8, minimumOpacity: 0.70, maximumOpacity: 1,
                      red: 1, green: 0.12, blue: 0.16)
        }
    }
}

public struct GlowStyle: Equatable, Sendable {
    public let width: Double
    public let period: Double
    public let minimumOpacity: Float
    public let maximumOpacity: Float
    public let red: Double
    public let green: Double
    public let blue: Double
}

public enum AlertPolicy {
    public static func level(for status: BatteryStatus, monitoringEnabled: Bool = true) -> AlertLevel? {
        guard monitoringEnabled, let reading = status.reading, !reading.isOnExternalPower else {
            return nil
        }
        switch reading.percent {
        case 0...1: return .urgent
        case 2: return .strong
        case 3: return .gentle
        default: return nil
        }
    }

    // A demo must never tone down a real battery emergency.
    public static func visibleLevel(live: AlertLevel?, preview: AlertLevel?) -> AlertLevel? {
        switch (live, preview) {
        case let (live?, preview?): live.rawValue < preview.rawValue ? live : preview
        case let (live?, nil): live
        case let (nil, preview?): preview
        case (nil, nil): nil
        }
    }
}
