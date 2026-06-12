import Foundation

/// Round-number milestone ladder (1–2.5–5 progression) plus on-track/behind
/// status against the user's goal, both driven by the Forecast engine.
enum Milestones {
    /// Next milestone strictly above `current`: …100k, 250k, 500k, 1M, 2.5M…
    static func nextMilestone(above current: Double) -> Double {
        guard current > 0 else { return 100_000 }
        var base = 1_000.0
        while true {
            for multiplier in [1.0, 2.5, 5.0] {
                let candidate = base * multiplier
                if candidate > current { return candidate }
            }
            base *= 10
            if base > 1e15 { return base }  // ladder cap; unreachable in practice
        }
    }

    /// Previous milestone at or below `current` (progress-bar floor).
    static func previousMilestone(atOrBelow current: Double) -> Double {
        guard current > 0 else { return 0 }
        var best = 0.0
        var base = 1_000.0
        while base <= current {
            for multiplier in [1.0, 2.5, 5.0] {
                let candidate = base * multiplier
                if candidate <= current { best = max(best, candidate) }
            }
            base *= 10
        }
        return best
    }

    struct Status {
        let goal: Double?               // display currency
        let goalETA: Date?              // trend-fit crossing
        let goalTargetDate: Date?
        /// Months ahead (negative) or behind (positive) the target date.
        let monthsOffPace: Int?
        let nextMilestone: Double
        let nextMilestoneETA: Date?
        let progressToNext: Double      // 0…1 from previous milestone
    }

    static func compute(history: [(Date, Double)],
                        method: ForecastMethod,
                        goal: Double?,
                        goalDate: Date?) -> Status? {
        guard let current = history.max(by: { $0.0 < $1.0 })?.1 else { return nil }

        let next = nextMilestone(above: current)
        let floor = previousMilestone(atOrBelow: current)
        let span = next - floor
        let progress = span > 0 ? min(1, max(0, (current - floor) / span)) : 0

        let goalForecast = goal.flatMap { g in
            Forecast.compute(history: history, method: method, horizonMonths: 0, goal: g)
        }
        let milestoneForecast = Forecast.compute(history: history, method: method,
                                                 horizonMonths: 0, goal: next)

        var offPace: Int? = nil
        if let eta = goalForecast?.etaForGoal, let target = goalDate {
            offPace = Calendar.current.dateComponents([.month], from: target, to: eta).month
        }

        return Status(goal: goal,
                      goalETA: goalForecast?.etaForGoal,
                      goalTargetDate: goalDate,
                      monthsOffPace: offPace,
                      nextMilestone: next,
                      nextMilestoneETA: milestoneForecast?.etaForGoal,
                      progressToNext: progress)
    }
}
