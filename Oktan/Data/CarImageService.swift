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
    
    /// Fetches car image using Gemini AI first, then fallbacks
    static func generateImage(make: String, model: String, year: Int) async -> Data? {
        // 1. Try Gemini 2.0 Flash Image Generation
        if let data = await generateWithGemini(make: make, model: model, year: year) {
            return data
        }
        
        // 2. Fallback: Imagin.studio
        if let data = await fetchFromImaginStudio(make: make, model: model, year: year) {
            return data
        }
        
        // 3. Fallback: Generic placeholder
        return await fetchGenericCarImage(make: make, model: model, year: year)
    }
    
    // MARK: - Gemini 2.0 Flash Image Generation
    
    /// Loads API key from Secrets.plist (not tracked in git)
    private static var geminiAPIKey: String? {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let key = dict["GEMINI_API_KEY"] as? String else {
            print("⚠️ Secrets.plist not found or GEMINI_API_KEY missing")
            return nil
        }
        return key
    }
    
    private static func generateWithGemini(make: String, model: String, year: Int) async -> Data? {
        guard let apiKey = geminiAPIKey else { return nil }
        
        // Use the image generation specific model
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-preview-image-generation:generateContent?key=\(apiKey)"
        
        guard let url = URL(string: endpoint) else { return nil }
        
        let prompt = "Create a photorealistic image of a \(year) \(make) \(model) car. Side profile view, isolated on pure white background, professional automotive studio photography, no watermarks, no text overlays, high resolution."
        
        // Correct format for Gemini image generation - modalities are case-sensitive
        let jsonBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "responseModalities": ["Text", "Image"]
            ]
        ]
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: jsonBody) else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = httpBody
        request.timeoutInterval = 60 // Image generation can take up to 30-60 seconds
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if !(200...299).contains(httpResponse.statusCode) {
                    if let errorString = String(data: data, encoding: .utf8) {
                        print("Gemini Image API Error: \(httpResponse.statusCode) - \(errorString)")
                    }
                    return nil
                }
            }
            
            // Parse the response to extract inlineData
            return extractImageFromGeminiResponse(data)
            
        } catch {
            print("Gemini Network Error: \(error)")
            return nil
        }
    }
    
    private static func extractImageFromGeminiResponse(_ data: Data) -> Data? {
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let firstCandidate = candidates.first,
                  let content = firstCandidate["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]] else {
                print("Failed to parse Gemini response structure")
                return nil
            }
            
            // Look for inlineData in any part
            for part in parts {
                if let inlineData = part["inlineData"] as? [String: Any],
                   let base64String = inlineData["data"] as? String {
                    print("Found image data in Gemini response!")
                    return Data(base64Encoded: base64String)
                }
            }
            
            // Debug: print what we got
            if let responseString = String(data: data, encoding: .utf8) {
                print("Gemini response (no image found): \(responseString.prefix(500))")
            }
            
            return nil
        } catch {
            print("JSON parsing error: \(error)")
            return nil
        }
    }

    private static func fetchFromImaginStudio(make: String, model: String, year: Int) async -> Data? {
        let formattedMake = make.lowercased().replacingOccurrences(of: " ", with: "-").replacingOccurrences(of: "-benz", with: "")
        let formattedModel = model.lowercased().replacingOccurrences(of: " ", with: "-").replacingOccurrences(of: "-class", with: "")
        
        // Try multiple years to find a valid image (newest first, then older)
        let yearsToTry = [min(year, 2023), 2022, 2021, 2020]
        
        for tryYear in yearsToTry {
            let urlString = "https://cdn.imagin.studio/getimage?customer=hrjavascript-mastery&make=\(formattedMake)&modelFamily=\(formattedModel)&modelYear=\(tryYear)&angle=23&width=800&height=500"
            
            guard let url = URL(string: urlString) else { continue }
            
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode),
                      data.count > 5000 else {
                    continue
                }
                
                // Check if the image is a valid car (not the red covered placeholder)
                if let image = UIImage(data: data), isValidCarImage(image) {
                    print("Found valid car image for year \(tryYear)")
                    return data
                }
            } catch {
                continue
            }
        }
        
        return nil
    }
    
    /// Checks if the image is a valid car (not a placeholder/covered car)
    private static func isValidCarImage(_ image: UIImage) -> Bool {
        // Check image dimensions
        guard image.size.width > 100, image.size.height > 100 else { return false }
        
        // Detect the red covered car placeholder by analyzing average color
        guard let cgImage = image.cgImage else { return true }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return true }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Sample the center of the image for the dominant color
        var totalRed: Int = 0
        var totalGreen: Int = 0
        var totalBlue: Int = 0
        var sampleCount = 0
        
        // Sample center region (where the car would be)
        let centerX = width / 2
        let centerY = height / 2
        let sampleRadius = min(width, height) / 4
        
        for y in (centerY - sampleRadius)..<(centerY + sampleRadius) {
            for x in (centerX - sampleRadius)..<(centerX + sampleRadius) {
                let offset = (y * width + x) * bytesPerPixel
                totalRed += Int(pixelData[offset])
                totalGreen += Int(pixelData[offset + 1])
                totalBlue += Int(pixelData[offset + 2])
                sampleCount += 1
            }
        }
        
        guard sampleCount > 0 else { return true }
        
        let avgRed = totalRed / sampleCount
        let avgGreen = totalGreen / sampleCount
        let avgBlue = totalBlue / sampleCount
        
        // The red covered car has high red, low green/blue
        // Typical values: R > 150, G < 80, B < 80
        let isRedCoveredCar = avgRed > 130 && avgGreen < 100 && avgBlue < 100
        
        if isRedCoveredCar {
            print("Detected red covered car placeholder (R:\(avgRed) G:\(avgGreen) B:\(avgBlue))")
        }
        
        return !isRedCoveredCar
    }
    
    /// Fallback: Fetch from a more reliable source
    private static func fetchGenericCarImage(make: String, model: String, year: Int) async -> Data? {
        // Use a placeholder image service as final fallback
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
