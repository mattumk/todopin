import AppKit
import SwiftUI

// MARK: - State bridge SwiftUI ↔ AppKit

/// Objet partagé entre FloatingPanelContent (AppKit) et FloatingCircleView (SwiftUI)
/// pour piloter l'animation de press sans passer par un DragGesture.
class FloatingPinState: ObservableObject {
    @Published var isPressed = false
}

// MARK: - NSHostingView custom (drag AppKit natif)

/// Sous-classe de NSHostingView qui gère le drag en AppKit pur.
///
/// Pourquoi pas SwiftUI DragGesture ?
/// DragGesture rapporte la translation dans le référentiel de la VUE. Quand le panel
/// se déplace, la vue se déplace avec lui → la position relative de la souris change →
/// oscillation / saccades. En revanche, NSEvent.mouseLocation est toujours en
/// coordonnées ÉCRAN absolues : aucune dérive possible.
class FloatingPanelContent: NSHostingView<AnyView> {

    var onTap:          (() -> Void)?
    var onDragEnded:    (() -> Void)?
    var onDragPosition: ((NSPoint) -> Void)?   // appelé en continu pendant le drag
    weak var targetPanel: NSPanel?

    // Référence partagée avec FloatingCircleView pour l'animation de press
    var pinState: FloatingPinState?

    private var startMouseLoc:    NSPoint?
    private var startPanelOrigin: NSPoint?
    private var hasDragged = false
    private let dragThreshold: CGFloat = 5

    // Le panel fait 128×128 ; le cercle visuel (56px) est centré → rayon hit = 36px
    private let hitRadius: CGFloat = 36

    required init(rootView: AnyView) {
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - AppKit mouse events

    override func mouseDown(with event: NSEvent) {
        // Ignorer les clics hors du cercle (zone transparente du panel élargi)
        let loc    = convert(event.locationInWindow, from: nil)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        guard hypot(loc.x - center.x, loc.y - center.y) <= hitRadius else { return }

        // NE PAS appeler super → on prend le contrôle total des événements souris.
        // .onHover (NSTrackingArea) fonctionne indépendamment de mouseDown.
        startMouseLoc    = NSEvent.mouseLocation   // coordonnées écran absolues
        startPanelOrigin = targetPanel?.frame.origin
        hasDragged       = false
        DispatchQueue.main.async { self.pinState?.isPressed = true }
    }

    override func mouseDragged(with event: NSEvent) {
        guard
            let start  = startMouseLoc,
            let origin = startPanelOrigin,
            let panel  = targetPanel
        else { return }

        let cur = NSEvent.mouseLocation
        let dx  = cur.x - start.x
        let dy  = cur.y - start.y

        if hypot(dx, dy) > dragThreshold {
            if !hasDragged {
                hasDragged = true
                DispatchQueue.main.async { self.pinState?.isPressed = false }
            }
            // AppKit Y et écran Y ont la même direction → pas d'inversion
            let newOrigin = NSPoint(x: origin.x + dx, y: origin.y + dy)
            panel.setFrameOrigin(newOrigin)
            onDragPosition?(newOrigin)          // ← tooltip suit en temps réel
        }
    }

    override func mouseUp(with event: NSEvent) {
        DispatchQueue.main.async { self.pinState?.isPressed = false }
        if !hasDragged {
            onTap?()
        } else {
            onDragEnded?()
        }
        startMouseLoc    = nil
        startPanelOrigin = nil
        hasDragged       = false
    }
}
