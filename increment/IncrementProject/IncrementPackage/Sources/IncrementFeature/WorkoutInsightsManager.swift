import Foundation
import Observation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Manages AI-generated workout insights using Apple's on-device Foundation Models
/// Clean abstraction layer over FoundationModels API (iOS 26+)
@Observable
@MainActor
public class WorkoutInsightsManager {

    // MARK: - Singleton

    public static let shared = WorkoutInsightsManager()

    // MARK: - State

    public var isGenerating: Bool = false
    public var currentInsight: WorkoutInsight?
    public var error: InsightError?

    // Store session as Any to avoid @available on stored property
    private var sessionStorage: Any?

    // MARK: - Errors

    public enum InsightError: Error, LocalizedError {
        case modelUnavailable(String)
        case generationFailed(String)
        case insufficientData

        public var errorDescription: String? {
            switch self {
            case .modelUnavailable(let reason):
                return "AI model unavailable: \(reason)"
            case .generationFailed(let message):
                return "Generation failed: \(message)"
            case .insufficientData:
                return "Not enough workout data"
            }
        }
    }

    // MARK: - Initialization

    private init() {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            initializeSession()
        }
        #endif
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func initializeSession() {
        sessionStorage = LanguageModelSession {
            """
            You are a motivational strength training coach analyzing workout data.
            Provide concise, encouraging insights in 2-3 sentences.
            Focus on progress, effort, and consistency.
            Use a supportive, terminal-style tone. No emojis.
            Keep responses under 100 words.
            """
        }
    }
    #endif

    // MARK: - Public API

    /// Generate post-workout motivational summary
    public func generatePostWorkoutSummary(for session: Session) async throws -> WorkoutInsight {
        guard !session.exerciseLogs.isEmpty else {
            throw InsightError.insufficientData
        }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return try await generateWithFoundationModels(for: session)
        }
        #endif

