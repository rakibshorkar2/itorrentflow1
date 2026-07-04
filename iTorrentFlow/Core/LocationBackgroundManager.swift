import Foundation
import CoreLocation

// MARK: - Location Background Manager
/// Uses significant location changes to keep the app alive in background
public final class LocationBackgroundManager: NSObject, CLLocationManagerDelegate {
    public static let shared = LocationBackgroundManager()
    private let manager = CLLocationManager()
    private var isUpdating = false

    private override init() {
        super.init()
        manager.delegate = self
        manager.distanceFilter = 500
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = true
    }

    public func requestAuthorization() {
        manager.requestAlwaysAuthorization()
    }

    public func start() {
        guard !isUpdating else { return }
        isUpdating = true
        manager.startUpdatingLocation()
    }

    public func stop() {
        guard isUpdating else { return }
        isUpdating = false
        manager.stopUpdatingLocation()
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse {
            if isUpdating { manager.startUpdatingLocation() }
        }
    }
}
