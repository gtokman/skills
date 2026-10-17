---
name: swiftui-rendering
description: How SwiftUI decides what to re-render — identity, lifetime, dependencies — and how to write views that update efficiently, especially SwiftUI hosted in UIKit cells (UIHostingConfiguration) and views rebuilt from streaming or generated content. Use when writing or reviewing SwiftUI views for performance, fixing views that lose state, flash, re-render too often or reload images, choosing ForEach identifiers, hosting SwiftUI in collection/table view cells, or debugging layout that changes when views are wrapped. Based on WWDC21 "Demystify SwiftUI" and WWDC23 "Demystify SwiftUI performance", plus lessons verified in practice.
---

# SwiftUI rendering

SwiftUI looks at three things in your code: **identity** (is this the same element as
before?), **lifetime** (how long that identity lasts — and with it, `@State`), and
**dependencies** (which inputs, when they change, make a `body` run again). Almost every
"why did it re-render / lose state / animate oddly / hitch" question is one of these.

## The model

- **View values are ephemeral; identity is not.** A view struct is created, compared with
  the previous value, and thrown away. What persists is its identity, and `@State` /
  `@StateObject` storage is tied to that identity: **when identity changes, state is
  replaced** and `onAppear`/`task` run again, images reload.
- **Two kinds of identity.** *Explicit*: `ForEach` IDs, `Identifiable`, `.id(_:)`.
  *Structural*: a view's type and position in the hierarchy — each branch of an `if`/`switch`
  is a different identity.
- **The dependency graph.** A view's dependencies are its stored properties (inputs from its
  parent), `@State`, `@Environment`, `@Binding`, and the `@Observable` properties its `body`
  reads. When one changes, only the views depending on it get a new `body`. SwiftUI then
  compares the new child values with the old ones and stops wherever nothing changed.
- **Update order** for an invalidated view: new value → dynamic properties updated →
  `body` runs → children compared → recurse.

## Rules

### Identity

1. **Never identify by index** (`ForEach(Array(x.enumerated()), id: \.offset)`, `0..<count`
   over dynamic data). Anything inserted above shifts every later index: their state resets,
   their images reload, animations go to the wrong place. Use a stable, unique ID.
2. **IDs must be stable and unique.** No `UUID()` in a computed `id` (new identity every
   render). No names that can repeat (two "Dog biscuit" treats). Uniquify repeats
   (`key`, `key#2`) if the data can't guarantee it — duplicate IDs in a `ForEach` misbehave.
3. **For generated or streamed content, derive identity from structure that doesn't
   move**: where the element starts in the source text (streaming only appends), or
   template position + per-iteration key for program output (React's model:
   `template:key`). Name unkeyed items (loose text, paragraphs) after the keyed element
   before them plus a counter (`e812+2`), so new content at the end never renames earlier
   items.
4. **Prefer one view with changing modifiers over branches.** `if expired { v.opacity(0.3) }
   else { v }` is *two* identities; `v.opacity(expired ? 0.3 : 1)` is one. "Inert"
   values (opacity 1, padding 0, `frame` with no sizes, `layoutPriority(0)`,
   `transformEnvironment`) cost ~nothing. Use a branch only for genuinely different views.
5. **Switch layouts with `AnyLayout`**, not `if wrap { FlowLayout { … } } else { HStack { … } }`
   — children keep their identity and state.
6. **Avoid `AnyView`.** It hides the type structure from SwiftUI (worse diffing, and in
   `List`/`Table` forces building every row to count them). Use `@ViewBuilder` functions,
   `switch`, generics.
7. **Model element kinds as an enum and switch over it** in the dispatching view, with no
   `default`: a new case can't be silently unhandled.

### Dependencies

8. **Pass views only what they use.** A view taking a whole model re-runs `body` when any
   field changes; pass the image, not the dog. Extract subviews to scope dependencies —
   with judgement, not for every line.
9. **`@Observable` tracks what `body` reads.** Reading a property in an *action closure*
   creates no dependency; reading it in `body` does. Put state the view shows in the model
   and read it in `body` only where needed.
10. **Never put a new closure (or other non-comparable value) in the environment per
    render** — e.g. `.environment(\.actions, Actions { … })` in a `body`. It can't be
    compared, so every reader is invalidated on every parent update. Put a stable object
    in the environment instead (`.environment(model)` with `@Observable`, read as
    `@Environment(Model.self) var model: Model?`), and call it from actions.
11. **Don't notify when nothing changed.** An `@Observable` property notifies on every set.
    Guard: `if new != value { value = new }` — matters when you rebuild derived state on
    every chunk or tick.
