import Foundation
import SwiftUI
import ImageIO

/// Service to load car images
enum CarImageService {

    private nonisolated static let maximumDownloadSize = 5 * 1_024 * 1_024

    /// Returns the asset name for a car make and model
    static func assetName(make: String, model: String) -> String {
        "\(make)_\(model)"
    }

    /// Loads a bundled car image for the given make and model
    static func loadBundledImage(make: String, model: String) -> UIImage? {
        let name = assetName(make: make, model: model)
        return UIImage(named: name)
    }

    /// Checks if a bundled image exists for the car
    static func hasBundledImage(make: String, model: String) -> Bool {
        loadBundledImage(make: make, model: model) != nil
    }

    /// Fetches a car image after explicit user action. The car's make/model/year
    /// is sent to the selected image provider as part of the request.
    nonisolated static func generateImage(make: String, model: String, year: Int) async -> Data? {
        if let data = await generateWithPollinations(make: make, model: model, year: year) {
            return data
        }
        return await fetchGenericCarImage(make: make, model: model, year: year)
    }

    // MARK: - Pollinations.ai Image Generation (free, no API key)

    private nonisolated static func generateWithPollinations(make: String, model: String, year: Int) async -> Data? {
        let prompt = "\(year) \(make) \(model) car, side profile view, isolated on white background, professional automotive photography, high quality, no watermarks, no text"

        let allowedPathCharacters = CharacterSet.urlPathAllowed
            .subtracting(CharacterSet(charactersIn: "/?#"))
        guard let encodedPrompt = prompt.addingPercentEncoding(withAllowedCharacters: allowedPathCharacters),
              let url = URL(string: "https://image.pollinations.ai/prompt/\(encodedPrompt)?width=800&height=500&nologo=true") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            return await processImage(data: data, response: response)
        } catch {
            return nil
        }
    }

    /// Fallback: placeholder image with the car's name
    private nonisolated static func fetchGenericCarImage(make: String, model: String, year: Int) async -> Data? {
        var components = URLComponents(string: "https://placehold.co/800x500/1a1a2e/ffffff")
        components?.queryItems = [URLQueryItem(name: "text", value: "\(make) \(model) \(year)")]
        guard let url = components?.url else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            return await processImage(data: data, response: response)
        } catch {
            return nil
        }
    }

    private nonisolated static func processImage(data: Data, response: URLResponse) async -> Data? {
        guard data.count > 1_000, data.count <= maximumDownloadSize,
              let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode),
              httpResponse.mimeType?.hasPrefix("image/") == true else {
            return nil
        }

        return await Task.detached(priority: .utility) {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1_200
            ]
            guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                return nil
            }
            return UIImage(cgImage: thumbnail).jpegData(compressionQuality: 0.82)
        }.value
    }
}
