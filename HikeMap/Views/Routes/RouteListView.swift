import SwiftUI
import UniformTypeIdentifiers

struct RouteListView: View {
    @ObservedObject var store: RouteStore
    let userId: String
    @Binding var showFilePicker: Bool
    @Binding var showPhotoPicker: Bool

    /// Routes sorted newest-first, grouped by year
    private var groupedRoutes: [(year: String, routes: [Route])] {
        let sorted = store.routes.sorted { a, b in
            routeSortKey(a) > routeSortKey(b)
        }
        var byYear: [String: [Route]] = [:]
        for route in sorted {
            let year = routeYear(route)
            byYear[year, default: []].append(route)
        }
        return byYear.keys.sorted(by: >).map { year in (year, byYear[year]!) }
    }

    var body: some View {
        List {
            if store.routes.isEmpty {
                ContentUnavailableView {
                    Label("No Routes", systemImage: "map.fill")
                } description: {
                    Text("Import a GPX file to get started")
                }
                .listRowBackground(Color.clear)
            } else {
                // Clear all header
                Section {
                    EmptyView()
                } header: {
                    HStack {
                        Text("\(store.routes.count) route\(store.routes.count == 1 ? "" : "s")")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Spacer()
                        Button("Clear All") { store.clearAll() }
                            .font(.system(size: 11))
                            .foregroundStyle(Color(hex: "#EF4444"))
                    }
                }
                .listRowInsets(EdgeInsets())

                // One section per year
                ForEach(groupedRoutes, id: \.year) { group in
                    Section {
                        ForEach(group.routes) { route in
                            RouteRow(route: route, store: store, userId: userId)
                        }
                    } header: {
                        Text(group.year)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button {
                    showFilePicker = true
                } label: {
                    Label("Import GPX", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Config.accent)

                Button {
                    showPhotoPicker = true
                } label: {
                    Label("Add Photos", systemImage: "photo.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Config.accent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: — Helpers

    private func routeSortKey(_ route: Route) -> String {
        route.hikeDate
            ?? DateFormatter.hikeDateFormatter.string(from: route.createdAt)
    }

    private func routeYear(_ route: Route) -> String {
        let key = routeSortKey(route)
        return key.count >= 4 ? String(key.prefix(4)) : "Unknown"
    }
}

// MARK: — Individual route row

struct RouteRow: View {
    let route: Route
    @ObservedObject var store: RouteStore
    let userId: String

    @State private var isRenaming = false
    @State private var newName = ""

    var isActive: Bool { store.activeRouteId == route.id }

    var body: some View {
        HStack(spacing: 12) {
            // Colour swatch + visibility toggle
            Button {
                store.toggleVisibility(route)
            } label: {
                Circle()
                    .fill(route.isVisible ? route.color : route.color.opacity(0.25))
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)

            // Name
            if isRenaming {
                TextField("Route name", text: $newName, onCommit: {
                    if !newName.isEmpty { store.renameRoute(route, to: newName) }
                    isRenaming = false
                })
                .font(.system(size: 13))
                .textFieldStyle(.plain)
            } else {
                Button {
                    store.activate(route)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(route.name)
                            .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                            .foregroundStyle(isActive ? Config.accent : .primary)
                            .lineLimit(1)
                        if let date = route.hikeDate {
                            Text(formatDate(date))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Distance badge
            Text(String(format: "%.1f km", route.routeData.totalDistanceKm))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()

            // Delete
            Button {
                store.removeRoute(route)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
        .listRowBackground(isActive ? Config.accent.opacity(0.08) : Color.clear)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { store.removeRoute(route) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                newName = route.name
                isRenaming = true
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            .tint(Config.accent)
        }
        .contextMenu {
            Button { store.activate(route) } label: { Label("Show Stats", systemImage: "chart.bar") }
            Button { newName = route.name; isRenaming = true } label: { Label("Rename", systemImage: "pencil") }
            Button { store.toggleVisibility(route) } label: {
                Label(route.isVisible ? "Hide Route" : "Show Route",
                      systemImage: route.isVisible ? "eye.slash" : "eye")
            }
            Divider()
            Button(role: .destructive) { store.removeRoute(route) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func formatDate(_ yyyy_mm_dd: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        guard let date = f.date(from: yyyy_mm_dd) else { return yyyy_mm_dd }
        let out = DateFormatter()
        out.dateStyle = .medium
        out.timeStyle = .none
        return out.string(from: date)
    }
}

import CoreLocation
