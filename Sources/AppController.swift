import AppKit
import SwiftUI

@MainActor
final class AppController: NSObject {
    let monitor = SystemMonitor()
    let usageMonitor = UsageMonitor()
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var eventMonitor: Any?

    override init() {
        super.init()
        setupStatusItem()
        setupPopover()
        startUpdating()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleClick)
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: StatusView(monitor: monitor, usageMonitor: usageMonitor)
        )
    }

    private func startUpdating() {
        Task { @MainActor in
            while true {
                monitor.update()
                statusItem.button?.attributedTitle = buildTitle()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    @objc private func handleClick(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            closePopover()
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                self?.closePopover()
            }
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func buildTitle() -> NSAttributedString {
        let result = NSMutableAttributedString()
        let monoFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [.font: monoFont]

        func icon(_ name: String) {
            let cfg = NSImage.SymbolConfiguration(pointSize: 10, weight: .regular)
            guard let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
                .withSymbolConfiguration(cfg) else { return }
            let attach = NSTextAttachment()
            attach.image = img
            attach.bounds = CGRect(x: 0, y: -2, width: 12, height: 12)
            result.append(NSAttributedString(attachment: attach))
        }

        func claudeIcon() {
            guard let url = Bundle.module.url(forResource: "claude-icon", withExtension: "png"),
                  let img = NSImage(contentsOf: url) else { icon("sparkles"); return }
            img.size = NSSize(width: 12, height: 12)
            let attach = NSTextAttachment()
            attach.image = img
            attach.bounds = CGRect(x: 0, y: -2, width: 12, height: 12)
            result.append(NSAttributedString(attachment: attach))
        }

        func txt(_ s: String) {
            result.append(NSAttributedString(string: s, attributes: attrs))
        }

        let diskPct = monitor.diskTotal > 0
            ? Double(monitor.diskUsed) / Double(monitor.diskTotal) * 100
            : 0.0

        icon("cpu")
        txt(String(format: " %3.0f%%", monitor.cpuUsage))
        txt("  ")
        icon("memorychip")
        txt(" \(monitor.formatBytes(monitor.memoryUsed))")
        txt("  ")
        icon("internaldrive")
        txt(String(format: " %3.0f%%", diskPct))
        txt("  ")
        icon("arrow.down")
        txt(" \(monitor.formatSpeed(monitor.networkIn))")
        txt("  ")
        icon("arrow.up")
        txt(" \(monitor.formatSpeed(monitor.networkOut))")
        txt("  ")
        claudeIcon()
        let s = usageMonitor.sessionPercent
        let w = usageMonitor.weekPercent
        if s > 0 || w > 0 {
            txt(String(format: " %.0f%%/%.0f%%", s, w))
        } else {
            txt(" --/--")
        }

        return result
    }
}
