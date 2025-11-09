import SwiftUI
import IncrementFeature

struct ExerciseHeader: View {
    @Environment(UserSettings.self) private var settings

    let exerciseName: String  // Display name like "Barbell Bench Press"
    let setInfo: String
    let goal: String
    let weight: Double
    let plates: [Double]?
    let equipment: Equipment?  // Optional equipment type for weight clarification

    var body: some View {
        HStack(alignment: .top) {
            // Left: Exercise name
            Text(exerciseName)
                .font(.system(.title2, design: .monospaced))
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Right: Stats column
            VStack(alignment: .trailing, spacing: 6) {
                Text("Set: \(setInfo)")
                Text("Goal: \(goal)")

                // Format weight with user's preferred unit
                let isDumbbell = equipment == .dumbbell
                Text("Weight: \(settings.weightUnit.formatted(weight, isDumbbell: isDumbbell))")

                if let plates = plates {
                    Text("Plates: \(plates.map { "\(Int($0))" }.joined(separator: " | "))")
                        .font(.system(.caption, design: .monospaced))
                }
            }
            .font(.system(.body, design: .monospaced))
        }
        .foregroundColor(.white)
        .padding(20)
        .background(Color.black.opacity(0.3))
    }
}
