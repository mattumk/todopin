import AppKit
import Foundation

/// Vérifie les mises à jour via GitHub Releases.
/// API : https://api.github.com/repos/mattumk/todopin/releases/latest
final class UpdateChecker {

    static let shared = UpdateChecker()
    private init() {}

    private let apiURL = URL(string: "https://api.github.com/repos/mattumk/todopin/releases/latest")!

    // ── Version courante lue depuis Info.plist ──────────────────────────
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    // MARK: - Check silencieux (au lancement)

    /// Vérifie en arrière-plan ; n'affiche une alerte que si une mise à jour est disponible.
    func checkSilently() {
        fetch { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let release) where self.isNewer(release.version):
                DispatchQueue.main.async {
                    self.showUpdateAlert(release: release, silent: true)
                }
            default:
                break   // pas de mise à jour ou pas de réseau → silencieux
            }
        }
    }

    // MARK: - Check manuel (menu "Vérifier les mises à jour…")

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

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(error)); return
            }
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag  = json["tag_name"] as? String,
                  let url  = json["html_url"]  as? String
            else {
                completion(.failure(CheckError.noRelease)); return
            }
            // tag_name peut être "v1.2.0" ou "1.2.0"
            let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            completion(.success(Release(version: version, pageURL: url, tagName: tag)))
        }.resume()
    }

    // MARK: - Comparaison de versions sémantiques

    /// Renvoie true si `remote` est strictement plus récente que `currentVersion`
    private func isNewer(_ remote: String) -> Bool {
        let r = semanticComponents(remote)
        let c = semanticComponents(currentVersion)
        for (a, b) in zip(r, c) {
            if a != b { return a > b }
        }
        return false
    }

    private func semanticComponents(_ v: String) -> [Int] {
        v.split(separator: ".").map { Int($0) ?? 0 }
         .padding(toLength: 3, withPad: 0)
    }

    // MARK: - Alertes

    private func showUpdateAlert(release: Release, silent: Bool) {
        let alert = NSAlert()
        alert.messageText    = "Mise à jour disponible — v\(release.version)"
        alert.informativeText = "Vous utilisez TodoPin v\(currentVersion).\nLa version \(release.version) est disponible sur GitHub."
        alert.alertStyle     = .informational
        alert.addButton(withTitle: "Télécharger")
        alert.addButton(withTitle: silent ? "Plus tard" : "Fermer")

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: release.pageURL)!)
        }
    }

    private func showUpToDateAlert() {
        let alert = NSAlert()
        alert.messageText     = "TodoPin est à jour"
        alert.informativeText = "Vous utilisez déjà la dernière version (v\(currentVersion))."
        alert.alertStyle      = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showErrorAlert(_ error: Error) {
        let alert = NSAlert()
        alert.messageText     = "Impossible de vérifier les mises à jour"
        alert.informativeText = "Vérifiez votre connexion internet et réessayez."
        alert.alertStyle      = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Types

    private struct Release {
        let version: String
        let pageURL: String
        let tagName: String
    }

    private enum CheckError: Error {
        case noRelease
    }
}

// MARK: - Helper

private extension Array {
    func padding(toLength length: Int, withPad pad: Element) -> [Element] {
        if count >= length { return Array(prefix(length)) }
        return self + Array(repeating: pad, count: length - count)
    }
}
