# Jac coding guidance for PulseGrid AI

- Target the project's Jac version: 0.16.7 (jaclang) with the `jac-client` plugin installed. Run `jac check main.jac` after changes.
- `main.jac` mixes contexts: plain server imports (none currently needed) above a `cl { ... }` block that holds the client entry (`def:pub app() -> JsxElement`). Client component files use the explicit `.cl.jac` extension.
- Keep graph entities, edges, traversal, simulation logic and UI in Jac. Use native `node`, `edge`, and `walker` archetypes where graph traversal is needed.
- Use `def:pub` functions for typed server APIs that do not traverse; use walkers when actual graph visits/reports are central.
- Client components use `.cl.jac`, `def:pub Name() -> JsxElement`, JSX, `has` reactive state, and Jac handlers. Do not author handwritten JS/TS for application behavior.
- Calls across a client/server boundary use `sv import` (in `.cl.jac` files) and are awaited. A top-level `import from services.X { ... }` in `main.jac` is only needed for endpoints no client file reaches via `sv import`.
- Use `jac add --shadcn <name>` to add primitives; never hand-edit managed files under `components/ui/`.
- Keep all network data synthetic and deterministic. Do not claim agent activity or introduce physical-control actions before implementation and review.
- Never commit credentials, `.env`, runtime graph state, dependency folders, or generated build output. `.env.example` may contain blank placeholders only.
- Local development: `jac install`, then `jac start --dev main.jac`.
