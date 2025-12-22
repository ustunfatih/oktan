import SwiftUI

struct CarSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Support both legacy binding and environment injection
    @Bindable var legacyCarRepository: CarRepository
    @Environment(CarRepositorySD.self) private var envCarRepositorySD: CarRepositorySD?
    
    /// The active car repository
    private var carRepository: CarRepositoryProtocol {
        envCarRepositorySD ?? legacyCarRepository
    }
    
    init(carRepository: CarRepository) {
        self.legacyCarRepository = carRepository
    }
    
    // Navigation Path
    @State private var path = NavigationPath()
    
    @State private var searchText: String = ""
    
    private var filteredMakes: [CarDatabase.CarMake] {
        if searchText.isEmpty {
            return CarDatabase.makes
        }
        return CarDatabase.makes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack(path: $path) {
            List(filteredMakes) { make in
                NavigationLink(value: make) {
                    HStack {
                        Text(make.name)
                            .font(.headline)
                        Spacer()
                        Text("\(make.models.count) models")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Select Make")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search makes")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(for: CarDatabase.CarMake.self) { make in
                CarModelSelectionView(make: make, path: $path, carRepository: carRepository, onFinish: { dismiss() })
            }
        }
    }
}

// MARK: - Step 2: Model Selection

struct CarModelSelectionView: View {
    let make: CarDatabase.CarMake
    @Binding var path: NavigationPath
    let carRepository: CarRepositoryProtocol
    let onFinish: () -> Void
    
    var body: some View {
        List(make.models) { model in
            NavigationLink(value: model) {
                HStack {
                    Text(model.name)
                        .font(.headline)
                    Spacer()
                    if model.tankCapacity > 0 {
                        Text("\(Int(model.tankCapacity))L")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Electric")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(make.name)
        .navigationDestination(for: CarDatabase.CarModel.self) { model in
            CarYearSelectionView(make: make, model: model, path: $path, carRepository: carRepository, onFinish: onFinish)
        }
    }
}

// MARK: - Step 3: Year Selection

struct CarYearSelectionView: View {
    let make: CarDatabase.CarMake
    let model: CarDatabase.CarModel
    @Binding var path: NavigationPath
    let carRepository: CarRepositoryProtocol
    let onFinish: () -> Void
    
    private let availableYears: [Int] = Array((2010...Calendar.current.component(.year, from: Date()) + 1).reversed())
    
    var body: some View {
        List(availableYears, id: \.self) { year in
            NavigationLink(value: year) {
                Text(verbatim: "\(year)")
            }
        }
        .listStyle(.plain)
        .navigationTitle("Select Year")
        .navigationDestination(for: Int.self) { year in
            CarConfirmationView(make: make, model: model, year: year, carRepository: carRepository, onFinish: onFinish)
        }
    }
}

// MARK: - Step 4: Confirmation

struct CarConfirmationView: View {
    let make: CarDatabase.CarMake
    let model: CarDatabase.CarModel
    let year: Int
    let carRepository: CarRepositoryProtocol
    let onFinish: () -> Void
    
    @State private var tankCapacity: Double
    @State private var carImage: UIImage?
    @State private var isGeneratingImage = false
    
    init(make: CarDatabase.CarMake, model: CarDatabase.CarModel, year: Int, carRepository: CarRepositoryProtocol, onFinish: @escaping () -> Void) {
        self.make = make
        self.model = model
        self.year = year
        self.carRepository = carRepository
        self.onFinish = onFinish
        _tankCapacity = State(initialValue: model.tankCapacity)
    }
    
    // MARK: - Body (Bible Compliant)
    // Removed: .frame(height: 200), .frame(width: 80), .padding(.trailing, 8), .font(.system(size: 80))

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    carImageSection
                        .aspectRatio(contentMode: .fit) // Use system sizing without numeric aspect ratio
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            Section("Vehicle Details") {
                LabeledContent("Make", value: make.name)
                LabeledContent("Model", value: model.name)
                LabeledContent("Year", value: String(year))
            }

            Section("Fuel Configuration") {
                LabeledContent("Tank Capacity") {
                    HStack {
                        TextField("Liters", value: $tankCapacity, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("L")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button(action: confirmSelection) {
                    if isGeneratingImage {
                        HStack {
                            ProgressView()
                            Text("Generating Image...")
                        }
                    } else {
                        Text("Save Car")
                            .frame(maxWidth: .infinity)
                            .bold()
                    }
                }
                .disabled(isGeneratingImage)
            }
        }
        .navigationTitle("Confirm")
        .task {
            generateCarImage()
        }
    }

    private var carImageSection: some View {
        ZStack {
            if let image = carImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if isGeneratingImage {
                VStack {
                    ProgressView()
                    Text("Generating car image...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Image(systemName: "car.fill")
                    .font(.largeTitle) // System font - Bible compliant
                    .foregroundStyle(.tertiary)
            }
        }
    }
    
    private func generateCarImage() {
        print("🎯 generateCarImage starting for: \(year) \(make.name) \(model.name)")
        isGeneratingImage = true
        
        Task {
            let imageData = await CarImageService.generateImage(
                make: make.name,
                model: model.name,
                year: year
            )
            
            await MainActor.run {
                if let data = imageData, let image = UIImage(data: data) {
                    self.carImage = image
                }
                self.isGeneratingImage = false
            }
        }
    }
    
    private func confirmSelection() {
        let car = Car(
            make: make.name,
            model: model.name,
            year: year,
            tankCapacity: tankCapacity,
            imageData: carImage?.pngData()
        )
        
        carRepository.saveCar(car)
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        onFinish()
    }
}

#Preview {
    CarSelectionView(carRepository: CarRepository())
}
