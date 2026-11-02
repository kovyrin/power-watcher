import AppKit
import QuartzCore
import PowerWatcherCore

@MainActor
final class EdgePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .fullScreenAuxiliary,
                              .stationary, .ignoresCycle]
        isExcludedFromWindowsMenu = true
        animationBehavior = .none
        contentView = EdgeGlowView(frame: NSRect(origin: .zero, size: screen.frame.size))
        setFrame(screen.frame, display: false)
    }

    func show(level: AlertLevel, steady: Bool) {
        (contentView as? EdgeGlowView)?.configure(style: level.style, steady: steady)
        orderFrontRegardless()
    }
}

@MainActor
final class EdgeGlowView: NSView {
    private let glowLayer = CALayer()
    private var style: GlowStyle?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.addSublayer(glowLayer)
    }

    required init?(coder: NSCoder) { nil }

    func configure(style: GlowStyle, steady: Bool) {
        self.style = style
        rebuildGradient()
        glowLayer.removeAnimation(forKey: "breathing")
        glowLayer.opacity = style.maximumOpacity
        guard !steady else { return }
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = style.maximumOpacity
        pulse.toValue = style.minimumOpacity
        pulse.duration = style.period / 2
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        glowLayer.add(pulse, forKey: "breathing")
    }

    override func layout() {
        super.layout()
        rebuildGradient()
    }

    private func rebuildGradient() {
        guard let style else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        glowLayer.frame = bounds
        glowLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        let width = min(CGFloat(style.width), min(bounds.width, bounds.height) / 2)
        let color = NSColor(srgbRed: style.red, green: style.green, blue: style.blue, alpha: 1)
        let edges: [(CGRect, CGPoint, CGPoint)] = [
            (CGRect(x: 0, y: 0, width: bounds.width, height: width),
             CGPoint(x: 0.5, y: 0), CGPoint(x: 0.5, y: 1)),
            (CGRect(x: 0, y: bounds.height - width, width: bounds.width, height: width),
             CGPoint(x: 0.5, y: 1), CGPoint(x: 0.5, y: 0)),
            (CGRect(x: 0, y: 0, width: width, height: bounds.height),
             CGPoint(x: 0, y: 0.5), CGPoint(x: 1, y: 0.5)),
            (CGRect(x: bounds.width - width, y: 0, width: width, height: bounds.height),
             CGPoint(x: 1, y: 0.5), CGPoint(x: 0, y: 0.5))
        ]
        for (frame, start, end) in edges {
            let gradient = CAGradientLayer()
            gradient.frame = frame
            gradient.colors = [color.cgColor, color.withAlphaComponent(0).cgColor]
            gradient.startPoint = start
            gradient.endPoint = end
            glowLayer.addSublayer(gradient)
        }
        CATransaction.commit()
    }
}

@MainActor
final class OverlayController {
    private(set) var panels: [EdgePanel] = []
    private var currentLevel: AlertLevel?
    private var steady = false

    func update(level: AlertLevel?, steady: Bool, rebuild: Bool = false) {
        guard rebuild || currentLevel != level || self.steady != steady else { return }
        currentLevel = level
        self.steady = steady
        guard let level else {
            panels.forEach { $0.close() }
            panels.removeAll()
            return
        }
        if rebuild || panels.isEmpty {
            panels.forEach { $0.close() }
            panels = NSScreen.screens.map { EdgePanel(screen: $0) }
        }
        panels.forEach { $0.show(level: level, steady: steady) }
    }

    func hide() { update(level: nil, steady: steady) }
}
