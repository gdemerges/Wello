import Testing
import Foundation
@testable import WelloKit

@Suite("CacheMétéo")
struct CacheMétéoTests {
    /// Fenêtre du premier plan (30 min), telle qu'appliquée par `HydrationStore`.
    private let fenêtrePremierPlan: TimeInterval = 1800

    private var calendrier: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Paris")!
        return c
    }

    private func date(_ jour: Int, _ heure: Int, _ minute: Int = 0) -> Date {
        calendrier.date(from: DateComponents(year: 2026, month: 7, day: jour,
                                             hour: heure, minute: minute))!
    }

    @Test("premier plan : un relevé de moins de 30 min est utilisable")
    func premierPlanFrais() {
        #expect(météoUtilisable(capturéeÀ: date(14, 14, 40), maintenant: date(14, 15),
                                fenêtre: fenêtrePremierPlan, calendar: calendrier))
    }

    @Test("premier plan : au-delà de 30 min, on refait un relevé")
    func premierPlanPérimé() {
        #expect(!météoUtilisable(capturéeÀ: date(14, 14), maintenant: date(14, 15),
                                 fenêtre: fenêtrePremierPlan, calendar: calendrier))
    }

    /// Le cœur du garde-fou : réveillé la nuit par une séance, sans droit au GPS, on accepte le
    /// relevé du matin — sinon le recalcul perdrait le bonus météo et baisserait l'objectif.
    @Test("arrière-plan : un relevé du matin reste utilisable le soir")
    func arrièrePlanTolèreLaJournée() {
        #expect(météoUtilisable(capturéeÀ: date(14, 8), maintenant: date(14, 22),
                                fenêtre: nil, calendar: calendrier))
    }

    @Test("arrière-plan : mais jamais le relevé de la veille")
    func arrièrePlanRefuseLaVeille() {
        #expect(!météoUtilisable(capturéeÀ: date(13, 23, 30), maintenant: date(14, 0, 30),
                                 fenêtre: nil, calendar: calendrier))
    }

    @Test("premier plan : la veille est refusée même à moins de 30 min d'écart")
    func premierPlanRefuseLaVeilleMalgréLaFenêtre() {
        // 23h50 → 00h10 : 20 min d'écart, mais la journée a changé.
        #expect(!météoUtilisable(capturéeÀ: date(13, 23, 50), maintenant: date(14, 0, 10),
                                 fenêtre: fenêtrePremierPlan, calendar: calendrier))
    }

    @Test("un relevé daté du futur est refusé (horloge reculée)")
    func relevéDuFutur() {
        #expect(!météoUtilisable(capturéeÀ: date(14, 16), maintenant: date(14, 15),
                                 fenêtre: nil, calendar: calendrier))
        #expect(!météoUtilisable(capturéeÀ: date(14, 16), maintenant: date(14, 15),
                                 fenêtre: fenêtrePremierPlan, calendar: calendrier))
    }
}
