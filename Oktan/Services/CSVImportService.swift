import Foundation
import UniformTypeIdentifiers

/// Service for importing fuel data from CSV files
enum CSVImportService {

    private nonisolated static let maximumFileSize = 10 * 1_024 * 1_024
    private nonisolated static let maximumRows = 50_000
    
    // MARK: - Types
    
    /// Result of parsing a CSV file
    struct ParseResult: Sendable {
        let headers: [String]
        let rows: [[String]]
        let totalRows: Int
        
        var isEmpty: Bool { rows.isEmpty }
    }
    
    /// Field mapping from CSV columns to FuelEntry properties
    struct FieldMapping {
        var dateColumn: Int?
        var odometerStartColumn: Int?
        var odometerEndColumn: Int?
        var litersColumn: Int?
        var pricePerLiterColumn: Int?
        var gasStationColumn: Int?
        var driveModeColumn: Int?
        var isFullRefillColumn: Int?
        var notesColumn: Int?
        
        /// Date format to use for parsing
        var dateFormat: String = "yyyy-MM-dd"
        
        /// Whether to use comma or period as decimal separator
        var useCommaDecimal: Bool = false
        
        var isValid: Bool {
            dateColumn != nil && litersColumn != nil && pricePerLiterColumn != nil
        }
    }
    
    /// Import preview entry
    struct PreviewEntry: Identifiable {
        let id = UUID()
        let rowNumber: Int
        let date: Date?
        let odometerStart: Double?
        let odometerEnd: Double?
        let liters: Double?
        let pricePerLiter: Double?
        let gasStation: String?
        let driveMode: FuelEntry.DriveMode?
        let isFullRefill: Bool
        let notes: String?
        let isValid: Bool
        let errors: [String]
        
        func toFuelEntry() -> FuelEntry? {
            guard isValid,
                  let date = date,
                  let liters = liters,
                  let price = pricePerLiter else { return nil }
            
            return FuelEntry(
                date: date,
                odometerStart: odometerStart,
                odometerEnd: odometerEnd,
                totalLiters: liters,
                pricePerLiter: price,
                gasStation: gasStation ?? "Unknown",
                driveMode: driveMode ?? .normal,
                isFullRefill: isFullRefill,
                notes: notes
            )
        }
    }
    
    /// Import result
    struct ImportResult {
        let successCount: Int
        let failedCount: Int
        let duplicateCount: Int
        let errors: [String]
        
        var isFullSuccess: Bool { failedCount == 0 && duplicateCount == 0 }
    }

    private struct DuplicateKey: Hashable {
        let day: Date
        let liters: Int
        let price: Int
        let odometerEnd: Int?
        let station: String

        init(_ entry: FuelEntry, calendar: Calendar = .current) {
            day = calendar.startOfDay(for: entry.date)
            liters = Int((entry.totalLiters * 1_000).rounded())
            price = Int((entry.pricePerLiter * 1_000).rounded())
            odometerEnd = entry.odometerEnd.map { Int($0.rounded()) }
            station = entry.gasStation.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
    }
    
    // MARK: - CSV Parsing
    
    /// Parses a CSV file from URL
    nonisolated static func parseCSV(from url: URL) throws -> ParseResult {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        if let fileSize = values.fileSize, fileSize > maximumFileSize {
            throw OktanError.importFailed(reason: "The CSV file exceeds the 10 MB limit")
        }
        let content = try String(contentsOf: url, encoding: .utf8)
        let result = parseCSV(content: content)
        if result.totalRows > maximumRows {
            throw OktanError.importFailed(reason: "The CSV file exceeds the 50,000 row limit")
        }
        return result
    }
    
