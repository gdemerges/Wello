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
}
