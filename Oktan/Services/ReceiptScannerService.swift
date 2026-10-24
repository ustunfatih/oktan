import Foundation
import ImageIO
import Vision

enum ReceiptScannerService {
    struct Result: Sendable {
        let date: Date?
        let liters: Double?
        let pricePerLiter: Double?
        let totalCost: Double?
        let station: String?
        let recognizedText: String
    }

    enum ScanError: LocalizedError {
        case invalidImage
        case noText

        var errorDescription: String? {
            switch self {
            case .invalidImage: return String(localized: "The selected receipt image could not be read.")
            case .noText: return String(localized: "No readable text was found on this receipt.")
            }
        }
    }

    nonisolated static func scan(imageData: Data) async throws -> Result {
        try await Task.detached(priority: .userInitiated) {
            guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                throw ScanError.invalidImage
            }

            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US", "tr-TR"]
            try VNImageRequestHandler(cgImage: image).perform([request])

            let lines = (request.results ?? []).compactMap {
                $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines)
            }.filter { !$0.isEmpty }
            guard !lines.isEmpty else { throw ScanError.noText }

            return parse(lines: lines)
        }.value
    }

    private nonisolated static func parse(lines: [String]) -> Result {
        let upper = lines.map { $0.uppercased() }
        var liters = value(in: upper, keywords: [" L", "LT", "LITRE", "LITER"], preferLast: false)
        var unitPrice = value(in: upper, keywords: ["/L", "PRICE/L", "UNIT PRICE", "BIRIM FIYAT", "LITRE FIYATI"], preferLast: true)
        let total = value(in: upper, keywords: ["TOTAL", "TOPLAM", "TUTAR", "AMOUNT"], preferLast: true)

        if unitPrice == nil, let liters, liters > 0, let total {
            let inferred = total / liters
            if inferred > 0.1, inferred < 100 { unitPrice = inferred }
        }
        if liters == nil, let unitPrice, unitPrice > 0, let total {
            let inferred = total / unitPrice
            if inferred > 0.1, inferred < 500 { liters = inferred }
        }

        let station = lines.first { line in
            let letterCount = line.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
            return letterCount >= 3 && !line.uppercased().contains("RECEIPT")
        }

        return Result(
            date: parseDate(from: lines),
            liters: liters,
            pricePerLiter: unitPrice,
            totalCost: total,
            station: station,
            recognizedText: lines.joined(separator: "\n")
        )
    }

    private nonisolated static func value(in lines: [String], keywords: [String], preferLast: Bool) -> Double? {
        let matching = lines.filter { line in keywords.contains { line.contains($0) } }
        let candidates = matching.flatMap(numbers(in:))
            .filter { $0 > 0 && $0 < 100_000 }
        return preferLast ? candidates.last : candidates.first
    }

    private nonisolated static func numbers(in text: String) -> [Double] {
        let pattern = #"\d{1,6}(?:[.,]\d{1,3})?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return Double(text[range].replacingOccurrences(of: ",", with: "."))
        }
    }

    private nonisolated static func parseDate(from lines: [String]) -> Date? {
        let patterns = [#"\b\d{4}[-/.]\d{1,2}[-/.]\d{1,2}\b"#, #"\b\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4}\b"#]
        let formats = ["yyyy-MM-dd", "yyyy/MM/dd", "yyyy.MM.dd", "dd-MM-yyyy", "dd/MM/yyyy", "dd.MM.yyyy", "dd-MM-yy", "dd/MM/yy", "dd.MM.yy"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.isLenient = false

        for line in lines {
            for pattern in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern),
                      let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                      let range = Range(match.range, in: line) else { continue }
                let candidate = String(line[range])
                for format in formats {
                    formatter.dateFormat = format
                    if let date = formatter.date(from: candidate) { return date }
                }
            }
        }
        return nil
    }
}