12. **`Equatable` views to skip unchanged subtrees.** Conform the view (only possible when it
    has no property wrappers) and apply `.equatable()` where a parent re-renders often with
    mostly-unchanged children (a list of blocks while content streams). Write a custom
    `==` comparing only what the view shows.
    ⚠️ **`.equatable()` hides the child's `layoutPriority` from its container.** Inside an
    `HStack`/row, a `layoutPriority(1)` child wrapped in `EquatableView` stops winning spare
    space and the row lays out differently. Use `.equatable()` in vertical lists of blocks,
    not on children of rows/stacks that rely on priority.

### Cheap `body`

13. **No parsing, decoding, filtering, sorting or allocation-heavy work in `body`.** It runs
    on every invalidation. Precompute in the model, cache (an `NSCache` keyed by input), or
    hoist it to the view whose inputs actually change.
14. **Split expensive inputs from fast-changing state.** If a view decodes data *and* holds
    `@State` that changes often (drag, scrub, hover), the decode re-runs on every change.
    Decode in a parent, pass the result to a child that owns the `@State`.
15. **Slow work goes in `.task`, not `init` or `body`.** Make it `async`; never block in
    a dynamic property's initial value.
16. **Cache costly formatting** — `AttributedString(markdown:)`, string interpolation on hot
    paths, bundle lookups.

### Lists

17. **`List`/`Table` gather every ID up front.** Keep ID generation cheap, and give each
    `ForEach` element a **constant number of views** — no `if` filters or `AnyView` inside
    the row closure (filter the data, in the model, not inline in `body`). Nested
    `ForEach` is fine for sections.

## SwiftUI in UIKit cells (`UIHostingConfiguration`)

- **Cells are reused**, and SwiftUI view state can carry into the next item shown in that
  cell. Give the root `.id(item.id)` so a different item gets a fresh tree — and keep
  user-visible state (checked, expanded, selection) in the model, keyed by stable IDs, not
  in `@State`, or it's lost/misapplied on reuse and scrolling.
- **Reconfiguring a cell rebuilds the root view value.** If content is driven by an
  observed model, make the root view `Equatable` on what it shows (not on raw inputs that
  only feed the model) and apply `.equatable()`, so reconfigure-per-update doesn't re-run
  the whole tree — the observation does the actual update.
- **Self-sizing measures with an open height.** Views without an ideal size collapse to
  zero there: `Canvas`, shapes, `GeometryReader`. `.aspectRatio(r, contentMode: .fit)` is
  not enough — give them a size with a small custom `Layout` (width from the proposal,
  height = width / ratio; ignore probing heights).
- **`.aspectRatio(nil, contentMode:)` locks a view to its content's ideal size** — cards
  stop filling their row. Apply `.aspectRatio` only when you have a ratio.

## Review checklist

- [ ] Every `ForEach` has stable, unique IDs — no `\.offset`, no computed `UUID()`.
- [ ] No `AnyView`; branches only for genuinely different views; `AnyLayout` for layout switches.
- [ ] Views receive only the data they render.
- [ ] Nothing non-comparable is created per render in the environment.
- [ ] `body` does no parsing/decoding/filtering; expensive inputs separated from fast `@State`.
- [ ] Observable properties aren't re-set to equal values.
- [ ] `.equatable()` where it saves work — and not on children that use `layoutPriority`.
- [ ] Hosted cells: root `.id(item.id)`, visible state in the model, Equatable root.
- [ ] Views without an ideal size are given one before going into self-sizing cells.

## Verifying

- **`let _ = Self._printChanges()`** at the top of a `body` logs why it ran (`@self`,
  `@identity`, or the property that changed). Debug only — remove before shipping.
- **Instruments → SwiftUI template** for body counts and slow updates; Hangs/Hitches for
  the effects.
- **Identity test**: render every prefix of streamed content and assert that every
  completed item's ID appears unchanged in the final render; after interactions, assert
  surviving elements kept their IDs; assert no duplicate sibling IDs.
- **Pixel diff before/after a rendering refactor**: render views offscreen on macOS with
  `ImageRenderer` (same code, `.frame(width:)`, `proposedSize` with nil height) and compare
  PNGs. It catches layout regressions like the `EquatableView`/`layoutPriority` one.
  (`Map`, `ScrollView` and remote images don't render offscreen; compare everything else.)
  Bisect a difference by toggling one changed file at a time.

## References

- `references/case-study.md` — the AddToChatMenu reply renderer (streamed, model-generated
  markup in collection view cells): each problem found against these rules and its fix.
- WWDC21 *Demystify SwiftUI* (session 10022); WWDC23 *Demystify SwiftUI performance*
  (session 10160).
