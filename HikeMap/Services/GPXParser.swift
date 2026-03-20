import Foundation
import CoreLocation

final class GPXParser: NSObject, XMLParserDelegate {
    private var points: [GPXPoint] = []
    private var routeName = ""

    // element tracking
    private var currentElement = ""
    private var inTrackPoint = false
    private var inName = false
    private var currentLat: Double = 0
    private var currentLon: Double = 0
    private var currentEleText = ""
    private var currentTimeText = ""
    private var currentNameText = ""

    // Shared ISO8601 parser
    private static let isoParser: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoParserNoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    func parse(data: Data) throws -> (name: String, points: [GPXPoint]) {
        points = []
        routeName = ""
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else {
            throw parser.parserError ?? NSError(domain: "GPXParser", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to parse GPX"])
        }
        return (routeName, points)
    }

    // MARK: — XMLParserDelegate

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String] = [:]
    ) {
        currentElement = elementName.lowercased()

        switch currentElement {
        case "trkpt", "rtept", "wpt":
            inTrackPoint = true
            currentLat = Double(attributes["lat"] ?? "") ?? 0
            currentLon = Double(attributes["lon"] ?? "") ?? 0
            currentEleText = ""
            currentTimeText = ""
        case "name":
            if !inTrackPoint { inName = true; currentNameText = "" }
        default: break
        }
    }

    func parser(
        _ parser: XMLParser,
        foundCharacters string: String
    ) {
        let s = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return }

        if inTrackPoint {
            switch currentElement {
            case "ele":  currentEleText  += s
            case "time": currentTimeText += s
            default: break
            }
        } else if inName {
            currentNameText += s
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?
    ) {
        let el = elementName.lowercased()

        switch el {
        case "trkpt", "rtept", "wpt":
            guard inTrackPoint else { return }
            let point = GPXPoint(
                coordinate: CLLocationCoordinate2D(latitude: currentLat, longitude: currentLon),
                elevation: Double(currentEleText) ?? 0,
                timestamp: parseDate(currentTimeText)
            )
            points.append(point)
            inTrackPoint = false

        case "name":
            if inName && routeName.isEmpty {
                routeName = currentNameText.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            inName = false

        default: break
        }
    }

    private func parseDate(_ string: String) -> Date? {
        guard !string.isEmpty else { return nil }
        return Self.isoParser.date(from: string)
            ?? Self.isoParserNoFrac.date(from: string)
    }
}
