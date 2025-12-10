import SwiftUI

struct FuelEntryFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var repository: FuelRepository

    private let existingEntry: FuelEntry?
    private var isEditing: Bool { existingEntry != nil }

    @State private var date: Date = .now
    @State private var odometerStart: String = ""
    @State private var odometerEnd: String = ""
    @State private var liters: String = ""
    @State private var pricePerLiter: String = ""
    @State private var gasStation: String = ""
    @State private var driveMode: FuelEntry.DriveMode = .normal
    @State private var isFull: Bool = true
    @State private var notes: String = ""

    @State private var errorMessage: String?

    init(existingEntry: FuelEntry? = nil) {
        self.existingEntry = existingEntry
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Fill-up") {
                    DatePicker("Date", selection: $date, displayedComponents: [.date])
                        .accessibilityLabel("Purchase date")

                    TextField("Liters", text: $liters)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel("Total liters purchased")

                    TextField("Price per liter", text: $pricePerLiter)
                        .keyboardType(.decimalPad)

                    TextField("Gas station", text: $gasStation)
                        .textInputAutocapitalization(.words)

                    Picker("Drive mode", selection: $driveMode) {
                        ForEach(FuelEntry.DriveMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }

                    Toggle("Full refill", isOn: $isFull)
                }

                Section("Odometer") {
                    TextField("Start", text: $odometerStart)
                        .keyboardType(.numberPad)
                    TextField("End", text: $odometerEnd)
                        .keyboardType(.numberPad)
                }

                Section("Notes") {
                    TextField("Optional notes (e.g., AC on, cargo)", text: $notes)
                        .textInputAutocapitalization(.sentences)
                }

                if let message = errorMessage {
                    Section {
                        Text(message)
                            .foregroundStyle(DesignSystem.ColorPalette.errorRed)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(DesignSystem.ColorPalette.background)
            .navigationTitle(isEditing ? "Edit Fill-up" : "Add Fill-up")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: { dismiss() })
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: save) {
                        Label("Save", systemImage: "checkmark.circle.fill")
                    }
                    .tint(DesignSystem.ColorPalette.primaryBlue)
                    .disabled(!isValidForm)
                }
            }
            .onAppear(perform: setupForm)
        }
    }

    private var isValidForm: Bool {
        guard Double(liters) ?? 0 > 0, Double(pricePerLiter) ?? 0 > 0 else { return false }
        if let start = Double(odometerStart), let end = Double(odometerEnd), end < start { return false }
        return true
    }

    private func setupForm() {
        if let entry = existingEntry {
            // Editing existing entry
            date = entry.date
            if let start = entry.odometerStart { odometerStart = String(Int(start)) }
            if let end = entry.odometerEnd { odometerEnd = String(Int(end)) }
            liters = String(format: "%.2f", entry.totalLiters)
            pricePerLiter = String(format: "%.2f", entry.pricePerLiter)
            gasStation = entry.gasStation
            driveMode = entry.driveMode
            isFull = entry.isFullRefill
            notes = entry.notes ?? ""
        } else {
            // New entry - prefill from last entry
            prefillFromLastEntry()
        }
    }

    private func prefillFromLastEntry() {
        guard let last = repository.entries.sorted(by: { $0.date < $1.date }).last else { return }
        if let end = last.odometerEnd { odometerStart = String(Int(end)) }
        pricePerLiter = String(format: "%.2f", last.pricePerLiter)
        driveMode = last.driveMode
        gasStation = last.gasStation
        isFull = last.isFullRefill
    }

    private func save() {
        guard let litersValue = Double(liters), litersValue > 0 else {
            errorMessage = "Please enter liters purchased."
            return
        }
        guard let price = Double(pricePerLiter), price > 0 else {
            errorMessage = "Please enter a valid price per liter."
            return
        }

        let entry = FuelEntry(
            id: existingEntry?.id ?? UUID(),
            date: date,
            odometerStart: Double(odometerStart),
            odometerEnd: Double(odometerEnd),
            totalLiters: litersValue,
            pricePerLiter: price,
            gasStation: gasStation.isEmpty ? "Unknown" : gasStation,
            driveMode: driveMode,
            isFullRefill: isFull,
            notes: notes.isEmpty ? nil : notes
        )

        if isEditing {
            repository.update(entry)
        } else {
            guard repository.add(entry) else {
                errorMessage = "The entry could not be saved. Check odometer values and required fields."
                return
            }
        }

        triggerHapticFeedback()
        dismiss()
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