        // Fallback for non-iOS 26 platforms
        return await generateFallbackSummary(for: session)
    }

    /// Check if on-device AI is available
    public func isModelAvailable() -> Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return true
            case .unavailable:
                return false
            }
        }
        #endif
        return false
    }

    // MARK: - Foundation Models Implementation

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func generateWithFoundationModels(for session: Session) async throws -> WorkoutInsight {
        isGenerating = true
        defer { isGenerating = false }

        // Check model availability
        guard case .available = SystemLanguageModel.default.availability else {
            let reason = getUnavailabilityReason()
            throw InsightError.modelUnavailable(reason)
        }

        // Ensure session is initialized
        guard let modelSession = sessionStorage as? LanguageModelSession else {
            throw InsightError.modelUnavailable("Session not initialized")
        }

        do {
            // Build context from workout data
            let context = buildSessionContext(session)

            // Create prompt
            let prompt = """
            Analyze this workout and provide a brief motivational summary:

            \(context)

            Summary:
            """

            // Generate response
            let response = try await modelSession.respond(to: prompt)
            let content = response.content.trimmingCharacters(in: .whitespacesAndNewlines)

            // Create insight
            let insight = WorkoutInsight(
                id: UUID(),
                type: .postWorkoutSummary,
                content: content,
                sessionId: session.id,
                generatedAt: Date(),
                isAIGenerated: true
            )

            currentInsight = insight
            return insight

        } catch {
            let insightError = InsightError.generationFailed(error.localizedDescription)
            self.error = insightError
            throw insightError
        }
    }

    @available(iOS 26.0, *)
    private func getUnavailabilityReason() -> String {
        switch SystemLanguageModel.default.availability {
        case .available:
            return "Available"
        case .unavailable(let reason):
            switch reason {
            case .appleIntelligenceNotEnabled:
                return "Apple Intelligence not enabled"
            case .deviceNotEligible:
                return "Device not eligible"
            case .modelNotReady:
                return "Model not ready"
            @unknown default:
                return "Unknown reason"
            }
        }
    }
    #endif

    // MARK: - Context Building

    private func buildSessionContext(_ session: Session) -> String {
        var context = ""

        // Pre-workout feeling
        if let feeling = session.preWorkoutFeeling {
            context += "Pre-workout energy: \(feeling.rating)/5\n"
        }

        // Workout type
        if let template = session.workoutTemplate {
            context += "Workout: \(template.name) (\(template.workoutType.rawValue))\n"
        }

        // Exercise performance
        context += "Exercises: \(session.exerciseLogs.count)\n"

        for log in session.exerciseLogs {
            let sets = log.setLogs.count
            let avgRating = averageRating(log.setLogs)
            context += "- \(log.exerciseId): \(sets) sets, \(avgRating)\n"

            if let decision = log.sessionDecision {
                context += "  → \(decision.rawValue)\n"
            }
        }

        // Total volume
        context += "Volume: \(Int(session.stats.totalVolume)) lbs\n"

        return context
    }

    // MARK: - Fallback Implementation

    private func generateFallbackSummary(for session: Session) async -> WorkoutInsight {
        isGenerating = true
        defer { isGenerating = false }

        // Simulate brief processing
        try? await Task.sleep(for: .seconds(0.5))

        let content = synthesizeInsight(for: session)

        let insight = WorkoutInsight(
            id: UUID(),
            type: .postWorkoutSummary,
            content: content,
            sessionId: session.id,
            generatedAt: Date(),
            isAIGenerated: false
        )

        currentInsight = insight
        return insight
    }

    private func synthesizeInsight(for session: Session) -> String {
        let exerciseCount = session.exerciseLogs.count
        let totalSets = session.exerciseLogs.reduce(0) { $0 + $1.setLogs.count }
        let volume = Int(session.stats.totalVolume)

        let progressions = session.exerciseLogs.filter {
            $0.sessionDecision == .up_1 || $0.sessionDecision == .up_2
        }.count

        let holds = session.exerciseLogs.filter {
            $0.sessionDecision == .hold
        }.count

        let deloads = session.exerciseLogs.filter {
            $0.sessionDecision == .down_1
        }.count

        var insights: [String] = []

        // Opening line
        if progressions > exerciseCount / 2 {
            insights.append("Strong session. Progressed on \(progressions)/\(exerciseCount) lifts.")
        } else if progressions > 0 {
            insights.append("Solid work. \(progressions) lifts progressed, \(holds) maintained.")
        } else {
            insights.append("Consistency over perfection. \(totalSets) sets completed.")
        }

        // Volume context
        if volume > 10000 {
            insights.append("Volume: \(volume) lbs. High-intensity work today.")
        } else {
            insights.append("Volume: \(volume) lbs.")
        }

        // Motivational closer
        if deloads > 0 {
            insights.append("Deloads are strategic. Trust the process.")
        } else if progressions == exerciseCount {
            insights.append("Perfect progression. This is how you build strength.")
        } else {
            insights.append("Every rep counts. See you next session.")
        }

        return insights.joined(separator: "\n")
    }

    // MARK: - Helpers

    private func averageRating(_ setLogs: [SetLog]) -> String {
        guard !setLogs.isEmpty else { return "N/A" }

        let ratingMap: [Rating: Double] = [
            .fail: 1.0,
            .holyShit: 2.0,
            .hard: 3.0,
            .easy: 4.0
        ]

        let sum = setLogs.reduce(0.0) { $0 + (ratingMap[$1.rating] ?? 3.0) }
        let avg = sum / Double(setLogs.count)

        if avg < 1.5 { return "very hard" }
        if avg < 2.5 { return "challenging" }
        if avg < 3.5 { return "moderate" }
        return "manageable"
    }
}

// MARK: - Models

/// Types of workout insights
public enum WorkoutInsightType: String, Codable, Sendable {
    case postWorkoutSummary
    case weeklyAnalysis
    case substitutionSuggestion
    case goalSuggestion
}

/// AI-generated workout insight
public struct WorkoutInsight: Codable, Identifiable, Sendable {
    public let id: UUID
    public let type: WorkoutInsightType
    public let content: String
    public let sessionId: UUID?
    public let generatedAt: Date
    public let isAIGenerated: Bool  // True if from Foundation Models, false if rule-based

    public init(
        id: UUID,
        type: WorkoutInsightType,
        content: String,
        sessionId: UUID?,
        generatedAt: Date,
        isAIGenerated: Bool = false
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.sessionId = sessionId
        self.generatedAt = generatedAt
        self.isAIGenerated = isAIGenerated
    }
}
