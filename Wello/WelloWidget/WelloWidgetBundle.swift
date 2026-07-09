import WidgetKit
import SwiftUI

/// Point d'entrée de l'extension widget : déclare le(s) widget(s) exposé(s).
@main
struct WelloWidgetBundle: WidgetBundle {
    var body: some Widget {
        WelloWidget()
        HydrationLiveActivity()
        // Control Widget (Centre de contrôle / écran verrouillé / Bouton Action) — iOS 18+.
        if #available(iOS 18.0, *) {
            WelloControl()
        }
    }
}
