# Jac coding guidance for PulseGrid AI

- Target Jac 0.34.23, the stable line (install with `--version 0.34.23`). Run `jac check` on each changed file (`jac check main.jac` reads imported modules as interfaces only) and `jac test` after changes.
- Keep graph entities, edges, traversal, simulation logic and UI in Jac. Use native `node`, `edge`, and `walker` archetypes where graph traversal is needed.
- Use `def:pub` functions for typed server APIs that do not traverse; use walkers when actual graph visits/reports are central.
- Client components use `.jac`, `def:pub Name() -> JsxElement`, JSX, `has` reactive state, and Jac handlers. Do not author handwritten JS/TS for application behavior.
- Calls across a client/server boundary use `sv import` and are awaited. Register server endpoints in `main.jac` imports. `jac.toml` keeps `[scale.microservices] enabled = false`; without it `jac start` launches each `sv import`-ed module as a separate service behind a gateway.
- On Jac 0.34, attach nodes to `root` before linking them. Links made between transient nodes that are attached afterwards are stored but cannot be traversed (see `services/seed.jac` and `open_incident` in `services/incidents.jac`). Linking a transient node to an already attached one is fine.
- Tests go in standalone `*_tests.jac` modules under a `tests/` folder (not `test_*.jac`, and not `.test.jac` annexes when they import sibling modules, which causes circular imports). HTTP endpoint tests use `JacTestClient` (`jaclang.runtimelib.testing`) from a pytest `test_*.py` file with a temporary `base_path` per test. `MockLLM` takes `model_name="mockllm", config={"outputs": [...]}`.
- Use `jac install --shadcn` to add primitives; never hand-edit managed files under `components/ui/`.
- Keep all network data synthetic and deterministic. Do not claim agent activity or introduce physical-control actions before implementation and review.
- Never commit credentials, `.env`, runtime graph state, dependency folders, or generated build output. `.env.example` may contain blank placeholders only.
- Local development: `jac install`, then `jac start --dev main.jac`. Tests: `jac test`. Use `jac guide <topic>` for 0.34 syntax.
