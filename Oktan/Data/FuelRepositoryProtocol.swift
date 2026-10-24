import Foundation
import Combine

/// Protocol defining the fuel repository interface
/// Both legacy (JSON) and SwiftData implementations conform to this
protocol FuelRepositoryProtocol: ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    /// All fuel entries, sorted by date
    var entries: [FuelEntry] { get }
    
    /// Adds a new fuel entry
    @discardableResult
    func add(_ entry: FuelEntry) -> Bool
    
    /// Updates an existing fuel entry
    @discardableResult
    func update(_ entry: FuelEntry) -> Bool
    
    /// Deletes a fuel entry
    @discardableResult
    func delete(_ entry: FuelEntry) -> Bool
    
    /// Loads persisted data during app startup
    func bootstrapIfNeeded()
    
    /// Returns a summary of all fuel entries
    func summary() -> FuelSummary
    
    /// Exports all entries to CSV format
    func exportToCSV() -> String
    
    /// Creates a shareable CSV file
    func createCSVFile() -> URL?
}

// MARK: - Legacy FuelRepository Conformance

extension FuelRepository: FuelRepositoryProtocol {}
