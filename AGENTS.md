# Agent Contract

Always-on contract for any coding agent working in this repository. Everything here is a digest; the full standards live in the catalog below.

## Precedence

1. [docs/architecture.md](docs/architecture.md) — the normative architecture. On any conflict, it wins.
2. Installed rule packs under [rules/](rules/) — durable standards the code must meet.
3. Skills under [skills/](skills/) — procedures for specific tasks; use the matching one before improvising.
4. This file — the digest that applies when nothing more specific is loaded.

Where all of these are silent, do not invent policy: say so and propose an ADR (see the ADR Triggers section of the architecture).

## Fixed stack

| Area      | Choice                                                                                       |
| --------- | -------------------------------------------------------------------------------------------- |
| Monorepo  | pnpm workspaces + Turborepo 2, Node.js 24 LTS                                                |
| Web       | React 19, TanStack Start 1 + Router + Query, Tailwind 4 + shadcn, Vite                       |
| API       | .NET 10 LTS, ASP.NET Core Minimal APIs, modular monolith with vertical slices                |
| Data      | EF Core 10 + PostgreSQL (Npgsql), one schema + `DbContext` per module                        |
| Contract  | Build-time OpenAPI 3.1 docs → `openapi-typescript` → `packages/api-client` (`openapi-fetch`) |
| API tests | xUnit, Shouldly, NSubstitute, NetArchTest, Testcontainers.PostgreSql                         |
| Web tests | Vitest + Testing Library                                                                     |

Pins: `global.json`, root `packageManager`, `Directory.Packages.props`, `.config/dotnet-tools.json`, `pnpm-lock.yaml`. Introduce nothing outside this stack without an ADR.

## Commands

```bash
pnpm install && dotnet tool restore   # once after clone
docker compose up -d db               # PostgreSQL
pnpm dev                              # web (:3000) + API (:5000)
pnpm lint | typecheck | test | build  # individual gates (both toolchains via Turbo)
pnpm generate                         # regenerate client after an API contract change
pnpm verify                           # full PR gate incl. drift check
pnpm --filter @repo/api exec dotnet ef migrations add <Name> \
  --project src/Modules/<M>/<M> --startup-project src/Api --context <M>DbContext
```

Drift check (run by `verify` and CI): `pnpm turbo run build generate && git diff --exit-code -- apps/api/openapi packages/api-client/src`.

## Boundary digest

1. One use case = one slice file in one module: `Command`/`Query` + `Response` + `Validator` + `Handler` + `Endpoint`, all nested, all `internal`.
2. A slice never calls another slice's handler; a module never references another module's implementation — only `{Module}.Contracts` or integration events via outbox/inbox.
3. A module owns its PostgreSQL schema and `DbContext`; no cross-schema foreign keys or joins, ever, including raw SQL.
4. Endpoints are thin and declare full OpenAPI metadata (operation id, group, tags, summary, every response); handlers own rules and return `Result`, mapped by `CustomResults.Problem`.
5. Web code is organized by product feature; routes only validate URL state, prefetch, and render feature entry points.
6. The web app calls the API only through TanStack server functions using the generated `openapi-fetch` client; the browser never sees the API base URL or tokens.
7. TypeScript DTOs come only from `@repo/api-client`; generated files (`*.gen.ts`, `openapi/*.json`, `routeTree.gen.ts`, applied migrations) are never hand-edited.
8. `Common.*` and `packages/*` stay application-neutral; feature or module logic never moves there.
9. Configuration is read only through validated typed options (`ValidateOnStart`) / the web config module; secrets never reach code, logs, or responses.
10. Handlers enforce resource ownership from `IUserContext`; every protected endpoint calls `RequireAuthorization`.

## Completion gate

Work is done only when all of these hold:

- `pnpm verify` passes: lint, typecheck, test, build on both toolchains, plus the contract drift check.
- New behavior has tests in the prescribed places (colocated `.test.ts(x)` on the web; test projects mirroring `Features/` on the API).
- Contract changes were made in C#, regenerated via `pnpm generate`, and the `openapi/*.json` diff was reviewed and committed.
- The Completion Checklist in [docs/architecture.md](docs/architecture.md) is satisfied.

Never weaken a gate to pass it: no skipped tests, no loosened lint rules, no `--no-verify`, no hand-edits to generated files.

## Agent conduct

- Prefer the smallest change that preserves the boundaries; do not refactor beyond the task.
- Follow the matching skill when one exists (see [skills/README.md](skills/README.md)); plan multi-slice work with `plan-feature` before editing and review the result with `review-changes` before merge.
- Decisions listed under ADR Triggers in the architecture are never yours alone — surface them and stop.
- Cite the architecture section or rule you are applying when reviewers ask why.
- When a command fails, diagnose against [skills/fix-verify-failures](skills/fix-verify-failures/SKILL.md) instead of retrying blindly.

## Catalog

| Component                                    | Purpose                                                |
| -------------------------------------------- | ------------------------------------------------------ |
| [docs/architecture.md](docs/architecture.md) | The normative architecture — the authority             |
| [rules/](rules/README.md)                    | Always-loaded standards, installable per role as packs |
| [skills/](skills/README.md)                  | On-demand procedures: build, plan, review, repair      |
| [hooks/](hooks/README.md)                    | Deterministic guards on harness/git events             |
| [templates/](templates/README.md)            | ADR, glossary, feature-spec seeds                      |
