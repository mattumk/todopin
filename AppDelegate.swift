import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {

    private var floatingController: FloatingController?
    private let taskManager = TaskManager.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenu()
        floatingController = FloatingController(taskManager: taskManager)
        floatingController?.show()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.checkRollover()
        }

        // Vérification silencieuse des mises à jour (2 s de délai pour ne pas bloquer le démarrage)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            UpdateChecker.shared.checkSilently()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - Menu

    private func setupMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu

        // Reporter les tâches d'hier (visible uniquement s'il y en a)
        let rolloverItem = NSMenuItem(
            title: "Reporter les tâches d'hier",
            action: #selector(handleManualRollover),
            keyEquivalent: ""
        )
        rolloverItem.target = self
        appMenu.addItem(rolloverItem)

        appMenu.addItem(.separator())

        let updateItem = NSMenuItem(
            title: "Vérifier les mises à jour…",
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        updateItem.target = self
        appMenu.addItem(updateItem)

        appMenu.addItem(.separator())

        appMenu.addItem(
            withTitle: "Quitter TodoPin",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        NSApp.mainMenu = mainMenu
    }

    // MARK: - Rollover

    /// Popup automatique au lancement — une seule fois par jour
    private func checkRollover() {
        guard !taskManager.wasRolloverShownToday() else { return }
        let incomplete = taskManager.yesterdayIncompleteTasks()
        guard !incomplete.isEmpty else { return }

        // Marquer avant d'afficher pour éviter la duplication si l'app est relancée
        taskManager.markRolloverShown()
        showRolloverAlert(incomplete)
    }

    @objc private func checkForUpdates() {
        UpdateChecker.shared.checkManually()
    }

    /// Reporter manuellement depuis le menu (disponible tant qu'il y a des tâches d'hier)
    @objc private func handleManualRollover() {
        let incomplete = taskManager.yesterdayIncompleteTasks()
        guard !incomplete.isEmpty else {
            let a = NSAlert()
            a.messageText = "Aucune tâche à reporter"
            a.informativeText = "Il n'y a pas de tâches non terminées d'hier."
            a.alertStyle = .informational
            a.addButton(withTitle: "OK")
            a.runModal()
            return
        }
        taskManager.rollover(incomplete)
        taskManager.markRolloverShown()
    }

    private func showRolloverAlert(_ incomplete: [Task]) {
        let n = incomplete.count
        let plural = n > 1

        let alert = NSAlert()
        alert.messageText = "Tâche\(plural ? "s" : "") non terminée\(plural ? "s" : "") hier"
        alert.informativeText = "Vous avez \(n) tâche\(plural ? "s" : "") non terminée\(plural ? "s" : "") d'hier. Voulez-vous les reporter sur aujourd'hui ?"
        alert.addButton(withTitle: "Reporter")
        alert.addButton(withTitle: "Ignorer")
        alert.alertStyle = .informational

        if alert.runModal() == .alertFirstButtonReturn {
            taskManager.rollover(incomplete)
        }
    }
}
