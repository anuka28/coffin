---
inclusion: always
---

# Design Language: "Haunted, not horror"

Spooky and playful, never gory. The interface should feel like a moonlit graveyard: dark, soft, glowing.

## Color
- Background: deep night `#0E0B16`, surfaces `#1A1525`, raised surfaces `#241C33`
- Primary: ghost-glow purple `#9B6BFF`
- Accent: pumpkin `#FF8A3D`, ectoplasm green `#7CFFB2` (for success / "alive" states)
- Danger: blood-moon red `#FF4D6D`
- Text: bone white `#EDE6F5`, muted `#9A90AB`
- Also provide a light "daylight" theme with the same tokens remapped. Contrast must meet WCAG AA in both themes.

## Typography
- Display/headings: a characterful spooky font (e.g. "Creepster" or "Nosifer" from Google Fonts) used sparingly, for titles only.
- Body/UI: a clean, readable font (e.g. "Inter" or "Outfit").

## Motion
- Movement is slow and floaty: ghosts bob, fog drifts, things fade in like mist.
- Default durations 300–600 ms with ease-in-out curves. Loops must be subtle.
- Respect reduced motion: when `MediaQuery.disableAnimations` is true, replace loops with static states.

## Components
- Rounded corners (16 px), soft glows instead of hard shadows.
- Tombstone-shaped cards, ghost loaders, flickering text for emphasis only.
- Every interactive element needs a hover/press state and a semantic label for screen readers.
- Minimum tap target 48×48.

## Tone of copy
Short, witty, slightly spooky ("Your ghost is getting hungry…", "This project has been dead for 214 days"). Never mean to the user.
