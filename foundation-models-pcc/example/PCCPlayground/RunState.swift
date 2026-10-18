import FoundationModels
import Observation

/// Streams one prompt through one model configuration and records output, reasoning and metrics.
@Observable
final class RunState {
    enum Phase { case idle, running, finished, failed }

    private(set) var phase = Phase.idle
    private(set) var text = ""
    private(set) var summary: ArticleSummary.PartiallyGenerated?
    private(set) var reasoning = ""
    private(set) var usage: LanguageModelSession.Usage?
    private(set) var timeToFirstToken: Duration?
    private(set) var totalTime: Duration?
    private(set) var errorMessage: String?
    private(set) var limitSuggestion: PrivateCloudComputeLanguageModel.QuotaUsage.LimitIncreaseSuggestion?

    private var task: Task<Void, Never>?

    var isRunning: Bool { phase == .running }

    func start(prompt: Prompt, config: RunConfig, structured: Bool, store: ModelStore) {
        cancel()
        task = Task { await perform(prompt: prompt, config: config, structured: structured, store: store) }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    func perform(prompt: Prompt, config: RunConfig, structured: Bool, store: ModelStore) async {
        reset()
        phase = .running

        let session = store.session(for: config.model)
        // Reasoning is a server-model feature; the on-device model gets no reasoning level.
        let level = config.model == .pcc ? config.reasoning.level : nil
        let clock = ContinuousClock()
        let start = clock.now

        do {
            if structured {
                let stream = session.streamResponse(
                    to: prompt,
                    generating: ArticleSummary.self,
                    contextOptions: ContextOptions(includeSchemaInPrompt: true, reasoningLevel: level)
                )
                for try await snapshot in stream {
                    if timeToFirstToken == nil { timeToFirstToken = clock.now - start }
                    summary = snapshot.content
                    absorb(snapshot.transcriptEntries, usage: snapshot.usage)
                }
            } else {
                let stream = session.streamResponse(
                    to: prompt,
                    contextOptions: ContextOptions(reasoningLevel: level)
                )
                for try await snapshot in stream {
                    if timeToFirstToken == nil { timeToFirstToken = clock.now - start }
                    text = snapshot.content
                    absorb(snapshot.transcriptEntries, usage: snapshot.usage)
                }
            }
            totalTime = clock.now - start
            phase = .finished
        } catch is CancellationError {
            phase = .idle
        } catch {
            totalTime = clock.now - start
            errorMessage = ErrorText.describe(error)
            if case .quotaLimitReached(let info) = error as? PrivateCloudComputeLanguageModel.Error {
                limitSuggestion = info.limitIncreaseSuggestion
            }
            phase = .failed
        }
    }

    func markSkipped(_ reason: String) {
        reset()
        errorMessage = "Skipped: \(reason)"
        phase = .failed
    }

    private func reset() {
        text = ""
        summary = nil
        reasoning = ""
        usage = nil
        timeToFirstToken = nil
        totalTime = nil
        errorMessage = nil
        limitSuggestion = nil
    }

    private func absorb(_ entries: ArraySlice<Transcript.Entry>, usage: LanguageModelSession.Usage) {
        self.usage = usage
        let thoughts = entries.compactMap { entry -> String? in
            guard case .reasoning(let reasoning) = entry else { return nil }
            return reasoning.segments.compactMap { segment in
                if case .text(let text) = segment { text.content } else { nil }
            }.joined()
        }
        if !thoughts.isEmpty { reasoning = thoughts.joined(separator: "\n\n") }
    }
}

enum ErrorText {
    static func describe(_ error: any Error) -> String {
        if let pccError = error as? PrivateCloudComputeLanguageModel.Error {
            switch pccError {
            case .quotaLimitReached(let info):
                var message = "Daily Private Cloud Compute limit reached."
                if let reset = info.resetDate {
                    message += " Resets \(reset.formatted(.relative(presentation: .named)))."
                }
                return message
            case .networkFailure(let info):
                return "Network failure: \(info.debugDescription)"
            case .serviceUnavailable(let info):
                return "Service unavailable: \(info.debugDescription)"
            @unknown default:
                return pccError.localizedDescription
            }
        }
        // Include the raw value so unfamiliar errors (e.g. a missing entitlement) are diagnosable.
        return "\(error.localizedDescription)\n\n\(String(describing: error))"
    }
}

extension Duration {
    var secondsText: String {
        let seconds = Double(components.seconds) + Double(components.attoseconds) / 1e18
        return seconds.formatted(.number.precision(.fractionLength(2))) + "s"
    }
}
