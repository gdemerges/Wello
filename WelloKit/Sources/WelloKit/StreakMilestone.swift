/// Paliers de série (jours consécutifs d'objectif d'hydratation atteint) qui déclenchent
/// une célébration renforcée sur l'écran d'accueil. Logique pure, testable en CLI.
public enum StreakMilestone {
    /// Paliers célébrés, ordre croissant. Choisis pour espacer les récompenses au fil du temps
    /// (première semaine, puis quinzaine, mois, etc.).
    public static let paliers = [3, 7, 14, 30, 60, 100, 200, 365]

    /// Renvoie le palier si `streak` en est exactement un, sinon `nil`.
    /// Ne se déclenche qu'au jour pile du palier (pas les jours au-delà), pour une célébration ponctuelle.
    public static func palier(pour streak: Int) -> Int? {
        paliers.contains(streak) ? streak : nil
    }
}
