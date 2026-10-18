---
name: foundation-models-pcc
description: Use Apple's server-class Foundation Model on Private Cloud Compute (PrivateCloudComputeLanguageModel, iOS/macOS/visionOS/watchOS 27) from an app — eligibility and the managed entitlement, signing gotchas, the Swift API (sessions, reasoning levels, image input, structured output, streaming usage), per-user quota UX, errors, routing between on-device and PCC with DynamicProfile, and when PCC is worth it versus on-device or a paid provider. Use when adding PCC to an app, debugging why PCC calls fail or the entitlement is missing, designing quota-limit UI, choosing between on-device/PCC/third-party models, or estimating whether PCC can replace a paid LLM API. Based on WWDC26 sessions 241, 242 and 319, the iOS 27 SDK interface, and a working test app.
---

# Foundation Models on Private Cloud Compute

iOS 27 lets third-party apps call Apple's server model on Private Cloud Compute (PCC)
through the same Foundation Models API as the on-device model. Switching is one line:
`LanguageModelSession(model: PrivateCloudComputeLanguageModel())`.

## What you get

| | On-device (`SystemLanguageModel`) | PCC (`PrivateCloudComputeLanguageModel`) |
|---|---|---|
| Context | 4K (OS 26), 8K (OS 27, newer devices) | 32K |
| Reasoning | No | `.light`, `.moderate`, `.deep` (and `.custom(String)`) |
| Images, tools, `@Generable` | Yes (images new in 27) | Yes |
| Offline | Yes | No |
| Limits | None | Daily per-user quota, tied to the user's iCloud account |
| Platforms | iOS, macOS, visionOS | Same, **plus watchOS 27** |
| Cost to developer | Free | Free (for eligible developers) |

- **No API keys, accounts or backend.** Auth is the OS and the user's iCloud account.
- **Privacy:** requests are used only to answer, never stored, and the design is
  independently verifiable. This is a real product advantage for health, journaling,
  finance and notes apps.
- **Requires an Apple Intelligence device** with Apple Intelligence on, for both models.

## Eligibility and access

All of these must be true (from developer.apple.com/private-cloud-compute):

1. Enrolled in the **App Store Small Business Program**.
2. Fewer than **2 million first-time App Store downloads** across all your apps.
   TestFlight and ad hoc installs don't count.
3. The **PCC entitlement assigned** to your account. Request it at
   developer.apple.com/private-cloud-compute. Approval can be very fast: minutes in our
   case, by email titled "Access to models on Private Cloud Compute".

If you pass 2M downloads or leave the Small Business Program, Apple notifies you and you
have **6 months to migrate**. Apple also says expanded access "will require payment in the
future", so don't treat free as permanent.

For setup, read [references/setup-and-signing.md](references/setup-and-signing.md). The
most common failure is that **automatic signing silently drops the entitlement** when it
falls back to a wildcard profile.

## Rules

### Sessions and API

1. **Write against the shared API, then pick the model.** Sessions, tools, `@Generable`,
   streaming and image attachments are identical. Keep model choice in one place so you can
   evaluate and switch without touching feature code.
   ```swift
   let session = LanguageModelSession(
       model: PrivateCloudComputeLanguageModel(),
       tools: [FindRelatedArticlesTool()],
       instructions: "Summarize articles for a reading app."
   )
   ```
2. **Reasoning is per request, via `ContextOptions`.** Reasoning tokens count toward the
   32K context and add latency, so start at `.light` and go deeper only when evals say so.
   Don't pass a reasoning level to the on-device model.
   ```swift
   let response = try await session.respond(
       to: prompt,
       contextOptions: ContextOptions(reasoningLevel: .light)
   )
   ```
3. **Images go in the prompt as `Attachment`.** Downscale first (around 1.5K px on the long
   edge is plenty) and bake in EXIF orientation.
   ```swift
   let prompt = Prompt {
       "Describe what's in this photo."
       Attachment(cgImage)
   }
   ```
4. **Use `usage` to measure cost.** `Response.usage` and each stream snapshot's `usage`
   give `input.totalTokenCount`, `input.cachedTokenCount`, `output.totalTokenCount` and
   `output.reasoningTokenCount`. Reasoning text appears in `transcriptEntries` as
   `.reasoning(Transcript.Reasoning)` entries, whose `.text` segments you can show.
5. **`contextSize` is async on PCC.** `try await PrivateCloudComputeLanguageModel().contextSize`
   (32768). On-device it's synchronous: `SystemLanguageModel.default.contextSize`.
6. **Check capabilities instead of assuming:** `model.capabilities.contains(.vision)`
   (also `.reasoning`, `.toolCalling`, `.guidedGeneration`).
