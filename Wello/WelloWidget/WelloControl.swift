import WidgetKit
import SwiftUI
import AppIntents

/// Control Widget (iOS 18+) : un bouton « + eau » posable dans le **Centre de contrôle**, sur
/// l'**écran verrouillé** ou déclenchable par le **Bouton Action**. Une pression enregistre
/// 250 ml via `AddWaterIntent` (partagé, App Group) sans ouvrir l'app.
@available(iOS 18.0, *)
struct WelloControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "Life.Wello.control.addWater") {
            ControlWidgetButton(action: AddWaterIntent(amountML: 250)) {
                Label("Ajouter 250 ml", systemImage: "drop.fill")
            }
        }
        .displayName("Wello — Ajouter de l'eau")
        .description("Enregistre une prise d'eau sans ouvrir l'app.")
    }
}
