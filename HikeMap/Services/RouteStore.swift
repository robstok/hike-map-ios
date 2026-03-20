import SwiftUI
import CoreLocation

/// Central in-memory store for routes and photos — the iOS equivalent of routes.js + db.js.
@MainActor
final class RouteStore: ObservableObject {
    @Published var routes: [Route] = []
    @Published var photos: [PhotoItem] = []
    @Published var activeRouteId: UUID?
    @Published var isLoading = false
    @Published var toasts: [Toast] = []

    private let supabaseService: SupabaseService
    private let parser = GPXParser()

    init(supabaseService: SupabaseService) {
        self.supabaseService = supabaseService
    }

    // MARK: — Active route

    var activeRoute: Route? {
        routes.first { $0.id == activeRouteId }
    }

    func activate(_ route: Route) {
        activeRouteId = route.id
    }

    // MARK: — GPX loading

    func processGPXFile(url: URL, userId: String) async {
        guard url.startAccessingSecurityScopedResource() else {
            showToast("Cannot access file", type: .error)
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try Data(contentsOf: url)
            try await processGPXData(data: data, filename: url.deletingPathExtension().lastPathComponent, userId: userId)
        } catch {
            showToast("Failed to load GPX: \(error.localizedDescription)", type: .error)
        }
    }

    func processGPXData(data: Data, filename: String, userId: String) async throws {
        let (name, points) = try parser.parse(data: data)
        guard !points.isEmpty else { throw NSError(domain: "RouteStore", code: 2,
            userInfo: [NSLocalizedDescriptionKey: "GPX file has no track points"]) }

        let finalName = name.isEmpty ? filename : name
        let color = Config.trailColors[routes.count % Config.trailColors.count]
        let routeData = buildRouteData(points: points)
        let analytics = AnalyticsService.calculate(points: points)

        let route = Route(
            id: UUID(),
            name: finalName,
            color: color,
            points: points,
            routeData: routeData,
            analytics: analytics,
            createdAt: Date()
        )
        routes.append(route)
        activeRouteId = route.id
        showToast("Loaded \(finalName)", type: .success)

        // Persist to Supabase in background
        Task {
            do {
                try await supabaseService.saveRoute(route, gpxData: data, userId: userId)
            } catch {
                showToast("Couldn't save route: \(error.localizedDescription)", type: .error)
            }
        }
    }

    // MARK: — Saved routes

