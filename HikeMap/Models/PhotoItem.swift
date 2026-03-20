import Foundation
import CoreLocation
import UIKit

struct PhotoItem: Identifiable {
    let id: UUID
    let image: UIImage
    let coordinate: CLLocationCoordinate2D
    let photoTime: Date?
    let originalFilename: String
    var routeId: UUID?

    var dbId: String?
}
