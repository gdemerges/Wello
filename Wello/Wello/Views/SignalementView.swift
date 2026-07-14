import SwiftUI
import UIKit
import WelloKit

/// Signalement d'un problème — le seul canal « télémétrie » compatible avec la promesse de Wello :
/// rien ne part tout seul. On montre à l'utilisateur **le texte exact** qui sera transmis, et c'est
/// lui qui l'envoie (mail, notes, ce qu'il veut) via la feuille de partage.
///
/// Le rapport ne contient aucune donnée de santé, aucune position, aucun volume bu : seulement
/// l'environnement (version, iOS, modèle), l'état des permissions et la fraîcheur des sources —
/// c'est-à-dire précisément ce qui explique les pannes silencieuses de l'app.
struct SignalementView: View {
    @Environment(HydrationStore.self) private var store
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(DiagnosticService.self) private var diagnostics
    @Environment(\.dismiss) private var dismiss

    private var rapport: String { construireRapport() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Décris ce qui ne va pas dans ton message, et laisse ces informations techniques en dessous : elles disent où l'app a échoué.")
                        .font(.welloProseDouce)
                        .foregroundStyle(WelloTheme.inkSoft)

                    CardContainer {
                        Text(rapport)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(WelloTheme.ink)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Text("Aucune donnée de santé, aucune position, aucun volume bu n'est inclus. Rien n'est envoyé automatiquement : tu choisis le destinataire.")
                        .font(.welloLégendeMini)
                        .foregroundStyle(WelloTheme.inkSoft)

                    ShareLink(item: rapport) {
                        Text("Envoyer le rapport")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(WelloTheme.accentGradient,
                                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    if !diagnostics.incidents.isEmpty {
                        Button("Oublier les incidents enregistrés", role: .destructive) {
                            diagnostics.oublier()
                        }
                        .font(.system(.subheadline, design: .rounded))
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
                .padding()
            }
            .welloBackground()
            .navigationTitle("Signaler un problème")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    /// Le rapport est volontairement en clair et lisible : l'utilisateur doit pouvoir juger de ce
    /// qu'il transmet. Non localisé — il est destiné au développeur, pas à l'utilisateur.
    private func construireRapport() -> String {
        let services = store.étatServices
        let sources = store.étatSources
        var lignes: [String] = [
            "— Wello · rapport technique —",
            "App : \(DiagnosticService.version)",
            "iOS : \(UIDevice.current.systemVersion) · \(modèleAppareil())",
            "Langue : \(Locale.current.identifier)",
            "Palier : \(entitlements.isUnlocked(.unlimitedHistory) ? "Wello+" : "gratuit")",
            "",
            "Permissions :",
            "· Météo/localisation : \(services.météoDisponible ? "OK" : "KO")",
            "· Notifications : \(services.notificationsAutorisées ? "OK" : "KO")",
            "",
            "Dernières mises à jour :",
            "· Objectif calculé : \(horodatage(sources.objectifCalculéÀ))",
            "· Énergie (Santé) : \(horodatage(sources.énergieLueÀ))",
            "· Météo relevée : \(horodatage(sources.météoCapturéeÀ))",
            "· Import Santé : \(horodatage(sources.importsSantéLusÀ)) (\(sources.importsSantéAjoutés) prise(s))",
            "· Mode des rappels : \(modeRappels())",
        ]

        if diagnostics.incidents.isEmpty {
            lignes += ["", "Aucun incident enregistré."]
        } else {
            lignes += ["", "Incidents (MetricKit) :"]
            lignes += diagnostics.incidents.map {
                "· \($0.genre) — \($0.cause) — build \($0.version) — \(horodatage($0.date))"
            }
        }
        return lignes.joined(separator: "\n")
    }

    private func horodatage(_ date: Date?) -> String {
        guard let date else { return "jamais" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private func modeRappels() -> String {
        switch store.étatRappels.mode {
        case .fixe: return "fixes"
        case .apprentissage: return "apprentissage"
        case .adaptatif: return "adaptatifs"
        }
    }

    /// Identifiant machine (« iPhone16,2 »), pas le nom que l'utilisateur a donné à son téléphone
    /// (qui, lui, contient souvent son prénom).
    private func modèleAppareil() -> String {
        var infos = utsname()
        uname(&infos)
        let machine = withUnsafePointer(to: &infos.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: $0)) {
                String(validatingCString: $0) ?? "?"
            }
        }
        return machine
    }
}
