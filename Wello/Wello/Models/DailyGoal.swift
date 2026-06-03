import Foundation
import SwiftData

/// Objectif calculé pour un jour donné (un seul par date, normalisée à minuit).
@Model
final class DailyGoal {
    /// Date du jour, normalisée au début de journée (`startOfDay`).
    @Attribute(.unique) var date: Date
    var baseML: Int
    var activityBonusML: Int
    var weatherBonusML: Int
    var medicalFloorML: Int
    var totalML: Int
    var calculatedAt: Date

    init(date: Date, baseML: Int, activityBonusML: Int, weatherBonusML: Int,
         medicalFloorML: Int, totalML: Int, calculatedAt: Date = .now) {
        self.date = date
        self.baseML = baseML
        self.activityBonusML = activityBonusML
        self.weatherBonusML = weatherBonusML
        self.medicalFloorML = medicalFloorML
        self.totalML = totalML
        self.calculatedAt = calculatedAt
    }
}
