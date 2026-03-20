import SwiftUI
import Charts

struct ElevationChartView: View {
    let route: Route
    /// Notifies parent of the geographic coordinate at the hovered distance
    var onHover: ((CLLocationCoordinate2D?) -> Void)?

    @State private var selectedDistance: Double?

    private var chartPoints: [(distance: Double, elevation: Double)] {
        route.routeData.chartPoints
    }

    private var minEle: Double { route.routeData.minElevation }
    private var maxEle: Double { route.routeData.maxElevation }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Stats row
            HStack(spacing: 16) {
                statPill(icon: "arrow.up.right", value: "\(Int(route.routeData.elevationGainM)) m", color: .green)
                statPill(icon: "arrow.down.right", value: "\(Int(route.routeData.elevationLossM)) m", color: .red)
                statPill(icon: "point.topleft.down.curvedto.point.bottomright.up", value: String(format: "%.1f km", route.routeData.totalDistanceKm), color: Config.accent)
            }

            // Chart
            Chart {
                ForEach(Array(chartPoints.enumerated()), id: \.offset) { _, pt in
                    AreaMark(
                        x: .value("Distance", pt.distance),
                        yStart: .value("Min", minEle),
                        yEnd: .value("Elevation", pt.elevation)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [route.color.opacity(0.5), route.color.opacity(0.05)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Distance", pt.distance),
                        y: .value("Elevation", pt.elevation)
                    )
                    .foregroundStyle(route.color)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }

                // Crosshair rule
                if let sd = selectedDistance {
                    RuleMark(x: .value("Selected", sd))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .annotation(position: .top) {
                            if let ele = elevation(at: sd) {
                                Text("\(Int(ele)) m")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
                            }
                        }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine().foregroundStyle(.white.opacity(0.1))
                    AxisTick().foregroundStyle(.white.opacity(0.3))
                    AxisValueLabel {
                        if let d = value.as(Double.self) {
                            Text(String(format: "%.1f", d))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine().foregroundStyle(.white.opacity(0.1))
                    AxisValueLabel {
                        if let e = value.as(Double.self) {
                            Text("\(Int(e))")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartYScale(domain: (minEle - 20)...(maxEle + 50))
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let x = value.location.x - geo.frame(in: .local).minX
                                    if let dist: Double = proxy.value(atX: x) {
                                        selectedDistance = dist
                                        onHover?(coordinate(at: dist))
                                    }
                                }
                                .onEnded { _ in
                                    selectedDistance = nil
                                    onHover?(nil)
                                }
                        )
                }
            }
            .frame(height: 120)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    // MARK: — Helpers

    private func statPill(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15), in: Capsule())
    }

    private func elevation(at distance: Double) -> Double? {
        guard let idx = nearestIndex(distance: distance) else { return nil }
        return chartPoints[idx].elevation
    }

    private func coordinate(at distance: Double) -> CLLocationCoordinate2D? {
        guard !route.routeData.cumulativeDistances.isEmpty else { return nil }
        // Binary search for closest cumulative distance in full track
        let dists = route.routeData.cumulativeDistances
        var lo = 0, hi = dists.count - 1
        while lo < hi {
            let mid = (lo + hi) / 2
            if dists[mid] < distance { lo = mid + 1 } else { hi = mid }
        }
        return route.routeData.coordinates[lo]
    }

    private func nearestIndex(distance: Double) -> Int? {
        guard !chartPoints.isEmpty else { return nil }
        return chartPoints.indices.min(by: { abs(chartPoints[$0].distance - distance) < abs(chartPoints[$1].distance - distance) })
    }
}

// CLLocationCoordinate2D needs to be imported for the return type
import CoreLocation
