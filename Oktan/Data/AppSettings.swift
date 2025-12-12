import Foundation
import SwiftUI

/// Observable app settings stored in UserDefaults
@Observable
final class AppSettings {
    // MARK: - Unit Settings
    
    enum DistanceUnit: String, CaseIterable, Identifiable {
        case kilometers = "km"
        case miles = "mi"
        
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .kilometers: return String(localized: "Kilometers")
            case .miles: return String(localized: "Miles")
            }
        }
    }
    
    enum VolumeUnit: String, CaseIterable, Identifiable {
        case liters = "L"
        case gallons = "gal"
        
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .liters: return String(localized: "Liters")
            case .gallons: return String(localized: "Gallons (US)")
            }
        }
    }
    
    enum EfficiencyUnit: String, CaseIterable, Identifiable {
        case litersPer100km = "L/100km"
        case kmPerLiter = "km/L"
        case mpg = "MPG"
        
        var id: String { rawValue }
        var displayName: String { rawValue }
    }
    
    enum AppLanguage: String, CaseIterable, Identifiable {
        case system = "system"
        case english = "en"
        case turkish = "tr"
        
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .system: return String(localized: "System Default")
            case .english: return "English"
            case .turkish: return "Türkçe"
            }
        }
    }
    
    // MARK: - Supported Currencies
    
    static let supportedCurrencies: [(code: String, name: String, symbol: String)] = [
        ("QAR", "Qatari Riyal", "﷼"),
        ("TRY", "Turkish Lira", "₺"),
        ("USD", "US Dollar", "$"),
        ("EUR", "Euro", "€"),
        ("GBP", "British Pound", "£"),
        ("AED", "UAE Dirham", "د.إ"),
        ("SAR", "Saudi Riyal", "﷼")
    ]
    
    // MARK: - Properties
    
    var currencyCode: String {
        didSet { UserDefaults.standard.set(currencyCode, forKey: "currencyCode") }
    }
    
    var distanceUnit: DistanceUnit {
        didSet { UserDefaults.standard.set(distanceUnit.rawValue, forKey: "distanceUnit") }
    }
    
    var volumeUnit: VolumeUnit {
        didSet { UserDefaults.standard.set(volumeUnit.rawValue, forKey: "volumeUnit") }
    }
    
    var efficiencyUnit: EfficiencyUnit {
        didSet { UserDefaults.standard.set(efficiencyUnit.rawValue, forKey: "efficiencyUnit") }
    }
    
    var showSplashAnimation: Bool {
        didSet { UserDefaults.standard.set(showSplashAnimation, forKey: "showSplashAnimation") }
    }
    
    var appLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(appLanguage.rawValue, forKey: "appLanguage")
            applyLanguage()
        }
    }
    
    // MARK: - Initialization
    
    init() {
        self.currencyCode = UserDefaults.standard.string(forKey: "currencyCode") ?? "QAR"
        self.distanceUnit = DistanceUnit(rawValue: UserDefaults.standard.string(forKey: "distanceUnit") ?? "") ?? .kilometers
        self.volumeUnit = VolumeUnit(rawValue: UserDefaults.standard.string(forKey: "volumeUnit") ?? "") ?? .liters
        self.efficiencyUnit = EfficiencyUnit(rawValue: UserDefaults.standard.string(forKey: "efficiencyUnit") ?? "") ?? .litersPer100km
        self.showSplashAnimation = UserDefaults.standard.object(forKey: "showSplashAnimation") as? Bool ?? true
        self.appLanguage = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "") ?? .system
    }
    
    // MARK: - Language
    
    private func applyLanguage() {
        switch appLanguage {
        case .system:
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        case .english:
            UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
        case .turkish:
            UserDefaults.standard.set(["tr"], forKey: "AppleLanguages")
        }
    }
    
    // MARK: - Conversion Helpers
    
    /// Converts km to the current distance unit
    func formatDistance(_ km: Double) -> String {
        switch distanceUnit {
        case .kilometers:
            return "\(km.formatted(.number.precision(.fractionLength(0)))) km"
        case .miles:
            let miles = km * 0.621371
            return "\(miles.formatted(.number.precision(.fractionLength(0)))) mi"
        }
    }
    
    /// Converts liters to the current volume unit
    func formatVolume(_ liters: Double) -> String {
        switch volumeUnit {
        case .liters:
            return "\(liters.formatted(.number.precision(.fractionLength(1)))) L"
        case .gallons:
            let gallons = liters * 0.264172
            return "\(gallons.formatted(.number.precision(.fractionLength(1)))) gal"
        }
    }
    
    /// Converts L/100km to the current efficiency unit (raw value for charts)
    func convertEfficiency(_ litersPer100km: Double) -> Double {
        switch efficiencyUnit {
        case .litersPer100km:
            return litersPer100km
        case .kmPerLiter:
            return 100.0 / litersPer100km
        case .mpg:
            return 235.215 / litersPer100km
        }
    }
    
    /// Converts L/100km to the current efficiency unit (formatted string)
    func formatEfficiency(_ litersPer100km: Double) -> String {
        let value = convertEfficiency(litersPer100km)
        switch efficiencyUnit {
        case .litersPer100km:
            return "\(value.formatted(.number.precision(.fractionLength(2)))) L/100km"
        case .kmPerLiter:
            return "\(value.formatted(.number.precision(.fractionLength(1)))) km/L"
        case .mpg:
            return "\(value.formatted(.number.precision(.fractionLength(1)))) MPG"
        }
    }
    
    /// Formats cost with current currency
    func formatCost(_ amount: Double) -> String {
        amount.formatted(.currency(code: currencyCode))
    }
    
    /// Converts cost per km to cost per current distance unit (raw value)
    func convertCostPerDistance(_ costPerKm: Double) -> Double {
        switch distanceUnit {
        case .kilometers:
            return costPerKm
        case .miles:
            return costPerKm / 0.621371  // cost per mile
        }
    }
    
    /// Formats cost per distance with current currency and distance unit
    func formatCostPerDistance(_ costPerKm: Double) -> String {
        let value = convertCostPerDistance(costPerKm)
        return "\(value.formatted(.number.precision(.fractionLength(3)))) \(currencyCode)/\(distanceUnit.rawValue)"
    }
}
