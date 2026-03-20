import Foundation

struct SpeedAnalytics {
    let movingTimeSec: Double
    let restTimeSec: Double
    let maxSpeedKmh: Double
    let avgMovingSpeedKmh: Double

    var movingTimeFormatted: String { formatDuration(movingTimeSec) }
    var restTimeFormatted:   String { formatDuration(restTimeSec) }
    var totalTimeSec: Double { movingTimeSec + restTimeSec }

    static let zero = SpeedAnalytics(
        movingTimeSec: 0, restTimeSec: 0, maxSpeedKmh: 0, avgMovingSpeedKmh: 0
    )
}

func formatDuration(_ seconds: Double) -> String {
    guard seconds > 0 else { return "—" }
    let s = Int(seconds)
    let h = s / 3600
    let m = (s % 3600) / 60
    let sec = s % 60
    if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
    return String(format: "%d:%02d", m, sec)
}
