import Foundation
import WelloKit

/// Construit les fichiers CSV d'export depuis les modèles SwiftData. Réservé à Wello+
/// (gating à l'UI). La sérialisation pure et testée vit dans `WelloKit.HydrationExport`.
enum HydrationExporter {

    /// CSV détaillé (une ligne par prise, plus récente d'abord) dans un fichier temporaire.
    static func detailFile(logs: [HydrationLog]) throws -> URL {
        let rows = logs.sorted { $0.loggedAt > $1.loggedAt }.map {
            ExportLogRow(loggedAt: $0.loggedAt, drinkLabel: $0.drink.label,
                         volumeML: $0.amountML, coefficient: $0.coefficient,
                         effectiveML: $0.effectiveML, source: $0.source)
        }
        return try écrire(HydrationExport.detailCSV(rows), nom: "Wello-prises-\(jourFichier()).csv")
    }

    /// CSV résumé (une ligne par jour avec objectif, plus récent d'abord).
    static func summaryFile(logs: [HydrationLog], goals: [DailyGoal]) throws -> URL {
        let cal = Calendar.current
        var conso: [Date: Int] = [:]
        for log in logs {
            conso[cal.startOfDay(for: log.loggedAt), default: 0] += log.effectiveML
        }
        let days = goals.sorted { $0.date > $1.date }.map {
            ExportDaySummary(day: $0.date,
                             consumedML: clampedDayTotal(conso[$0.date] ?? 0),
                             goalML: $0.totalML)
        }
        return try écrire(HydrationExport.summaryCSV(days), nom: "Wello-jours-\(jourFichier()).csv")
    }

    /// Écrit le CSV (UTF-8 avec BOM, pour les accents sous Excel) dans le dossier temporaire.
    private static func écrire(_ csv: String, nom: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(nom)
        let bom = Data([0xEF, 0xBB, 0xBF])
        try (bom + Data(csv.utf8)).write(to: url, options: .atomic)
        return url
    }

    /// Supprime les exports Wello de `tmp/` : ce sont des données santé, on ne les laisse pas
    /// traîner jusqu'à la purge iOS. Appelé à la fermeture de la feuille de partage (les
    /// destinataires ont déjà consommé les fichiers) — balaie aussi les restes d'exports passés.
    static func nettoyer() {
        let fm = FileManager.default
        guard let fichiers = try? fm.contentsOfDirectory(at: fm.temporaryDirectory,
                                                         includingPropertiesForKeys: nil) else { return }
        for f in fichiers where f.lastPathComponent.hasPrefix("Wello-") && f.pathExtension == "csv" {
            try? fm.removeItem(at: f)
        }
    }

    private static func jourFichier() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: .now)
    }
}
