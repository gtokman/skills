import FoundationModels
import Observation

enum ModelChoice: String, CaseIterable, Identifiable {
    case onDevice = "On-device"
    case pcc = "Private Cloud"

    var id: Self { self }
}

enum ReasoningChoice: String, CaseIterable, Identifiable {
    case off = "Off"
    case light = "Light"
    case moderate = "Moderate"
    case deep = "Deep"

    var id: Self { self }

    var level: ContextOptions.ReasoningLevel? {
        switch self {
        case .off: nil
        case .light: .light
        case .moderate: .moderate
        case .deep: .deep
        }
    }
}

/// One model + reasoning combination to run a prompt against.
struct RunConfig: Hashable, Identifiable {
    var model: ModelChoice
    var reasoning: ReasoningChoice = .off

    var id: String { "\(model.rawValue)-\(reasoning.rawValue)" }

    var title: String {
        switch model {
        case .onDevice: "On-device"
        case .pcc: reasoning == .off ? "PCC" : "PCC · \(reasoning.rawValue) reasoning"
        }
    }

    static let all: [RunConfig] = [
        RunConfig(model: .onDevice),
        RunConfig(model: .pcc),
        RunConfig(model: .pcc, reasoning: .light),
        RunConfig(model: .pcc, reasoning: .moderate),
        RunConfig(model: .pcc, reasoning: .deep),
    ]
}

/// Owns the two models so availability and quota observation is shared app-wide.
@Observable
final class ModelStore {
    let system = SystemLanguageModel.default
    let pcc = PrivateCloudComputeLanguageModel()

    private(set) var pccContextSize: Int?
    private(set) var pccContextSizeError: String?

    static let instructions = """
        You are a helpful assistant inside a developer test app. \
        Answer clearly and concisely. Use plain text, not Markdown tables.
        """

    func loadPCCContextSize() async {
        do {
            pccContextSize = try await pcc.contextSize
            pccContextSizeError = nil
        } catch {
            pccContextSizeError = ErrorText.describe(error)
        }
    }

    func session(for model: ModelChoice) -> LanguageModelSession {
        switch model {
        case .onDevice: LanguageModelSession(model: system, instructions: Self.instructions)
        case .pcc: LanguageModelSession(model: pcc, instructions: Self.instructions)
        }
    }

    func isAvailable(_ model: ModelChoice) -> Bool {
        switch model {
        case .onDevice: system.isAvailable
        case .pcc: pcc.isAvailable
        }
    }

    func capabilities(of model: ModelChoice) -> LanguageModelCapabilities {
        switch model {
        case .onDevice: system.capabilities
        case .pcc: pcc.capabilities
        }
    }

    /// Why a run can't start right now, or nil when it can.
    func blockingReason(for model: ModelChoice) -> String? {
        if !isAvailable(model) { return "\(model.rawValue) model is unavailable. See the Status tab." }
        if model == .pcc, pcc.quotaUsage.isLimitReached { return "Daily Private Cloud Compute limit reached." }
        return nil
    }
}
