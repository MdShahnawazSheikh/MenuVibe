import SwiftUI

/// The Sensors tab: a couple of clean numeric readouts with a 60-second sparkline,
/// not a cluttered dashboard (spec §7). Sampling only runs while this tab is on
/// screen, so the feature is free when you're not looking at it.
struct SensorMonitorView: View {
    @ObservedObject var monitor: SensorMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.comfy) {
            readout(title: "CPU Load",
                    value: percent(monitor.cpuUsage),
                    fraction: monitor.cpuUsage,
                    history: monitor.cpuHistory.map(\.value))
            readout(title: "Memory Used",
                    value: percent(monitor.memoryUsedFraction),
                    fraction: monitor.memoryUsedFraction,
                    history: monitor.memoryHistory.map(\.value))

            if !monitor.thermalSensorsAvailable {
                thermalNote
            }
        }
        .padding(DS.Spacing.comfy)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { monitor.start() }
        .onDisappear { monitor.stop() }
    }

    private func readout(title: String, value: String, fraction: Double, history: [Double]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.snug) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(DS.Font.sectionHeader)
                    .foregroundStyle(DS.Color.secondaryLabel)
                Spacer()
                Text(value)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.Color.primaryLabel)
                    .monospacedDigit()
            }
            Sparkline(values: history)
                .stroke(DS.Color.accent, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
                .frame(height: 34)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.thumbnail, style: .continuous)
                        .fill(DS.Color.accent.opacity(0.06))
                )
        }
        .padding(DS.Spacing.comfy)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.panel, style: .continuous)
                .fill(DS.Color.primaryLabel.opacity(0.04))
        )
    }

    private var thermalNote: some View {
        HStack(spacing: DS.Spacing.snug) {
            Image(systemName: "thermometer.medium.slash")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DS.Color.tertiaryLabel)
            Text("Temperature & fan sensors aren't exposed on this Mac.")
                .font(DS.Font.caption)
                .foregroundStyle(DS.Color.tertiaryLabel)
        }
        .padding(.horizontal, DS.Spacing.tight)
    }

    private func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }
}

/// A tiny sparkline path normalised to its own bounds. No axes, no chrome — just the
/// trend line (spec §7).
struct Sparkline: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count > 1 else { return path }
        let maxValue = max(values.max() ?? 1, 0.01)
        let stepX = rect.width / CGFloat(values.count - 1)

        for (index, value) in values.enumerated() {
            let x = rect.minX + CGFloat(index) * stepX
            let y = rect.maxY - CGFloat(value / maxValue) * rect.height
            let point = CGPoint(x: x, y: y)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}
