import Foundation
import SwiftData

/// Une prise d'eau enregistrée.
@Model
final class HydrationLog {
    var amountML: Int
    var loggedAt: Date
    /// Provenance : "app" (saisie dans Wello) ou "healthkit" (importée).
    var source: String

    init(amountML: Int, loggedAt: Date = .now, source: String = "app") {
        self.amountML = amountML
        self.loggedAt = loggedAt
        self.source = source
    }
}
