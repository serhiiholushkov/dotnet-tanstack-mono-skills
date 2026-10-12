# Rules

Rules are the durable standards code in this repository must always meet. A rule states the standard and what catches violations — it never contains procedure (that is a skill's job) and never narrates rationale beyond a sentence (that is [../docs/architecture.md](../docs/architecture.md)'s job).

## Format

Every rule file is one topic, ≤ ~80 lines, imperative and testable, with frontmatter:

```yaml
---
title: Module boundaries
description: One-line summary used for indexes and discovery.
appliesTo: 'apps/api/**/*.cs'
---
```

`appliesTo` is a comma-separated list of glob hints relative to the consuming repository root. Installation maps it to each harness's scoping mechanism (Copilot `applyTo` frontmatter, Cursor rule globs, Claude selective installation). Harnesses without file scoping load the whole installed pack.

## Packs

Always-loaded context is expensive; install only the packs an agent's role needs.

| Pack                       | Covers                                                                       | Scope                  |
| -------------------------- | ---------------------------------------------------------------------------- | ---------------------- |
| [common/](common/)         | Boundaries, naming, error shape, security, commits — the cross-stack floor   | Everything             |
| [csharp/](csharp/)         | C# language discipline: nullability, async, `Result`, EF Core, logging       | `apps/api/**/*.cs`     |
| [dotnet-api/](dotnet-api/) | Modules, slices, endpoint/OpenAPI metadata, data ownership, options, caching | `apps/api/**/*.cs`     |
| [typescript/](typescript/) | TS strictness, type sourcing, async/error handling, module resolution        | `**/*.ts(x)`           |
| [web/](web/)               | Feature folders, routes, TanStack Query, server functions, components        | `apps/web/**`          |
| [monorepo/](monorepo/)     | pnpm/Turbo wiring, the codegen pipeline, the command surface                 | Root configs, pipeline |
| [testing/](testing/)       | Test placement, the test-type tables, discipline                             | Test files             |

Role combinations:

| Agent role           | Install                                              |
| -------------------- | ---------------------------------------------------- |
| Full-stack (default) | All seven packs                                      |
| API-only             | `common` + `csharp` + `dotnet-api` + `testing`       |
| Web-only             | `common` + `typescript` + `web` + `testing`          |
| Reviewer / planner   | `common` + `monorepo` (plus read access to the rest) |

## Installation

The catalog here is canonical; installed copies are disposable and regenerated, never edited in place. `install.sh` installs the selected packs (`--packs all | api | web | reviewer | <list>`) and translates `appliesTo` per harness:

- **GitHub Copilot** — `.github/instructions/<pack>-<name>.instructions.md` with `applyTo`.
- **Claude Code** — `.claude/rules/<pack>-<name>.md` with a `paths` list (omitted for `**/*` rules, which then load unconditionally).
- **Codex and other AGENTS.md readers** — no scoped-rule mechanism; the packs stay in the vendored catalog and are reached through the root `AGENTS.md` links.
- **Cursor** — `.cursor/rules/<pack>-<name>.mdc` with `globs` + `alwaysApply`.

Details and the manual equivalent live in [../docs/install.md](../docs/install.md).

## Index

| File                                                               | Standard                                                        |
| ------------------------------------------------------------------ | --------------------------------------------------------------- |
| [common/boundaries.md](common/boundaries.md)                       | Dependency directions and forbidden edges across the whole repo |
| [common/naming.md](common/naming.md)                               | Names for files, types, routes, operations, keys, tests         |
| [common/errors.md](common/errors.md)                               | One error shape end to end; nothing internal leaks              |
| [common/security.md](common/security.md)                           | Secrets, trust boundary, authn/authz floor                      |
| [common/git-commits.md](common/git-commits.md)                     | Conventional Commits and PR expectations                        |
| [csharp/language.md](csharp/language.md)                           | net10.0 project discipline, records, primary constructors       |
| [csharp/nullability.md](csharp/nullability.md)                     | Nullable reference types as contract                            |
| [csharp/async.md](csharp/async.md)                                 | Async and `CancellationToken` discipline                        |
| [csharp/results.md](csharp/results.md)                             | `Result`/`Error`/`ErrorType` usage                              |
| [csharp/ef-core.md](csharp/ef-core.md)                             | Query, projection, and save rules                               |
| [csharp/logging.md](csharp/logging.md)                             | Structured logging and correlation                              |
| [dotnet-api/modules.md](dotnet-api/modules.md)                     | Two-project modules, registration, Contracts                    |
| [dotnet-api/slices.md](dotnet-api/slices.md)                       | Slice anatomy and isolation                                     |
| [dotnet-api/endpoints-openapi.md](dotnet-api/endpoints-openapi.md) | Endpoint metadata completeness and versioned groups             |
| [dotnet-api/data-ownership.md](dotnet-api/data-ownership.md)       | Schema ownership and cross-module reads                         |
| [dotnet-api/configuration.md](dotnet-api/configuration.md)         | Typed options, `ValidateOnStart`                                |
| [dotnet-api/caching.md](dotnet-api/caching.md)                     | `HybridCache` keys and invalidation                             |
| [typescript/language.md](typescript/language.md)                   | Strict mode, no `any`                                           |
| [typescript/types.md](typescript/types.md)                         | DTO sourcing and discriminated unions                           |
| [typescript/async-errors.md](typescript/async-errors.md)           | Timeouts, `AbortSignal`, typed errors                           |
| [typescript/modules-imports.md](typescript/modules-imports.md)     | Extensionless imports, barrels, `import type`                   |
| [web/features.md](web/features.md)                                 | Feature-folder ownership and barrels                            |
| [web/routes.md](web/routes.md)                                     | Thin route files                                                |
| [web/tanstack-query.md](web/tanstack-query.md)                     | `queryOptions` factories, keys, hydration                       |
| [web/server-functions.md](web/server-functions.md)                 | Server functions as the only API path                           |
| [web/components-styling.md](web/components-styling.md)             | shadcn/Tailwind conventions, a11y floor                         |
| [monorepo/workspace-turbo.md](monorepo/workspace-turbo.md)         | Workspace and Turbo task rules                                  |
| [monorepo/codegen-pipeline.md](monorepo/codegen-pipeline.md)       | The generated-contract pipeline                                 |
| [monorepo/commands.md](monorepo/commands.md)                       | The canonical command surface                                   |
| [testing/api-testing.md](testing/api-testing.md)                   | API test types and placement                                    |
| [testing/web-testing.md](testing/web-testing.md)                   | Web test colocations and boundaries                             |
| [testing/discipline.md](testing/discipline.md)                     | What tests must never do                                        |
