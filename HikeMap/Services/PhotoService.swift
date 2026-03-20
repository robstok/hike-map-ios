import Foundation
import UIKit
import CoreLocation
import ImageIO

enum PhotoService {
    /// Extract GPS coordinate and timestamp from image data using ImageIO.
    static func extractMetadata(from data: Data) -> (coordinate: CLLocationCoordinate2D, date: Date?)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let gps = props[kCGImagePropertyGPSDictionary] as? [CFString: Any],
              let lat = gps[kCGImagePropertyGPSLatitude] as? Double,
              let latRef = gps[kCGImagePropertyGPSLatitudeRef] as? String,
              let lon = gps[kCGImagePropertyGPSLongitude] as? Double,
              let lonRef = gps[kCGImagePropertyGPSLongitudeRef] as? String
        else { return nil }

        let finalLat = latRef == "S" ? -lat : lat
        let finalLon = lonRef == "W" ? -lon : lon
        let coord = CLLocationCoordinate2D(latitude: finalLat, longitude: finalLon)

        // Extract EXIF date
        let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let dateStr = exif?[kCGImagePropertyExifDateTimeOriginal] as? String
        let date = dateStr.flatMap { parseExifDate($0) }

        return (coord, date)
    }

    /// Match a photo to the closest route by proximity (< 500 m from any track point).
    static func matchRoute(coordinate: CLLocationCoordinate2D, routes: [Route]) -> UUID? {
        let maxDistM = 500.0
        var bestRouteId: UUID?
        var bestDist = Double.infinity

        for route in routes {
            for pt in route.points {
                let d = haversineMetres(coordinate, pt.coordinate)
                if d < bestDist {
                    bestDist = d
                    bestRouteId = route.id
                }
            }
        }
        return bestDist <= maxDistM ? bestRouteId : nil
    }

    private static func parseExifDate(_ string: String) -> Date? {
        // EXIF format: "YYYY:MM:DD HH:MM:SS"
        let f = DateFormatter()
        f.dateFormat = "yyyy:MM:dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.date(from: string)
    }
}
