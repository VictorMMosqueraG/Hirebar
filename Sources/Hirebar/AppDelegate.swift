import AppKit
import HirebarCore
import HirebarEngine
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let loginItem = NSMenuItem(title: "Abrir al iniciar sesión", action: #selector(toggleLogin), keyEquivalent: "")
    private var activity: NSObjectProtocol?

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
        statusItem.menu = menu
        StatusMenu.shared.onRefresh = { [weak self] busy in self?.render(busy: busy) }
        render(busy: false)
    }

    private func render(busy: Bool) {
        statusItem.button?.image = StatusIcon.make(dot: busy ? .systemOrange : .systemGreen)
        statusItem.button?.toolTip = "Hirebar · Claude: \(Controller.shared.status)"
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
