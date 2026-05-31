import Foundation
import SwiftData

@Model
final class UserStats {
    var currentStreak: Int
    var longestStreak: Int
    var lastActiveDate: Date?
    var weekCompletedCount: Int

    init() {
        self.currentStreak = 0
        self.longestStreak = 0
        self.lastActiveDate = nil
        self.weekCompletedCount = 0
    }
}
