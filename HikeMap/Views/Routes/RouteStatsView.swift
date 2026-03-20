import SwiftUI

struct RouteStatsView: View {
    let route: Route
    @ObservedObject var store: RouteStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Route name + colour
                HStack {
                    Circle()
                        .fill(route.color)
                        .frame(width: 12, height: 12)
                    Text(route.name)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(2)
                }

                // Distance & elevation
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    StatCard(icon: "arrow.left.and.right", label: "Distance",
                             value: String(format: "%.2f km", route.routeData.totalDistanceKm))
                    StatCard(icon: "arrow.up.right", label: "Elevation Gain",
                             value: "\(Int(route.routeData.elevationGainM)) m", color: .green)
                    StatCard(icon: "arrow.down.right", label: "Elevation Loss",
                             value: "\(Int(route.routeData.elevationLossM)) m", color: .red)
                    StatCard(icon: "mountain.2.fill", label: "Max Altitude",
                             value: "\(Int(route.routeData.maxElevation)) m")
                }

                Divider().overlay(.white.opacity(0.1))

                // Speed & time analytics
                if route.analytics.totalTimeSec > 0 {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        StatCard(icon: "figure.walk", label: "Moving Time",
                                 value: route.analytics.movingTimeFormatted, color: .green)
                        StatCard(icon: "pause.circle", label: "Rest Time",
                                 value: route.analytics.restTimeFormatted, color: Color(hex: "#F59E0B"))
                        StatCard(icon: "bolt.fill", label: "Max Speed",
                                 value: String(format: "%.1f km/h", route.analytics.maxSpeedKmh), color: Config.accent)
                        StatCard(icon: "speedometer", label: "Avg Speed",
                                 value: String(format: "%.1f km/h", route.analytics.avgMovingSpeedKmh))
                    }

                    // Moving time bar
                    let total = route.analytics.totalTimeSec
                    let movFraction = route.analytics.movingTimeSec / max(total, 1)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Time breakdown")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        GeometryReader { geo in
                            HStack(spacing: 0) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.green)
                                    .frame(width: geo.size.width * movFraction)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(hex: "#F59E0B"))
                                    .frame(maxWidth: .infinity)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .frame(height: 8)
                        HStack {
                            Circle().fill(.green).frame(width: 8, height: 8)
                            Text("Moving \(Int(movFraction * 100))%").font(.system(size: 10)).foregroundStyle(.secondary)
                            Spacer()
                            Circle().fill(Color(hex: "#F59E0B")).frame(width: 8, height: 8)
                            Text("Rest \(Int((1 - movFraction) * 100))%").font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                    }
                }

                // Hike date
                if let date = route.hikeDate {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Text(date)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
        }
    }
}

struct StatCard: View {
    let icon: String
    let label: String
    let value: String
    var color: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .monospacedDigit()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.07), lineWidth: 1))
    }
}
