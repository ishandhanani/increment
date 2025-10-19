import SwiftUI

// MARK: - Custom Exercises List View

@MainActor
public struct CustomExercisesListView: View {
    @Binding var isPresented: Bool
    @State private var customLifts: [Lift] = []
    @State private var showingAddExercise = false
    @State private var editingLift: Lift?
    @State private var showingEditForm = false
    @State private var isLoading = true
    @State private var errorMessage: String?

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    isPresented = false
                } label: {
                    HStack(spacing: 6) {
                        Text("←")
                            .font(.system(.body, design: .monospaced))
                        Text("Back")
                            .font(.system(.body, design: .monospaced))
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .padding(20)

                Spacer()
            }

            // Content
            if isLoading {
                Spacer()
                ProgressView()
                    .tint(.white)
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                Text("Error: \(error)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            } else if customLifts.isEmpty {
                Spacer()
                VStack(spacing: 24) {
                    Text("No custom exercises")
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Button {
                        showingAddExercise = true
                    } label: {
                        Text("Create Exercise")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.black)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        // Header with count
                        HStack {
                            Text("\(customLifts.count) custom exercise\(customLifts.count == 1 ? "" : "s")")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.white.opacity(0.6))

                            Spacer()

                            Button {
                                showingAddExercise = true
                            } label: {
                                HStack(spacing: 4) {
                                    Text("+")
                                        .font(.system(.body, design: .monospaced))
                                    Text("New")
                                        .font(.system(.caption, design: .monospaced))
                                }
                                .foregroundColor(.white)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)

                        ForEach(customLifts, id: \.id) { lift in
                            CustomExerciseRow(lift: lift) {
                                editingLift = lift
                                showingEditForm = true
                            } onDelete: {
                                deleteExercise(lift)
                            }
                        }
                    }
                    .padding(.top, 20)
                }
            }
        }
        .background(Color.black)
        .task {
            await loadCustomLifts()
        }
        .fullScreenCover(isPresented: $showingAddExercise) {
            CustomExerciseFormView(isPresented: $showingAddExercise, existingLift: nil) {
                Task { await loadCustomLifts() }
            }
        }
        .fullScreenCover(isPresented: $showingEditForm) {
            CustomExerciseFormView(isPresented: $showingEditForm, existingLift: editingLift) {
                editingLift = nil
                Task { await loadCustomLifts() }
            }
        }
    }

    private func loadCustomLifts() async {
        isLoading = true
        errorMessage = nil

        do {
            customLifts = try await DatabaseManager.shared.loadCustomLifts()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func deleteExercise(_ lift: Lift) {
        Task {
            do {
                try await DatabaseManager.shared.deleteCustomLift(named: lift.name)
                await loadCustomLifts()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Custom Exercise Row

struct CustomExerciseRow: View {
    let lift: Lift
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onEdit) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(lift.name)
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.medium)
                            .foregroundColor(.white)

                        HStack(spacing: 6) {
                            Text(lift.category.rawValue)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))

                            Text("•")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.white.opacity(0.2))

                            Text(lift.equipment.rawValue)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }

                    Spacer()

                    Button(action: onDelete) {
                        Text("×")
                            .font(.system(.title3, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.white.opacity(0.05))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.white.opacity(0.1)),
                alignment: .bottom
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Custom Exercise Form View

@MainActor
public struct CustomExerciseFormView: View {
    @Binding var isPresented: Bool
    let existingLift: Lift?
    let onSave: () -> Void

    @State private var name: String
    @State private var category: LiftCategory
    @State private var equipment: Equipment
    @State private var selectedMuscleGroups: Set<MuscleGroup>

    @State private var isSaving = false
    @State private var errorMessage: String?

    public init(isPresented: Binding<Bool>, existingLift: Lift?, onSave: @escaping () -> Void) {
        self._isPresented = isPresented
        self.existingLift = existingLift
        self.onSave = onSave

        if let lift = existingLift {
            _name = State(initialValue: lift.name)
            _category = State(initialValue: lift.category)
            _equipment = State(initialValue: lift.equipment)
            _selectedMuscleGroups = State(initialValue: Set(lift.muscleGroups))
        } else {
            _name = State(initialValue: "")
            _category = State(initialValue: .push)
            _equipment = State(initialValue: .barbell)
            _selectedMuscleGroups = State(initialValue: [])
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    isPresented = false
                } label: {
                    HStack(spacing: 6) {
                        Text("←")
                            .font(.system(.body, design: .monospaced))
                        Text("Cancel")
                            .font(.system(.body, design: .monospaced))
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .padding(20)

                Spacer()
            }

            ScrollView {
                VStack(spacing: 32) {
                    // Title
                    Text(existingLift == nil ? "New Exercise" : "Edit Exercise")
                        .font(.system(.title, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    // Name field
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Name")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))

                        TextField("Exercise name", text: $name)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(16)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    }

                    // Category picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Category")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))

                        HStack(spacing: 8) {
                            ForEach(LiftCategory.allCases, id: \.self) { cat in
                                Button {
                                    category = cat
                                } label: {
                                    Text(cat.rawValue)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(category == cat ? .black : .white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(category == cat ? Color.white : Color.white.opacity(0.1))
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Equipment picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Equipment")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))

                        VStack(spacing: 8) {
                            ForEach(Array(Equipment.allCases.chunked(into: 3)), id: \.first) { row in
                                HStack(spacing: 8) {
                                    ForEach(row, id: \.self) { eq in
                                        Button {
                                            equipment = eq
                                        } label: {
                                            Text(equipmentLabel(eq))
                                                .font(.system(.caption, design: .monospaced))
                                                .foregroundColor(equipment == eq ? .black : .white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 10)
                                                .background(equipment == eq ? Color.white : Color.white.opacity(0.1))
                                                .cornerRadius(6)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }

                    // Muscle groups
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Muscle Groups")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))

                        VStack(spacing: 8) {
                            ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                                Button {
                                    if selectedMuscleGroups.contains(muscle) {
                                        selectedMuscleGroups.remove(muscle)
                                    } else {
                                        selectedMuscleGroups.insert(muscle)
                                    }
                                } label: {
                                    HStack {
                                        Text(muscle.rawValue.capitalized)
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundColor(.white)

                                        Spacer()

                                        if selectedMuscleGroups.contains(muscle) {
                                            Text("✓")
                                                .font(.system(.body, design: .monospaced))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .padding(16)
                                    .background(selectedMuscleGroups.contains(muscle) ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Error message
                    if let error = errorMessage {
                        Text(error)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                            .padding()
                    }

                    // Save button
                    Button {
                        Task { await saveExercise() }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Text("Save Exercise")
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.medium)
                        }
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isValid ? Color.white : Color.white.opacity(0.3))
                    .cornerRadius(8)
                    .disabled(!isValid || isSaving)
                    .buttonStyle(.plain)
                }
                .padding(24)
            }
        }
        .background(Color.black)
    }

    private var isValid: Bool {
        !name.isEmpty && !selectedMuscleGroups.isEmpty
    }

    private func equipmentLabel(_ equipment: Equipment) -> String {
        switch equipment {
        case .barbell: return "Barbell"
        case .dumbbell: return "Dumbbell"
        case .cable: return "Cable"
        case .machine: return "Machine"
        case .bodyweight: return "Bodyweight"
        case .cardioMachine: return "Cardio"
        }
    }

    private func saveExercise() async {
        isSaving = true
        errorMessage = nil

        do {
            let steelConfig = SteelConfig(
                repRange: 8...12,
                baseIncrement: 5.0,
                rounding: 2.5,
                microAdjustStep: 2.5,
                weeklyCapPct: 5.0
            )

            let lift = Lift(
                id: name.lowercased().replacingOccurrences(of: " ", with: "_"),
                name: name,
                category: category,
                equipment: equipment,
                muscleGroups: Array(selectedMuscleGroups),
                steelConfig: steelConfig
            )

            if let existing = existingLift {
                try await DatabaseManager.shared.deleteCustomLift(named: existing.name)
            }

            try await DatabaseManager.shared.saveCustomLift(lift)

            isSaving = false
            isPresented = false
            onSave()
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }
}

// MARK: - Array Extension

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
