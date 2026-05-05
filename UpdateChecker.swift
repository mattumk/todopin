import AppKit
import Foundation

/// Vérifie et installe automatiquement les mises à jour via GitHub Releases.
/// API : https://api.github.com/repos/mattumk/todopin/releases/latest
final class UpdateChecker {

    static let shared = UpdateChecker()
    private init() {}

    private let apiURL = URL(string: "https://api.github.com/repos/mattumk/todopin/releases/latest")!

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    // MARK: - Check silencieux (au lancement)

    func checkSilently() {
        fetch { [weak self] result in
            guard let self else { return }
            if case .success(let release) = result, self.isNewer(release.version) {
                DispatchQueue.main.async { self.showUpdateAlert(release: release, silent: true) }
            }
        }
    }

    // MARK: - Check manuel (menu)

    func checkManually() {
        fetch { [weak self] result in
            guard let self else { return }
            DispatchQueue.main.async {
                switch result {
                case .success(let release):
                    if self.isNewer(release.version) {
                        self.showUpdateAlert(release: release, silent: false)
                    } else {
                        self.showUpToDateAlert()
                    }
                case .failure(let error):
                    self.showErrorAlert(error)
                }
            }
        }
    }

    // MARK: - Réseau

    private func fetch(completion: @escaping (Result<Release, Error>) -> Void) {
        var request = URLRequest(url: apiURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 8

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error { completion(.failure(error)); return }
            guard
                let data,
                let json     = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let tag      = json["tag_name"] as? String,
                let pageURL  = json["html_url"]  as? String
            else { completion(.failure(CheckError.noRelease)); return }

            let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag

            // Cherche un asset .zip (auto-update) ou .dmg (fallback)
            let assets = json["assets"] as? [[String: Any]] ?? []
            let zipURL = assets.first { ($0["name"] as? String)?.hasSuffix(".zip") == true }
                              .flatMap { $0["browser_download_url"] as? String }
            let dmgURL = assets.first { ($0["name"] as? String)?.hasSuffix(".dmg") == true }
                              .flatMap { $0["browser_download_url"] as? String }

            completion(.success(Release(version: version,
                                        pageURL: pageURL,
                                        zipURL: zipURL,
                                        dmgURL: dmgURL)))
        }.resume()
    }

    // MARK: - Alertes

    private func showUpdateAlert(release: Release, silent: Bool) {
        let alert = NSAlert()
        alert.messageText     = "Mise à jour disponible — v\(release.version)"
        alert.informativeText = "Vous utilisez TodoPin v\(currentVersion).\nLa version \(release.version) va être installée automatiquement."
        alert.alertStyle      = .informational
        alert.addButton(withTitle: "Installer maintenant")
        alert.addButton(withTitle: silent ? "Plus tard" : "Fermer")

        if alert.runModal() == .alertFirstButtonReturn {
            startInstall(release: release)
        }
    }

    private func showUpToDateAlert() {
        let a = NSAlert()
        a.messageText     = "TodoPin est à jour"
        a.informativeText = "Vous utilisez déjà la dernière version (v\(currentVersion))."
        a.alertStyle      = .informational
        a.addButton(withTitle: "OK")
        a.runModal()
    }

    private func showErrorAlert(_ error: Error) {
        let a = NSAlert()
        a.messageText     = "Impossible de vérifier les mises à jour"
        a.informativeText = "Vérifiez votre connexion internet et réessayez."
        a.alertStyle      = .warning
        a.addButton(withTitle: "OK")
        a.runModal()
    }

    // MARK: - Installation automatique

    private func startInstall(release: Release) {
        guard let urlString = release.zipURL ?? release.dmgURL,
              let url = URL(string: urlString)
        else {
            // Pas d'asset : ouvrir la page GitHub
            if let u = URL(string: release.pageURL) { NSWorkspace.shared.open(u) }
            return
        }

        let isZip = urlString.hasSuffix(".zip")
        let progress = ProgressWindow()
        progress.show()

        let task = URLSession.shared.downloadTask(with: url) { [weak self] localURL, _, error in
            DispatchQueue.main.async {
                progress.close()
                if let error {
                    self?.showInstallError(error); return
                }
                guard let localURL else { return }
                if isZip {
                    self?.installFromZip(at: localURL)
                } else {
                    self?.installFromDMG(at: localURL)
                }
            }
        }

        // Progression
        observation = task.progress.observe(\.fractionCompleted) { p, _ in
            DispatchQueue.main.async { progress.update(p.fractionCompleted) }
        }

        task.resume()
    }

    private var observation: NSKeyValueObservation?

    // ── Installation depuis un ZIP ──────────────────────────────────────

    private func installFromZip(at localURL: URL) {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("TodoPin_update.zip")
        try? FileManager.default.removeItem(at: tmp)
        guard (try? FileManager.default.moveItem(at: localURL, to: tmp)) != nil else {
            showInstallError(InstallError.moveFailed); return
        }

        let extractDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("TodoPin_extracted")
        try? FileManager.default.removeItem(at: extractDir)
        try? FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)

        let unzip = Process()
        unzip.launchPath = "/usr/bin/unzip"
        unzip.arguments  = ["-q", tmp.path, "-d", extractDir.path]
        unzip.launch()
        unzip.waitUntilExit()

