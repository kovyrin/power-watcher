import AppKit
import PowerWatcherCore
import SwiftUI

// An opt-in integration check. It uses isolated preferences and never changes
// login items, battery data, or the user's monitoring preferences.
@MainActor
enum SelfCheck {
    static func run() async -> Int32 {
        var failures: [String] = []
        func check(_ condition: Bool, _ message: String) {
            if !condition { failures.append(message) }
            print("\(condition ? "PASS" : "FAIL") \(message)")
        }

        let suite = "PowerWatcher.SelfCheck.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else { return 1 }
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = AppModel(defaults: defaults)
        let critical = BatteryReading(currentCapacity: 1, maximumCapacity: 100, isOnExternalPower: false)!
        let powered = BatteryReading(currentCapacity: 1, maximumCapacity: 100, isOnExternalPower: true)!
        model.receive(.ready(critical))
        model.preview(.gentle)
        check(model.visibleLevel == .urgent, "Preview never weakens a real critical warning")
        model.stopPreview()
        check(model.visibleLevel == .urgent, "Stopping a preview restores the live warning")
        model.receive(.ready(powered))
        check(model.visibleLevel == nil, "External power clears the live warning")
        model.preview(.urgent)
        model.receive(.ready(critical))
        model.receive(.ready(powered))
        check(model.previewLevel == nil && model.visibleLevel == nil, "Connecting power cancels an active preview")
        model.preview(.strong)
        model.monitoringEnabled = false
        check(model.visibleLevel == nil, "Pausing stops both monitoring and an active preview")
        model.monitoringEnabled = true
        model.preview(.gentle)
        let previewExpired = await waitUntil(timeout: .seconds(9)) { model.previewLevel == nil }
        check(previewExpired && model.visibleLevel == nil, "Preview expires automatically after six seconds")
        model.previewSequence()
        let sequenceProgressed = await waitUntil(timeout: .seconds(5)) { model.previewLevel == .strong }
        check(sequenceProgressed, "Sequence progresses from 3% to 2%")
        model.stopPreview()
        try? await Task.sleep(for: .milliseconds(100))
        check(model.previewLevel == nil, "Cancelled sequence stays stopped")

        if let screen = NSScreen.screens.first {
            let panel = EdgePanel(screen: screen)
            check(panel.ignoresMouseEvents, "Overlay passes through mouse events")
            check(!panel.canBecomeKey && !panel.canBecomeMain, "Overlay cannot take keyboard focus")
            check(!panel.isOpaque && panel.backgroundColor.alphaComponent == 0, "Overlay window is transparent")
            check(panel.collectionBehavior.contains(.canJoinAllApplications)
                  && panel.collectionBehavior.contains(.canJoinAllSpaces), "Overlay joins Spaces and full-screen applications")
            check(panel.frame == screen.frame, "Overlay covers the complete display, including menu bar edges")
            panel.close()
        } else {
            check(false, "At least one display is available")
        }

        let outputDirectory: URL
        if let flag = CommandLine.arguments.firstIndex(of: "--artifacts"),
           CommandLine.arguments.indices.contains(flag + 1) {
            outputDirectory = URL(fileURLWithPath: CommandLine.arguments[flag + 1], isDirectory: true)
        } else {
            outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent(".build/self-check", isDirectory: true)
        }

        do {
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
            for level in AlertLevel.allCases {
                let view = EdgeGlowView(frame: NSRect(x: 0, y: 0, width: 960, height: 600))
                view.configure(style: level.style, steady: true)
                view.layoutSubtreeIfNeeded()
                guard let bitmap = renderLayer(view, size: view.bounds.size) else {
                    check(false, "Render \(level.rawValue)% overlay")
                    continue
                }
                let width = Int(level.style.width)
                check((bitmap.colorAt(x: 480, y: 300)?.alphaComponent ?? 1) == 0,
                      "\(level.rawValue)% glow leaves the center completely transparent")
                check((bitmap.colorAt(x: width + 1, y: 300)?.alphaComponent ?? 1) == 0,
                      "\(level.rawValue)% glow ends at \(width) points")
                check((bitmap.colorAt(x: 1, y: 300)?.alphaComponent ?? 0) > 0.5,
                      "\(level.rawValue)% glow is visible at the edge")
                let middleAlpha = bitmap.colorAt(x: width / 2, y: 300)?.alphaComponent ?? 1
                check(middleAlpha > 0.2 && middleAlpha < 0.7,
                      "\(level.rawValue)% glow fades smoothly halfway inward")
                try writePNG(bitmap, to: outputDirectory.appendingPathComponent("glow-\(level.rawValue).png"))
            }
            // Documentation screenshots always use simulated, non-personal data.
            model.receive(.ready(BatteryReading(currentCapacity: 42, maximumCapacity: 100,
                                               isOnExternalPower: false)!))
            let host = NSHostingView(rootView: ControlsView(model: model).environment(\.colorScheme, .light))
            let size = host.fittingSize
            host.frame = NSRect(origin: .zero, size: size)
            let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.contentView = host
            host.layoutSubtreeIfNeeded()
            if let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
                host.cacheDisplay(in: host.bounds, to: bitmap)
                try writePNG(bitmap, to: outputDirectory.appendingPathComponent("controls.png"))
                check(bitmap.pixelsWide > 0 && bitmap.pixelsHigh > 0, "Render menu-bar controls")
            } else { check(false, "Render menu-bar controls") }
            window.close()
        } catch {
            check(false, "Save visual artifacts: \(error.localizedDescription)")
        }
        let liveBattery = BatteryMonitor.read()
        if CommandLine.arguments.contains("--require-battery") {
            check(liveBattery.reading != nil, "Read the internal battery via IOKit")
        }
        print("Live battery: \(liveBattery)")
        print("Artifacts: \(outputDirectory.path)")
        print("\(failures.isEmpty ? "All integration checks passed." : "\(failures.count) integration checks failed.")")
        return failures.isEmpty ? 0 : 1
    }

    private static func waitUntil(timeout: Duration, condition: () -> Bool) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !condition() {
            guard clock.now < deadline else { return false }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return true
    }

    private static func renderLayer(_ view: NSView, size: CGSize) -> NSBitmapImageRep? {
        guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height),
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let layer = view.layer else { return nil }
        layer.render(in: context)
        guard let image = context.makeImage() else { return nil }
        return NSBitmapImageRep(cgImage: image)
    }

    private static func writePNG(_ bitmap: NSBitmapImageRep, to url: URL) throws {
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: url)
    }
}
