import MapLibre
import CoreLocation
import SwiftUI

@MainActor
final class MapCoordinator: NSObject, MLNMapViewDelegate {
    let store: RouteStore
    weak var mapView: MLNMapView?

    var renderedRouteIds: [UUID] = []
    var lastIs3DEnabled        = false
    var lastIsSatelliteEnabled = false
    var lastIsHikingEnabled    = false
    var lastActiveRouteId: UUID? = nil

    private var hoverAnnotation: MLNPointAnnotation?
    var photoAnnotations: [UUID: PhotoAnnotation] = [:]

    init(store: RouteStore) {
        self.store = store
    }

    // MARK: — Style loaded

    func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
        setupTerrain(style: style, mapView: mapView)
        // Re-add all existing routes after style reload
        renderedRouteIds.removeAll()
        for route in store.routes {
            addRouteLayer(route: route, to: mapView)
        }
    }

    // MARK: — Terrain

    func setupTerrain(style: MLNStyle, mapView: MLNMapView) {
        // OSM raster base — visible in 2D, hidden in 3D (matches web app behaviour)
        let osmSource = MLNRasterTileSource(
            identifier: "osm-base",
            tileURLTemplates: [Config.osmTileURL],
            options: [
                .tileSize: NSNumber(value: 256),
                .attributionInfos: [MLNAttributionInfo(title: NSAttributedString(string: "© OpenStreetMap contributors"), url: URL(string: "https://www.openstreetmap.org/copyright")!)]
            ]
        )
        style.addSource(osmSource)
        let osmLayer = MLNRasterStyleLayer(identifier: "osm-base-layer", source: osmSource)
        osmLayer.rasterOpacity = NSExpression(forConstantValue: 1.0)
        // Start hidden if 3D is on (lastIs3DEnabled defaults to false but 3D starts enabled in UI)
        osmLayer.isVisible = !lastIs3DEnabled
        style.insertLayer(osmLayer, at: 0)

        // DEM hillshade for 3D terrain
        let demSource = MLNRasterDEMSource(
            identifier: "terrain-dem",
            tileURLTemplates: [Config.terrainTileURL],
            options: [
                .minimumZoomLevel: NSNumber(value: 0),
                .maximumZoomLevel: NSNumber(value: 15),
                .tileSize: NSNumber(value: 256)
            ]
        )
        style.addSource(demSource)

        let hillshade = MLNHillshadeStyleLayer(identifier: "hillshade", source: demSource)
        hillshade.hillshadeExaggeration = NSExpression(forConstantValue: NSNumber(value: 0.35))
        hillshade.isVisible = lastIs3DEnabled
        if let firstSymbol = style.layers.first(where: { $0 is MLNSymbolStyleLayer }) {
            style.insertLayer(hillshade, below: firstSymbol)
        } else {
            style.addLayer(hillshade)
        }
    }

    func setOSMBaseVisible(_ visible: Bool, on mapView: MLNMapView) {
        guard let style = mapView.style else { return }
        style.layer(withIdentifier: "osm-base-layer")?.isVisible = visible
        style.layer(withIdentifier: "hillshade")?.isVisible = !visible
    }

    // MARK: — Satellite layer

    func setSatelliteVisible(_ visible: Bool, on mapView: MLNMapView) {
        guard let style = mapView.style else { return }
        let sourceId = "satellite-source"
        let layerId  = "satellite-layer"

        if visible {
            if style.source(withIdentifier: sourceId) == nil {
                let source = MLNRasterTileSource(
                    identifier: sourceId,
                    tileURLTemplates: [Config.satelliteTileURL],
                    options: [.tileSize: NSNumber(value: 256)]
                )
                style.addSource(source)
            }
            if style.layer(withIdentifier: layerId) == nil {
                let layer = MLNRasterStyleLayer(identifier: layerId,
                    source: style.source(withIdentifier: sourceId)!)
                layer.rasterOpacity = NSExpression(forConstantValue: 0.9)
                if let hillshade = style.layer(withIdentifier: "hillshade") {
                    style.insertLayer(layer, above: hillshade)
                } else {
                    style.insertLayer(layer, at: 0)
                }
            }
            style.layer(withIdentifier: layerId)?.isVisible = true
        } else {
            style.layer(withIdentifier: layerId)?.isVisible = false
        }
    }

    // MARK: — Hiking trails overlay

    func setHikingLayerVisible(_ visible: Bool, on mapView: MLNMapView) {
        guard let style = mapView.style else { return }
        let sourceId = "hiking-source"
        let layerId  = "hiking-layer"

        if visible {
            if style.source(withIdentifier: sourceId) == nil {
                let source = MLNRasterTileSource(
                    identifier: sourceId,
                    tileURLTemplates: [Config.hikingTilesURL],
                    options: [.tileSize: NSNumber(value: 256)]
                )
                style.addSource(source)
            }
            if style.layer(withIdentifier: layerId) == nil {
                let layer = MLNRasterStyleLayer(identifier: layerId,
                    source: style.source(withIdentifier: sourceId)!)
                layer.rasterOpacity = NSExpression(forConstantValue: 0.65)
                style.addLayer(layer)
            }
            style.layer(withIdentifier: layerId)?.isVisible = true
        } else {
            style.layer(withIdentifier: layerId)?.isVisible = false
        }
    }

    // MARK: — Route layers

    func addRouteLayer(route: Route, to mapView: MLNMapView) {
        guard let style = mapView.style else { return }
        let coords = route.routeData.coordinates
        guard !coords.isEmpty else { return }

        var clCoords = coords
        let line = MLNPolylineFeature(coordinates: &clCoords, count: UInt(clCoords.count))

        let sourceId = "route-\(route.id)"
        let source = MLNShapeSource(identifier: sourceId, features: [line], options: nil)
        style.addSource(source)

        let uiColor = UIColor(route.color)

        // Glow layer (wide, semi-transparent)
        let glow = MLNLineStyleLayer(identifier: "route-glow-\(route.id)", source: source)
        glow.lineColor = NSExpression(forConstantValue: uiColor.withAlphaComponent(0.3))
        glow.lineWidth = NSExpression(forConstantValue: 14)
        glow.lineBlur  = NSExpression(forConstantValue: 8)
        style.addLayer(glow)

        // Casing (dark border)
        let casing = MLNLineStyleLayer(identifier: "route-casing-\(route.id)", source: source)
        casing.lineColor = NSExpression(forConstantValue: UIColor(red: 0, green: 0, blue: 0, alpha: 0.4))
        casing.lineWidth = NSExpression(forConstantValue: 6)
        casing.lineJoin  = NSExpression(forConstantValue: "round")
        casing.lineCap   = NSExpression(forConstantValue: "round")
        style.addLayer(casing)

        // Main line
        let line2 = MLNLineStyleLayer(identifier: "route-line-\(route.id)", source: source)
        line2.lineColor = NSExpression(forConstantValue: uiColor)
        line2.lineWidth = NSExpression(forConstantValue: 4)
        line2.lineJoin  = NSExpression(forConstantValue: "round")
        line2.lineCap   = NSExpression(forConstantValue: "round")
        style.addLayer(line2)

        renderedRouteIds.append(route.id)

        // Fit bounds if this is the first / only route, or auto-fit
        if let bounds = route.routeData.bounds {
            let sw = CLLocationCoordinate2D(latitude: bounds.sw.latitude - 0.01, longitude: bounds.sw.longitude - 0.01)
            let ne = CLLocationCoordinate2D(latitude: bounds.ne.latitude + 0.01, longitude: bounds.ne.longitude + 0.01)
            let coordBounds = MLNCoordinateBounds(sw: sw, ne: ne)
            mapView.setVisibleCoordinateBounds(coordBounds, edgePadding: UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40), animated: true)
        }
    }

    func fitBounds(_ bounds: (sw: CLLocationCoordinate2D, ne: CLLocationCoordinate2D), on mapView: MLNMapView) {
        let sw = CLLocationCoordinate2D(latitude: bounds.sw.latitude - 0.01, longitude: bounds.sw.longitude - 0.01)
        let ne = CLLocationCoordinate2D(latitude: bounds.ne.latitude + 0.01, longitude: bounds.ne.longitude + 0.01)
        let coordBounds = MLNCoordinateBounds(sw: sw, ne: ne)
        mapView.setVisibleCoordinateBounds(coordBounds,
            edgePadding: UIEdgeInsets(top: 60, left: 40, bottom: 120, right: 40),
            animated: true)
    }

    func removeRouteLayer(id: UUID, from mapView: MLNMapView) {
        guard let style = mapView.style else { return }
        for suffix in ["glow", "casing", "line"] {
            if let layer = style.layer(withIdentifier: "route-\(suffix)-\(id)") {
                style.removeLayer(layer)
            }
        }
        if let source = style.source(withIdentifier: "route-\(id)") {
            style.removeSource(source)
        }
        renderedRouteIds.removeAll { $0 == id }
    }

    func setRouteVisible(_ id: UUID, visible: Bool, on mapView: MLNMapView) {
        guard let style = mapView.style else { return }
        for suffix in ["glow", "casing", "line"] {
            style.layer(withIdentifier: "route-\(suffix)-\(id)")?.isVisible = visible
        }
    }

    // MARK: — Photo annotations

    func addPhotoAnnotation(_ photo: PhotoItem, to mapView: MLNMapView) {
        let ann = PhotoAnnotation(photo: photo)
        ann.coordinate = photo.coordinate
        photoAnnotations[photo.id] = ann
        mapView.addAnnotation(ann)
    }

    func removePhotoAnnotation(id: UUID, from mapView: MLNMapView) {
        guard let ann = photoAnnotations.removeValue(forKey: id) else { return }
        mapView.removeAnnotation(ann)
    }

    // MARK: — Hover dot

    func updateHoverDot(coordinate: CLLocationCoordinate2D, on mapView: MLNMapView) {
        if hoverAnnotation == nil {
            let ann = MLNPointAnnotation()
            hoverAnnotation = ann
            mapView.addAnnotation(ann)
        }
        hoverAnnotation?.coordinate = coordinate
    }

    func removeHoverDot(from mapView: MLNMapView) {
        if let ann = hoverAnnotation {
            mapView.removeAnnotation(ann)
            hoverAnnotation = nil
        }
    }

    // MARK: — Annotation appearance

    func mapView(_ mapView: MLNMapView, viewFor annotation: MLNAnnotation) -> MLNAnnotationView? {
        guard let photoAnn = annotation as? PhotoAnnotation else { return nil }
        let reuseId = "photo-thumb"
        if let reused = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? PhotoAnnotationView {
            reused.configure(with: photoAnn.photo)
            return reused
        }
        let view = PhotoAnnotationView(reuseIdentifier: reuseId)
        view.configure(with: photoAnn.photo)
        return view
    }

    func mapView(_ mapView: MLNMapView, imageFor annotation: MLNAnnotation) -> MLNAnnotationImage? {
        guard !(annotation is PhotoAnnotation) else { return nil }
        let size = CGSize(width: 16, height: 16)
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            UIColor(Config.accent).setFill()
            ctx.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
        }
        return MLNAnnotationImage(image: img, reuseIdentifier: "hover-dot")
    }

    func mapView(_ mapView: MLNMapView, annotationCanShowCallout annotation: MLNAnnotation) -> Bool { false }

    func mapView(_ mapView: MLNMapView, didSelect annotation: MLNAnnotation) {
        guard let photoAnn = annotation as? PhotoAnnotation else { return }
        mapView.deselectAnnotation(annotation, animated: false)
        store.selectedPhoto = photoAnn.photo
    }
}

// MARK: — Photo annotation classes

final class PhotoAnnotation: MLNPointAnnotation {
    let photo: PhotoItem
    init(photo: PhotoItem) { self.photo = photo; super.init() }
    required init?(coder: NSCoder) { fatalError() }
}

final class PhotoAnnotationView: MLNAnnotationView {
    private let imageView = UIImageView()
    private let thumbSize: CGFloat = 40

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: thumbSize, height: thumbSize)
        imageView.frame = bounds
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 6
        imageView.layer.borderWidth = 1.5
        imageView.layer.borderColor = UIColor.white.cgColor
        addSubview(imageView)
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.4
        layer.shadowRadius = 4
        layer.shadowOffset = CGSize(width: 0, height: 2)
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with photo: PhotoItem) {
        imageView.image = photo.image
    }
}
