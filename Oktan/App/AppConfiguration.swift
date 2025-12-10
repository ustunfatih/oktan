import Foundation

/// App-wide configuration values
enum AppConfiguration {
    /// The currency code used for displaying costs
    /// Change this value to support different currencies (e.g., "USD", "EUR", "GBP")
    static let currencyCode = "QAR"

    /// The locale identifier for formatting
    static let localeIdentifier = "en_QA"
}

extension FormatStyle where Self == FloatingPointFormatStyle<Double>.Currency {
    /// A currency format style using the app's configured currency
    static var appCurrency: FloatingPointFormatStyle<Double>.Currency {
        .currency(code: AppConfiguration.currencyCode)
    }
}
