import FoundationModels
import SwiftUI

/// Runs the same prompt through several configurations one after another, for side-by-side quality and latency.
struct CompareView: View {
    @Environment(ModelStore.self) private var store
    @State private var promptText = SamplePrompt.reasoning.text
    @State private var selected: Set<RunConfig> = [RunConfig.all[0], RunConfig.all[2], RunConfig.all[4]]
    @State private var runs: [RunConfig: RunState] = [:]
    @State private var compareTask: Task<Void, Never>?

    private var isRunning: Bool { compareTask != nil }

    var body: some View {
        NavigationStack {
            Form {
                QuotaSection(model: store.pcc)

                Section {
                    TextEditor(text: $promptText)
                        .frame(minHeight: 120)
                } header: {
                    HStack {
                        Text("Prompt")
                        Spacer()
                        Menu("Samples") {
                            ForEach(SamplePrompt.allCases.filter { $0 != .photo }) { sample in
                                Button(sample.rawValue) { promptText = sample.text }
                            }
                        }
                        .textCase(nil)
                    }
                }

                Section {
                    ForEach(RunConfig.all) { config in
                        Toggle(config.title, isOn: binding(for: config))
                            .disabled(isRunning)
                    }
                } header: {
                    Text("Configurations")
                } footer: {
                    Text("Runs execute one at a time so latency numbers aren't skewed. Every PCC run counts against your daily quota.")
                }

                Section {
                    if isRunning {
                        Button("Stop", role: .destructive) {
                            compareTask?.cancel()
                            compareTask = nil
                        }
                    } else {
                        Button("Run comparison") { startComparison() }
                            .disabled(selected.isEmpty || promptText.isEmpty)
                    }
                }

                ForEach(RunConfig.all.filter { runs[$0] != nil }) { config in
                    if let run = runs[config] {
                        Section(config.title) {
                            CompareResultRow(run: run)
                        }
                    }
                }
            }
            .navigationTitle("Compare")
        }
    }

    private func binding(for config: RunConfig) -> Binding<Bool> {
        Binding(
            get: { selected.contains(config) },
            set: { isOn in
                if isOn { selected.insert(config) } else { selected.remove(config) }
            }
        )
    }

    private func startComparison() {
        let configs = RunConfig.all.filter { selected.contains($0) }
        runs = Dictionary(uniqueKeysWithValues: configs.map { ($0, RunState()) })
        let prompt = Prompt(promptText)
        compareTask = Task {
            for config in configs {
                guard !Task.isCancelled, let run = runs[config] else { break }
                if let reason = store.blockingReason(for: config.model) {
                    run.markSkipped(reason)
                    continue
                }
                await run.perform(prompt: prompt, config: config, structured: false, store: store)
            }
            compareTask = nil
        }
    }
}

private struct CompareResultRow: View {
    let run: RunState

    var body: some View {
        switch run.phase {
        case .idle:
            Text("Waiting…").foregroundStyle(.secondary)
        case .running where run.text.isEmpty:
            ProgressView()
        default:
            if !run.reasoning.isEmpty {
                DisclosureGroup("Reasoning") {
                    Text(run.reasoning)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            if !run.text.isEmpty {
                Text(run.text).textSelection(.enabled)
            }
            if let message = run.errorMessage {
                Text(message).foregroundStyle(.red)
            }
            MetricsView(run: run)
        }
    }
}
