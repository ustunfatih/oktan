import SwiftUI
import UniformTypeIdentifiers

struct CSVImportView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var repository: FuelRepository
    
    // Import State
    @State private var currentStep: ImportStep = .selectFile
    @State private var parseResult: CSVImportService.ParseResult?
    @State private var fieldMapping = CSVImportService.FieldMapping()
    @State private var previewEntries: [CSVImportService.PreviewEntry] = []
    @State private var importResult: CSVImportService.ImportResult?
    
    // UI State
    @State private var showingFilePicker = false
    @State private var errorMessage: String?
    @State private var skipDuplicates = true
    
    enum ImportStep: Int, CaseIterable {
        case selectFile
        case mapFields
        case preview
        case importing
        case complete
    }
    
    var body: some View {
        NavigationStack {
            Group {
                switch currentStep {
                case .selectFile:
                    selectFileView
                case .mapFields:
                    mapFieldsView
                case .preview:
                    previewView
                case .importing:
                    importingView
                case .complete:
                    completeView
                }
            }
            .navigationTitle(stepTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if currentStep != .complete && currentStep != .importing {
                        Button("Cancel") { dismiss() }
                    } else if currentStep == .complete {
                         Button("Done") { dismiss() }
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.commaSeparatedText, .csv],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
        }
    }
    
    private var stepTitle: String {
        switch currentStep {
        case .selectFile: return "Import Data"
        case .mapFields: return "Map Fields"
        case .preview: return "Preview"
        case .importing: return "Importing"
        case .complete: return "Complete"
        }
    }
    
    // MARK: - Step 1: Select File
    
    private var selectFileView: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)
                    
                    Text("Import from CSV")
                        .font(.title2.bold())
                    
                    Text("Select a CSV file containing your fuel records. We'll help you map the columns to the correct fields.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }
            .listRowBackground(Color.clear)
            
            Section {
                Button(action: { showingFilePicker = true }) {
                    Label("Choose File", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .listRowBackground(Color.clear)
            
            Section("Supported Columns") {
                Text("Date, Odometer Start, Odometer End, Liters, Price per Liter, Station, Drive Mode, Full Refill, Notes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Step 2: Map Fields
    
    private var mapFieldsView: some View {
        Form {
            if let result = parseResult {
                Section {
                    Label("\(result.totalRows) rows found", systemImage: "doc.text")
                }
            }
            
            Section("Required Fields") {
                mappingPicker("Date", selection: $fieldMapping.dateColumn, required: true)
                mappingPicker("Liters", selection: $fieldMapping.litersColumn, required: true)
                mappingPicker("Price / Liter", selection: $fieldMapping.pricePerLiterColumn, required: true)
            }
            
            Section("Optional Fields") {
                mappingPicker("Odometer Start", selection: $fieldMapping.odometerStartColumn)
                mappingPicker("Odometer End", selection: $fieldMapping.odometerEndColumn)
                mappingPicker("Station", selection: $fieldMapping.gasStationColumn)
                mappingPicker("Drive Mode", selection: $fieldMapping.driveModeColumn)
                mappingPicker("Notes", selection: $fieldMapping.notesColumn)
            }
            
            Section("Options") {
                Picker("Date Format", selection: $fieldMapping.dateFormat) {
                    Text("YYYY-MM-DD").tag("yyyy-MM-dd")
                    Text("DD/MM/YYYY").tag("dd/MM/yyyy")
                    Text("MM/DD/YYYY").tag("MM/dd/yyyy")
                    Text("DD.MM.YYYY").tag("dd.MM.yyyy")
                }
                
                Toggle("Comma decimal (1,5)", isOn: $fieldMapping.useCommaDecimal)
                Toggle("Skip duplicates", isOn: $skipDuplicates)
            }
            
            Section {
                Button("Preview Import") {
                    generatePreview()
                }
                .disabled(!fieldMapping.isValid)
            }
        }
    }
    
    private func mappingPicker(_ label: String, selection: Binding<Int?>, required: Bool = false) -> some View {
        Picker(selection: Binding(
            get: { selection.wrappedValue ?? -1 },
            set: { selection.wrappedValue = $0 == -1 ? nil : $0 }
        )) {
            Text("Not mapped").tag(-1)
            if let headers = parseResult?.headers {
                ForEach(Array(headers.enumerated()), id: \.offset) { index, header in
                    Text(header).tag(index)
                }
            }
        } label: {
            HStack {
                Text(label)
                if required {
                    Text("*").foregroundStyle(.red)
                }
            }
        }
    }
    
    // MARK: - Step 3: Preview
    
    private var previewView: some View {
        List {
            Section {
                HStack {
                    VStack {
                        Text("\(previewEntries.filter { $0.isValid }.count)")
                            .font(.title)
                            .bold()
                            .foregroundStyle(.green)
                        Text("Valid")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    
                    VStack {
                        Text("\(previewEntries.filter { !$0.isValid }.count)")
                            .font(.title)
                            .bold()
                            .foregroundStyle(.red)
                        Text("Invalid")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            
            Section("Entries") {
                ForEach(previewEntries) { entry in
                    HStack {
                        VStack(alignment: .leading) {
                            if let date = entry.date {
                                Text(date.formatted(date: .abbreviated, time: .omitted))
                            } else {
                                Text("Invalid Date")
                                    .foregroundStyle(.red)
                            }
                            
                            if !entry.errors.isEmpty {
                                Text(entry.errors.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                        
                        Spacer()
                        
                        if let liters = entry.liters {
                            Text(String(format: "%.2f L", liters))
                        }
                    }
                }
            }
            
            Section {
                Button("Import Entries") {
                    performImport()
                }
                .disabled(previewEntries.filter { $0.isValid }.isEmpty)
                
                Button("Back") {
                    currentStep = .mapFields
                }
            }
        }
    }
    
    // MARK: - Step 4: Importing
    
    private var importingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Importing entries...")
                .font(.headline)
        }
    }
    
    // MARK: - Step 5: Complete
    
    private var completeView: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    if let result = importResult {
                        Image(systemName: result.isFullSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(result.isFullSuccess ? .green : .orange)
                        
                        Text(result.isFullSuccess ? "Import Complete" : "Completed with Issues")
                            .font(.title2.bold())
                        
                        HStack(spacing: 20) {
                            labelCount(result.successCount, "Imported", .green)
                            if result.duplicateCount > 0 {
                                labelCount(result.duplicateCount, "Skipped", .orange)
                            }
                            if result.failedCount > 0 {
                                labelCount(result.failedCount, "Failed", .red)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }
            .listRowBackground(Color.clear)
            
            if let result = importResult, !result.errors.isEmpty {
                Section("Errors") {
                    ForEach(result.errors.prefix(10), id: \.self) { error in
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            
            Section {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
    
    private func labelCount(_ count: Int, _ label: String, _ color: Color) -> some View {
        VStack {
            Text("\(count)")
                .font(.headline)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    // Actions match originals...
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Unable to access the file"
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                parseResult = try CSVImportService.parseCSV(from: url)
                if let result = parseResult, !result.isEmpty {
                    fieldMapping = CSVImportService.suggestMapping(for: result.headers)
                    currentStep = .mapFields
                    errorMessage = nil
                } else {
                    errorMessage = "The CSV file appears to be empty"
                }
            } catch {
                errorMessage = "Failed to read file: \(error.localizedDescription)"
            }
        case .failure(let error):
            errorMessage = "Failed to select file: \(error.localizedDescription)"
        }
    }
    
    private func generatePreview() {
        guard let result = parseResult else { return }
        previewEntries = CSVImportService.generatePreview(from: result, mapping: fieldMapping)
        currentStep = .preview
    }
    
    private func performImport() {
        guard let result = parseResult else { return }
        currentStep = .importing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            importResult = CSVImportService.importEntries(
                from: result,
                mapping: fieldMapping,
                repository: repository,
                skipDuplicates: skipDuplicates
            )
            currentStep = .complete
        }
    }
}

#Preview {
    CSVImportView()
        .environmentObject(FuelRepository())
}