    /// Parses CSV content string
    nonisolated static func parseCSV(content: String) -> ParseResult {
        var rows: [[String]] = []
        var headers: [String] = []
        
        var parsedRows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var index = content.startIndex

        while index < content.endIndex {
            let character = content[index]
            let nextIndex = content.index(after: index)

            if character == "\"" {
                if inQuotes, nextIndex < content.endIndex, content[nextIndex] == "\"" {
                    field.append("\"")
                    index = content.index(after: nextIndex)
                    continue
                }
                inQuotes.toggle()
            } else if character == ",", !inQuotes {
                row.append(field.trimmingCharacters(in: .whitespaces))
                field = ""
            } else if character.isNewline, !inQuotes {
                // Swift folds "\r\n" into one Character, so CRLF files land
                // here exactly once per line break.
                row.append(field.trimmingCharacters(in: .whitespaces))
                field = ""
                if !row.allSatisfy({ $0.isEmpty }) {
                    parsedRows.append(row)
                }
                row = []
            } else {
                field.append(character)
            }
            index = nextIndex
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field.trimmingCharacters(in: .whitespaces))
            if !row.allSatisfy({ $0.isEmpty }) {
                parsedRows.append(row)
            }
        }

        if let first = parsedRows.first {
            headers = first
            rows = Array(parsedRows.dropFirst())
        }

        return ParseResult(headers: headers, rows: rows, totalRows: rows.count)
    }
    
    // MARK: - Field Mapping Suggestions
    
    /// Exact header names (lowercased) from Oktan's own export format and the
    /// documented sample CSV. These take precedence over fuzzy matching so a
    /// round-trip (export -> import) always maps correctly.
    private static let exactHeaderFields: [String: WritableKeyPath<FieldMapping, Int?>] = [
        "date": \.dateColumn,
        "odometer_start": \.odometerStartColumn,
        "odometer_pre": \.odometerStartColumn,
        "odometer_end": \.odometerEndColumn,
        "odometer_post": \.odometerEndColumn,
        "total_liters": \.litersColumn,
        "total_litres": \.litersColumn,
        "price_per_liter": \.pricePerLiterColumn,
        "price_per_litre": \.pricePerLiterColumn,
        "full_refill": \.isFullRefillColumn,
        "full_depot": \.isFullRefillColumn,
        "drive_mode": \.driveModeColumn,
        "gas_station": \.gasStationColumn,
        "notes": \.notesColumn
    ]

    /// Suggests field mappings based on header names.
    /// Exact known headers are matched first; fuzzy matching then only fills
    /// columns that are still unmapped (so derived columns like "Cost_per_KM"
    /// can't steal the price field).
    static func suggestMapping(for headers: [String]) -> FieldMapping {
        var mapping = FieldMapping()

        // Lowercase + strip diacritics so Turkish headers match reliably
        // ("İstasyon".lowercased() produces a combining dot that defeats
        // plain contains(); folding maps ü/ş/ç to ascii). Dotless ı is a
        // standalone letter, not a diacritic, so it needs an explicit map.
        let normalizedHeaders = headers.map {
            $0.lowercased()
                .folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US_POSIX"))
                .replacingOccurrences(of: "\u{0131}", with: "i")
                .trimmingCharacters(in: .whitespaces)
        }
        var consumedColumns = Set<Int>()

        // Pass 1: exact matches from the known export/sample vocabulary
        for (index, header) in normalizedHeaders.enumerated() {
            if let field = Self.exactHeaderFields[header], mapping[keyPath: field] == nil {
                mapping[keyPath: field] = index
                consumedColumns.insert(index)
            }
        }

        // Pass 2: fuzzy matches for anything still unmapped
        for (index, header) in normalizedHeaders.enumerated() {
            guard !consumedColumns.contains(index) else { continue }

            // Date column
            if mapping.dateColumn == nil, header.contains("date") || header.contains("tarih") {
                mapping.dateColumn = index
                continue
            }

            // Odometer columns
            if header.contains("odometer") || header.contains("km") || header.contains("mileage") {
                if header.contains("start") || header.contains("baslangic") {
                    if mapping.odometerStartColumn == nil { mapping.odometerStartColumn = index; continue }
                } else if header.contains("end") || header.contains("bitis") {
                    if mapping.odometerEndColumn == nil { mapping.odometerEndColumn = index; continue }
                } else if mapping.odometerStartColumn == nil, !header.contains("per") {
                    mapping.odometerStartColumn = index
                    continue
                } else if mapping.odometerEndColumn == nil, !header.contains("per") {
                    mapping.odometerEndColumn = index
                    continue
                }
            }

            // Liters column ("per" excluded so Price_per_Liter can't match)
            if mapping.litersColumn == nil, !header.contains("per"),
               header.contains("liter") || header.contains("litre") || header.contains("fuel") ||
               header.contains("gallon") || header.contains("yakit") {
                mapping.litersColumn = index
                continue
            }

            // Price column
            if mapping.pricePerLiterColumn == nil,
               header.contains("price") || header.contains("fiyat") || header.contains("birim") {
                mapping.pricePerLiterColumn = index
                continue
            }

            // Gas station
            if mapping.gasStationColumn == nil,
               header.contains("station") || header.contains("location") || header.contains("istasyon") ||
               header.contains("brand") || header.contains("name") {
                mapping.gasStationColumn = index
                continue
            }

            // Drive mode
            if mapping.driveModeColumn == nil,
               header.contains("mode") || header.contains("type") || header.contains("surus") {
                mapping.driveModeColumn = index
                continue
            }

            // Full refill
            if mapping.isFullRefillColumn == nil,
               header.contains("full") || header.contains("complete") || header.contains("tam") {
                mapping.isFullRefillColumn = index
                continue
            }

            // Notes
            if mapping.notesColumn == nil,
               header.contains("note") || header.contains("comment") || header.contains("not") {
                mapping.notesColumn = index
            }
        }

        return mapping
    }
    
