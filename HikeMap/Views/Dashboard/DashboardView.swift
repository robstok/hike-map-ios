import SwiftUI

struct DashboardView: View {
    @ObservedObject var store: RouteStore
    @Environment(\.dismiss) private var dismiss

    private var stats: RouteStore.AllTimeStats { store.allTimeStats }

    var body: some View {
        NavigationStack {
            ScrollView {
                if store.routes.isEmpty {
                    ContentUnavailableView(
                        "No Hikes Yet",
                        systemImage: "figure.hiking",
                        description: Text("Import your first GPX file to see all-time stats")
                    )
                    .padding(.top, 60)
                } else {
                    VStack(spacing: 16) {
                        // Hike badge
                        HStack {
                            Spacer()
                            Label("\(stats.hikeCount) hike\(stats.hikeCount == 1 ? "" : "s")", systemImage: "mountain.2.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Config.accent.opacity(0.2), in: Capsule())
                                .foregroundStyle(Config.accent)
                            Spacer()
                        }

                        // Main stats grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            BigStatCard(
                                icon: "arrow.left.and.right",
                                label: "Total Distance",
                                value: formatDistance(stats.totalDistanceKm),
                                color: Config.accent
                            )
                            BigStatCard(
                                icon: "mountain.2.fill",
                                label: "Total Hikes",
                                value: "\(stats.hikeCount)",
                                color: .blue
                            )
                            BigStatCard(
                                icon: "figure.walk",
                                label: "Moving Time",
                                value: formatDuration(stats.totalMovingSec),
                                color: .green
                            )
                            BigStatCard(
                                icon: "pause.circle",
                                label: "Rest Time",
                                value: formatDuration(stats.totalRestSec),
                                color: Color(hex: "#F59E0B")
                            )
                        }

                        // Moving time bar
                        if stats.totalMovingSec + stats.totalRestSec > 0 {
                            let total = stats.totalMovingSec + stats.totalRestSec
                            let frac  = stats.totalMovingSec / total
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Time breakdown")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                GeometryReader { geo in
                                    HStack(spacing: 0) {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.green)
                                            .frame(width: geo.size.width * frac)
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color(hex: "#F59E0B"))
                                            .frame(maxWidth: .infinity)
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                .frame(height: 12)
                                HStack {
                                    Circle().fill(.green).frame(width: 8, height: 8)
                                    Text("Moving \(Int(frac * 100))%")
                                        .font(.system(size: 11)).foregroundStyle(.secondary)
                                    Spacer()
                                    Circle().fill(Color(hex: "#F59E0B")).frame(width: 8, height: 8)
                                    Text("Rest \(Int((1 - frac) * 100))%")
                                        .font(.system(size: 11)).foregroundStyle(.secondary)
                                }
                            }
                            .padding(12)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                        }

                        // Personal records
                        if let ms = stats.maxSpeedRoute {
                            PRCard(
                                emoji: "⚡",
                                title: "Max Speed",
                                value: String(format: "%.1f km/h", ms.speed),
                                subtitle: ms.routeName
                            )
                        }
                        if let lr = stats.longestRoute {
                            PRCard(
                                emoji: "🥾",
                                title: "Longest Hike",
                                value: String(format: "%.1f km", lr.distKm),
                                subtitle: lr.routeName
                            )
                        }
                    }
                    .padding(16)
                }
            }
            .background(Color(hex: "#0d1117"))
            .navigationTitle("All-Time Stats")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Config.accent)
                }
            }
        }
    }

    private func formatDistance(_ km: Double) -> String {
        if km >= 1_000 { return String(format: "%.1f Mm", km / 1_000) }
        return String(format: "%.0f km", km)
    }
}

struct BigStatCard: View {
    let icon: String
    let label: String
    let value: String
    var color: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.primary)
                .monospacedDigit()
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.07), lineWidth: 1))
    }
}

struct PRCard: View {
    let emoji: String
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Text(emoji)
                .font(.system(size: 28))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.07), lineWidth: 1))
    }
}
