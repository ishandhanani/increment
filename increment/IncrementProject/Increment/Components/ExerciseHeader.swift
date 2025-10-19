import SwiftUI
import IncrementFeature

struct ExerciseHeader: View {
    let exerciseName: String  // Display name like "Barbell Bench Press"
    let setInfo: String
    let goal: String
    let weight: Double
    let plates: [Double]?

    var body: some View {
        HStack(alignment: .top) {
            // Left: Exercise name
            Text(exerciseName)
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