    // MARK: - Preview Generation
    
    /// Generates preview entries using the field mapping
    static func generatePreview(from parseResult: ParseResult, mapping: FieldMapping, limit: Int = 10) -> [PreviewEntry] {
        let rowsToPreview = Array(parseResult.rows.prefix(limit))
        
        return rowsToPreview.enumerated().map { index, row in
            createPreviewEntry(from: row, rowNumber: index + 2, mapping: mapping)
        }
    }
    
    private static func createPreviewEntry(from row: [String], rowNumber: Int, mapping: FieldMapping) -> PreviewEntry {
        var errors: [String] = []
        
        // Parse date
        var date: Date?
        if let col = mapping.dateColumn, col < row.count {
            date = parseDate(row[col], format: mapping.dateFormat)
            if date == nil {
                errors.append("Invalid date format")
            }
        } else {
            errors.append("Missing date")
        }
        
        // Parse odometer
        let odometerStart = mapping.odometerStartColumn.flatMap { $0 < row.count ? parseNumber(row[$0], useCommaDecimal: mapping.useCommaDecimal) : nil }
        let odometerEnd = mapping.odometerEndColumn.flatMap { $0 < row.count ? parseNumber(row[$0], useCommaDecimal: mapping.useCommaDecimal) : nil }
        
        // Parse liters
        var liters: Double?
        if let col = mapping.litersColumn, col < row.count {
            liters = parseNumber(row[col], useCommaDecimal: mapping.useCommaDecimal)
            if liters == nil || liters! <= 0 {
                errors.append("Invalid liters value")
            }
        } else {
            errors.append("Missing liters")
        }
        
        // Parse price
        var pricePerLiter: Double?
        if let col = mapping.pricePerLiterColumn, col < row.count {
            pricePerLiter = parseNumber(row[col], useCommaDecimal: mapping.useCommaDecimal)
            if pricePerLiter == nil || pricePerLiter! <= 0 {
                errors.append("Invalid price value")
            }
        } else {
            errors.append("Missing price")
        }
        
        // Parse optional fields
        let gasStation = mapping.gasStationColumn.flatMap { $0 < row.count ? row[$0] : nil }
        let driveMode = mapping.driveModeColumn.flatMap { $0 < row.count ? parseDriveMode(row[$0]) : nil }
        let isFullRefill = mapping.isFullRefillColumn.flatMap { $0 < row.count ? parseBool(row[$0]) : nil } ?? true
        let notes = mapping.notesColumn.flatMap { $0 < row.count && !row[$0].isEmpty ? row[$0] : nil }
        
        // Validate odometer values
        if let start = odometerStart, let end = odometerEnd, end < start {
            errors.append("End odometer less than start")
        }
        
        return PreviewEntry(
            rowNumber: rowNumber,
            date: date,
            odometerStart: odometerStart,
            odometerEnd: odometerEnd,
            liters: liters,
            pricePerLiter: pricePerLiter,
            gasStation: gasStation,
            driveMode: driveMode,
            isFullRefill: isFullRefill,
            notes: notes,
            isValid: errors.isEmpty,
            errors: errors
        )
    }
    
