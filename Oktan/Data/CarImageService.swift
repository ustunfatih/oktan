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
    
    /// Fetches car image using Pollinations.ai (free, no API key needed)
    static func generateImage(make: String, model: String, year: Int) async -> Data? {
        print("🚗 CarImageService.generateImage called for: \(year) \(make) \(model)")
        
        // 1. Try Pollinations.ai - FREE AI image generation, no API key needed!
        print("🔄 Attempting Pollinations.ai image generation...")
        if let data = await generateWithPollinations(make: make, model: model, year: year) {
            print("✅ Pollinations.ai image generation succeeded!")
            return data
        }
        print("❌ Pollinations.ai failed, trying Imagin.studio fallback...")
        
        // 2. Fallback: Imagin.studio
        if let data = await fetchFromImaginStudio(make: make, model: model, year: year) {
            print("✅ Imagin.studio fallback succeeded!")
            return data
        }
        print("❌ Imagin.studio failed, using generic placeholder...")
        
        // 3. Fallback: Generic placeholder
        return await fetchGenericCarImage(make: make, model: model, year: year)
    }
    
    // MARK: - Pollinations.ai Image Generation (FREE, No API Key)
    
    private static func generateWithPollinations(make: String, model: String, year: Int) async -> Data? {
        // Pollinations.ai is free and requires no API key!
        // Just encode the prompt in the URL
        let prompt = "\(year) \(make) \(model) car, side profile view, isolated on white background, professional automotive photography, high quality, no watermarks, no text"
        
        guard let encodedPrompt = prompt.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            print("Failed to encode prompt")
            return nil
        }
        
        // Pollinations.ai endpoint - simple GET request with prompt in URL
        let urlString = "https://image.pollinations.ai/prompt/\(encodedPrompt)?width=800&height=500&nologo=true"
        
        print("📡 Pollinations URL: \(urlString)")
        
        guard let url = URL(string: urlString) else { 
            print("Invalid URL")
            return nil 
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 60 // AI generation can take time
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📥 Pollinations response status: \(httpResponse.statusCode)")
                if !(200...299).contains(httpResponse.statusCode) {
                    return nil
                }
            }
            
            // Verify we got valid image data
            if data.count > 1000, UIImage(data: data) != nil {
                print("✅ Got valid image from Pollinations: \(data.count) bytes")
                return data
            } else {
                print("❌ Invalid image data from Pollinations")
                return nil
            }
            
        } catch {
            print("❌ Pollinations error: \(error)")
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
        
        context.draw(cgImage, in: .init(x: 0, y: 0, width: width, height: height))
        
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
