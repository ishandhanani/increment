import SwiftUI

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
