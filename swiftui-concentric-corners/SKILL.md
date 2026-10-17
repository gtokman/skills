---
name: swiftui-concentric-corners
description: Concentric corners in SwiftUI (iOS 26+): ConcentricRectangle, containerShape, Edge.Corner.Style.concentric(minimum:), and a reusable corner scale so nested shapes — a photo in a card, a card floating on a map, a thumbnail in that card, a hero image near the screen edge — share their corner centers instead of looking pinched or flared. Use when choosing corner radii, nesting rounded views, adopting Liquid Glass shapes, fixing corners that look "off" inside containers, or building a design system's radius tokens. Based on WWDC25 "Get to know the new design system" and the iOS 26 SDK.
---

# Concentric corners

Nested rounded shapes look right when they share their corner centers: the inner radius is
the outer radius minus the space between them. Get it wrong and corners look **flared**
(inner rounder than outer) or **pinched** (inner far squarer). Apple's three shape types:

- **Fixed** — a constant radius (`RoundedRectangle(cornerRadius:)`).
- **Capsule** — radius is half the height; concentric by nature (buttons, badges, pills).
- **Concentric** — radius = parent's radius − padding, worked out by the system.

## The API (iOS 26, macOS 26)

```swift
// The container declares its shape. Must be a RoundedRectangularShape:
// RoundedRectangle, UnevenRoundedRectangle, Rectangle, Capsule, Circle.
card.containerShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

// Content inside is concentric with it, never below the minimum (its radius when
// standalone or far from a container corner).
ConcentricRectangle(corners: .concentric(minimum: .fixed(16)), isUniform: false)
```

- `.concentric(minimum:)` is a **floor**, not a target: radius = max(container − inset,
  minimum). If the container is too tight for the content's padding, raise the container's
  radius — don't lower the minimum.
- `isUniform: true` gives every corner the same radius (a card floating near one edge of a
  map); `false` makes only corners near the container's corners concentric (Apple's sheets).
- Without any `containerShape`, concentric shapes resolve against the window/display corners
  — so a full-screen view's top content can follow the device's bezel.
- `ConcentricRectangle` is **not** a `RoundedRectangularShape`: it can't be a container.
  A container that is itself nested (a card on a map) declares its *resulting* radius as a
  `RoundedRectangle` (`map radius − inset`) for its own children.
- `matchedTransitionSource { $0.clipShape(…) }` only accepts `RoundedRectangle` — give it the
  content's usual radius.
- Before iOS 26: fall back to `RoundedRectangle` at the minimum radius. `containerShape` on a
  `RoundedRectangle` still compiles (the older `InsettableShape` overload).

## A reusable corner scale

Derive containers from contents, not the other way round: pick one **inner** radius for
photos and small cards, and make every container `inner + padding`. Then anything one
padding in comes out at `inner` exactly.

```swift
enum Corners {
    static let inner: CGFloat = 16          // photos, small cards
    static let map: CGFloat = 28            // maps and big media
    static let mapInset: CGFloat = 12       // cards on a map → 16

    static func container(padding: CGFloat) -> CGFloat { inner + padding }   // 12 pt → 28

    static func rect(_ radius: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }

    /// Content nested in a container: concentric, never below `minimum`.
    static func nested(minimum: CGFloat, uniform: Bool = false) -> AnyShape {
        if #available(iOS 26, *) {
            AnyShape(ConcentricRectangle(corners: .concentric(minimum: .fixed(minimum)), isUniform: uniform))
        } else {
            AnyShape(rect(minimum))
        }
    }
}
```

Usage:

```swift
// A card: radius from its padding, declared as the container.
let shape = Corners.rect(max(requested, Corners.container(padding: padding)))
VStack { photo }.padding(padding)
    .background(shape.fill(.surface))
    .containerShape(shape)

// A photo anywhere: concentric with whatever holds it, 16 on its own.
let photo = Corners.nested(minimum: Corners.inner)
photo.fill(.placeholder).overlay { image }.clipShape(photo)

// A map with a floating glass card holding a thumbnail.
map.clipShape(Corners.rect(Corners.map)).containerShape(Corners.rect(Corners.map))
    .overlay(alignment: .bottom) {
        HStack { Corners.nested(minimum: 10).fill(…).frame(width: 64, height: 64) … }
            .padding(12)
            .glassEffect(.regular, in: Corners.nested(minimum: Corners.map - Corners.mapInset, uniform: true))
            .containerShape(Corners.rect(Corners.map - Corners.mapInset))
            .padding(Corners.mapInset)
    }
```

## Checklist

- [ ] Every container that holds rounded content declares `.containerShape(_:)`.
- [ ] Nested content uses `ConcentricRectangle` (or a helper) with a sensible `minimum`.
- [ ] Container radius ≥ content radius + padding; never a bigger radius inside a smaller one.
- [ ] Clip, background, glass and hit-testing (`contentShape`) all use the same shape.
- [ ] Capsules for buttons, badges and pills; extra margin from the screen edge on phones.
- [ ] iOS 18 fallback in place.

## Verifying

Render offscreen on macOS 26+ (`ImageRenderer`, `#available(iOS 26, macOS 26, *)` in a copy
of the helper) with high-contrast fills: a container, content one padding in, the same content
standalone, and a floating card in a larger container. Corners should visibly share centers;
the standalone one shows the minimum.
