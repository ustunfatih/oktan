import Foundation
import SwiftUI

/// Service to load car images
enum CarImageService {

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

    /// Fetches a car image. Note: the car's make/model/year is sent to the
    /// image provider as part of the request (disclosed in the privacy manifest).
    static func generateImage(make: String, model: String, year: Int) async -> Data? {
        if let data = await generateWithPollinations(make: make, model: model, year: year) {
            return data
        }
        return await fetchGenericCarImage(make: make, model: model, year: year)
    }

    // MARK: - Pollinations.ai Image Generation (free, no API key)

    private static func generateWithPollinations(make: String, model: String, year: Int) async -> Data? {
        let prompt = "\(year) \(make) \(model) car, side profile view, isolated on white background, professional automotive photography, high quality, no watermarks, no text"

        guard let encodedPrompt = prompt.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://image.pollinations.ai/prompt/\(encodedPrompt)?width=800&height=500&nologo=true") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                return nil
            }

            // Verify we got valid image data
            if data.count > 1000, UIImage(data: data) != nil {
                return data
            }
            return nil
        } catch {
            return nil
        }
    }

    /// Fallback: placeholder image with the car's name
    private static func fetchGenericCarImage(make: String, model: String, year: Int) async -> Data? {
        let urlString = "https://placehold.co/800x500/1a1a2e/ffffff?text=\(make)+\(model)+\(year)"

        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return data
        } catch {
            return nil
        }
    }
}
