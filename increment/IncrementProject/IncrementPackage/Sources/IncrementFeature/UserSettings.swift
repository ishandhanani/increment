import Foundation
import Observation

/// Weight unit preference
public enum WeightUnit: String, Codable, CaseIterable {
    case pounds = "lb"
    case kilograms = "kg"

    /// Convert from pounds to this unit
    public func convert(fromPounds pounds: Double) -> Double {
        switch self {
        case .pounds:
            return pounds
        case .kilograms:
            return pounds * 0.453592
        }
    }

    /// Convert to pounds from this unit
    public func convertToPounds(_ value: Double) -> Double {
        switch self {
        case .pounds:
            return value
        case .kilograms:
            return value / 0.453592
        }
    }

    /// Format weight value with unit label
    public func formatted(_ weight: Double) -> String {
        let converted = convert(fromPounds: weight)
        return "\(Int(converted.rounded())) \(self.rawValue)"
    }

    /// Format weight value with optional "each" suffix for dumbbells
    public func formatted(_ weight: Double, isDumbbell: Bool) -> String {
        let converted = convert(fromPounds: weight)
        let weightStr = "\(Int(converted.rounded())) \(self.rawValue)"
        return isDumbbell ? "\(weightStr) each" : weightStr
    }
}

/// Observable user settings manager
@Observable
@MainActor
public class UserSettings {
    /// Shared instance for global access
    public static let shared = UserSettings()

    /// Weight unit preference (persisted to UserDefaults)
    public var weightUnit: WeightUnit {
        didSet {
            UserDefaults.standard.set(weightUnit.rawValue, forKey: "weightUnit")
        }
    }

    private init() {
        // Load from UserDefaults
        if let savedUnit = UserDefaults.standard.string(forKey: "weightUnit"),
           let unit = WeightUnit(rawValue: savedUnit) {
            self.weightUnit = unit
        } else {
            // Default to pounds
            self.weightUnit = .pounds
        }
    }
}
