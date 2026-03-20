import Foundation
import CoreLocation

enum AnalyticsService {
    /// Port of the web app's calculateSpeedAnalytics() — handles both smart
    /// recorders (gaps on stop) and constant recorders (Garmin etc.).
    static func calculate(points: [GPXPoint]) -> SpeedAnalytics {
        // Need at least two timestamped points
        let timed = points.filter { $0.timestamp != nil }
        guard timed.count >= 2 else { return .zero }

        // Build segments: (distance m, elapsed s, speed km/h)
        var segments: [(distM: Double, timeSec: Double, speedKmh: Double)] = []
        for i in 1..<timed.count {
            let prev = timed[i - 1], curr = timed[i]
            let distM = haversineMetres(prev.coordinate, curr.coordinate)
            let timeSec = curr.timestamp!.timeIntervalSince(prev.timestamp!)
            guard timeSec > 0 else { continue }
            let speedKmh = (distM / 1000.0) / (timeSec / 3600.0)
            segments.append((distM, timeSec, speedKmh))
        }
        guard !segments.isEmpty else { return .zero }

        // Detect gap rests (smart recorders pause recording)
        let medianGap = segments.map(\.timeSec).sorted()[segments.count / 2]
        let gapThreshold = max(medianGap * 3, Config.restMinSeconds)

        // Rolling-average smoothing for constant recorders
        let window = Config.rollingWindowSize
        let smoothedSpeeds: [Double] = segments.indices.map { i in
            let lo = max(0, i - window / 2)
            let hi = min(segments.count - 1, i + window / 2)
            let slice = segments[lo...hi]
            return slice.map(\.speedKmh).reduce(0, +) / Double(slice.count)
        }

        var movingSec = 0.0, restSec = 0.0
        var allMovingSpeeds: [Double] = []

        for (i, seg) in segments.enumerated() {
            let isGapRest = seg.timeSec >= gapThreshold && seg.distM < Config.restThresholdMetres
            let isSlowRest = smoothedSpeeds[i] < Config.minMovingSpeedKMH

            if isGapRest || isSlowRest {
                restSec += seg.timeSec
            } else {
                movingSec += seg.timeSec
                allMovingSpeeds.append(seg.speedKmh)
            }
        }

        // 98th-percentile max speed (avoids GPS spikes)
        let maxSpeed: Double
        if allMovingSpeeds.isEmpty {
            maxSpeed = 0
        } else {
            let sorted = allMovingSpeeds.sorted()
            let idx = Int(Double(sorted.count - 1) * 0.98)
            maxSpeed = sorted[idx]
        }

        let avgSpeed = allMovingSpeeds.isEmpty ? 0
            : allMovingSpeeds.reduce(0, +) / Double(allMovingSpeeds.count)

        return SpeedAnalytics(
            movingTimeSec: movingSec,
            restTimeSec: restSec,
            maxSpeedKmh: maxSpeed,
            avgMovingSpeedKmh: avgSpeed
        )
    }
}

// MARK: — Haversine

func haversineMetres(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
    let R = 6_371_000.0
    let φ1 = a.latitude  * .pi / 180
    let φ2 = b.latitude  * .pi / 180
    let Δφ = (b.latitude  - a.latitude)  * .pi / 180
    let Δλ = (b.longitude - a.longitude) * .pi / 180
    let x = sin(Δφ/2) * sin(Δφ/2) + cos(φ1) * cos(φ2) * sin(Δλ/2) * sin(Δλ/2)
    return R * 2 * atan2(sqrt(x), sqrt(1 - x))
}

// MARK: — Route geometry

func buildRouteData(points: [GPXPoint]) -> RouteData {
    guard !points.isEmpty else {
        return RouteData(coordinates: [], cumulativeDistances: [], elevations: [],
                        totalDistanceKm: 0, elevationGainM: 0, elevationLossM: 0,
                        maxElevation: 0, minElevation: 0, bounds: nil)
    }

    var coords: [CLLocationCoordinate2D] = []
    var dists:  [Double] = []
    var eles:   [Double] = []
    var gain = 0.0, loss = 0.0
    var cumDist = 0.0

    for (i, pt) in points.enumerated() {
        coords.append(pt.coordinate)
        eles.append(pt.elevation)
        if i > 0 {
            cumDist += haversineMetres(points[i-1].coordinate, pt.coordinate) / 1000.0
            let eleDiff = pt.elevation - points[i-1].elevation
            if eleDiff > 0.5  { gain += eleDiff }
            if eleDiff < -0.5 { loss -= eleDiff }
        }
        dists.append(cumDist)
    }

    let eleMin = eles.min() ?? 0
    let eleMax = eles.max() ?? 0

    let lats = coords.map(\.latitude)
    let lons = coords.map(\.longitude)
    let bounds: (CLLocationCoordinate2D, CLLocationCoordinate2D)? = coords.isEmpty ? nil : (
        CLLocationCoordinate2D(latitude: lats.min()!, longitude: lons.min()!),
        CLLocationCoordinate2D(latitude: lats.max()!, longitude: lons.max()!)
    )

    return RouteData(
        coordinates: coords,
        cumulativeDistances: dists,
        elevations: eles,
        totalDistanceKm: cumDist,
        elevationGainM: gain,
        elevationLossM: loss,
        maxElevation: eleMax,
        minElevation: eleMin,
        bounds: bounds
    )
}
