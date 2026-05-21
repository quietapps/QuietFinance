import Foundation

enum ForecastMethod: String, CaseIterable, Identifiable {
    case linear     // Ordinary least squares straight line.
    case cagr       // Compound annual growth rate, exponential curve.
    var id: String { rawValue }
    var label: String {
        switch self { case .linear: return "Linear"; case .cagr: return "CAGR" }
    }
}

enum Forecast {
    struct Point: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
        let lower: Double
        let upper: Double
    }

    /// Result bundle: historical data + projected line + ETA estimate to reach
    /// optional goal value.
    struct Result {
        let history: [(date: Date, value: Double)]
        let fit: [Point]            // sampled along history dates (for residuals)
        let projection: [Point]     // future dates (today → end)
        let etaForGoal: Date?       // when the fit crosses goal, if achievable
        let cagrPct: Double?        // annual growth rate when applicable
        let slopePerDay: Double?    // linear slope per day
        let stdev: Double           // residual stdev (used for ±1σ band)
    }

    /// Fit `history` to chosen method, project forward by `horizonMonths`.
    /// `goal` optional — if positive, computes `etaForGoal`.
    static func compute(history: [(Date, Double)],
                        method: ForecastMethod,
                        horizonMonths: Int,
                        goal: Double?) -> Result? {
        guard history.count >= 2 else { return nil }
        let sorted = history.sorted { $0.0 < $1.0 }
        let t0 = sorted.first!.0
        let xs = sorted.map { $0.0.timeIntervalSince(t0) / 86_400 }   // days
        let ys = sorted.map { $0.1 }

        // Build fit.
        let fitFn: (Double) -> Double
        var slopePerDay: Double? = nil
        var cagrPct: Double? = nil

        switch method {
        case .linear:
            let (m, b) = ols(xs: xs, ys: ys)
            slopePerDay = m
            fitFn = { x in m * x + b }
        case .cagr:
            // Fit log(y) = m*x + b on positive ys; reject if any y <= 0.
            let positive = ys.allSatisfy { $0 > 0 }
            if positive {
                let logs = ys.map { Foundation.log($0) }
                let (m, b) = ols(xs: xs, ys: logs)
                cagrPct = (Foundation.exp(m * 365) - 1) * 100
                fitFn = { x in Foundation.exp(m * x + b) }
            } else {
                // Fall back to linear if values include zero / negative.
                let (m, b) = ols(xs: xs, ys: ys)
                slopePerDay = m
                fitFn = { x in m * x + b }
            }
        }

        // Residuals.
        let predicted = xs.map { fitFn($0) }
        let resid = zip(ys, predicted).map { $0 - $1 }
        let mean = resid.reduce(0, +) / Double(resid.count)
        let variance = resid.map { pow($0 - mean, 2) }.reduce(0, +) / Double(max(1, resid.count - 1))
        let stdev = sqrt(variance)

        // Sampled fit at history points.
        let fit: [Point] = zip(sorted, predicted).map { item, pred in
            Point(date: item.0, value: pred, lower: pred - stdev, upper: pred + stdev)
        }

        // Project forward at monthly steps.
        let cal = Calendar.current
        let lastDate = sorted.last!.0
        let endDate = cal.date(byAdding: .month, value: max(1, horizonMonths), to: lastDate) ?? lastDate
        var projection: [Point] = []
        var d = lastDate
        while d <= endDate {
            let x = d.timeIntervalSince(t0) / 86_400
            let v = fitFn(x)
            projection.append(Point(date: d, value: v, lower: v - stdev, upper: v + stdev))
            guard let next = cal.date(byAdding: .month, value: 1, to: d) else { break }
            d = next
        }

        // ETA to goal.
        var etaForGoal: Date?
        if let g = goal, g > 0, let last = ys.last, g > last {
            switch method {
            case .linear:
                if let m = slopePerDay, m > 0 {
                    let bIntercept = ys.last! - m * xs.last!
                    let xGoal = (g - bIntercept) / m
                    etaForGoal = t0.addingTimeInterval(xGoal * 86_400)
                }
            case .cagr:
                if let cagr = cagrPct, cagr > 0, let lastY = ys.last, lastY > 0 {
                    let m = log(1 + cagr / 100) / 365  // per day
                    let lastX = xs.last!
                    let xGoal = lastX + log(g / lastY) / m
                    etaForGoal = t0.addingTimeInterval(xGoal * 86_400)
                }
            }
        }

        let historyTuples = sorted.map { (date: $0.0, value: $0.1) }
        return Result(history: historyTuples,
                      fit: fit,
                      projection: projection,
                      etaForGoal: etaForGoal,
                      cagrPct: cagrPct,
                      slopePerDay: slopePerDay,
                      stdev: stdev)
    }

    /// Ordinary least squares — returns (slope, intercept).
    private static func ols(xs: [Double], ys: [Double]) -> (Double, Double) {
        let n = Double(xs.count)
        let xMean = xs.reduce(0, +) / n
        let yMean = ys.reduce(0, +) / n
        var num = 0.0, den = 0.0
        for i in 0..<xs.count {
            num += (xs[i] - xMean) * (ys[i] - yMean)
            den += pow(xs[i] - xMean, 2)
        }
        let slope = den == 0 ? 0 : num / den
        let intercept = yMean - slope * xMean
        return (slope, intercept)
    }
}
