# Skills

Agent skills for Claude Code (and other agents that read `SKILL.md`).

| Skill | What it covers |
|---|---|
| [swiftui-rendering](swiftui-rendering/SKILL.md) | How SwiftUI decides what to re-render — identity, lifetime, dependencies — and how to write views that update efficiently, especially SwiftUI hosted in UIKit cells and views rebuilt from streaming or generated content. Based on WWDC21 *Demystify SwiftUI* and WWDC23 *Demystify SwiftUI performance*, plus a case study. |
| [swiftui-concentric-corners](swiftui-concentric-corners/SKILL.md) | Concentric corners in SwiftUI (iOS 26+): `ConcentricRectangle`, `containerShape` and `.concentric(minimum:)`, plus a reusable corner scale, so photos in cards, cards on maps and hero images share their corner centers instead of looking pinched or flared. Based on WWDC25 *Get to know the new design system*. |
| [foundation-models-pcc](foundation-models-pcc/SKILL.md) | Apple's server Foundation Model on Private Cloud Compute (iOS 27+): eligibility and the managed entitlement, the signing trap where a wildcard profile silently drops it, the `PrivateCloudComputeLanguageModel` API (reasoning levels, images, structured output, token usage), per-user quota UI, errors, routing with `DynamicProfile`, and when PCC can replace a paid LLM API. Includes a SwiftUI test app. Based on WWDC26 sessions 241, 242 and 319 and the iOS 27 SDK. |

## Install

Copy a skill's folder into `~/.claude/skills/` (for all your projects) or `.claude/skills/`
in a project:

```sh
git clone https://github.com/gtokman/skills
cp -R skills/swiftui-rendering ~/.claude/skills/
```
