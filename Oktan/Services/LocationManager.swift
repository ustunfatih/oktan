import Foundation
import CoreLocation
import MapKit
import OSLog
import UserNotifications

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    private let logger = Logger(subsystem: "com.oktan.app", category: "Location")
    
    private let manager = CLLocationManager()
    var currentLocation: CLLocation?
    var permissionStatus: CLAuthorizationStatus = .notDetermined
    var smartRefuelEnabled: Bool {
        didSet {
            UserDefaults.standard.set(smartRefuelEnabled, forKey: "smartRefuelEnabled")
        }
    }
    
    override init() {
        self.smartRefuelEnabled = UserDefaults.standard.bool(forKey: "smartRefuelEnabled")
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters // Don't need super high precision for gas stations
        permissionStatus = manager.authorizationStatus
    }
    
    func requestPermission() {
        // When-in-use is sufficient: the Smart Refuel check runs right after the
        // CarPlay scene disconnects, within the app's foreground grace period.
        manager.requestWhenInUseAuthorization()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        permissionStatus = manager.authorizationStatus
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        self.currentLocation = loc
        // If we were creating a one-off request, stop updating to save battery
        manager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        logger.error("Location update failed: \(error.localizedDescription, privacy: .private)")
    }
    
    // MARK: - Smart Refuel Logic
    
    /// Triggered when CarPlay disconnects
    func checkForGasStation() {
        guard smartRefuelEnabled else { return }
        logger.debug("Smart Refuel location check started")
        
        // Ensure we have permission
        guard manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways else {
            logger.notice("Smart Refuel skipped because location is not authorized")
            return
        }
        
        // Request fresh location
        manager.startUpdatingLocation()
        
        // We give it a few seconds to get a fix, then search.
        // In background context, this must happen quickly.
        Task {
            // Wait briefly for location update
            try? await Task.sleep(for: .seconds(2))
            
            guard let location = manager.location ?? currentLocation else {
                logger.notice("Smart Refuel could not obtain a location")
                return
            }
            
            await searchForGasStation(near: location)
        }
    }
    
    private func searchForGasStation(near location: CLLocation) async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "Gas Station"
        request.region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 500, longitudinalMeters: 500)
        
        let search = MKLocalSearch(request: request)
        
        do {
            let response = try await search.start()
            // If we find a gas station within ~100-200 meters
            if let firstMatch = response.mapItems.first {
                // Calculate actual distance
                let itemLocation = firstMatch.location
                let distance = itemLocation.distance(from: location)
                
                if distance < 150 { // If within 150 meters
                    sendRefuelNotification(stationName: firstMatch.name)
                }
            }
        } catch {
            logger.error("Gas-station search failed: \(error.localizedDescription, privacy: .private)")
        }
        
        manager.stopUpdatingLocation()
    }
    
    private func sendRefuelNotification(stationName: String?) {
        let content = UNMutableNotificationContent()
        content.title = "Refueling?"
        content.body = "Detected stop at \(stationName ?? "Gas Station"). Tap to log."
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: "smart_refuel_nudge", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
