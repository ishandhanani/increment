import SwiftUI

@MainActor
struct PreWorkoutView: View {
    @Environment(SessionManager.self) private var sessionManager
    @State private var selectedRating: Int = 3
    @State private var feelingNote: String = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Back button header
            HStack {
                Button {
                    sessionManager.discardSession()
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

            VStack(spacing: 24) {
                Spacer()

                // Header
                VStack(spacing: 12) {
                Text("How are you feeling?")
                    .font(.system(.title2, design: .monospaced))
                    .fontWeight(.bold)

                Text("Rate your energy and readiness")
                    .font(.system(.body, design: .monospaced))
                    .opacity(0.7)
            }
            .foregroundColor(.white)

            // Rating scale
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    ForEach(1...5, id: \.self) { rating in
                        Button {
                            selectedRating = rating
                        } label: {
                            Text("\(rating)")
                                .font(.system(.title, design: .monospaced))
                                .fontWeight(selectedRating == rating ? .bold : .regular)
                                .frame(width: 50, height: 50)
                                .background(
                                    selectedRating == rating
                                        ? Color.white
                                        : Color.white.opacity(0.1)
                                )
                                .foregroundColor(
                                    selectedRating == rating
                                        ? Color(red: 0.1, green: 0.15, blue: 0.3)
                                        : .white
                                )
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Rating labels
                HStack {
                    Text("Low")
                        .font(.system(.caption, design: .monospaced))
                        .opacity(0.5)
                    Spacer()
                    Text("High")
                        .font(.system(.caption, design: .monospaced))
                        .opacity(0.5)
                }
                .foregroundColor(.white)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 24)

            // Optional note
            VStack(alignment: .leading, spacing: 8) {
                Text("How do you feel? (optional)")
                    .font(.system(.caption, design: .monospaced))
                    .opacity(0.7)

                TextField("e.g., tired, energized, sore...", text: $feelingNote)
                    .font(.system(.body, design: .monospaced))
                    .padding(12)
                    .background(Color.white.opacity(0.1))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .focused($isTextFieldFocused)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)

            Spacer()

                // Action Bar
                ActionBar {
                    let feeling = PreWorkoutFeeling(
                        rating: selectedRating,
                        note: feelingNote.isEmpty ? nil : feelingNote
                    )
                    sessionManager.logPreWorkoutFeeling(feeling)
                } label: {
                    Text("START WORKOUT")
                }
            }
            .onTapGesture {
                isTextFieldFocused = false
            }
        }
    }
}