    func loadSavedRoutes(userId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let records = try await supabaseService.loadRoutes(userId: userId)
            for record in records {
                guard !routes.contains(where: { $0.id.uuidString == record.id }) else { continue }
                if let data = record.gpx_content.data(using: .utf8) {
                    if let (name, points) = try? parser.parse(data: data), !points.isEmpty {
                        let color = Color(hex: record.color)
                        let routeData = buildRouteData(points: points)
                        let analytics = AnalyticsService.calculate(points: points)
                        var route = Route(
                            id: UUID(uuidString: record.id) ?? UUID(),
                            name: record.name,
                            color: color,
                            points: points,
                            routeData: routeData,
                            analytics: analytics,
                            createdAt: Date()
                        )
                        route.dbId = record.id
                        routes.append(route)
                    }
                }
            }
        } catch {
            showToast("Couldn't load saved routes", type: .error)
        }
    }

    // MARK: — Load saved photos

    func loadSavedPhotos(userId: String) async {
        do {
            let records = try await supabaseService.loadPhotos()
            var loaded = 0
            for record in records {
                guard !photos.contains(where: { $0.dbId == record.id }),
                      let dataURL = record.photo_data,
                      let image = imageFromDataURL(dataURL)
                else { continue }

                let routeId = record.route_id.flatMap { UUID(uuidString: $0) }
                let coord = CLLocationCoordinate2D(latitude: record.lat, longitude: record.lon)
                let photoTime: Date? = record.photo_time.flatMap {
                    ISO8601DateFormatter().date(from: $0)
                }
                photos.append(PhotoItem(
                    id: UUID(uuidString: record.id) ?? UUID(),
                    image: image,
                    coordinate: coord,
                    photoTime: photoTime,
                    originalFilename: record.name,
                    routeId: routeId,
                    dbId: record.id
                ))
                loaded += 1
            }
            if loaded > 0 {
                showToast("\(loaded) photo\(loaded == 1 ? "" : "s") restored", type: .success)
            }
        } catch {
            showToast("Couldn't load photos: \(error.localizedDescription)", type: .error)
        }
    }

    private func imageFromDataURL(_ dataURL: String) -> UIImage? {
        let base64 = dataURL.components(separatedBy: ",").last ?? dataURL
        guard let data = Data(base64Encoded: base64) else { return nil }
        return UIImage(data: data)
    }

    // MARK: — Route management

    func removeRoute(_ route: Route) {
        routes.removeAll { $0.id == route.id }
        if activeRouteId == route.id { activeRouteId = nil }
        photos.removeAll { $0.routeId == route.id }

        if let dbId = route.dbId {
            Task { try? await supabaseService.deleteRoute(id: dbId) }
        }
    }

    func clearAll() {
        let dbIds = routes.compactMap(\.dbId)
        routes = []
        photos = []
        activeRouteId = nil
        for id in dbIds {
            Task { try? await supabaseService.deleteRoute(id: id) }
        }
    }

    func renameRoute(_ route: Route, to name: String) {
        if let idx = routes.firstIndex(where: { $0.id == route.id }) {
            routes[idx].name = name
        }
        if let dbId = route.dbId {
            Task { try? await supabaseService.updateRouteName(id: dbId, name: name) }
        }
    }

    func toggleVisibility(_ route: Route) {
        if let idx = routes.firstIndex(where: { $0.id == route.id }) {
            routes[idx].isVisible.toggle()
        }
    }

    // MARK: — Photos

    func addPhoto(imageData: Data, image: UIImage, filename: String, userId: String) async {
        guard let meta = PhotoService.extractMetadata(from: imageData) else {
            showToast("No GPS data found in photo", type: .error)
            return
        }
        let routeId = PhotoService.matchRoute(coordinate: meta.coordinate, routes: routes)
        var photo = PhotoItem(
            id: UUID(),
            image: image,
            coordinate: meta.coordinate,
            photoTime: meta.date,
            originalFilename: filename,
            routeId: routeId
        )
        photos.append(photo)
        if routeId == nil {
            showToast("Photo added but didn't match any route", type: .info)
        }

        Task {
            do {
                try await supabaseService.savePhoto(photo, routeId: routeId, userId: userId, imageData: imageData)
                showToast("Photo saved", type: .success)
            } catch {
                showToast("DB photo save error: \(error.localizedDescription)", type: .error)
            }
        }
    }

    func removePhoto(_ photo: PhotoItem) {
        photos.removeAll { $0.id == photo.id }
        if let dbId = photo.dbId {
            Task { try? await supabaseService.deletePhoto(id: dbId) }
        }
    }

    // MARK: — Toasts

    func showToast(_ message: String, type: Toast.ToastType) {
        let toast = Toast(id: UUID(), message: message, type: type)
        toasts.append(toast)
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            toasts.removeAll { $0.id == toast.id }
        }
    }
}

// MARK: — Dashboard stats

extension RouteStore {
    struct AllTimeStats {
        let totalDistanceKm: Double
        let hikeCount: Int
        let totalMovingSec: Double
        let totalRestSec: Double
        let maxSpeedRoute: (speed: Double, routeName: String)?
        let longestRoute: (distKm: Double, routeName: String)?
    }

    var allTimeStats: AllTimeStats {
        let totalDist = routes.reduce(0.0) { $0 + $1.routeData.totalDistanceKm }
        let totalMoving = routes.reduce(0.0) { $0 + $1.analytics.movingTimeSec }
        let totalRest = routes.reduce(0.0) { $0 + $1.analytics.restTimeSec }

        let maxSpeedRoute = routes.max(by: { $0.analytics.maxSpeedKmh < $1.analytics.maxSpeedKmh })
            .map { ($0.analytics.maxSpeedKmh, $0.name) }
        let longestRoute = routes.max(by: { $0.routeData.totalDistanceKm < $1.routeData.totalDistanceKm })
            .map { ($0.routeData.totalDistanceKm, $0.name) }

        return AllTimeStats(
            totalDistanceKm: totalDist,
            hikeCount: routes.count,
            totalMovingSec: totalMoving,
            totalRestSec: totalRest,
            maxSpeedRoute: maxSpeedRoute,
            longestRoute: longestRoute
        )
    }
}
