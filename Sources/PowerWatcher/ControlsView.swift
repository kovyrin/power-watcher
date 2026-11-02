import AppKit
import PowerWatcherCore
import ServiceManagement
import SwiftUI

extension AlertLevel {
    var color: Color {
        Color(red: style.red, green: style.green, blue: style.blue)
    }
}

struct ControlsView: View {
    @Bindable var model: AppModel
    @FocusState private var focusedPreview: AlertLevel?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            status
            previewSection
            settings
            footer
        }
        .padding(24)
        .frame(width: 400)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { model.refreshLoginStatus() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                ForEach(0..<3) { index in
                    RoundedRectangle(cornerRadius: CGFloat(5 - index))
                        .strokeBorder(.white.opacity([1.0, 0.55, 0.25][index]), lineWidth: 1.5)
                        .padding(CGFloat(index) * 3)
                }
            }
                .frame(width: 25, height: 25)
                .frame(width: 48, height: 48)
                .background(.linearGradient(colors: [.orange, Color(red: 0.95, green: 0.27, blue: 0.12)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 13))
            Text("Power Watcher").font(.system(size: 21, weight: .bold, design: .rounded))
            Spacer(minLength: 0)
        }
    }

    private var status: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(statusColor.opacity(0.12)).frame(width: 38, height: 38)
                Image(systemName: statusIcon).foregroundStyle(statusColor).font(.system(size: 17))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(model.statusTitle).font(.system(size: 13, weight: .semibold))
                Text(model.statusDetail).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                ForEach(AlertLevel.allCases) { level in
                    previewCard(level)
                }
            }
            if let level = model.previewLevel {
                HStack {
                    Label("Previewing \(level.rawValue)%", systemImage: "play.circle.fill")
                        .foregroundStyle(level.color)
                    Spacer()
                    Button("Stop preview") { model.stopPreview() }
                        .buttonStyle(.bordered).controlSize(.small)
                        .accessibilityIdentifier("stopPreview")
                }
                .font(.system(size: 12, weight: .medium))
                .frame(height: 28)
            } else {
                Button { model.previewSequence() } label: {
                    HStack {
                        Image(systemName: "play.fill").font(.system(size: 10))
                        Text("Try 3% → 2% → 1%")
                        Spacer()
                        Text("9 sec").foregroundStyle(.secondary)
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10).frame(height: 28)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("previewSequence")
            }
        }
    }

    private func previewCard(_ level: AlertLevel) -> some View {
        Button { model.preview(level) } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .textBackgroundColor))
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(level.color.opacity(0.25), lineWidth: miniWidth(level) * 2)
                        .blur(radius: 3)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(level.color.opacity(0.95), lineWidth: miniWidth(level))
                    Text("\(level.rawValue)%")
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                .frame(height: 52)
                Text(level.title).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            }
            .padding(9)
            .frame(maxWidth: .infinity)
            .background(.primary.opacity(model.previewLevel == level ? 0.07 : 0.025),
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(model.previewLevel == level ? level.color.opacity(0.7)
                                  : .primary.opacity(focusedPreview == level ? 0.22 : 0.06))
            }
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .focused($focusedPreview, equals: level)
        .focusEffectDisabled()
        .accessibilityLabel("Preview \(level.rawValue) percent, \(level.title.lowercased()) glow for six seconds")
        .accessibilityIdentifier("preview\(level.rawValue)")
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            Toggle(isOn: $model.monitoringEnabled) {
                Text("Watch my battery").font(.system(size: 12, weight: .medium))
            }
            .toggleStyle(.switch).controlSize(.small)
            .accessibilityIdentifier("monitoringEnabled")

            Toggle("Open at login", isOn: Binding(get: { model.launchAtLogin },
                                                set: { model.setLaunchAtLogin($0) }))
                .accessibilityIdentifier("launchAtLogin")
            Toggle("Use a steady glow", isOn: $model.steadyGlow)
                .accessibilityIdentifier("steadyGlow")

            if model.systemReduceMotion {
                Text("Reduce Motion is on")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
            if model.loginStatus == .requiresApproval {
                Button("Allow Power Watcher in Login Items…") { SMAppService.openSystemSettingsLoginItems() }
                    .font(.system(size: 11))
            }
            if let error = model.loginError {
                Text("Login item: \(error)").font(.system(size: 10)).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(.system(size: 12))
        .toggleStyle(.checkbox)
    }

    private var footer: some View {
        HStack(alignment: .center) {
            Link("Privacy", destination: URL(string: "https://github.com/kovyrin/power-watcher/blob/main/PRIVACY.md")!)
                .font(.system(size: 11)).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .font(.system(size: 11)).buttonStyle(.plain).foregroundStyle(.secondary)
                .accessibilityIdentifier("quit")
        }
    }

    private func miniWidth(_ level: AlertLevel) -> CGFloat {
        switch level {
        case .gentle: 1.5
        case .strong: 2.5
        case .urgent: 4
        }
    }

    private var statusColor: Color {
        if !model.monitoringEnabled { return .secondary }
        if let level = model.liveLevel { return level.color }
        if model.battery.reading != nil { return .green }
        return .orange
    }

    private var statusIcon: String {
        if !model.monitoringEnabled { return "pause.fill" }
        if model.liveLevel != nil { return "exclamationmark.bolt.fill" }
        if model.battery.reading?.isOnExternalPower == true { return "powerplug.fill" }
        return model.battery.reading == nil ? "questionmark" : "checkmark.shield.fill"
    }
}
