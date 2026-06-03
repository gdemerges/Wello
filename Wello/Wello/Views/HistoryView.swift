import SwiftUI
import SwiftData
import Charts
import WelloKit

/// Historique : graphe consommé vs objectif, statistiques, et jours détaillables.
struct HistoryView: View {
    @Query(sort: \DailyGoal.date, order: .reverse) private var objectifs: [DailyGoal]
    @Query private var logs: [HydrationLog]
    @State private var plage = 7

    var body: some View {
        NavigationStack {
            Group {
                if objectifs.isEmpty {
                    étatVide
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            sélecteurPlage
                            grapheCard
                            statsCard
                            ForEach(objectifs) { goal in
                                NavigationLink {
                                    DayDetailView(date: goal.date)
                                } label: {
                                    carteJour(goal)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                }
            }
            .welloBackground()
            .navigationTitle("Historique")
        }
    }

    // MARK: Sélecteur 7 / 30 jours

    private var sélecteurPlage: some View {
        Picker("Plage", selection: $plage) {
            Text("7 jours").tag(7)
            Text("30 jours").tag(30)
        }
        .pickerStyle(.segmented)
    }

    // MARK: Graphe

    private struct JourBarre: Identifiable {
        let id: Date
        let date: Date
        let consommé: Int
        let objectif: Int
        var atteint: Bool { objectif > 0 && consommé >= objectif }
        var ratio: Double { objectif > 0 ? Double(consommé) / Double(objectif) : 0 }
    }

    private var barres: [JourBarre] {
        objectifs.prefix(plage).map {
            JourBarre(id: $0.date, date: $0.date, consommé: consommé(pour: $0.date), objectif: $0.totalML)
        }
        .reversed()   // chronologique pour l'axe X
    }

    private var grapheCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Text("Atteinte de l'objectif")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(WelloTheme.ink)
                Chart {
                    ForEach(barres) { jour in
                        BarMark(
                            x: .value("Jour", jour.date, unit: .day),
                            y: .value("Atteinte", min(jour.ratio, 1.2))
                        )
                        .foregroundStyle(jour.atteint ? Color.green : WelloTheme.accent)
                        .cornerRadius(4)
                        .accessibilityLabel(jour.date.formatted(.dateTime.weekday(.wide).day().month()))
                        .accessibilityValue("\(jour.consommé) sur \(jour.objectif) millilitres, \(Int((jour.ratio * 100).rounded())) pour cent, \(jour.atteint ? "objectif atteint" : "objectif non atteint")")
                    }
                    RuleMark(y: .value("Objectif", 1.0))
                        .foregroundStyle(WelloTheme.inkSoft.opacity(0.55))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .annotation(position: .topTrailing, alignment: .trailing) {
                            Text("objectif")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(WelloTheme.inkSoft)
                        }
                }
                .chartYScale(domain: 0...1.25)
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: plage == 7 ? 1 : 6)) {
                        AxisValueLabel(format: .dateTime.day().month(.narrow))
                    }
                }
                .frame(height: 170)
            }
        }
    }

    // MARK: Stats

    private var totals: [DailyTotal] {
        objectifs.map { DailyTotal(consumedML: consommé(pour: $0.date), goalML: $0.totalML) }
    }

    private var série: Int {
        var liste = objectifs.map { (date: $0.date,
                                     total: DailyTotal(consumedML: consommé(pour: $0.date), goalML: $0.totalML)) }
        // Un « aujourd'hui » encore en cours ne casse pas la série.
        if let premier = liste.first, !premier.total.reached, Calendar.current.isDateInToday(premier.date) {
            liste.removeFirst()
        }
        return HydrationStats.currentStreak(liste.map(\.total))
    }

    private var statsCard: some View {
        HStack(spacing: 12) {
            statTuile("\(série) j", "série en cours", "flame.fill", .orange)
            statTuile(litres(HydrationStats.averageConsumed(totals, lastN: 7)), "moyenne 7 j", "drop.fill", WelloTheme.accent)
        }
    }

    private func statTuile(_ valeur: String, _ légende: String, _ icon: String, _ teinte: Color) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: icon).foregroundStyle(teinte)
                Text(valeur)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(WelloTheme.ink)
                Text(légende)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(WelloTheme.inkSoft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Carte jour

    private func carteJour(_ goal: DailyGoal) -> some View {
        let bu = consommé(pour: goal.date)
        let atteint = bu >= goal.totalML
        let ratio = goal.totalML > 0 ? min(Double(bu) / Double(goal.totalML), 1) : 0

        return CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(goal.date, format: .dateTime.weekday(.wide).day().month())
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(WelloTheme.ink)
                    Spacer()
                    if atteint {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(WelloTheme.inkSoft.opacity(0.6))
                }

                ProgressView(value: ratio)
                    .tint(atteint ? .green : WelloTheme.accent)

                HStack {
                    Text("Bu : \(bu) ml")
                        .foregroundStyle(atteint ? .green : WelloTheme.inkSoft)
                    Spacer()
                    Text("Objectif : \(goal.totalML) ml")
                        .foregroundStyle(WelloTheme.inkSoft)
                }
                .font(.system(.subheadline, design: .rounded))
            }
        }
    }

    private var étatVide: some View {
        VStack(spacing: 12) {
            Image(systemName: "drop.fill")
                .font(.system(size: 44))
                .foregroundStyle(WelloTheme.accent.opacity(0.6))
            Text("Aucun historique pour l'instant")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(WelloTheme.ink)
            Text("Tes objectifs quotidiens apparaîtront ici au fil des jours.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(WelloTheme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    private func consommé(pour jour: Date) -> Int {
        let cal = Calendar.current
        return logs.filter { cal.isDate($0.loggedAt, inSameDayAs: jour) }
                   .reduce(0) { $0 + $1.amountML }
    }

    private func litres(_ ml: Int) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.maximumFractionDigits = 1
        return (f.string(from: NSNumber(value: Double(ml) / 1000)) ?? "0") + " L"
    }
}

#if DEBUG
#Preview {
    HistoryView()
        .modelContainer(PreviewSupport.container())
}
#endif
