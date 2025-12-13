import Foundation
import CoreLocation
import MapKit
import UserNotifications

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    
    private let manager = CLLocationManager()
    var currentLocation: CLLocation?
    var permissionStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters // Don't need super high precision for gas stations
    }
    
    func requestPermission() {
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
        print("Location Manager Error: \(error)")
    }
    
    // MARK: - Smart Refuel Logic
    
    /// Triggered when CarPlay disconnects
    func checkForGasStation() {
        print("CarPlay Disconnected: Checking for gas stations...")
        
        // Ensure we have permission
        guard manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways else {
            print("Location permission not granted for Smart Refuel.")
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
                print("Could not determine location.")
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
                let itemLocation = firstMatch.placemark.location
                let distance = itemLocation?.distance(from: location) ?? 1000
                
                print("Nearest Gas Station: \(firstMatch.name ?? "Unknown") at \(Int(distance))m")
                
                if distance < 150 { // If within 150 meters
                    sendRefuelNotification(stationName: firstMatch.name)
                }
            }
        } catch {
            print("Gas Station Search Failed: \(error)")
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
