import SwiftUI
import UniformTypeIdentifiers

struct RouteListView: View {
    @ObservedObject var store: RouteStore
    let userId: String
    @Binding var showFilePicker: Bool
    @Binding var showPhotoPicker: Bool

    var body: some View {
        List {
            Section {
                ForEach(store.routes) { route in
                    RouteRow(route: route, store: store, userId: userId)
                }
                .onDelete { offsets in
                    offsets.forEach { store.removeRoute(store.routes[$0]) }
                }
            } header: {
                HStack {
                    Text("Routes (\(store.routes.count))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Spacer()
                    if !store.routes.isEmpty {
                        Button("Clear All") { store.clearAll() }
                            .font(.system(size: 11))
                            .foregroundStyle(Color(hex: "#EF4444"))
                    }
                }
            }

            if store.routes.isEmpty {
                ContentUnavailableView {
                    Label("No Routes", systemImage: "map.fill")
                } description: {
                    Text("Import a GPX file to get started")
                }
                .listRowBackground(Color.clear)
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

            // Name (tap to rename, tap to activate)
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
                    Text(route.name)
                        .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                        .foregroundStyle(isActive ? Config.accent : .primary)
                        .lineLimit(1)
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
}

import CoreLocation
