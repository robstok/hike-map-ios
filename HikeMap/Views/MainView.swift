import SwiftUI
import UniformTypeIdentifiers
import CoreLocation

struct MainView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var store: RouteStore

    // Layer toggles
    @State private var is3DEnabled   = true
    @State private var isSatellite   = false
    @State private var isHiking      = false

    // Hover sync: elevation chart → map dot
    @State private var hoverCoordinate: CLLocationCoordinate2D?

    // Sheet / modal states
    @State private var showRouteList   = false
    @State private var showFilePicker  = false
    @State private var showPhotoPicker = false
    @State private var showDashboard   = false
    @State private var showStats       = false

    // Sidebar (iPad) / sheet (iPhone)
    @Environment(\.horizontalSizeClass) private var hSizeClass

    init(supabaseService: SupabaseService) {
        _store = StateObject(wrappedValue: RouteStore(supabaseService: supabaseService))
    }

    private var userId: String { appState.currentUser?.id.uuidString ?? "" }

    var body: some View {
        ZStack {
            if hSizeClass == .regular {
                // iPad: side-by-side
                iPadLayout
            } else {
                // iPhone: map + floating controls
                iPhoneLayout
            }

            // Toast overlay
            VStack {
                Spacer()
                ToastStack(toasts: store.toasts)
            }
            .allowsHitTesting(false)
        }
        .task {
            await store.loadSavedRoutes(userId: userId)
            await store.loadSavedPhotos(userId: userId)
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [
                UTType(filenameExtension: "gpx") ?? .xml,
                .xml
            ],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                for url in urls {
                    Task { await store.processGPXFile(url: url, userId: userId) }
                }
            case .failure(let error):
                store.showToast("File error: \(error.localizedDescription)", type: .error)
            }
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPickerView(store: store, userId: userId)
        }
        .sheet(isPresented: $showDashboard) {
            DashboardView(store: store)
        }
        .sheet(isPresented: $showStats) {
            if let route = store.activeRoute {
                NavigationStack {
                    VStack(alignment: .leading, spacing: 0) {
                        ElevationChartView(route: route) { coord in
                            hoverCoordinate = coord
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        RouteStatsView(route: route, store: store)
                    }
                    .navigationTitle(route.name)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showStats = false }
                                .fontWeight(.semibold)
                                .foregroundStyle(Config.accent)
                        }
                    }
                    .background(Color(hex: "#0d1117"))
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: — iPad layout

    private var iPadLayout: some View {
        NavigationSplitView {
            sidebarContent
                .navigationTitle("Hitrekk")
                .toolbar { iPadToolbar }
        } detail: {
            mapWithOverlays
        }
    }

    // MARK: — iPhone layout

    private var iPhoneLayout: some View {
        ZStack(alignment: .bottom) {
            mapWithOverlays

            // Floating buttons (top-right)
            VStack(spacing: 10) {
                mapControlButton(icon: is3DEnabled ? "view.3d" : "map", label: "3D") {
                    is3DEnabled.toggle()
                }
                mapControlButton(icon: "globe", label: "Sat") {
                    isSatellite.toggle()
                }
                mapControlButton(icon: "map.fill", label: "Trails") {
                    isHiking.toggle()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.top, 60)
            .padding(.trailing, 12)

            // Bottom bar
            iPhoneBottomBar
        }
        .sheet(isPresented: $showRouteList) {
            RouteListView(store: store, userId: userId,
                         showFilePicker: $showFilePicker,
                         showPhotoPicker: $showPhotoPicker)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var iPhoneBottomBar: some View {
        HStack(spacing: 0) {
            // Routes button
            Button {
                showRouteList = true
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 20))
                    Text("Routes")
                        .font(.system(size: 10))
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(store.routes.isEmpty ? .secondary : Config.accent)
            }

            // Active route stats
            if let route = store.activeRoute {
                Button { showStats = true } label: {
                    HStack(spacing: 6) {
                        Circle().fill(route.color).frame(width: 8, height: 8)
                        Text(route.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                        Spacer()
                        Text(String(format: "%.1f km", route.routeData.totalDistanceKm))
                            .font(.system(size: 11)).foregroundStyle(.secondary).monospacedDigit()
                        Image(systemName: "chevron.up").font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            } else {
                Button { showFilePicker = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill").foregroundStyle(Config.accent)
                        Text("Import GPX").font(.system(size: 13, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }

            // Profile menu (stats + sign out)
            Menu {
                Button { showDashboard = true } label: {
                    Label("All-Time Stats", systemImage: "chart.bar.fill")
                }
                Divider()
                Button(role: .destructive) {
                    Task { try? await appState.signOut() }
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "person.circle")
                        .font(.system(size: 20))
                    Text("Account")
                        .font(.system(size: 10))
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle().fill(.white.opacity(0.08)).frame(height: 0.5)
        }
    }

    // MARK: — Map + overlays

    private var mapWithOverlays: some View {
        MapLibreView(
            store: store,
            hoverCoordinate: $hoverCoordinate,
            is3DEnabled: $is3DEnabled,
            isSatelliteEnabled: $isSatellite,
            isHikingLayerEnabled: $isHiking
        )
        .ignoresSafeArea()
    }

    // MARK: — iPad sidebar

    private var sidebarContent: some View {
        VStack(spacing: 0) {
            // User info
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.displayName)
                        .font(.system(size: 13, weight: .semibold))
                    Text("Signed in").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Task { try? await appState.signOut() }
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Layer toggles
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader("Layers")
                Toggle("3D Terrain", isOn: $is3DEnabled).toggleStyle(.switch).tint(Config.accent)
                Toggle("Satellite", isOn: $isSatellite).toggleStyle(.switch).tint(Config.accent)
                Toggle("Hiking Trails", isOn: $isHiking).toggleStyle(.switch).tint(Config.accent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            RouteListView(store: store, userId: userId,
                         showFilePicker: $showFilePicker,
                         showPhotoPicker: $showPhotoPicker)

            // Elevation chart for active route
            if let route = store.activeRoute {
                Divider()
                ElevationChartView(route: route) { coord in hoverCoordinate = coord }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            }
        }
    }

    @ToolbarContentBuilder
    private var iPadToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { showDashboard = true } label: {
                Image(systemName: "chart.bar.fill")
            }
            .foregroundStyle(Config.accent)
        }
    }

    // MARK: — Helpers

    private func mapControlButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.system(size: 16))
                Text(label).font(.system(size: 9, weight: .medium))
            }
            .frame(width: 44, height: 44)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.1), lineWidth: 1))
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.bottom, 4)
            .padding(.top, 8)
    }
}
