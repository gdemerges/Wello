import Testing
import Foundation
@testable import WelloKit

@Suite("AdaptiveReminders")
struct AdaptiveRemindersTests {
    let planner = AdaptiveReminderPlanner()

    @Test("cold-start : moins de 7 jours de données → données insuffisantes")
    func coldStart() {
        let six = (0..<6).map { _ in JourDePrises(minutesDePrise: [480, 720]) }
        #expect(planner.aAssezDeDonnées(six) == false)
        let sept = (0..<7).map { _ in JourDePrises(minutesDePrise: [480, 720]) }
        #expect(planner.aAssezDeDonnées(sept) == true)
    }

    @Test("cold-start : un jour sans prise ne compte pas")
    func coldStartJoursVides() {
        var jours = (0..<7).map { _ in JourDePrises(minutesDePrise: [480]) }
        jours.append(JourDePrises(minutesDePrise: []))
        #expect(planner.aAssezDeDonnées(jours) == true)         // 7 jours pleins
        let presqueVide = (0..<6).map { _ in JourDePrises(minutesDePrise: [480]) }
            + [JourDePrises(minutesDePrise: [])]
        #expect(planner.aAssezDeDonnées(presqueVide) == false)  // 6 pleins seulement
    }

    @Test("fenêtre historique : percentiles des 1ʳᵉˢ/dernières prises")
    func fenêtreHistorique() {
        let jours = (0..<10).map { _ in JourDePrises(minutesDePrise: [480, 720, 1200]) }
        let f = planner.fenêtreDepuisHistorique(jours)
        #expect(f == FenêtreÉveil(réveilMin: 480, coucherMin: 1200))
    }

    @Test("fenêtre historique : aucune donnée → nil")
    func fenêtreHistoriqueVide() {
        #expect(planner.fenêtreDepuisHistorique([]) == nil)
        #expect(planner.fenêtreDepuisHistorique([JourDePrises(minutesDePrise: [])]) == nil)
    }

    @Test("fenêtre historique : bornes clampées")
    func fenêtreHistoriqueClamp() {
        // Réveil très tôt (2:00) et coucher très tard (23:50) → clampés.
        let jours = (0..<8).map { _ in JourDePrises(minutesDePrise: [120, 1430]) }
        let f = planner.fenêtreDepuisHistorique(jours)
        #expect(f?.réveilMin == 240)    // plancher 4:00
        #expect(f?.coucherMin == 1410)  // plafond 23:30
    }
}
