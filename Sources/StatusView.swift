import SwiftUI
import AppKit
import ServiceManagement

struct StatusView: View {
    var monitor: SystemMonitor
    var usageMonitor: UsageMonitor

    @State private var launchAtLogin: Bool = false

    private var cpuProgressTint: Color {
        if monitor.cpuUsage >= 85 {
            return Color(.systemRed)
        } else if monitor.cpuUsage >= 60 {
            return Color(.systemYellow)
        } else {
            return Color(.systemGreen)
        }
    }

    private var diskProgressTint: Color {
        guard monitor.diskTotal > 0 else { return Color(.systemGreen) }
        let ratio = Double(monitor.diskUsed) / Double(monitor.diskTotal) * 100.0
        if ratio >= 85 {
            return Color(.systemRed)
        } else if ratio >= 60 {
            return Color(.systemYellow)
        } else {
            return Color(.systemGreen)
        }
    }

    private func usageTint(_ pct: Double) -> Color {
        if pct >= 85 { return Color(.systemRed) }
        if pct >= 60 { return Color(.systemYellow) }
        return Color(.systemGreen)
    }

    private var memoryRatio: Double {
        guard monitor.memoryTotal > 0 else { return 0 }
        return Double(monitor.memoryUsed) / Double(monitor.memoryTotal)
    }

    private var diskRatio: Double {
        guard monitor.diskTotal > 0 else { return 0 }
        return Double(monitor.diskUsed) / Double(monitor.diskTotal)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("System Monitor")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Color(.secondaryLabelColor))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider()
                .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 8) {
                // CPU row
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "cpu")
                                .foregroundStyle(Color(.labelColor))
                            Text("CPU")
                                .foregroundStyle(Color(.labelColor))
                        }
                        Spacer()
                        Text(String(format: "%.0f%%", monitor.cpuUsage))
                            .font(.system(size: 12).monospacedDigit())
                            .foregroundStyle(Color(.labelColor))
                    }
                    ProgressView(value: monitor.cpuUsage / 100.0)
                        .progressViewStyle(.linear)
                        .tint(cpuProgressTint)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                // Memory row
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "memorychip")
                                .foregroundStyle(Color(.labelColor))
                            Text("Memory")
                                .foregroundStyle(Color(.labelColor))
                        }
                        Spacer()
                        Text("\(monitor.formatBytes(monitor.memoryUsed)) / \(monitor.formatBytes(monitor.memoryTotal))")
                            .font(.system(size: 12).monospacedDigit())
                            .foregroundStyle(Color(.labelColor))
                    }
                    ProgressView(value: memoryRatio)
                        .progressViewStyle(.linear)
                        .tint(Color(.systemBlue))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                // Disk row
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "internaldrive")
                                .foregroundStyle(Color(.labelColor))
                            Text("Disk")
                                .foregroundStyle(Color(.labelColor))
                        }
                        Spacer()
                        Text("\(monitor.formatBytes(monitor.diskUsed)) / \(monitor.formatBytes(monitor.diskTotal))")
                            .font(.system(size: 12).monospacedDigit())
                            .foregroundStyle(Color(.labelColor))
                    }
                    ProgressView(value: diskRatio)
                        .progressViewStyle(.linear)
                        .tint(diskProgressTint)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                // Network row
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "network")
                            .foregroundStyle(Color(.labelColor))
                        Text("Network")
                            .foregroundStyle(Color(.labelColor))
                    }
                    Spacer()
                    Text("↓\(monitor.formatSpeed(monitor.networkIn))  ↑\(monitor.formatSpeed(monitor.networkOut))")
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(Color(.labelColor))
                }
            }
            .padding(.horizontal, 12)

            Divider()
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 8) {
                // Claude Code header row
                HStack(spacing: 4) {
                    if let url = Bundle.module.url(forResource: "claude-icon", withExtension: "png"),
                       let img = NSImage(contentsOf: url) {
                        Image(nsImage: img)
                            .resizable()
                            .frame(width: 14, height: 14)
                    }
                    Text("Claude Code")
                        .foregroundStyle(Color(.labelColor))
                }

                // Session (5h block) row
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("세션 · 리셋 \(usageMonitor.timeUntilReset())")
                            .foregroundStyle(Color(.secondaryLabelColor))
                        Spacer()
                        Text(String(format: "%.0f%%", usageMonitor.sessionPercent))
                            .font(.system(size: 12).monospacedDigit())
                            .foregroundStyle(Color(.labelColor))
                    }
                    ProgressView(value: min(usageMonitor.sessionPercent / 100, 1.0))
                        .progressViewStyle(.linear)
                        .tint(usageTint(usageMonitor.sessionPercent))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                // Weekly row
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("이번 주")
                            .foregroundStyle(Color(.secondaryLabelColor))
                        Spacer()
                        Text(String(format: "%.0f%%", usageMonitor.weekPercent))
                            .font(.system(size: 12).monospacedDigit())
                            .foregroundStyle(Color(.labelColor))
                    }
                    ProgressView(value: min(usageMonitor.weekPercent / 100, 1.0))
                        .progressViewStyle(.linear)
                        .tint(usageTint(usageMonitor.weekPercent))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            Divider()
                .padding(.top, 8)
                .padding(.bottom, 8)

            Toggle(isOn: $launchAtLogin) {
                HStack(spacing: 4) {
                    Image(systemName: "power")
                        .foregroundStyle(Color(.labelColor))
                    Text("로그인 시 자동 실행")
                        .foregroundStyle(Color(.labelColor))
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            .onChange(of: launchAtLogin) { _, enabled in
                if enabled {
                    try? SMAppService.mainApp.register()
                } else {
                    try? SMAppService.mainApp.unregister()
                }
            }

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("Quit")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .font(.system(size: 13))
            .foregroundStyle(Color(.secondaryLabelColor))
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
        }
        .frame(width: 280)
        .background(Color(.windowBackgroundColor))
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