7. **`@Generable` types in MainActor-default projects** (Xcode 27 templates) should be
   declared `nonisolated struct` so their conformance isn't MainActor-isolated.

### Availability and quota

8. **Always gate on availability and keep a fallback.** `pcc.availability` is `.available`
   or `.unavailable(.deviceNotEligible | .systemNotReady)`. Fall back to on-device, a paid
   provider, or hide the feature.
9. **The quota belongs to the user, not to you.** You can't buy more of it, and Apple
   doesn't publish the limit. Users raise it by upgrading to iCloud+, and the API gives you
   the upsell button.
10. **Show quota as persistent state, not an alert.** Disable the action and show a banner.
    The model is `@Observable`, so reading `quotaUsage` in `body` updates automatically.
    ```swift
    let usage = pcc.quotaUsage
    if usage.isLimitReached {
        Label("Daily limit reached", systemImage: "xmark.octagon.fill")
    } else if case .belowLimit(let info) = usage.status, info.isApproachingLimit {
        Label("Nearing daily limit", systemImage: "exclamationmark.triangle.fill")
    }
    if let suggestion = usage.limitIncreaseSuggestion {
        Button("Show options") { suggestion.show() }
    }
    // usage.resetDate: when the quota resets, if known
    ```
11. **Handle `PrivateCloudComputeLanguageModel.Error`:** `.quotaLimitReached` (has
    `limitIncreaseSuggestion` and `resetDate`), `.networkFailure`, `.serviceUnavailable`.
    Add `@unknown default` and log `String(describing: error)` for anything unfamiliar. A
    missing entitlement surfaces as an unfamiliar error.
12. **Test quota UI without burning quota:** Edit Scheme → Run → Options → *Simulate Apple
    Foundation Models Availability* → "Quota Usage Limit Reached" / "Nearing Usage Limit".

### Choosing and routing models

13. **Decide with evals, not vibes.** Apple repeats this. The OS 27 on-device model handles
    more than you'd expect: classification, short extraction, rewriting, tagging and
    feedback on small inputs. Use the Evaluations framework, or a side-by-side harness like
    the example app's Compare tab, on *your* prompts.
14. **Reach for PCC when you need** more than about 6–8K tokens of input, multi-step
    reasoning, many tool calls with large outputs, better image understanding, or any model
    at all on watchOS.
15. **Route per step with `DynamicProfile`** so one session shares context while each phase
    uses the right model. Apple's origami demo: brainstorm and plan on PCC, review on-device
    "to save on unnecessary server calls".
    ```swift
    struct CraftProfile: LanguageModelSession.DynamicProfile {
        var mode: Mode
        let pcc: PrivateCloudComputeLanguageModel
        let onDevice: SystemLanguageModel

        var body: some LanguageModelSession.DynamicProfile {
            switch mode {
            case .brainstorm:
                LanguageModelSession.Profile { Instructions("Suggest creative project ideas.") }
                    .model(pcc).temperature(1)
            case .plan:
                LanguageModelSession.Profile { Instructions("Write a step-by-step tutorial.") }
                    .model(pcc).reasoningLevel(.deep)
            case .review:
                LanguageModelSession.Profile { Instructions("Give short feedback on technique.") }
                    .model(onDevice)
            }
        }
    }
    let session = LanguageModelSession(profile: CraftProfile(mode: .brainstorm, pcc: pcc, onDevice: .default))
    ```
    A `Profile` builder takes `Instructions(...)`, tools, or `[any Tool]`. Bare string
    literals don't compile there.
16. **Production pattern:** on-device for light work, PCC for heavy work, and a paid
    provider (Claude or Gemini via their Foundation Models packages, same API) when the
    user is over quota, on an ineligible device, or on Android/web.

## When PCC is (and isn't) a good bet

- **Good:** Apple-only indie or small apps paying OpenAI or Anthropic for mid-tier tasks
  (summarizing, extraction, classification, drafting from photos plus text). Marginal cost
  goes to zero and you can delete the key-hiding proxy. Also privacy-sensitive categories,
  watch apps, and long-context or agentic features the on-device model can't fit.
- **Weak:** cross-platform products (you still need a backend), heavy-usage core features
  (an opaque per-user cap you can't raise), tasks needing frontier-model quality, and
  businesses expecting to pass 2M downloads soon.

## Example app

[example/](example/) is a SwiftUI test app (xcodegen) with:
- **Playground:** on-device/PCC toggle, reasoning picker, structured output, photo input,
  streaming, reasoning view and token/latency metrics.
- **Compare:** one prompt across on-device and PCC at several reasoning levels.
- **Status:** availability, context sizes, capabilities and quota.

See [example/README.md](example/README.md) to run it.
