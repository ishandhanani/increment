import SwiftUI

// MARK: - Workout Rotation View

@MainActor
public struct WorkoutRotationView: View {
    @Binding var isPresented: Bool
    @State private var builtInTemplates: [WorkoutTemplate] = []
    @State private var customTemplates: [WorkoutTemplate] = []
    @State private var selectedTemplateIds: [UUID] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    private var allTemplates: [WorkoutTemplate] {
        builtInTemplates + customTemplates
    }

    private var selectedTemplates: [WorkoutTemplate] {
        selectedTemplateIds.compactMap { id in
            allTemplates.first { $0.id == id }
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
                        Text("Back")
                            .font(.system(.body, design: .monospaced))
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .padding(20)

                Spacer()

                Button {
                    Task {
                        do {
                            try await DatabaseManager.shared.saveWorkoutRotation(selectedTemplateIds)
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                } label: {
                    Text("Save")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .padding(20)
            }

            if isLoading {
                Spacer()
                ProgressView()
                    .tint(.white)
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Workout Rotation")
                            .font(.system(.title, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("Select and order workouts for your rotation cycle")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))

                        // Current rotation
                        if !selectedTemplates.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Current Rotation (\(selectedTemplates.count))")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.6))

                                ForEach(Array(selectedTemplates.enumerated()), id: \.element.id) { index, template in
                                    HStack {
                                        Text("\(index + 1).")
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundColor(.white.opacity(0.6))
                                            .frame(width: 30, alignment: .leading)

                                        Text(template.name)
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundColor(.white)

                                        Spacer()

                                        // Move up
                                        if index > 0 {
                                            Button {
                                                selectedTemplateIds.swapAt(index, index - 1)
                                            } label: {
                                                Text("↑")
                                                    .font(.system(.body, design: .monospaced))
                                                    .foregroundColor(.white.opacity(0.6))
                                            }
                                            .buttonStyle(.plain)
                                        }

                                        // Move down
                                        if index < selectedTemplates.count - 1 {
                                            Button {
                                                selectedTemplateIds.swapAt(index, index + 1)
                                            } label: {
                                                Text("↓")
                                                    .font(.system(.body, design: .monospaced))
                                                    .foregroundColor(.white.opacity(0.6))
                                            }
                                            .buttonStyle(.plain)
                                        }

                                        Button {
                                            selectedTemplateIds.remove(at: index)
                                        } label: {
                                            Text("✕")
                                                .font(.system(.body, design: .monospaced))
                                                .foregroundColor(.red.opacity(0.8))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(12)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(8)
                                }
                            }
                        } else {
                            Text("No workouts in rotation")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.white.opacity(0.4))
                                .padding(.vertical, 16)
                        }

                        // Available workouts
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Available Workouts")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.white.opacity(0.6))

                            // Built-in workouts
                            if !builtInTemplates.isEmpty {
                                Text("Built-in")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.4))
                                    .padding(.top, 8)

                                ForEach(builtInTemplates) { template in
                                    if !selectedTemplateIds.contains(template.id) {
                                        Button {
                                            selectedTemplateIds.append(template.id)
                                        } label: {
                                            HStack {
                                                Text(template.name)
                                                    .font(.system(.body, design: .monospaced))
                                                    .foregroundColor(.white)

                                                Spacer()

                                                Text("+")
                                                    .font(.system(.body, design: .monospaced))
                                                    .foregroundColor(.white.opacity(0.6))
                                            }
                                            .padding(12)
                                            .background(Color.white.opacity(0.03))
                                            .cornerRadius(8)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }

                            // Custom workouts
                            if !customTemplates.isEmpty {
                                Text("Custom")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.4))
                                    .padding(.top, 8)

                                ForEach(customTemplates) { template in
                                    if !selectedTemplateIds.contains(template.id) {
                                        Button {
                                            selectedTemplateIds.append(template.id)
                                        } label: {
                                            HStack {
                                                Text(template.name)
                                                    .font(.system(.body, design: .monospaced))
                                                    .foregroundColor(.white)

                                                Spacer()

                                                Text("+")
                                                    .font(.system(.body, design: .monospaced))
                                                    .foregroundColor(.white.opacity(0.6))
                                            }
                                            .padding(12)
                                            .background(Color.white.opacity(0.03))
                                            .cornerRadius(8)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .background(Color.black)
        .task {
            await loadData()
        }
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            // Load built-in templates (generated from WorkoutBuilder)
            builtInTemplates = [
                WorkoutBuilder.build(type: .push),
                WorkoutBuilder.build(type: .pull),
                WorkoutBuilder.build(type: .legs),
                WorkoutBuilder.build(type: .cardio)
            ]

            // Load custom templates
            customTemplates = try await DatabaseManager.shared.loadCustomTemplates()

            // Load saved rotation
            if let savedIds = try await DatabaseManager.shared.loadWorkoutRotation() {
                selectedTemplateIds = savedIds
            } else {
                // Default to built-in rotation if nothing saved
                selectedTemplateIds = builtInTemplates.map { $0.id }
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Custom Workout Templates List View

@MainActor
public struct CustomWorkoutTemplatesListView: View {
    @Binding var isPresented: Bool
    @State private var customTemplates: [WorkoutTemplate] = []
    @State private var customLifts: [Lift] = []
    @State private var showingAddTemplate = false
    @State private var editingTemplate: WorkoutTemplate?
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
            } else if customTemplates.isEmpty {
                Spacer()
                VStack(spacing: 24) {
                    Text("No custom workouts")
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Button {
                        showingAddTemplate = true
                    } label: {
                        Text("Create Workout")
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
                            Text("\(customTemplates.count) custom workout\(customTemplates.count == 1 ? "" : "s")")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.white.opacity(0.6))

                            Spacer()

                            Button {
                                showingAddTemplate = true
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

                        // List of templates
                        ForEach(customTemplates) { template in
                            VStack(spacing: 0) {
                                Button {
                                    editingTemplate = template
                                    showingEditForm = true
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(template.name)
                                                .font(.system(.body, design: .monospaced))
                                                .foregroundColor(.white)

                                            Text("\(template.exercises.count) exercise\(template.exercises.count == 1 ? "" : "s")")
                                                .font(.system(.caption, design: .monospaced))
                                                .foregroundColor(.white.opacity(0.6))
                                        }

                                        Spacer()

                                        Text("→")
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundColor(.white.opacity(0.4))
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 16)
                                    .background(Color.black)
                                }
                                .buttonStyle(.plain)

                                Divider()
                                    .background(Color.white.opacity(0.1))
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
        .background(Color.black)
        .fullScreenCover(isPresented: $showingAddTemplate) {
            CustomWorkoutTemplateFormView(
                isPresented: $showingAddTemplate,
                existingTemplate: nil,
                customLifts: customLifts,
                onSave: { template in
                    Task {
                        do {
                            try await DatabaseManager.shared.saveCustomTemplate(template)
                            await loadTemplates()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
            )
        }
        .fullScreenCover(isPresented: $showingEditForm) {
            if let template = editingTemplate {
                CustomWorkoutTemplateFormView(
                    isPresented: $showingEditForm,
                    existingTemplate: template,
                    customLifts: customLifts,
                    onSave: { updatedTemplate in
                        Task {
                            do {
                                try await DatabaseManager.shared.saveCustomTemplate(updatedTemplate)
                                await loadTemplates()
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    },
                    onDelete: {
                        Task {
                            do {
                                try await DatabaseManager.shared.deleteCustomTemplate(id: template.id)
                                await loadTemplates()
                                showingEditForm = false
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    }
                )
            }
        }
        .task {
            await loadTemplates()
            await loadCustomLifts()
        }
    }

    private func loadTemplates() async {
        isLoading = true
        errorMessage = nil
        do {
            customTemplates = try await DatabaseManager.shared.loadCustomTemplates()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func loadCustomLifts() async {
        do {
            customLifts = try await DatabaseManager.shared.loadCustomLifts()
        } catch {
            // Silently fail - custom lifts are optional
        }
    }
}

// MARK: - Custom Workout Template Form View

@MainActor
public struct CustomWorkoutTemplateFormView: View {
    @Binding var isPresented: Bool
    let existingTemplate: WorkoutTemplate?
    let customLifts: [Lift]
    let onSave: (WorkoutTemplate) -> Void
    let onDelete: (() -> Void)?

    @State private var name: String
    @State private var selectedExercises: [WorkoutExercise] = []
    @State private var showingExercisePicker = false
    @State private var editingExerciseIndex: Int?

    public init(
        isPresented: Binding<Bool>,
        existingTemplate: WorkoutTemplate?,
        customLifts: [Lift],
        onSave: @escaping (WorkoutTemplate) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self._isPresented = isPresented
        self.existingTemplate = existingTemplate
        self.customLifts = customLifts
        self.onSave = onSave
        self.onDelete = onDelete
        self._name = State(initialValue: existingTemplate?.name ?? "")
        self._selectedExercises = State(initialValue: existingTemplate?.exercises ?? [])
    }

    private var isValid: Bool {
        !name.isEmpty && !selectedExercises.isEmpty
    }

    private var allLifts: [Lift] {
        LiftLibrary.allLifts(including: customLifts)
    }

    private var headerView: some View {
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

            if let onDelete = onDelete {
                Button {
                    onDelete()
                } label: {
                    Text("Delete")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .padding(20)
            }
        }
    }

    private var formContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Title
            Text(existingTemplate == nil ? "New Workout" : "Edit Workout")
                .font(.system(.title, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.white)

            // Name
            VStack(alignment: .leading, spacing: 8) {
                Text("Workout Name")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))

                TextField("e.g., Upper Body", text: $name)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
            }

            exercisesSection

            Spacer(minLength: 80)
        }
        .padding(20)
    }

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Exercises (\(selectedExercises.count))")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))

                Spacer()

                Button {
                    editingExerciseIndex = nil
                    showingExercisePicker = true
                } label: {
                    HStack(spacing: 4) {
                        Text("+")
                            .font(.system(.body, design: .monospaced))
                        Text("Add")
                            .font(.system(.caption, design: .monospaced))
                    }
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }

            if selectedExercises.isEmpty {
                Text("No exercises added yet")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.vertical, 32)
                    .frame(maxWidth: .infinity)
            } else {
                exerciseList
            }
        }
    }

    @ViewBuilder
    private var exerciseList: some View {
        ForEach(selectedExercises.indices, id: \.self) { index in
            exerciseRow(index: index, exercise: selectedExercises[index])
        }
    }

    private func exerciseRow(index: Int, exercise: WorkoutExercise) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(index + 1). \(exercise.lift.name)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)

                Text("\(exercise.sets) sets × \(exercise.reps) reps, \(exercise.restSeconds)s rest")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            Button {
                editingExerciseIndex = index
                showingExercisePicker = true
            } label: {
                Text("Edit")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
            }
            .buttonStyle(.plain)

            Button {
                removeExercise(at: index)
            } label: {
                Text("✕")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.red.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }

    private func removeExercise(at index: Int) {
        selectedExercises.remove(at: index)
        // Reorder
        for i in 0..<selectedExercises.count {
            selectedExercises[i] = WorkoutExercise(
                id: selectedExercises[i].id,
                lift: selectedExercises[i].lift,
                order: i,
                priority: selectedExercises[i].priority,
                sets: selectedExercises[i].sets,
                reps: selectedExercises[i].reps,
                restSeconds: selectedExercises[i].restSeconds
            )
        }
    }

    private var saveButton: some View {
        Button {
            let template = WorkoutTemplate(
                id: existingTemplate?.id ?? UUID(),
                name: name,
                workoutType: .push, // Not used for custom templates
                exercises: selectedExercises
            )
            onSave(template)
            isPresented = false
        } label: {
            Text("Save Workout")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(isValid ? .black : .white.opacity(0.3))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isValid ? Color.white : Color.white.opacity(0.1))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .disabled(!isValid)
        .padding(20)
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerView

            ScrollView {
                formContent
            }

            saveButton
        }
        .background(Color.black)
        .sheet(isPresented: $showingExercisePicker) {
            ExercisePickerView(
                allLifts: allLifts,
                selectedExercise: editingExerciseIndex != nil ? selectedExercises[editingExerciseIndex!] : nil,
                onSelect: { exercise in
                    if let editIndex = editingExerciseIndex {
                        selectedExercises[editIndex] = exercise
                    } else {
                        selectedExercises.append(exercise)
                    }
                    showingExercisePicker = false
                }
            )
        }
    }
}

// MARK: - Exercise Picker View

@MainActor
struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let allLifts: [Lift]
    let selectedExercise: WorkoutExercise?
    let onSelect: (WorkoutExercise) -> Void

    @State private var selectedLift: Lift?
    @State private var sets: Int
    @State private var reps: Int
    @State private var restSeconds: Int
    @State private var priority: LiftPriority
    @State private var searchText = ""

    init(allLifts: [Lift], selectedExercise: WorkoutExercise?, onSelect: @escaping (WorkoutExercise) -> Void) {
        self.allLifts = allLifts
        self.selectedExercise = selectedExercise
        self.onSelect = onSelect
        self._selectedLift = State(initialValue: selectedExercise?.lift)
        self._sets = State(initialValue: selectedExercise?.sets ?? 3)
        self._reps = State(initialValue: selectedExercise?.reps ?? 10)
        self._restSeconds = State(initialValue: selectedExercise?.restSeconds ?? 90)
        self._priority = State(initialValue: selectedExercise?.priority ?? .accessory)
    }

    private var filteredLifts: [Lift] {
        if searchText.isEmpty {
            return allLifts
        }
        return allLifts.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var isValid: Bool {
        selectedLift != nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white.opacity(0.6))
                    TextField("Search exercises", text: $searchText)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                // Exercise list
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredLifts, id: \.name) { lift in
                            Button {
                                selectedLift = lift
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(lift.name)
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundColor(.white)

                                        Text("\(lift.category.rawValue) • \(lift.equipment.rawValue)")
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundColor(.white.opacity(0.6))
                                    }

                                    Spacer()

                                    if selectedLift?.name == lift.name {
                                        Text("✓")
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(selectedLift?.name == lift.name ? Color.white.opacity(0.1) : Color.clear)
                            }
                            .buttonStyle(.plain)

                            Divider()
                                .background(Color.white.opacity(0.1))
                        }
                    }
                }

                // Configuration
                if selectedLift != nil {
                    VStack(spacing: 16) {
                        Divider()
                            .background(Color.white.opacity(0.2))

                        // Sets
                        HStack {
                            Text("Sets")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.white)

                            Spacer()

                            HStack(spacing: 12) {
                                Button("-") {
                                    if sets > 1 { sets -= 1 }
                                }
                                .foregroundColor(.white)

                                Text("\(sets)")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.white)
                                    .frame(minWidth: 30)

                                Button("+") {
                                    if sets < 10 { sets += 1 }
                                }
                                .foregroundColor(.white)
                            }
                            .buttonStyle(.plain)
                        }

                        // Reps
                        HStack {
                            Text("Reps")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.white)

                            Spacer()

                            HStack(spacing: 12) {
                                Button("-") {
                                    if reps > 1 { reps -= 1 }
                                }
                                .foregroundColor(.white)

                                Text("\(reps)")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.white)
                                    .frame(minWidth: 30)

                                Button("+") {
                                    if reps < 50 { reps += 1 }
                                }
                                .foregroundColor(.white)
                            }
                            .buttonStyle(.plain)
                        }

                        // Rest
                        HStack {
                            Text("Rest (sec)")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.white)

                            Spacer()

                            HStack(spacing: 12) {
                                Button("-") {
                                    if restSeconds > 30 { restSeconds -= 15 }
                                }
                                .foregroundColor(.white)

                                Text("\(restSeconds)")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.white)
                                    .frame(minWidth: 40)

                                Button("+") {
                                    if restSeconds < 300 { restSeconds += 15 }
                                }
                                .foregroundColor(.white)
                            }
                            .buttonStyle(.plain)
                        }

                        // Priority
                        HStack {
                            Text("Priority")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.white)

                            Spacer()

                            HStack(spacing: 12) {
                                ForEach([LiftPriority.core, LiftPriority.accessory], id: \.self) { p in
                                    Button {
                                        priority = p
                                    } label: {
                                        Text(p.rawValue)
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundColor(priority == p ? .black : .white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(priority == p ? Color.white : Color.white.opacity(0.1))
                                            .cornerRadius(4)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // Add button
                        Button {
                            guard let lift = selectedLift else { return }
                            let exercise = WorkoutExercise(
                                id: selectedExercise?.id ?? UUID(),
                                lift: lift,
                                order: selectedExercise?.order ?? 0,
                                priority: priority,
                                sets: sets,
                                reps: reps,
                                restSeconds: restSeconds
                            )
                            onSelect(exercise)
                        } label: {
                            Text(selectedExercise == nil ? "Add Exercise" : "Update Exercise")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(20)
                }
            }
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }
}
