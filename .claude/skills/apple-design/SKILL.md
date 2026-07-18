---
name: apple-design
description: Apple fluid-interface design principles (WWDC-derived) — response, direct manipulation, interruptibility, springs, velocity handoff, materials, typography. Use when designing or reviewing any UI/motion in this project.
---

# Apple Design

How Apple builds interfaces that stop feeling like a computer and start feeling like an extension of you. This knowledge comes from Apple's WWDC design talks — chiefly *Designing Fluid Interfaces* (WWDC 2018).

The through-line: **an interface feels alive when motion starts from the current on-screen value, inherits the user's velocity, projects momentum forward, and can be grabbed and reversed at any instant.** Springs are the tool that makes all of this natural, because they are inherently interruptible and velocity-aware.

## The Core Idea

> "When we align the interface to the way we think and move, something magical happens — it stops feeling like a computer"

Apple frames design as serving four human needs: **safety/predictability, understanding, achievement, and joy.** Every rule here serves one of them.

## 1. Response — kill latency

- **Respond on pointer-down, not on release.** Highlight a button the instant it's pressed.
- **Be vigilant about every latency.** Audit debounces, artificial timers, transition waits.
- **Feedback must be continuous *during* the interaction, not just at the end.** For a drag, slider, or drawer, update the UI 1:1 with the pointer the whole way through.

## 2. Direct manipulation — 1:1 tracking

> "Touch and content should move together."

When the user drags something, it must stay glued to the finger — and respect the offset from *where they grabbed it*. Track a short velocity/position history — you'll need velocity at release.

## 3. Interruptibility — the single most important principle

> "The thought and the gesture happen in parallel."

- **Never lock out input during a transition.**
- **Always animate from the *presentation* (current) value, never the target value.**
- **When a gesture reverses, blend velocity — don't hard-cut it.**
- **Decompose 2D motion into independent X and Y springs.**

## 4. Behavior over animation — use springs

- **Damping ratio** — controls overshoot. `1.0` = critically damped, no bounce. `< 1.0` = overshoots.
- **Response** — how quickly the value reaches the target, in seconds. Lower = snappier.

**Defaults:**
- Start most UI at **damping `1.0`** (critically damped).
- Add bounce (**damping ~`0.8`**) **only when the gesture itself carried momentum**.

**Concrete values Apple ships:**

| Interaction | Damping | Response |
| --- | --- | --- |
| Move / reposition (e.g. PiP) | `1.0` | `0.4` |
| Rotation | `0.8` | `0.4` |
| Drawer / sheet | `0.8` | `0.3` |

SwiftUI: `.spring(response: 0.4, dampingFraction: 1.0)`.

## 5. Velocity handoff

When a gesture ends, the animation must **continue at the finger's exact velocity**. `relativeVelocity = gestureVelocity / (targetValue − currentValue)`.

## 6. Momentum projection

Don't snap to the nearest boundary from the *release point* — project the resting position:

```
project(v, d = 0.998) = (v / 1000) * d / (1 - d)
target = nearestSnapPoint(current + project(releaseVelocity))
```

## 7. Spatial consistency

- **Enter and exit along the same path.**
- **Anchor interactions to their source** (menus/popovers scale from their trigger).
- **Mirror the easing on reversible transitions.**

## 8. Hint in the direction of the gesture

Intermediate motion should telegraph where things are going.

## 9. Rubber-banding — soft boundaries

At an edge, resist progressively instead of stopping hard:
`rubberband(x, dim, c = 0.55) = (x * dim * c) / (dim + c * |x|)`

## 10. Gesture design details

- **Tap:** highlight on touch-*down*, commit on touch-*up*, ~10px hysteresis, cancel-by-dragging-away.
- **Drag/swipe:** small movement threshold before committing to a direction, then 1:1.
- **Detect all plausible gestures in parallel**, cancel the losers once intent is clear.

## 11. Frame-level smoothness

Animate only compositor-friendly properties — `transform` and `opacity`.

## 12. Materials & depth

- **Build nav/toolbars/sheets as translucent layers** with content scrolling underneath.
- **Material weight encodes hierarchy.** Never stack a light translucent surface on another.
- **Dim to focus, separate to keep flow.** Modal task = scrim + push background back.
- **Vibrancy keeps text legible over changing backgrounds** — higher contrast, slightly heavier weight, small letter-spacing bump.
- **Scroll edge effects, not hard dividers.**
- **Materialize, don't just fade** — animate blur radius and scale together on enter/exit.

## 13. Multimodal feedback — motion + sound + haptics

1. **Causality** — trigger on the actual causal event.
2. **Harmony** — visual, sound, haptic on the **same frame**.
3. **Utility** — reserve haptics/sound for meaningful moments (success, error, commit, snap).

## 14. Reduced motion & accessibility

- Reduced motion → short opacity cross-fades, drop elastic/overshoot.
- Reduced transparency → frostier/solid surfaces.
- Avoid full-viewport moving backgrounds and abrupt brightness jumps.

## 15. Typography

- **Tracking is size-specific.** Large display text wants *negative* tracking; small text slightly *positive*.
- **Leading tracks size inversely.** Tight on large headings, looser on body.
- **Build hierarchy from weight + size + leading as a set.**
- **Respect Dynamic Type.** Scale layout *with* the text.
- **Default to the platform's system font.**

## 16. Design foundations — the eight principles

1. **Purpose.** Decide what *not* to build.
2. **Agency.** Easy undo; confirmation only for genuinely destructive actions.
3. **Responsibility.** Privacy: ask at the right moment, only what's needed.
4. **Familiarity.** Things that look the same must behave the same.
5. **Flexibility.** Adapt to platform, situation, abilities.
6. **Simplicity — not minimalism.** Hierarchy so the most important thing is the most obvious.
7. **Craft.** Every spacing, timing, and alignment value is a deliberate choice you can defend.
8. **Delight.** The result of getting the other seven right.

Tactical: feedback = status/completion/warning/error; wayfinding (Where am I? How do I get out?); proximity implies relationship; direct, specific labels beat generic ones.

## 17. Process

- **Prototype interactively** — an interactive demo is worth "a million static designs."
- **Design interaction and visuals together.**
- **Review motion frame-by-frame** to catch what's invisible at full speed.

## Quick Reference

| Need | Technique | Concrete value |
| --- | --- | --- |
| Default UI spring | Critically damped | `damping 1.0`, `response 0.3–0.4` |
| Momentum / flick spring | Slight bounce | `damping ~0.8`, `response 0.3–0.4` |
| Interrupt cleanly | Start from presentation value | read live transform |
| Decide reverse vs. commit | Velocity **sign**, not position | at release |
| Boundary | Rubber-band | progressive resistance |
| Type tracking | Size-specific | tighten large text, body near 0 |
| Reduced motion | Cross-fade, not slide/spring | check accessibility settings |
