import SwiftUI

// MARK: - Settings View

@MainActor
public struct SettingsView: View {
    @Binding var isPresented: Bool
    @State private var showingDiagnostic = false
    @State private var showingCalibration = false

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header with back button
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

                Spacer()

                Text("SETTINGS")
                    .font(.system(.title3, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .padding(20)
            .background(Color.black.opacity(0.3))

            // Settings Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Training Section
                    SettingsSection(title: "TRAINING") {
                        SettingButton(
                            title: "Run Diagnostic",
                            description: "View monthly progress metrics"
                        ) {
                            showingDiagnostic = true
                        }

                        Divider()
                            .background(Color.white.opacity(0.1))

                        SettingButton(
                            title: "Recalibrate Weights",
                            description: "Update starting weights from 1RM"
                        ) {
                            showingCalibration = true
                        }
                    }

                    // About Section
                    SettingsSection(title: "ABOUT") {
                        SettingRow(
                            title: "Version",
                            value: "1.0.0"
                        )

                        SettingRow(
                            title: "Build",
                            value: "2025.1"
                        )
                    }
                }
                .padding(24)
            }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showingDiagnostic) {
            DiagnosticView(isPresented: $showingDiagnostic)
        }
        .fullScreenCover(isPresented: $showingCalibration) {
            CalibrationView(isPresented: $showingCalibration)
        }
        #else
        .sheet(isPresented: $showingDiagnostic) {
            DiagnosticView(isPresented: $showingDiagnostic)
        }
        .sheet(isPresented: $showingCalibration) {
            CalibrationView(isPresented: $showingCalibration)
        }
        #endif
    }
}

// MARK: - Settings Section

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .textCase(.uppercase)

            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

// MARK: - Setting Toggle

struct SettingToggle: View {
    let title: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.white)

                    Text(description)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .tint(.cyan)
            }
            .padding(20)
        }
    }
}

// MARK: - Setting Button

struct SettingButton: View {
    let title: String
    let description: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.white)

                    Text(description)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                Text("→")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(20)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Setting Row

struct SettingRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.white)

            Spacer()

            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(20)
    }
}
