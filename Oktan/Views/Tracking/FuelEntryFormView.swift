import SwiftUI
import PhotosUI

struct FuelEntryFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var repository: FuelRepository
    @Environment(NotificationService.self) private var notificationService
    @Environment(AppSettings.self) private var settings

    private let existingEntry: FuelEntry?
    private var isEditing: Bool { existingEntry != nil }

    // Draft state persistence (only for new entries, not editing)
    @SceneStorage("fuelEntryForm.date") private var draftDate: Date = .now
    @SceneStorage("fuelEntryForm.odometerStart") private var draftOdometerStart: String = ""
    @SceneStorage("fuelEntryForm.odometerEnd") private var draftOdometerEnd: String = ""
    @SceneStorage("fuelEntryForm.liters") private var draftLiters: String = ""
    @SceneStorage("fuelEntryForm.pricePerLiter") private var draftPricePerLiter: String = ""
    @SceneStorage("fuelEntryForm.gasStation") private var draftGasStation: String = ""
    @SceneStorage("fuelEntryForm.driveMode") private var draftDriveModeRaw: String = FuelEntry.DriveMode.normal.rawValue
    @SceneStorage("fuelEntryForm.isFull") private var draftIsFull: Bool = true
    @SceneStorage("fuelEntryForm.notes") private var draftNotes: String = ""
    
    // Computed properties that use draft state for new entries, or direct state for editing
    private var date: Binding<Date> {
        if isEditing {
            return Binding(
                get: { _date },
                set: { _date = $0 }
            )
        } else {
            return $draftDate
        }
    }
    
    private var odometerStart: Binding<String> {
        if isEditing {
            return Binding(
                get: { _odometerStart },
                set: { _odometerStart = $0 }
            )
        } else {
            return $draftOdometerStart
        }
    }
    
    private var odometerEnd: Binding<String> {
        if isEditing {
            return Binding(
                get: { _odometerEnd },
                set: { _odometerEnd = $0 }
            )
        } else {
            return $draftOdometerEnd
        }
    }
    
    private var liters: Binding<String> {
        if isEditing {
            return Binding(
                get: { _liters },
                set: { _liters = $0 }
            )
        } else {
            return $draftLiters
        }
    }
    
    private var pricePerLiter: Binding<String> {
        if isEditing {
            return Binding(
                get: { _pricePerLiter },
                set: { _pricePerLiter = $0 }
            )
        } else {
            return $draftPricePerLiter
        }
    }
    
    private var gasStation: Binding<String> {
        if isEditing {
            return Binding(
                get: { _gasStation },
                set: { _gasStation = $0 }
            )
        } else {
            return $draftGasStation
        }
    }
    
    private var driveMode: Binding<FuelEntry.DriveMode> {
        if isEditing {
            return Binding(
                get: { _driveMode },
                set: { _driveMode = $0 }
            )
        } else {
            return Binding(
                get: { FuelEntry.DriveMode(rawValue: draftDriveModeRaw) ?? .normal },
                set: { draftDriveModeRaw = $0.rawValue }
            )
        }
    }
    
    private var isFull: Binding<Bool> {
        if isEditing {
            return Binding(
                get: { _isFull },
                set: { _isFull = $0 }
            )
        } else {
            return $draftIsFull
        }
    }
    
    private var notes: Binding<String> {
        if isEditing {
            return Binding(
                get: { _notes },
                set: { _notes = $0 }
            )
        } else {
            return $draftNotes
        }
    }
    
    // Direct state for editing mode
    @State private var _date: Date = .now
    @State private var _odometerStart: String = ""
    @State private var _odometerEnd: String = ""
    @State private var _liters: String = ""
    @State private var _pricePerLiter: String = ""
    @State private var _gasStation: String = ""
    @State private var _driveMode: FuelEntry.DriveMode = .normal
    @State private var _isFull: Bool = true
    @State private var _notes: String = ""

    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var receiptItem: PhotosPickerItem?
    @State private var isScanningReceipt = false
    @State private var receiptStatus: String?

    init(existingEntry: FuelEntry? = nil) {
        self.existingEntry = existingEntry
    }

    var body: some View {
        ZStack {
            FormShell(title: isEditing ? "Edit Fill-up" : "Add Fill-up") {
                Section {
                    PhotosPicker(selection: $receiptItem, matching: .images) {
                        Label(
                            isScanningReceipt ? "Reading Receipt…" : "Scan Receipt",
                            systemImage: "doc.text.viewfinder"
                        )
                    }
                    .disabled(isScanningReceipt)

                    if isScanningReceipt {
                        ProgressView()
                    }
                    if let receiptStatus {
                        Text(receiptStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Choose a receipt photo to fill in recognized date, liters, unit price, and station. Review every value before saving.")
                }

                Section("Fill-up") {
                    DatePicker("Date", selection: date, displayedComponents: [.date])
                        .accessibilityLabel("Purchase date")
                        .accessibilityIdentifier(AccessibilityID.formDatePicker)

                    TextField("Liters", text: liters)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel("Total liters purchased")
                        .accessibilityIdentifier(AccessibilityID.formLitersField)

                    TextField("Price per liter", text: pricePerLiter)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel("Price per liter")
                        .accessibilityIdentifier(AccessibilityID.formPriceField)

                    TextField("Gas station", text: gasStation)
                        .textInputAutocapitalization(.words)
                        .accessibilityLabel("Gas station name")
                        .accessibilityIdentifier(AccessibilityID.formStationField)

                    Picker("Drive mode", selection: driveMode) {
                        ForEach(FuelEntry.DriveMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }

                    Toggle("Full refill", isOn: isFull)
                }

                Section("Odometer") {
                    TextField("Start", text: odometerStart)
                        .keyboardType(.numberPad)
                        .accessibilityLabel("Odometer start reading")

                    TextField("End", text: odometerEnd)
                        .keyboardType(.numberPad)
                        .accessibilityLabel("Odometer end reading")

                    if let previousEnd = odometerGapWarning {
                        VStack(alignment: .leading) {
                            Label(
                                "Start doesn't match your last recorded reading (\(Int(previousEnd))).",
                                systemImage: "exclamationmark.triangle"
                            )
                            .font(.caption)
                            .foregroundStyle(.orange)

                            Button("Use \(Int(previousEnd))") {
                                odometerStart.wrappedValue = String(Int(previousEnd))
                            }
                            .font(.caption)
                        }
                    }
                }

                Section("Notes") {
                    TextField("Optional notes (e.g., AC on, cargo)", text: notes)
                        .textInputAutocapitalization(.sentences)
                        .accessibilityLabel("Notes")
                }

                if let message = errorMessage {
                    Section {
                        Text(message)
                            .foregroundStyle(.red)
                            .accessibilityLabel("Error: \(message)")
                    }
                }
            }
            .opacity(showSuccess ? 0.3 : 1)
            .disabled(showSuccess)
            
            if showSuccess {
                VStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .scaleEffect(2.0)
                        .foregroundStyle(.green)
                        .symbolEffect(.bounce, value: showSuccess)
                    
                    Text("Saved!")
                        .font(.title.bold())
                        .padding(.top)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close", action: { dismiss() })
                    .accessibilityIdentifier(AccessibilityID.formCloseButton)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(action: save) {
                    Label("Save", systemImage: "checkmark.circle.fill")
                }
                .disabled(!isValidForm)
                .accessibilityLabel(isValidForm ? "Save fill-up" : "Save (disabled, complete required fields)")
                .accessibilityIdentifier(AccessibilityID.formSaveButton)
            }
        }
        .onAppear(perform: setupForm)
        .onChange(of: receiptItem) { _, item in
            guard let item else { return }
            scanReceipt(item)
        }
    }

    /// The previous entry's end reading when the entered start diverges from it
    /// (new entries only) — used to warn about odometer gaps or overlaps.
    private var odometerGapWarning: Double? {
        guard !isEditing,
              let previousEnd = repository.visibleEntries.last?.odometerEnd,
              let start = parseNumber(draftOdometerStart),
              abs(start - previousEnd) > 0.5 else { return nil }
        return previousEnd
    }

    private var isValidForm: Bool {
        let litersValue = isEditing ? _liters : draftLiters
        let priceValue = isEditing ? _pricePerLiter : draftPricePerLiter
        let startValue = isEditing ? _odometerStart : draftOdometerStart
        let endValue = isEditing ? _odometerEnd : draftOdometerEnd
        
        guard parseNumber(litersValue) ?? 0 > 0, parseNumber(priceValue) ?? 0 > 0 else { return false }
        if let start = parseNumber(startValue), let end = parseNumber(endValue), end < start { return false }
        return true
    }

    private func setupForm() {
        if let entry = existingEntry {
            // Editing existing entry - use direct state
            _date = entry.date
            if let start = entry.odometerStart { _odometerStart = String(Int(start)) }
            if let end = entry.odometerEnd { _odometerEnd = String(Int(end)) }
            _liters = String(format: "%.2f", entry.totalLiters)
            _pricePerLiter = String(format: "%.2f", entry.pricePerLiter)
            _gasStation = entry.gasStation
            _driveMode = entry.driveMode
            _isFull = entry.isFullRefill
            _notes = entry.notes ?? ""
        } else {
            // New entry - prefill from last entry if draft is empty
            if draftLiters.isEmpty && draftPricePerLiter.isEmpty {
                prefillFromLastEntry()
            }
            // Otherwise, draft state is already restored from @SceneStorage
        }
    }

    private func prefillFromLastEntry() {
        guard let last = repository.visibleEntries.last else { return }
        if let end = last.odometerEnd { draftOdometerStart = String(Int(end)) }
        draftPricePerLiter = String(format: "%.2f", last.pricePerLiter)
        draftDriveModeRaw = last.driveMode.rawValue
        draftGasStation = last.gasStation
        draftIsFull = last.isFullRefill
    }

    private func scanReceipt(_ item: PhotosPickerItem) {
        isScanningReceipt = true
        receiptStatus = nil
        errorMessage = nil

        Task {
            defer {
                isScanningReceipt = false
                receiptItem = nil
            }
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw ReceiptScannerService.ScanError.invalidImage
                }
                let result = try await ReceiptScannerService.scan(imageData: data)
                applyReceipt(result)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func applyReceipt(_ result: ReceiptScannerService.Result) {
        var recognizedFields = 0
        if let receiptDate = result.date {
            date.wrappedValue = receiptDate
            recognizedFields += 1
        }
        if let receiptLiters = result.liters {
            liters.wrappedValue = String(format: "%.2f", receiptLiters)
            recognizedFields += 1
        }
        if let receiptPrice = result.pricePerLiter {
            pricePerLiter.wrappedValue = String(format: "%.3f", receiptPrice)
            recognizedFields += 1
        }
        if let receiptStation = result.station {
            gasStation.wrappedValue = receiptStation
            recognizedFields += 1
        }

        receiptStatus = recognizedFields > 0
            ? String(localized: "Filled \(recognizedFields) fields. Please verify the values.")
            : String(localized: "Text was detected, but no fuel values could be identified.")
    }

    private func save() {
        // Get values from appropriate source (draft or direct state)
        let litersValue: String
        let priceValue: String
        let dateValue: Date
        let odometerStartValue: String
        let odometerEndValue: String
        let gasStationValue: String
        let driveModeValue: FuelEntry.DriveMode
        let isFullValue: Bool
        let notesValue: String
        
        if isEditing {
            litersValue = _liters
            priceValue = _pricePerLiter
            dateValue = _date
            odometerStartValue = _odometerStart
            odometerEndValue = _odometerEnd
            gasStationValue = _gasStation
            driveModeValue = _driveMode
            isFullValue = _isFull
            notesValue = _notes
        } else {
            litersValue = draftLiters
            priceValue = draftPricePerLiter
            dateValue = draftDate
            odometerStartValue = draftOdometerStart
            odometerEndValue = draftOdometerEnd
            gasStationValue = draftGasStation
            driveModeValue = FuelEntry.DriveMode(rawValue: draftDriveModeRaw) ?? .normal
            isFullValue = draftIsFull
            notesValue = draftNotes
        }
        
        guard let litersDouble = parseNumber(litersValue), litersDouble > 0 else {
            errorMessage = "Please enter liters purchased."
            return
        }
        guard let price = parseNumber(priceValue), price > 0 else {
            errorMessage = "Please enter a valid price per liter."
            return
        }

        let entry = FuelEntry(
            id: existingEntry?.id ?? UUID(),
            date: dateValue,
            odometerStart: parseNumber(odometerStartValue),
            odometerEnd: parseNumber(odometerEndValue),
            totalLiters: litersDouble,
            pricePerLiter: price,
            gasStation: gasStationValue.isEmpty ? "Unknown" : gasStationValue,
            driveMode: driveModeValue,
            isFullRefill: isFullValue,
            notes: notesValue.isEmpty ? nil : notesValue
        )

        if isEditing {
            guard repository.update(entry) else {
                errorMessage = repository.lastError?.errorDescription ?? "The entry could not be updated."
                repository.clearError()
                return
            }
        } else {
            guard repository.add(entry) else {
                // Show specific error from repository if available
                if let error = repository.lastError {
                    errorMessage = error.errorDescription
                    repository.clearError()
                } else {
                    errorMessage = "The entry could not be saved. Check odometer values and required fields."
                }
                return
            }
            
            // Clear draft state after successful save
            draftOdometerStart = ""
            draftOdometerEnd = ""
            draftLiters = ""
            draftPricePerLiter = ""
            draftGasStation = ""
            draftDriveModeRaw = FuelEntry.DriveMode.normal.rawValue
            draftIsFull = true
            draftNotes = ""
        }

        // Reset inactivity reminder and refresh the next fill-up prediction
        Task {
            await notificationService.scheduleInactivityReminder(lastEntryDate: dateValue)
            if let prediction = ChartDataService.predictNextFillup(from: repository.visibleEntries) {
                await notificationService.scheduleNextFillupReminder(
                    predictedDate: prediction.date,
                    estimatedCost: prediction.estimatedCost.map { settings.formatCost($0) }
                )
            }
        }
        
        triggerHapticFeedback()
        
        withAnimation(.spring()) {
            showSuccess = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            dismiss()
        }
    }

    private func triggerHapticFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func parseNumber(_ text: String) -> Double? {
        FuelEntryFormView.parseDecimal(text, locale: settings.locale)
    }

    /// A single "." or "," is always the decimal separator, so prefilled values
    /// ("1.659") and decimal-pad input ("1,659") agree in every locale. Only
    /// grouped input ("1.234,5") goes through the locale's number formatter.
    static func parseDecimal(_ text: String, locale: Locale) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let separators = trimmed.filter { $0 == "." || $0 == "," }
        if separators.count <= 1 {
            return Double(trimmed.replacingOccurrences(of: ",", with: "."))
        }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        return formatter.number(from: trimmed)?.doubleValue
    }
}

#Preview {
    FuelEntryFormView()
        .environmentObject(FuelRepository())
}