    // MARK: - Import Execution
    
    /// Imports entries from CSV into the repository
    @MainActor
    static func importEntries(
        from parseResult: ParseResult,
        mapping: FieldMapping,
        repository: FuelRepository,
        skipDuplicates: Bool = true
    ) -> ImportResult {
        var successCount = 0
        var failedCount = 0
        var duplicateCount = 0
        var errors: [String] = []
        
        var existingEntries = Set(repository.entries.map { DuplicateKey($0) })
        
        var entriesToInsert: [FuelEntry] = []

        for (index, row) in parseResult.rows.enumerated() {
            let preview = createPreviewEntry(from: row, rowNumber: index + 2, mapping: mapping)
            
            guard preview.isValid, let entry = preview.toFuelEntry() else {
                failedCount += 1
                errors.append("Row \(index + 2): \(preview.errors.joined(separator: ", "))")
                continue
            }
            
            // Check for duplicates
            let duplicateKey = DuplicateKey(entry)
            if skipDuplicates && existingEntries.contains(duplicateKey) {
                duplicateCount += 1
                continue
            }
            
            entriesToInsert.append(entry)
            existingEntries.insert(duplicateKey)
        }

        if repository.addBatch(entriesToInsert) {
            successCount = entriesToInsert.count
        } else if !entriesToInsert.isEmpty {
            failedCount += entriesToInsert.count
            errors.append(repository.lastError?.errorDescription ?? "The import transaction could not be saved")
        }
        
        return ImportResult(
            successCount: successCount,
            failedCount: failedCount,
            duplicateCount: duplicateCount,
            errors: errors
        )
    }
    
    // MARK: - Parsing Helpers
    
    private static func parseDate(_ string: String, format: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        if let date = formatter.date(from: string) {
            return date
        }
        
        // Try common alternative formats
        let alternativeFormats = [
            "yyyy-MM-dd",
            "dd/MM/yyyy",
            "MM/dd/yyyy",
            "dd.MM.yyyy",
            "yyyy/MM/dd",
            "d/M/yyyy",
            "d.M.yyyy"
        ]
        
        for altFormat in alternativeFormats {
            formatter.dateFormat = altFormat
            if let date = formatter.date(from: string) {
                return date
            }
        }
        
        return nil
    }
    
    private static func parseNumber(_ string: String, useCommaDecimal: Bool) -> Double? {
        var cleanedString = string.trimmingCharacters(in: .whitespaces)
        
        // Remove currency symbols
        cleanedString = cleanedString.replacingOccurrences(of: "$", with: "")
        cleanedString = cleanedString.replacingOccurrences(of: "€", with: "")
        cleanedString = cleanedString.replacingOccurrences(of: "₺", with: "")
        cleanedString = cleanedString.replacingOccurrences(of: "£", with: "")
        cleanedString = cleanedString.trimmingCharacters(in: .whitespaces)
        
        if useCommaDecimal {
            cleanedString = cleanedString.replacingOccurrences(of: ",", with: ".")
        } else {
            // Remove thousand separators
            cleanedString = cleanedString.replacingOccurrences(of: ",", with: "")
        }
        
        return Double(cleanedString)
    }
    
    private static func parseDriveMode(_ string: String) -> FuelEntry.DriveMode? {
        let lowercased = string.lowercased().trimmingCharacters(in: .whitespaces)
        
        switch lowercased {
        case "eco", "ekonomik", "economy":
            return .eco
        case "normal", "standart", "standard":
            return .normal
        case "sport", "sportif", "performance":
            return .sport
        default:
            return nil
        }
    }
    
    private static func parseBool(_ string: String) -> Bool? {
        let lowercased = string.lowercased().trimmingCharacters(in: .whitespaces)
        
        switch lowercased {
        case "true", "yes", "1", "evet", "tam", "full":
            return true
        case "false", "no", "0", "hayır", "kısmi", "partial":
            return false
        default:
            return nil
        }
    }
}

// MARK: - Supported File Types

extension UTType {
    static let csv = UTType(filenameExtension: "csv") ?? .commaSeparatedText
}
