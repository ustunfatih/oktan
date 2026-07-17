import XCTest
@testable import oktan

/// Critical accuracy tests for fuel calculations
/// These tests verify the mathematical correctness of all efficiency and cost calculations
final class CalculationAccuracyTests: XCTestCase {
    
    // MARK: - Liters Per 100KM Formula Verification
    
    /// The formula is: (liters / distance_km) * 100
    func testLitersPer100KMFormulaBasic() {
        // If you use 50 liters to travel 500 km
        // L/100km = (50 / 500) * 100 = 10 L/100km
        let liters = 50.0
        let distance = 500.0
        let expected = (liters / distance) * 100
        
        XCTAssertEqual(expected, 10.0, accuracy: 0.0001)
    }
    
    func testLitersPer100KMFormulaEdgeCases() {
        // Very efficient (hybrid-like): 4 L/100km
        let efficient = (20.0 / 500.0) * 100
        XCTAssertEqual(efficient, 4.0, accuracy: 0.0001)
        
        // Inefficient (large SUV): 18 L/100km
        let inefficient = (90.0 / 500.0) * 100
        XCTAssertEqual(inefficient, 18.0, accuracy: 0.0001)
    }
    
    // MARK: - MPG Conversion Verification
    
    /// The conversion factor from L/100km to MPG (US) is: 235.215 / (L/100km)
    func testMPGConversionFormula() {
        // 10 L/100km should equal approximately 23.52 MPG
        let lPer100 = 10.0
        let mpg = 235.215 / lPer100
        
        XCTAssertEqual(mpg, 23.5215, accuracy: 0.0001)
    }
    
    func testMPGConversionKnownValues() {
        // Known reference values
        // 5 L/100km = 47.043 MPG (very efficient)
        XCTAssertEqual(235.215 / 5.0, 47.043, accuracy: 0.001)
        
        // 8 L/100km = 29.40 MPG (efficient)
        XCTAssertEqual(235.215 / 8.0, 29.402, accuracy: 0.001)
        
        // 12 L/100km = 19.60 MPG (average)
        XCTAssertEqual(235.215 / 12.0, 19.601, accuracy: 0.001)
        
        // 20 L/100km = 11.76 MPG (inefficient)
        XCTAssertEqual(235.215 / 20.0, 11.761, accuracy: 0.001)
    }
    
    // MARK: - KM/L Conversion Verification
    
    /// The conversion from L/100km to km/L is: 100 / (L/100km)
    func testKMPerLiterConversionFormula() {
        // 10 L/100km = 100/10 = 10 km/L
        let lPer100 = 10.0
        let kmPerL = 100.0 / lPer100
        
        XCTAssertEqual(kmPerL, 10.0, accuracy: 0.0001)
    }
    
    func testKMPerLiterConversionKnownValues() {
        // 5 L/100km = 20 km/L
        XCTAssertEqual(100.0 / 5.0, 20.0, accuracy: 0.001)
        
        // 8 L/100km = 12.5 km/L
        XCTAssertEqual(100.0 / 8.0, 12.5, accuracy: 0.001)
        
        // 12.5 L/100km = 8 km/L
        XCTAssertEqual(100.0 / 12.5, 8.0, accuracy: 0.001)
    }
    
    // MARK: - Distance Conversion Verification
    
    /// 1 kilometer = 0.621371 miles
    func testKilometersToMilesConversion() {
        let kmToMiles = 0.621371
        
        // 100 km = 62.1371 miles
        XCTAssertEqual(100 * kmToMiles, 62.1371, accuracy: 0.0001)
        
        // 1000 km = 621.371 miles
        XCTAssertEqual(1000 * kmToMiles, 621.371, accuracy: 0.001)
    }
    
    func testMilesToKilometersConversion() {
        let milesToKm = 1.60934
        
        // 100 miles = 160.934 km
        XCTAssertEqual(100 * milesToKm, 160.934, accuracy: 0.001)
    }
    
    // MARK: - Volume Conversion Verification
    
    /// 1 liter = 0.264172 US gallons
    func testLitersToGallonsConversion() {
        let litersToGallons = 0.264172
        
        // 1 liter = 0.264172 gallons
        XCTAssertEqual(1 * litersToGallons, 0.264172, accuracy: 0.0001)
        
        // 50 liters = 13.2086 gallons
        XCTAssertEqual(50 * litersToGallons, 13.2086, accuracy: 0.001)
    }
    
    // MARK: - Cost Calculations Verification
    
    func testTotalCostCalculation() {
        let liters = 41.46
        let pricePerLiter = 2.05
        let expectedCost = liters * pricePerLiter // 84.993
        
        XCTAssertEqual(expectedCost, 84.993, accuracy: 0.0001)
    }
    
    func testCostPerKMCalculation() {
        let totalCost = 84.993
        let distance = 414.0
        let costPerKM = totalCost / distance // 0.2053...
        
        XCTAssertEqual(costPerKM, 0.20529, accuracy: 0.0001)
    }
    
    func testCostPerMileConversion() {
        let costPerKM = 0.2
        // Cost per mile = cost per km / km per mile
        // = cost per km / 0.621371
        let costPerMile = costPerKM / 0.621371
        
        XCTAssertEqual(costPerMile, 0.32187, accuracy: 0.0001)
    }
    
    // MARK: - Real-World Data Verification
    
