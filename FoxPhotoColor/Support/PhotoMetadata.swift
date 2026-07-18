import Foundation
import ImageIO
import CoreLocation

/// EXIF capture date + GPS pulled straight from the picked image data —
/// no photo-library permission needed.
struct PhotoMetadata {
    var creationDate: Date?
    var coordinate: CLLocationCoordinate2D?
    var camera: CameraInfo?
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
        var camera = CameraInfo()
        if let gps = props[kCGImagePropertyGPSDictionary] as? [CFString: Any] {
            if let lat = gps[kCGImagePropertyGPSLatitude] as? Double,
               let lon = gps[kCGImagePropertyGPSLongitude] as? Double {
                let latRef = gps[kCGImagePropertyGPSLatitudeRef] as? String ?? "N"
                let lonRef = gps[kCGImagePropertyGPSLongitudeRef] as? String ?? "E"
                coordinate = CLLocationCoordinate2D(latitude: latRef == "S" ? -lat : lat,
                                                    longitude: lonRef == "W" ? -lon : lon)
            }
            if let alt = gps[kCGImagePropertyGPSAltitude] as? Double {
                let belowSea = (gps[kCGImagePropertyGPSAltitudeRef] as? Int) == 1
                camera.altitude = belowSea ? -alt : alt
            }
            camera.headingDegrees = gps[kCGImagePropertyGPSImgDirection] as? Double
        }
        if let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            camera.model = tiff[kCGImagePropertyTIFFModel] as? String
        }
        if let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            camera.fNumber = exif[kCGImagePropertyExifFNumber] as? Double
            camera.exposureSeconds = exif[kCGImagePropertyExifExposureTime] as? Double
            camera.iso = (exif[kCGImagePropertyExifISOSpeedRatings] as? [Int])?.first
        }

        return PhotoMetadata(creationDate: date, coordinate: coordinate,
                             camera: camera.isEmpty ? nil : camera)
    }

    /// Two-level place name like the reference poster: "San Francisco Bay
    /// Trail · Richmond" — the most specific name, a middle dot, then the
    /// city. Falls back to a single level when only one is known.
    static func placeName(for coordinate: CLLocationCoordinate2D) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first else {
            return nil
        }
        let specific = placemark.areasOfInterest?.first ?? placemark.subLocality
        let city = placemark.locality ?? placemark.administrativeArea
        if let specific, let city, specific != city {
            return "\(specific) · \(city)"
        }
        return specific ?? city ?? placemark.country
    }
}
