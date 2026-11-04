import AppKit
import HirebarCore
import HirebarEngine
import ServiceManagement
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let loginItem = NSMenuItem(title: "Abrir al iniciar sesión", action: #selector(toggleLogin), keyEquivalent: "")
    private let popover = NSPopover()
    private let panel = PanelModel()
    private var activity: NSObjectProtocol?
    private var panelTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiatedAllowingIdleSystemSleep],
                                                         reason: "Hirebar busca proyectos y vacantes durante el día")
        Engine.start(resources: Bundle.main.resourceURL)
        StatusMenu.shared.install(in: menu)
        menu.addItem(.separator())
        loginItem.target = self
        menu.addItem(loginItem)
        let quit = NSMenuItem(title: "Salir de Hirebar", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        panel.onConfigureTelegram = { [weak self] in self?.closePanel { StatusMenu.shared.configureTelegram() } }
        panel.onSendTest = { StatusMenu.shared.sendTest() }
        panel.onForgetChat = { [weak self] in self?.closePanel { StatusMenu.shared.forgetChat() } }
        panel.onQuit = { NSApp.terminate(nil) }
        popover.behavior = .transient
        popover.delegate = self
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: PanelView(model: panel))

        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        StatusMenu.shared.onRefresh = { [weak self] busy in
            self?.render(busy: busy)
            if self?.popover.isShown == true { self?.panel.refresh() }
        }
        render(busy: false)
    }

    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showMenu()
        } else {
            togglePanel()
        }
    }

    private func showMenu() {
        closePanel()
        StatusMenu.shared.refresh()
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func togglePanel() {
        if popover.isShown {
            closePanel()
            return
        }
        guard let button = statusItem.button else { return }
        panel.refresh()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in self?.panel.refresh() }
        RunLoop.main.add(timer, forMode: .common)
        panelTimer = timer
    }

    private func closePanel(then action: (() -> Void)? = nil) {
        panelTimer?.invalidate()
        panelTimer = nil
        if popover.isShown { popover.performClose(nil) }
        if let action { DispatchQueue.main.async(execute: action) }
    }

    func popoverDidClose(_ notification: Notification) {
        panelTimer?.invalidate()
        panelTimer = nil
    }

    private func render(busy: Bool) {
        statusItem.button?.image = StatusIcon.make(dot: busy ? .systemOrange : .systemGreen)
        statusItem.button?.toolTip = "Hirebar · Claude: \(Controller.shared.status)\nClic: panel · Clic derecho: menú"
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            StatusMenu.shared.info("No pude cambiar el inicio automático: \(error.localizedDescription)")
        }
        render(busy: !Controller.shared.isIdle)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
