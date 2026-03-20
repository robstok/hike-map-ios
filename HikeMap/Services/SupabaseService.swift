import Foundation
import UIKit
import Supabase

// MARK: — DB record types (must match Supabase schema)

struct RouteRecord: Codable {
    var id: String
    var user_id: String
    var name: String
    var color: String
    var gpx_content: String
    var stats: RouteStats?
    var hike_date: String?
    var created_at: String?
}

struct RouteStats: Codable {
    var totalDist: Double
    var elevGain: Double
    var movTimeSec: Double
    var rstTimeSec: Double
    var maxSpeedKmh: Double
}

struct PhotoRecord: Codable {
    var id: String
    var user_id: String
    var route_id: String?
    var name: String
    var lat: Double
    var lon: Double
    var photo_time: String?
    var storage_path: String?   // legacy Storage-based path
    var photo_data: String?     // base64 data URL (web app format)
}

// MARK: — Service

final class SupabaseService {
    let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    // MARK: — Routes

    func saveRoute(_ route: Route, gpxData: Data, userId: String) async throws {
        let record = RouteRecord(
            id: route.id.uuidString,
            user_id: userId,
            name: route.name,
            color: route.color.hexString,
            gpx_content: String(data: gpxData, encoding: .utf8) ?? "",
            stats: RouteStats(
                totalDist: route.routeData.totalDistanceKm,
                elevGain: route.routeData.elevationGainM,
                movTimeSec: route.analytics.movingTimeSec,
                rstTimeSec: route.analytics.restTimeSec,
                maxSpeedKmh: route.analytics.maxSpeedKmh
            ),
            hike_date: route.hikeDate
        )
        try await client.from("routes").upsert(record).execute()
    }

    func loadRoutes(userId: String) async throws -> [RouteRecord] {
        try await client.from("routes")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func deleteRoute(id: String) async throws {
        try await client.from("routes")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    func updateRouteName(id: String, name: String) async throws {
        try await client.from("routes")
            .update(["name": name])
            .eq("id", value: id)
            .execute()
    }

    // MARK: — Photos

    func savePhoto(_ photo: PhotoItem, routeId: UUID?, userId: String, imageData: Data) async throws {
        // Compress to JPEG and store as base64 data URL — matches web app format
        let jpeg = UIImage(data: imageData)?
            .jpegData(compressionQuality: 0.82) ?? imageData
        let base64 = "data:image/jpeg;base64," + jpeg.base64EncodedString()

        let isoDate = photo.photoTime.map { ISO8601DateFormatter().string(from: $0) }
        let record = PhotoRecord(
            id: photo.id.uuidString,
            user_id: userId,
            route_id: routeId?.uuidString,
            name: photo.originalFilename,
            lat: photo.coordinate.latitude,
            lon: photo.coordinate.longitude,
            photo_time: isoDate,
            storage_path: nil,
            photo_data: base64
        )
        try await client.from("photos").insert(record).execute()
    }

    func loadPhotos(userId: String) async throws -> [PhotoRecord] {
        try await client.from("photos")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
    }

    func deletePhoto(id: String, storagePath: String) async throws {
        try await client.from("photos").delete().eq("id", value: id).execute()
        try await client.storage.from("photos").remove(paths: [storagePath])
    }

    func photoURL(path: String) async throws -> URL {
        try await client.storage.from("photos").createSignedURL(path: path, expiresIn: 3600)
    }
}
