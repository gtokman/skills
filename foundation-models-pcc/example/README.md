# PCC Playground

A SwiftUI test app for Apple Foundation Models on Private Cloud Compute (iOS 27).

- **Playground:** switch between on-device and PCC, pick a reasoning level, toggle
  structured output (`ArticleSummary`), attach a photo, and stream the response. The app
  shows the model's reasoning, time to first token, total time, and input, cached, output
  and reasoning token counts.
- **Compare:** runs one prompt across on-device and PCC at several reasoning levels, one
  at a time so latency comparisons are fair.
- **Status:** availability, context sizes, capabilities, and the quota status, reset time
  and "higher limits" button.

## Run

1. Get the PCC entitlement and set up an explicit App ID with **Access to models on Private
   Cloud Compute** enabled. See [../references/setup-and-signing.md](../references/setup-and-signing.md).
2. In `project.yml`, set `DEVELOPMENT_TEAM` and change `com.example` to your bundle prefix.
3. `brew install xcodegen` if needed, then `xcodegen generate && open PCCPlayground.xcodeproj`.
4. In Signing & Capabilities, add the **Private Cloud Compute** capability so Xcode creates
   an explicit profile. The wildcard profile silently drops the entitlement.
5. Run on a physical Apple Intelligence device running iOS 27.

Every PCC run, including each one in the Compare tab, counts against the signed-in iCloud
account's daily limit.
