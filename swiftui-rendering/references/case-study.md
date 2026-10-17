# Case study: a streamed, generated-UI chat reply in collection view cells

Project: AddToChatMenu (`~/Desktop/AddToChatMenu`). A ChatGPT-style app whose replies are
model-written markup (Markdown + elements + small JS programs), parsed into a tree and
rendered with SwiftUI inside `UICollectionView` cells via `UIHostingConfiguration`. Text
streams in (every chunk re-parses the reply); interactive replies re-render on every slider
tick. Audited October 2026 against the two WWDC talks.

| Problem found | Rule | Fix |
|---|---|---|
| Every list used `ForEach(Array(x.enumerated()), id: \.offset)`. An `{#if}` branch appearing, or a paragraph becoming a table mid-stream, shifted every later index — checkboxes reset, map pins re-geocoded, images reloaded. | 1, 3 | `MarkupElement.key`: source position for parsed markup (`e812`), template position + iteration key for program output (`e3692:Water`, the model's `key=` when given), uniquified among siblings. `MarkupBlock.id`: element key, or last element's key + count (`e812+2`). Verified: 5,790 streamed block-ID checks across six replies, 0 changed. |
| Controls got their actions through `.environment(\.markupActions, MarkupActions { … })` created in the reply's `body` — a new closure every chunk and slider tick, invalidating every button/slider/toggle. | 10 | `.environment(document)` — the reply's `@Observable ReplyDocument`, one object per reply; controls read `@Environment(ReplyDocument.self) var document: ReplyDocument?` and call it in actions only. |
| `ReplyDocument.blocks` was assigned on every chunk even when unchanged (chunk ending mid-tag; handler not changing state). | 11 | `setBlocks` assigns only when `new != blocks`. |
| `MarkupChart` decoded JSON (up to hundreds of points) in `body` and held the scrub `@State`, so dragging re-decoded on every movement. | 13, 14 | `MarkupChart` decodes (`ChartSpec(element)`) and passes it to `ChartPlotView`, which owns `@State selectedIndex`. |
| `AttributedString(markdown:)` ran in every paragraph's `body`. | 13, 16 | `InlineMarkdown.attributed(_:)` with an `NSCache`. |
| Checkbox `@State` in a reused cell could show another reply's ticks; scrolling away lost them. | Cells | `ReplyDocument.checkedItems` keyed by element key; root `.id(message.id)`. |
| The cell's root re-ran `body` on every per-chunk reconfigure although content came from the observed document. | Cells, 12 | `MessageRowView: Equatable` comparing id, streaming flag, activity, user text, document identity; `.equatable()` in the hosting configuration. |
| `MarkupRow` switched `FlowLayout`/`HStack` with `if`/`else`; `MarkupBox` applied `flex` with `if`/`else`. | 4, 5 | `AnyLayout`; `.frame(maxWidth: flex ? .infinity : nil).layoutPriority(flex ? 1 : 0)` — verified pixel-identical. |
| `Canvas` (SVG drawings) collapsed to zero height in self-sizing cells, then rendered tiny in a large gap when stacks probed with small heights. | Cells | `AspectLayout`: width from the proposal (320 if open), height = width / ratio, never shrinking to a probed height. |
| `.aspectRatio(nil, contentMode: .fit)` on every box locked cards to their content's width. | Cells | Apply `.aspectRatio` only when the attribute exists. |

## The non-obvious one: `.equatable()` vs `layoutPriority`

After adding `.equatable()` to children of rows (`MarkupChildren`), the itinerary rows (a
fixed-width image beside a `flex` box with `layoutPriority(1)`) rendered ~41 pt taller in
total. Bisected by rebuilding with one file reverted at a time: the cause was
`EquatableView` wrapping the box — the row no longer saw its layout priority. Fix: keep
`.equatable()` on vertical lists of blocks (where the savings are), not on row/grid
children. `MarkupElementView` stays `Equatable` either way.

Lesson: wrappers that look transparent can change layout. Pixel-diff before and after
rendering refactors.

## How it was verified

- Typecheck against the iOS SDK (`xcrun swiftc -typecheck -sdk iphoneos …`).
- A macOS harness compiling the same `Sources/Conversation` files: renders replies with
  `ImageRenderer` to PNG (pixel-compared before/after), runs an identity-stability test
  over every 150-character prefix, simulates slider/button interactions through the JS
  program and checks keys survive.
- On device: `_printChanges()` in `MarkupBlockView.body` — streaming should log only the
  growing last block; a slider only the blocks depending on it.
