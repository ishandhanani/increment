import SwiftUI

/// App-wide theme system for consistent styling
public struct IncrementTheme {

    // MARK: - Colors

    /// Primary background gradient (deep blue-black to black)
    public static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.05, blue: 0.1),
                Color.black
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Legacy flat background color (for migration)
    public static var legacyBackground: Color {
        Color(red: 0.1, green: 0.15, blue: 0.3)
    }

    /// Accent color (cyan)
    public static var accent: Color {
        .cyan
    }

    /// Text colors
    public struct Text {
        public static var primary: Color { .white }
        public static var secondary: Color { .white.opacity(0.7) }
        public static var tertiary: Color { .white.opacity(0.5) }
    }

    /// Status colors
    public struct Status {
        public static var success: Color { .green }
        public static var warning: Color { .yellow }
        public static var error: Color { .red }
        public static var info: Color { .cyan }
    }

    /// Card/surface colors
    public struct Surface {
        public static var card: Color { .white.opacity(0.04) }
        public static var cardBorder: Color { .white.opacity(0.2) }
        public static var cardHighlight: Color { .cyan.opacity(0.3) }
    }
}

// MARK: - View Extension for Easy Access

public extension View {
    /// Apply the standard app background gradient
    func incrementBackground() -> some View {
        self.background(
            IncrementTheme.backgroundGradient
                .ignoresSafeArea()
        )
    }
}
