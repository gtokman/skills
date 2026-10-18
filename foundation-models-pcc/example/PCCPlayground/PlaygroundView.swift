import FoundationModels
import SwiftUI

struct PlaygroundView: View {
    @Environment(ModelStore.self) private var store
    @State private var model = ModelChoice.pcc
    @State private var reasoning = ReasoningChoice.off
    @State private var structured = false
    @State private var promptText = SamplePrompt.summarize.text
    @State private var image: CGImage?
    @State private var run = RunState()

    var body: some View {
        NavigationStack {
            Form {
                if model == .pcc {
                    QuotaSection(model: store.pcc)
                }

                Section("Model") {
                    Picker("Model", selection: $model) {
                        ForEach(ModelChoice.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if model == .pcc {
                        Picker("Reasoning", selection: $reasoning) {
                            ForEach(ReasoningChoice.allCases) { Text($0.rawValue).tag($0) }
                        }
                    }

                    Toggle("Structured output", isOn: $structured)
                }

                Section {
                    TextEditor(text: $promptText)
                        .frame(minHeight: 160)
                    ImageAttachmentRow(image: $image)
                    if image != nil, !store.capabilities(of: model).contains(.vision) {
                        Label("This model doesn't report vision support.", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                } header: {
                    HStack {
                        Text("Prompt")
                        Spacer()
                        Menu("Samples") {
                            ForEach(SamplePrompt.allCases) { sample in
                                Button(sample.rawValue) { promptText = sample.text }
                            }
                        }
                        .textCase(nil)
                    }
                } footer: {
                    if structured {
                        Text("Generates an ArticleSummary (one-line summary, key points, tone).")
                    }
                }

                Section {
                    if run.isRunning {
                        Button("Stop", role: .destructive) { run.cancel() }
                    } else {
                        Button("Run") { start() }
                            .disabled(promptText.isEmpty || store.blockingReason(for: model) != nil)
                    }
                } footer: {
                    if let reason = store.blockingReason(for: model) {
                        Text(reason)
                    }
                }

                RunResultSections(run: run, structured: structured)
            }
            .navigationTitle("Playground")
        }
    }

    private func start() {
        let prompt: Prompt
        if let image {
            prompt = Prompt {
                promptText
                Attachment(image)
            }
        } else {
            prompt = Prompt(promptText)
        }
        run.start(
            prompt: prompt,
            config: RunConfig(model: model, reasoning: reasoning),
            structured: structured,
            store: store
        )
    }
}

/// Output, reasoning, metrics and errors for one run, as Form sections.
struct RunResultSections: View {
    let run: RunState
    let structured: Bool

    var body: some View {
        if !run.reasoning.isEmpty {
            Section {
                DisclosureGroup("Reasoning") {
                    Text(run.reasoning)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }

        if structured, let summary = run.summary {
            Section("Summary") {
                if let line = summary.oneLineSummary { Text(line).bold() }
                ForEach(Array((summary.keyPoints ?? []).enumerated()), id: \.offset) { _, point in
                    Label(point, systemImage: "circle.fill")
                        .labelStyle(BulletLabelStyle())
                }
                if let tone = summary.tone { LabeledContent("Tone", value: tone) }
            }
        } else if !run.text.isEmpty {
            Section("Response") {
                Text(run.text)
                    .textSelection(.enabled)
            }
        } else if run.isRunning {
            Section { ProgressView().frame(maxWidth: .infinity) }
        }

        if let message = run.errorMessage {
            Section("Error") {
                Text(message)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
                if let suggestion = run.limitSuggestion {
                    Button("Show options for higher limits") { suggestion.show() }
                }
            }
        }

        if run.phase != .idle {
            Section("Metrics") {
                MetricsView(run: run)
            }
        }
    }
}

struct MetricsView: View {
    let run: RunState

    var body: some View {
        LabeledContent("First token", value: run.timeToFirstToken?.secondsText ?? "–")
        LabeledContent("Total time", value: run.totalTime?.secondsText ?? (run.isRunning ? "running…" : "–"))
        if let usage = run.usage {
            LabeledContent("Input tokens", value: "\(usage.input.totalTokenCount) (\(usage.input.cachedTokenCount) cached)")
            LabeledContent("Output tokens", value: "\(usage.output.totalTokenCount)")
            LabeledContent("Reasoning tokens", value: "\(usage.output.reasoningTokenCount)")
        }
    }
}

private struct BulletLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            configuration.icon.font(.system(size: 5)).foregroundStyle(.secondary)
            configuration.title
        }
    }
}
