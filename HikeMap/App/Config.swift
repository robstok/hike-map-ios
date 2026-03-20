import SwiftUI
import CoreLocation

enum Config {
    // MARK: — Supabase
    static let supabaseURL    = "https://hhtcmtozzehiualfcksn.supabase.co"
    static let supabaseAnonKey = "sb_publishable_tIVuDKuz8ngzUIVfDojI-Q_-sIpxvDi"

    // MARK: — Map
    static let mapStyleURL     = "https://tiles.openfreemap.org/styles/liberty"
    static let terrainTileURL  = "https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png"
    static let hikingTilesURL  = "https://tile.waymarkedtrails.org/hiking/{z}/{x}/{y}.png"
    static let satelliteTileURL = "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}"

    static let initialCenter   = CLLocationCoordinate2D(latitude: 46.8, longitude: 8.2)
    static let initialZoom     = 7.0
    static let terrainExaggeration = 1.5

    // MARK: — Analytics
    static let minMovingSpeedKMH: Double = 0.8
    static let restThresholdMetres: Double = 10
    static let restMinSeconds: Double = 60
    static let rollingWindowSize = 5

    // MARK: — Trail colours (matches web app)
    static let trailColors: [Color] = [
        Color(hex: "#4ECDC4"),
        Color(hex: "#45B7D1"),
        Color(hex: "#96CEB4"),
        Color(hex: "#F7DC6F"),
        Color(hex: "#BB8FCE"),
        Color(hex: "#F19066"),
        Color(hex: "#6C5CE7"),
    ]

    // MARK: — UI
    static let accent = Color(hex: "#FF6B2B")
}

// MARK: — Colour helpers
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        let int = UInt64(hex, radix: 16) ?? 0
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double( int        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    var hexString: String {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r*255), Int(g*255), Int(b*255))
    }
}
