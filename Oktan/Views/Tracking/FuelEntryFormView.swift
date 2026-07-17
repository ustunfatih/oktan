import SwiftUI

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

    init(existingEntry: FuelEntry? = nil) {
        self.existingEntry = existingEntry
    }

    var body: some View {
        ZStack {
            FormShell(title: isEditing ? "Edit Fill-up" : "Add Fill-up") {
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
    }

    /// The previous entry's end reading when the entered start diverges from it
    /// (new entries only) — used to warn about odometer gaps or overlaps.
    private var odometerGapWarning: Double? {
        guard !isEditing,
              let previousEnd = repository.visibleEntries.last?.odometerEnd,
              let start = Double(draftOdometerStart),
              abs(start - previousEnd) > 0.5 else { return nil }
        return previousEnd
    }

    private var isValidForm: Bool {
        let litersValue = isEditing ? _liters : draftLiters
        let priceValue = isEditing ? _pricePerLiter : draftPricePerLiter
        let startValue = isEditing ? _odometerStart : draftOdometerStart
        let endValue = isEditing ? _odometerEnd : draftOdometerEnd
        
        guard Double(litersValue) ?? 0 > 0, Double(priceValue) ?? 0 > 0 else { return false }
        if let start = Double(startValue), let end = Double(endValue), end < start { return false }
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
        
        guard let litersDouble = Double(litersValue), litersDouble > 0 else {
            errorMessage = "Please enter liters purchased."
            return
        }
        guard let price = Double(priceValue), price > 0 else {
            errorMessage = "Please enter a valid price per liter."
            return
        }

        let entry = FuelEntry(
            id: existingEntry?.id ?? UUID(),
            date: dateValue,
            odometerStart: Double(odometerStartValue),
            odometerEnd: Double(odometerEndValue),
            totalLiters: litersDouble,
            pricePerLiter: price,
            gasStation: gasStationValue.isEmpty ? "Unknown" : gasStationValue,
            driveMode: driveModeValue,
            isFullRefill: isFullValue,
            notes: notesValue.isEmpty ? nil : notesValue
        )

        if isEditing {
            repository.update(entry)
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
}

#Preview {
    FuelEntryFormView()
        .environmentObject(FuelRepository())
}
