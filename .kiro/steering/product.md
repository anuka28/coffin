---
inclusion: always
---

# Product: Coffin

Coffin is a lean, spooky Flutter starter kit built for the Kiroween 2026 hackathon (Skeleton Crew category). The skeleton should be clear enough to read in one sitting and flexible enough to power very different apps.

## What we are building
1. **coffin_core** (`packages/coffin_core`): the reusable skeleton. Theme, routing, storage, AI layer, spooky widgets.
2. **Hauntagotchi** (`apps/hauntagotchi`): a ghost pet that thrives or fades based on the user's real daily habits. Completing habits feeds the ghost; neglect makes it fade and eventually die; it can be resurrected.
3. **Graveyard** (`apps/graveyard`): abandoned side projects become tombstones. An AI "séance" scores each project's resurrection potential and gives a 3-step revival plan.

## Who it's for
- Coffin: Flutter developers who want to start a polished app fast.
- Hauntagotchi: people who struggle to keep habits and want them to feel fun.
- Graveyard: developers with a pile of unfinished side projects.

## Product principles
- Every spooky effect must support the app's function, not just decorate it.
- Both apps must feel complete: onboarding, empty states, error states, no dead ends.
- Both apps run on Flutter Web (judges test via URL) and look good on mobile screen sizes.
- Anything app-specific belongs in the app. Only genuinely reusable code goes in `coffin_core`.

## Hard rules
- All code is new work created during the hackathon. Never copy code from other projects.
- No API keys, secrets or tokens in the repo, ever.
- Use only assets (fonts, sounds, images) with a license that allows it, and record them in `CREDITS.md`.
