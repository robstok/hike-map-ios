import Foundation
import CoreLocation

struct GPXPoint {
    let coordinate: CLLocationCoordinate2D
    let elevation: Double   // metres
    let timestamp: Date?

    var latitude:  Double { coordinate.latitude }
    var longitude: Double { coordinate.longitude }
}
