import SwiftUI

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
                .foregroundColor(Color(red: 0.1, green: 0.15, blue: 0.3))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .padding(24)
    }
}
