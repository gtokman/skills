# Skills

Agent skills for Claude Code (and other agents that read `SKILL.md`).

| Skill | What it covers |
|---|---|
| [swiftui-rendering](swiftui-rendering/SKILL.md) | How SwiftUI decides what to re-render — identity, lifetime, dependencies — and how to write views that update efficiently, especially SwiftUI hosted in UIKit cells and views rebuilt from streaming or generated content. Based on WWDC21 *Demystify SwiftUI* and WWDC23 *Demystify SwiftUI performance*, plus a case study. |

## Install

Copy a skill's folder into `~/.claude/skills/` (for all your projects) or `.claude/skills/`
in a project:

```sh
git clone https://github.com/gtokman/skills
cp -R skills/swiftui-rendering ~/.claude/skills/
```