        // Cherche TodoPin.app dans le dossier extrait
        let fm = FileManager.default
        guard let appURL = (try? fm.contentsOfDirectory(at: extractDir,
                                                         includingPropertiesForKeys: nil))?
                              .first(where: { $0.lastPathComponent == "TodoPin.app" })
        else { showInstallError(InstallError.appNotFound); return }

        replaceAndRelaunch(newAppURL: appURL)
    }

    // ── Installation depuis un DMG ──────────────────────────────────────

    private func installFromDMG(at localURL: URL) {
        let dmgPath   = NSTemporaryDirectory() + "TodoPin_update.dmg"
        let mountPath = NSTemporaryDirectory() + "TodoPin_mount"

        try? FileManager.default.removeItem(atPath: dmgPath)
        try? FileManager.default.moveItem(at: localURL, to: URL(fileURLWithPath: dmgPath))
        try? FileManager.default.createDirectory(atPath: mountPath, withIntermediateDirectories: true)

        let mount = Process()
        mount.launchPath = "/usr/bin/hdiutil"
        mount.arguments  = ["attach", dmgPath, "-nobrowse", "-quiet", "-mountpoint", mountPath]
        mount.launch(); mount.waitUntilExit()

        let sourceApp = URL(fileURLWithPath: mountPath + "/TodoPin.app")
        replaceAndRelaunch(newAppURL: sourceApp)

        let detach = Process()
        detach.launchPath = "/usr/bin/hdiutil"
        detach.arguments  = ["detach", mountPath, "-quiet", "-force"]
        detach.launch(); detach.waitUntilExit()
    }

    // ── Remplacement + relance ──────────────────────────────────────────

    private func replaceAndRelaunch(newAppURL: URL) {
        let destURL = Bundle.main.bundleURL
        let fm = FileManager.default

        guard fm.fileExists(atPath: newAppURL.path) else {
            showInstallError(InstallError.appNotFound); return
        }

        do {
            if fm.fileExists(atPath: destURL.path) {
                try fm.removeItem(at: destURL)
            }
            try fm.copyItem(at: newAppURL, to: destURL)
        } catch {
            showInstallError(error); return
        }

        // Attendre que le processus courant quitte avant de rouvrir
        let path = destURL.path.replacingOccurrences(of: "'", with: "'\\''")
        Process.launchedProcess(launchPath: "/bin/sh",
                                arguments: ["-c", "sleep 0.8 && open '\(path)'"])
        NSApp.terminate(nil)
    }

    private func showInstallError(_ error: Error) {
        let a = NSAlert()
        a.messageText     = "Échec de la mise à jour"
        a.informativeText = "Une erreur s'est produite. Téléchargez la mise à jour manuellement."
        a.alertStyle      = .critical
        a.addButton(withTitle: "OK")
        a.runModal()
    }

    // MARK: - Comparaison sémantique

    private func isNewer(_ remote: String) -> Bool {
        let r = semanticComponents(remote)
        let c = semanticComponents(currentVersion)
        for (a, b) in zip(r, c) { if a != b { return a > b } }
        return false
    }

    private func semanticComponents(_ v: String) -> [Int] {
        v.split(separator: ".").map { Int($0) ?? 0 }.padding(toLength: 3, withPad: 0)
    }

    // MARK: - Types

    private struct Release {
        let version: String
        let pageURL: String
        let zipURL:  String?
        let dmgURL:  String?
    }

    private enum CheckError: Error { case noRelease }
    private enum InstallError: Error { case moveFailed, appNotFound }
}

// MARK: - Fenêtre de progression

private final class ProgressWindow: NSObject {
    private var window: NSWindow?
    private var bar: NSProgressIndicator?
    private var label: NSTextField?

    func show() {
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 80),
                          styleMask: [.titled],
                          backing: .buffered,
                          defer: false)
        win.title = "Mise à jour TodoPin"
        win.center()
        win.isReleasedWhenClosed = false

        let lbl = NSTextField(labelWithString: "Téléchargement en cours…")
        lbl.frame = NSRect(x: 20, y: 50, width: 280, height: 18)
        lbl.font = .systemFont(ofSize: 13)
        win.contentView?.addSubview(lbl)

        let progress = NSProgressIndicator()
        progress.frame = NSRect(x: 20, y: 20, width: 280, height: 16)
        progress.style = .bar
        progress.isIndeterminate = false
        progress.minValue = 0; progress.maxValue = 1
        progress.doubleValue = 0
        win.contentView?.addSubview(progress)

        win.makeKeyAndOrderFront(nil)
        self.window = win
        self.bar = progress
        self.label = lbl
    }

    func update(_ fraction: Double) {
        bar?.doubleValue = fraction
        let pct = Int(fraction * 100)
        label?.stringValue = "Téléchargement en cours… \(pct)%"
    }

    func close() { window?.close() }
}

// MARK: - Helper

private extension Array {
    func padding(toLength length: Int, withPad pad: Element) -> [Element] {
        count >= length ? Array(prefix(length)) : self + Array(repeating: pad, count: length - count)
    }
}
