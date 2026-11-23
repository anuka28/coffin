# Bone Shop: working with Kiro

This `.kiro/` folder holds the house rules for Bone Shop.

- `steering/` has the product, tech, structure and design rules Kiro reads.
- `hooks/` formats and analyzes Dart files when you save them.
- `specs/` is where your specs go (`.kiro/specs/`). Kiro creates it with your first spec.

## How to start

1. Open this app's folder in Kiro so it loads this .kiro/
2. Fill in `steering/product.md`: what the app is, who it is for, its principles and hard rules.
3. Ask Kiro for a spec, for example "Create a spec for my first feature".
4. Review the requirements. Ask for changes until they are right.
5. Review the design. Then review the tasks.
6. Run the tasks one at a time. Check `flutter test` after each one.

Each spec is saved in `.kiro/specs/<feature-name>/` as `requirements.md`, `design.md` and `tasks.md`.
