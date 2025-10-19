import SwiftUI

// MARK: - Exercise Header

struct ExerciseHeader: View {
    let exerciseId: String
    let setInfo: String
    let goal: String
    let weight: Double
    let plates: [Double]?

    var body: some View {
        HStack(alignment: .top) {
            // Left: Exercise name
            Text(exerciseId)
                .font(.system(.title3, design: .monospaced))
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Right: Stats column
            VStack(alignment: .trailing, spacing: 4) {
                Text("Set: \(setInfo)")
                Text("Goal: \(goal)")
                Text("Weight: \(Int(weight)) lb")

                if let plates = plates {
                    Text("Plates: \(plates.map { "\(Int($0))" }.joined(separator: " | "))")
                        .font(.system(.caption, design: .monospaced))
                }
            }
            .font(.system(.caption, design: .monospaced))
        }
        .foregroundColor(.white)
        .padding(16)
        .background(Color.black.opacity(0.3))
    }
}

// MARK: - Action Bar

struct ActionBar<Label: View>: View {
    let action: () -> Void
    let label: () -> Label

    var body: some View {
        Button(action: action) {
            label()
                .font(.system(.body, design: .monospaced))
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(Color.white)
                .foregroundColor(.black)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .padding(24)
    }
}

// MARK: - Decision Badge

struct DecisionBadge: View {
    let decision: SessionDecision

    var body: some View {
        HStack(spacing: 8) {
            Text(badgeText(decision))
                .font(.system(.title2, design: .monospaced))
                .fontWeight(.bold)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(badgeColor(decision))
                .foregroundColor(.white)
                .cornerRadius(8)
        }
    }

    private func badgeText(_ decision: SessionDecision) -> String {
        switch decision {
        case .up_2:
            return "UP ++"
        case .up_1:
            return "UP +"
        case .down_1:
            return "DOWN -"
        case .hold:
            return "HOLD"
        }
    }

    private func badgeColor(_ decision: SessionDecision) -> Color {
        switch decision {
        case .up_2, .up_1:
            return Color.green.opacity(0.8)
        case .down_1:
            return Color.red.opacity(0.8)
        case .hold:
            return Color.blue.opacity(0.8)
        }
    }
}
