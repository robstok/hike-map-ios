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

    // Set after upload
    var storagePath: String?
    var publicURL: String?
    var dbId: String?
}
