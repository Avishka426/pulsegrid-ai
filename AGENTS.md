# Jac coding guidance for PulseGrid AI

- Target Jac 0.37.x (verified with 0.37.25). Run `jac check` (whole program) and `jac test` after changes.
- Keep graph entities, edges, traversal, simulation logic and UI in Jac. Use native `node`, `edge`, and `walker` archetypes where graph traversal is needed.
- Use `def:pub` functions for typed server APIs that do not traverse; use walkers when actual graph visits/reports are central.
- Client components use `.jac`, `def:pub Name() -> JsxElement`, JSX, `has` reactive state, and Jac handlers. Do not author handwritten JS/TS for application behavior.
- Placement is inferred: client code imports server functions with a plain `import` (no `sv`/`cl` markers) and awaits them. Register server endpoints in `main.jac` imports.
- Use `jac install --shadcn` to add primitives; never hand-edit managed files under `components/ui/`.
- Keep all network data synthetic and deterministic. Do not claim agent activity or introduce physical-control actions before implementation and review.
- Never commit credentials, `.env`, runtime graph state, dependency folders, or generated build output. `.env.example` may contain blank placeholders only.
- Local development: `jac install`, then `jac run --dev`. Tests: `jac test`. Use `jac guide <topic>` for current syntax.