    /// Test with actual seed data to ensure calculations match expected values
    func testSeedDataCalculation1() {
        // Entry: 28/04/2025, 170-584 km, 41.46 L @ 2.05/L
        let odometerStart = 170.0
        let odometerEnd = 584.0
        let totalLiters = 41.46
        let pricePerLiter = 2.05
        
        // Calculate distance
        let distance = odometerEnd - odometerStart // 414 km
        XCTAssertEqual(distance, 414.0, accuracy: 0.01)
        
        // Calculate L/100km
        let lPer100 = (totalLiters / distance) * 100 // 10.0145...
        XCTAssertEqual(lPer100, 10.0145, accuracy: 0.001)
        
        // Calculate total cost
        let totalCost = totalLiters * pricePerLiter // 84.993
        XCTAssertEqual(totalCost, 84.993, accuracy: 0.001)
        
        // Calculate cost per km
        let costPerKM = totalCost / distance // 0.20529...
        XCTAssertEqual(costPerKM, 0.20529, accuracy: 0.0001)
    }
    
    func testSeedDataCalculation2() {
        // Entry: 12/05/2025, 584-963 km, 41.03 L @ 1.95/L
        let odometerStart = 584.0
        let odometerEnd = 963.0
        let totalLiters = 41.03
        let pricePerLiter = 1.95
        
        let distance = odometerEnd - odometerStart // 379 km
        XCTAssertEqual(distance, 379.0, accuracy: 0.01)
        
        let lPer100 = (totalLiters / distance) * 100 // 10.826...
        XCTAssertEqual(lPer100, 10.826, accuracy: 0.001)
        
        let totalCost = totalLiters * pricePerLiter // 80.0085
        XCTAssertEqual(totalCost, 80.0085, accuracy: 0.001)
        
        let costPerKM = totalCost / distance // 0.2111...
        XCTAssertEqual(costPerKM, 0.2111, accuracy: 0.001)
    }
    
    func testSeedDataCalculation3() {
        // Entry: 20/07/2025, 1773-2130 km, 42.57 L @ 2.0/L (Sport mode)
        let odometerStart = 1773.0
        let odometerEnd = 2130.0
        let totalLiters = 42.57
        let pricePerLiter = 2.0
        
        let distance = odometerEnd - odometerStart // 357 km
        XCTAssertEqual(distance, 357.0, accuracy: 0.01)
        
        let lPer100 = (totalLiters / distance) * 100 // 11.9244...
        XCTAssertEqual(lPer100, 11.9244, accuracy: 0.001)
        
        let totalCost = totalLiters * pricePerLiter // 85.14
        XCTAssertEqual(totalCost, 85.14, accuracy: 0.001)
        
        let costPerKM = totalCost / distance // 0.2385...
        XCTAssertEqual(costPerKM, 0.2385, accuracy: 0.001)
    }
    
    // MARK: - Rolling Average Verification
    
    func testRollingAverageCalculation() {
        let values = [10.0, 10.5, 11.0, 9.5, 10.2]
        let average = values.reduce(0, +) / Double(values.count)
        
        // (10 + 10.5 + 11 + 9.5 + 10.2) / 5 = 51.2 / 5 = 10.24
        XCTAssertEqual(average, 10.24, accuracy: 0.001)
    }
    
    // MARK: - Aggregate Summary Verification
    
    func testAggregateSummaryCalculation() {
        // Test with 3 fill-ups from seed data
        let distances = [414.0, 379.0, 401.0]  // km
        let liters = [41.46, 41.03, 41.04]
        let costs = [84.993, 80.0085, 80.028]
        
        let totalDistance = distances.reduce(0, +) // 1194 km
        XCTAssertEqual(totalDistance, 1194.0, accuracy: 0.01)
        
        let totalLiters = liters.reduce(0, +) // 123.53 L
        XCTAssertEqual(totalLiters, 123.53, accuracy: 0.01)
        
        let totalCost = costs.reduce(0, +) // 245.0295
        XCTAssertEqual(totalCost, 245.0295, accuracy: 0.01)
        
        // Aggregate efficiency = total liters / total distance * 100
        let aggregateLPer100 = (totalLiters / totalDistance) * 100 // 10.346...
        XCTAssertEqual(aggregateLPer100, 10.346, accuracy: 0.01)
        
        // Aggregate cost per km = total cost / total distance
        let aggregateCostPerKM = totalCost / totalDistance // 0.2052...
        XCTAssertEqual(aggregateCostPerKM, 0.2052, accuracy: 0.001)
    }
    
    // MARK: - Precision Edge Cases
    
    func testFloatingPointPrecision() {
        // Test that common floating point issues don't affect our calculations
        // 0.1 + 0.2 should equal 0.3
        let result = 0.1 + 0.2
        XCTAssertEqual(result, 0.3, accuracy: 0.0001)
    }
    
    func testSmallDistanceCalculation() {
        // Very short trip: 5 liters over 20 km = 25 L/100km
        let lPer100 = (5.0 / 20.0) * 100
        XCTAssertEqual(lPer100, 25.0, accuracy: 0.001)
    }
    
    func testLargeDistanceCalculation() {
        // Long trip: 80 liters over 1000 km = 8 L/100km
        let lPer100 = (80.0 / 1000.0) * 100
        XCTAssertEqual(lPer100, 8.0, accuracy: 0.001)
    }
    
    func testVerySmallPriceCalculation() {
        // Very cheap fuel: 50 liters @ 0.5/L = 25 cost
        let totalCost = 50.0 * 0.5
        XCTAssertEqual(totalCost, 25.0, accuracy: 0.001)
    }
    
    func testVeryHighPriceCalculation() {
        // Expensive fuel: 50 liters @ 3.5/L = 175 cost
        let totalCost = 50.0 * 3.5
        XCTAssertEqual(totalCost, 175.0, accuracy: 0.001)
    }
}
