import SwiftUI
import MapLibre
import CoreLocation

// MARK: — SwiftUI wrapper around MLNMapView

struct MapLibreView: UIViewRepresentable {
    @ObservedObject var store: RouteStore
    /// Coordinate to show a hover/crosshair dot (driven by elevation chart)
    @Binding var hoverCoordinate: CLLocationCoordinate2D?
    @Binding var is3DEnabled: Bool
    @Binding var isSatelliteEnabled: Bool
    @Binding var isHikingLayerEnabled: Bool

    func makeCoordinator() -> MapCoordinator {
        MapCoordinator(store: store)
    }

    func makeUIView(context: Context) -> MLNMapView {
        let mapView = MLNMapView(frame: .zero, styleURL: URL(string: Config.mapStyleURL))
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.delegate = context.coordinator
        mapView.compassView.isHidden = false
        mapView.logoView.isHidden = true
        mapView.attributionButton.isHidden = true

        // Default camera
        mapView.setCenter(Config.initialCenter, zoomLevel: Config.initialZoom, animated: false)
        mapView.minimumZoomLevel = 2
        mapView.maximumZoomLevel = 22
        mapView.maximumPitch = 85

        context.coordinator.mapView = mapView
        return mapView
    }

    func updateUIView(_ mapView: MLNMapView, context: Context) {
        let coord = context.coordinator

        // Sync 3D pitch + OSM base layer visibility (2D = OSM raster, 3D = hillshade)
        if is3DEnabled != coord.lastIs3DEnabled {
            coord.lastIs3DEnabled = is3DEnabled
            let camera = mapView.camera.copy() as! MLNMapCamera
            camera.pitch = is3DEnabled ? 60 : 0
            mapView.setCamera(camera, withDuration: 0.5, animationTimingFunction: nil)
            coord.setOSMBaseVisible(!is3DEnabled, on: mapView)
        }

        // Sync satellite layer
        if isSatelliteEnabled != coord.lastIsSatelliteEnabled {
            coord.lastIsSatelliteEnabled = isSatelliteEnabled
            coord.setSatelliteVisible(isSatelliteEnabled, on: mapView)
        }

        // Sync hiking overlay
        if isHikingLayerEnabled != coord.lastIsHikingEnabled {
            coord.lastIsHikingEnabled = isHikingLayerEnabled
            coord.setHikingLayerVisible(isHikingLayerEnabled, on: mapView)
        }

        // Sync routes (add new, remove deleted)
        let renderedIds = Set(coord.renderedRouteIds)
        let storeIds    = Set(store.routes.map(\.id))

        for removed in renderedIds.subtracting(storeIds) {
            coord.removeRouteLayer(id: removed, from: mapView)
        }
        for route in store.routes where !renderedIds.contains(route.id) {
            coord.addRouteLayer(route: route, to: mapView)
        }

        // Visibility sync
        for route in store.routes {
            coord.setRouteVisible(route.id, visible: route.isVisible, on: mapView)
        }

        // Fit map to active route when selection changes
        if store.activeRouteId != coord.lastActiveRouteId {
            coord.lastActiveRouteId = store.activeRouteId
            if let route = store.activeRoute, let bounds = route.routeData.bounds {
                coord.fitBounds(bounds, on: mapView)
            }
        }

        // Hover dot
        if let hc = hoverCoordinate {
            coord.updateHoverDot(coordinate: hc, on: mapView)
        } else {
            coord.removeHoverDot(from: mapView)
        }
    }
}
