import Foundation
import AppKit
import SwiftData

/// Adds an NSStatusBar item that shows the latest snapshot's net worth and
/// QoQ delta. Refreshes every 60 s and on demand. Toggleable from Settings.
@MainActor
final class MenuBarController: NSObject {
    static let shared = MenuBarController()

    private var statusItem: NSStatusItem?
    private var refreshTimer: Timer?
    private weak var container: ModelContainer?
    private var displayCurrency: Currency = .USD
    private var stealthMode: Bool = false

    func attach(container: ModelContainer) {
        self.container = container
    }

    func setEnabled(_ on: Bool) {
        if on {
            install()
            refresh()
        } else {
            uninstall()
        }
    }

    func setDisplayCurrency(_ c: Currency) {
        displayCurrency = c
        refresh()
    }

    func setStealth(_ on: Bool) {
        stealthMode = on
        refresh()
    }

    private func install() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.behavior = []
        item.button?.title = "Quiet Finance"
        item.button?.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Quiet Finance", action: #selector(openApp), keyEquivalent: "o"))
        menu.items.last?.target = self
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Refresh", action: #selector(refreshNow), keyEquivalent: "r"))
        menu.items.last?.target = self
        menu.addItem(NSMenuItem(title: "Hide menu bar item", action: #selector(hide), keyEquivalent: ""))
        menu.items.last?.target = self
        item.menu = menu
        statusItem = item

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }

    private func uninstall() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItem = nil
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    @objc private func openApp() {
        NSApp.activate(ignoringOtherApps: true)
        for w in NSApp.windows where w.canBecomeMain {
            w.makeKeyAndOrderFront(nil)
            return
        }
    }

    @objc private func refreshNow() { refresh() }

    @objc private func hide() {
        UserDefaults.standard.set(false, forKey: "menuBarEnabled")
        setEnabled(false)
    }

    func refresh() {
        guard let container, let button = statusItem?.button else { return }
        let ctx = ModelContext(container)
        let descriptor = FetchDescriptor<Snapshot>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        guard let snaps = try? ctx.fetch(descriptor), let latest = snaps.first else {
            button.title = "Quiet Finance · —"
            return
        }
        let inc = UserDefaults.standard.object(forKey: "includeIlliquidInNetWorth") as? Bool ?? true
        let curTotal = total(latest, ccy: displayCurrency, includeIlliquid: inc)
        let prevTotal: Double? = snaps.dropFirst().first.map { total($0, ccy: displayCurrency, includeIlliquid: inc) }

        if stealthMode {
            button.title = "Quiet Finance · ••• "
            return
        }

        let value = compactString(curTotal, ccy: displayCurrency)
        if let prev = prevTotal, prev != 0 {
            let pct = (curTotal - prev) / abs(prev) * 100
            let sign = pct >= 0 ? "▲" : "▼"
            button.title = "\(value) \(sign)\(String(format: "%.1f", abs(pct)))%"
        } else {
            button.title = value
        }
    }

    private func total(_ s: Snapshot, ccy: Currency, includeIlliquid: Bool) -> Double {
        s.totalsValues.reduce(0.0) { acc, v in
            acc + CurrencyConverter.netDisplayValue(for: v, in: ccy, includeIlliquid: includeIlliquid)
        }
    }

    private func compactString(_ v: Double, ccy: Currency) -> String {
        let symbol = ccy.symbol
        let mag: Double = Swift.abs(v)
        let sign = v < 0 ? "−" : ""
        if mag >= 1_000_000 {
            return "\(sign)\(symbol)\(String(format: "%.2f", mag / 1_000_000))M"
        } else if mag >= 1_000 {
            return "\(sign)\(symbol)\(String(format: "%.1f", mag / 1_000))K"
        }
        return "\(sign)\(symbol)\(String(format: "%.0f", mag))"
    }
}
