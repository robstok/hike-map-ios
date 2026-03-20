import MapLibre
import CoreLocation
import SwiftUI

@MainActor
final class MapCoordinator: NSObject, MLNMapViewDelegate {
    let store: RouteStore
    weak var mapView: MLNMapView?

    var renderedRouteIds: [UUID] = []
    var lastIs3DEnabled       = false
    var lastIsSatelliteEnabled = false
    var lastIsHikingEnabled   = false

    // Annotation for hover dot
    private var hoverAnnotation: MLNPointAnnotation?

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
        hillshade.hillshadeHighlightColor = NSExpression(forConstantValue: UIColor.white.withAlphaComponent(0.1))
        // Insert hillshade before labels
        if let firstSymbol = style.layers.first(where: { $0 is MLNSymbolStyleLayer }) {
            style.insertLayer(hillshade, below: firstSymbol)
        } else {
            style.addLayer(hillshade)
        }
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
        casing.lineColor = NSExpression(forConstantValue: UIColor.black.withAlphaComponent(0.4))
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

    func mapView(_ mapView: MLNMapView, imageFor annotation: MLNAnnotation) -> MLNAnnotationImage? {
        // Return a custom orange dot for hover annotation
        let size = CGSize(width: 16, height: 16)
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            UIColor(Config.accent).setFill()
            ctx.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
        }
        return MLNAnnotationImage(image: img, reuseIdentifier: "hover-dot")
    }

    func mapView(_ mapView: MLNMapView, annotationCanShowCallout annotation: MLNAnnotation) -> Bool {
        false
    }

    // MARK: — Tap to select route

    func mapView(_ mapView: MLNMapView, didSelect annotation: MLNAnnotation) {}
}
