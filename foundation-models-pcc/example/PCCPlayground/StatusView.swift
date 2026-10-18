import FoundationModels
import SwiftUI

struct StatusView: View {
    @Environment(ModelStore.self) private var store

    var body: some View {
        NavigationStack {
            Form {
                Section("Private Cloud Compute") {
                    LabeledContent("Availability", value: describe(store.pcc.availability))
                    LabeledContent("Context size") {
                        if let size = store.pccContextSize {
                            Text("\(size) tokens")
                        } else if let error = store.pccContextSizeError {
                            Text(error).foregroundStyle(.red)
                        } else {
                            ProgressView()
                        }
                    }
                    CapabilityRows(capabilities: store.pcc.capabilities)
                    LabeledContent("Quota", value: describe(store.pcc.quotaUsage))
                    if let reset = store.pcc.quotaUsage.resetDate {
                        LabeledContent("Resets", value: reset.formatted(date: .abbreviated, time: .shortened))
                    }
                    if let suggestion = store.pcc.quotaUsage.limitIncreaseSuggestion {
                        Button("Show options for higher limits") { suggestion.show() }
                    }
                    Button("Reload context size") {
                        Task { await store.loadPCCContextSize() }
                    }
                }

                Section("On-device") {
                    LabeledContent("Availability", value: describe(store.system.availability))
                    LabeledContent("Context size", value: "\(store.system.contextSize) tokens")
                    CapabilityRows(capabilities: store.system.capabilities)
                }

                Section("Testing quota states") {
                    Text("""
                        In Xcode, edit the scheme → Run → Options → \
                        Simulate Apple Foundation Models Availability, then pick \
                        "Quota Usage Limit Reached" or "Nearing Usage Limit".
                        """)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Status")
        }
    }

    private func describe(_ availability: PrivateCloudComputeLanguageModel.Availability) -> String {
        switch availability {
        case .available: "Available"
        case .unavailable(.deviceNotEligible): "Device not eligible"
        case .unavailable(.systemNotReady): "System not ready"
        case .unavailable(let reason): "Unavailable (\(String(describing: reason)))"
        }
    }

    private func describe(_ availability: SystemLanguageModel.Availability) -> String {
        switch availability {
        case .available: "Available"
        case .unavailable(.deviceNotEligible): "Device not eligible"
        case .unavailable(.appleIntelligenceNotEnabled): "Apple Intelligence off"
        case .unavailable(.modelNotReady): "Model downloading"
        case .unavailable(let reason): "Unavailable (\(String(describing: reason)))"
        }
    }

    private func describe(_ usage: PrivateCloudComputeLanguageModel.QuotaUsage) -> String {
        switch usage.status {
        case .belowLimit(let info): info.isApproachingLimit ? "Nearing limit" : "Below limit"
        case .limitReached: "Limit reached"
        @unknown default: "Unknown"
        }
    }
}

private struct CapabilityRows: View {
    let capabilities: LanguageModelCapabilities

    var body: some View {
        LabeledContent("Capabilities", value: names.isEmpty ? "None reported" : names.joined(separator: ", "))
    }

    private var names: [String] {
        [
            (LanguageModelCapabilities.Capability.vision, "Vision"),
            (.reasoning, "Reasoning"),
            (.toolCalling, "Tools"),
            (.guidedGeneration, "Guided generation"),
        ]
        .filter { capabilities.contains($0.0) }
        .map(\.1)
    }
}

/// Apple's guidance: show quota as persistent state, not an alert.
struct QuotaSection: View {
    let model: PrivateCloudComputeLanguageModel

    var body: some View {
        let usage = model.quotaUsage
        if usage.isLimitReached || isApproaching(usage) {
            Section {
                if usage.isLimitReached {
                    Label("Daily PCC limit reached", systemImage: "xmark.octagon.fill")
                        .foregroundStyle(.red)
                } else {
                    Label("Nearing daily PCC limit", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                if let suggestion = usage.limitIncreaseSuggestion {
                    Button("Show options") { suggestion.show() }
                }
            }
        }
    }

    private func isApproaching(_ usage: PrivateCloudComputeLanguageModel.QuotaUsage) -> Bool {
        if case .belowLimit(let info) = usage.status { info.isApproachingLimit } else { false }
    }
}
