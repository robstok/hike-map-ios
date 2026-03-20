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

// Columns returned by SELECT — matches web app schema exactly
struct PhotoRecord: Codable {
    var id: String
    var route_id: String?
    var name: String
    var lat: Double
    var lon: Double
    var photo_time: String?
    var photo_data: String?
}

// Separate struct for INSERT — includes user_id, excludes storage_path
private struct PhotoInsert: Encodable {
    var id: String
    var user_id: String
    var route_id: String?
    var name: String
    var lat: Double
    var lon: Double
    var photo_time: String?
    var photo_data: String
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
        let jpeg = UIImage(data: imageData)?.jpegData(compressionQuality: 0.82) ?? imageData
        let base64 = "data:image/jpeg;base64," + jpeg.base64EncodedString()
        let isoDate = photo.photoTime.map { ISO8601DateFormatter().string(from: $0) }

        let record = PhotoInsert(
            id: photo.id.uuidString,
            user_id: userId,
            route_id: routeId?.uuidString,
            name: photo.originalFilename,
            lat: photo.coordinate.latitude,
            lon: photo.coordinate.longitude,
            photo_time: isoDate,
            photo_data: base64
        )
        try await client.from("photos").insert(record).execute()
    }

    func loadPhotos() async throws -> [PhotoRecord] {
        // RLS filters to the authenticated user — no explicit user_id filter needed
        // Column list matches web app exactly (no storage_path)
        try await client.from("photos")
            .select("id, route_id, name, lat, lon, photo_time, photo_data")
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    func deletePhoto(id: String) async throws {
        try await client.from("photos").delete().eq("id", value: id).execute()
    }
}
