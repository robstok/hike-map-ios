import Foundation
import SwiftUI
import CoreLocation

struct RouteData {
    let coordinates: [CLLocationCoordinate2D]
    let cumulativeDistances: [Double]   // km, same count as coordinates
    let elevations: [Double]            // metres
    let totalDistanceKm: Double
    let elevationGainM: Double
    let elevationLossM: Double
    let maxElevation: Double
    let minElevation: Double
    let bounds: (sw: CLLocationCoordinate2D, ne: CLLocationCoordinate2D)?

    /// Downsampled for chart rendering (≤500 points)
    var chartPoints: [(distance: Double, elevation: Double)] {
        let step = max(1, cumulativeDistances.count / 500)
        return stride(from: 0, to: cumulativeDistances.count, by: step).map {
            (cumulativeDistances[$0], elevations[$0])
        }
    }
}

struct Route: Identifiable {
    let id: UUID
    var name: String
    let color: Color
    let points: [GPXPoint]
    let routeData: RouteData
    let analytics: SpeedAnalytics
    var isVisible: Bool = true
    let createdAt: Date

    // DB-persisted fields
    var dbId: String?   // server-side UUID string
    var hikeDate: String? { // YYYY-MM-DD derived from first point timestamp
        points.first?.timestamp.map { DateFormatter.hikeDateFormatter.string(from: $0) }
    }
}

extension DateFormatter {
    static let hikeDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
