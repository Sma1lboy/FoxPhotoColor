import Foundation
import ImageIO
import CoreLocation

/// EXIF capture date + GPS pulled straight from the picked image data —
/// no photo-library permission needed.
struct PhotoMetadata {
    var creationDate: Date?
    var coordinate: CLLocationCoordinate2D?
}

enum PhotoMetadataParser {

    static func parse(from data: Data) -> PhotoMetadata {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] else {
            return PhotoMetadata()
        }

        var date: Date?
        if let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any],
           let raw = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy:MM:dd HH:mm:ss"
            fmt.locale = Locale(identifier: "en_US_POSIX")
            fmt.timeZone = .current
            // Wall-clock strings can land in a DST spring-forward gap; lenient
            // parsing keeps the photo's time instead of nil-ing out.
            fmt.isLenient = true
            date = fmt.date(from: raw)
        }

        var coordinate: CLLocationCoordinate2D?
        if let gps = props[kCGImagePropertyGPSDictionary] as? [CFString: Any],
           let lat = gps[kCGImagePropertyGPSLatitude] as? Double,
           let lon = gps[kCGImagePropertyGPSLongitude] as? Double {
            let latRef = gps[kCGImagePropertyGPSLatitudeRef] as? String ?? "N"
            let lonRef = gps[kCGImagePropertyGPSLongitudeRef] as? String ?? "E"
            coordinate = CLLocationCoordinate2D(latitude: latRef == "S" ? -lat : lat,
                                                longitude: lonRef == "W" ? -lon : lon)
        }

        return PhotoMetadata(creationDate: date, coordinate: coordinate)
    }

    /// Reverse-geocode to a poster-worthy place name, most specific first
    /// (point of interest → neighborhood → city → region → country).
    static func placeName(for coordinate: CLLocationCoordinate2D) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first else {
            return nil
        }
        return placemark.areasOfInterest?.first
            ?? placemark.subLocality
            ?? placemark.locality
            ?? placemark.administrativeArea
            ?? placemark.country
    }
}
