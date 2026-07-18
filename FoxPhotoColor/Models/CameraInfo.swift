import Foundation

/// Capture-time camera details pulled from EXIF/GPS — feeds the Moment Card
/// metadata block. All fields optional; screenshots and stripped files have
/// none. Foundation-only so the macOS metadata self-check can compile it.
struct CameraInfo: Codable, Equatable {
    var model: String?
    var fNumber: Double?
    var exposureSeconds: Double?
    var iso: Int?
    /// GPS altitude in meters (negative = below sea level).
    var altitude: Double?
    /// Compass heading of the camera at capture, degrees 0-360.
    var headingDegrees: Double?

    var isEmpty: Bool {
        model == nil && fNumber == nil && exposureSeconds == nil
            && iso == nil && altitude == nil && headingDegrees == nil
    }
}
