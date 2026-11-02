import Testing
@testable import PowerWatcherCore

private func status(_ percent: Int, powered: Bool = false) -> BatteryStatus {
    .ready(BatteryReading(currentCapacity: percent, maximumCapacity: 100, isOnExternalPower: powered)!)
}

@Test(arguments: [4, 5, 20, 50, 100])
func staysQuietAboveThreshold(percent: Int) {
    #expect(AlertPolicy.level(for: status(percent)) == nil)
}

@Test func exactThresholdsAndZero() {
    #expect(AlertPolicy.level(for: status(3)) == .gentle)
    #expect(AlertPolicy.level(for: status(2)) == .strong)
    #expect(AlertPolicy.level(for: status(1)) == .urgent)
    #expect(AlertPolicy.level(for: status(0)) == .urgent)
}

@Test(arguments: [0, 1, 2, 3, 100])
func externalPowerAlwaysClearsWarning(percent: Int) {
    #expect(AlertPolicy.level(for: status(percent, powered: true)) == nil)
}

@Test func disabledAndUnavailableStatesAreQuiet() {
    #expect(AlertPolicy.level(for: status(1), monitoringEnabled: false) == nil)
    #expect(AlertPolicy.level(for: .noBattery) == nil)
    #expect(AlertPolicy.level(for: .unavailable) == nil)
}

@Test func normalizesRawCapacityAndRejectsInvalidReadings() {
    let raw = BatteryReading(currentCapacity: 170, maximumCapacity: 5000, isOnExternalPower: false)
    #expect(raw?.percent == 3)
    #expect(AlertPolicy.level(for: .ready(raw!)) == .gentle)
    #expect(BatteryReading(currentCapacity: 5, maximumCapacity: 0, isOnExternalPower: false) == nil)
    #expect(BatteryReading(currentCapacity: -1, maximumCapacity: 100, isOnExternalPower: false) == nil)
    #expect(BatteryReading(currentCapacity: 5, maximumCapacity: -100, isOnExternalPower: false) == nil)
    #expect(BatteryReading(currentCapacity: 101, maximumCapacity: 100, isOnExternalPower: false)?.percent == 100)
}

@Test(arguments: Array(0...100))
func wholePercentagesDoNotLosePrecision(percent: Int) {
    #expect(BatteryReading(currentCapacity: percent, maximumCapacity: 100, isOnExternalPower: false)?.percent == percent)
}

@Test func intensityEscalatesWithoutFastFlashing() {
    let styles = AlertLevel.allCases.map(\.style)
    #expect(styles[0].width == 20)
    #expect(styles[0].width < styles[1].width && styles[1].width < styles[2].width)
    #expect(styles[0].minimumOpacity < styles[1].minimumOpacity && styles[1].minimumOpacity < styles[2].minimumOpacity)
    #expect(styles[0].maximumOpacity < styles[1].maximumOpacity && styles[1].maximumOpacity < styles[2].maximumOpacity)
    #expect(styles[0].period > styles[1].period && styles[1].period > styles[2].period)
    #expect(styles.allSatisfy { $0.period >= 1.8 && $0.minimumOpacity > 0 })
    #expect(styles[2].maximumOpacity == 1)
}

@Test func previewCannotDowngradeRealWarning() {
    for live in AlertLevel.allCases {
        for preview in AlertLevel.allCases {
            let visible = AlertPolicy.visibleLevel(live: live, preview: preview)
            #expect(visible?.rawValue == min(live.rawValue, preview.rawValue))
        }
        #expect(AlertPolicy.visibleLevel(live: live, preview: nil) == live)
        #expect(AlertPolicy.visibleLevel(live: nil, preview: live) == live)
    }
    #expect(AlertPolicy.visibleLevel(live: nil, preview: nil) == nil)
}
