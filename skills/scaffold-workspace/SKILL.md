---
name: scaffold-workspace
description: 'Bootstrap the whole monorepo from an empty folder: root pins and workspace files, Turbo wiring, the .NET solution with Common.* projects and the Api host, the web tooling packages, api-client codegen package, the TanStack Start app, Docker Compose for PostgreSQL, and CI. Use whenever a repository for this stack does not exist yet — when asked to create, initialize, set up, or start a new project, app, workspace, or monorepo with .NET and React/TanStack, even if the request only names the product ("build me an ordering app") and never says "scaffold". Run it before any feature work; business modules come afterwards via add-module. Trigger terms: scaffold, bootstrap, new repo, init workspace, project setup, monorepo skeleton, greenfield, from scratch.'
---

# Scaffold the workspace

Builds the repository skeleton in verifiable stages. Every file's exact content lives in the references; this body is the order and the checks. Each stage ends with something runnable, because a skeleton assembled in one pass fails in one undiagnosable pile — a stage that does not pass its check is fixed before the next begins.

Version numbers shown in references are pinned examples — pin to the current LTS/stable at scaffold time, but never change the majors fixed by the architecture (.NET 10, Node 24, React 19, TanStack Start 1, Tailwind 4, Turborepo 2). Look versions up rather than guessing: `npm view <package> version` for npm packages, `dotnet --list-sdks` for the SDK pin in `global.json`, and `dotnet package search <id> --exact-match` (or the NuGet gallery) for `Directory.Packages.props`.

## Before you start

- **Toolchain.** Confirm `node --version` is 24.x, `corepack enable` has made `pnpm` available (the root `packageManager` field then pins the exact version), `dotnet --version` reports a 10.x SDK, and Docker is running. Missing prerequisites are reported to the user, not worked around — the pins exist so every machine builds the same thing.
- **Target folder.** An empty directory or a metadata-only repository, including `README`, `LICENSE`, `.git`, existing project instructions, and an installed harness (`.agents/`, `docs/`, and native `.claude/`, `.github/`, or `.cursor/` adapters). Preserve these assets; their presence is not application code. If the target already contains application code, this is not a scaffold task; stop and say so.
- **Harness authority.** Read [the architecture](../../docs/architecture.md) before scaffolding. Installation supplies the shared catalog, not project root contracts; create those only in the final step below.
- **Names.** Workspace packages use the `@repo/*` scope (`@repo/api`, `@repo/web`, `@repo/api-client`, …) regardless of product name — the scope is internal and the product name belongs in the first module, not the skeleton.

## Procedure

1. **Root files** — [references/root-files.md](references/root-files.md): root `package.json` (with `packageManager` pin and the `dev|lint|typecheck|test|build|generate|verify` scripts), `pnpm-workspace.yaml`, `turbo.json` (the codegen edge and caching rules), `global.json`, `.config/dotnet-tools.json`, `.gitignore`, `.env.example`, `docker-compose.yml` (PostgreSQL on 5432).
   _Check:_ `pnpm install` succeeds; `dotnet tool restore` succeeds; `docker compose up -d db` starts PostgreSQL.
2. **Web tooling packages** — [references/web-packages.md](references/web-packages.md) §1: `packages/typescript-config` (strict, bundler resolution) and `packages/eslint-config` (boundaries, generated-file read-only overrides).
   _Check:_ both resolve as workspace deps.
3. **API solution** — [references/api-solution.md](references/api-solution.md): `apps/api` with `Api.slnx`, `Directory.Build.props`, `Directory.Packages.props`, four `Common.*` projects, the `Api` host (Program.cs, `launchSettings.json` on port 5000, build-time OpenAPI into `apps/api/openapi`), the thin `package.json` wrapper, and test projects. Seed `Common.*` with the kernel primitives — [references/common-kernel.md](references/common-kernel.md): `Result`/`Error`/`ErrorType`, messaging interfaces, decorators, `IEndpoint` + discovery, `CustomResults`, `Tags`/`ApiVersions`, schema-reference-id config, global exception handler, health checks.
   _Check:_ `pnpm --filter @repo/api build` compiles and writes `apps/api/openapi/v1.json`; `pnpm --filter @repo/api dev` serves `/health/live` on `:5000`.
4. **api-client and ui packages** — [references/web-packages.md](references/web-packages.md) §2–3: `packages/api-client` (`generate` script running `openapi-typescript` per version document, config-free `client.ts` factory, curated `index.ts`) and `packages/ui` (shadcn primitives + tokens).
   _Check:_ `pnpm turbo run build generate` produces `packages/api-client/src/v1.gen.ts`.
5. **Web app** — [references/web-packages.md](references/web-packages.md) §4: `apps/web` TanStack Start app on port 3000 — Vite config, router with per-request `QueryClient` + SSR Query integration, `src/routes/`, `src/features/`, `lib/` (validated server-only config, `api-client` instantiation), Tailwind 4 + `components.json`, Vitest setup.
   _Check:_ `pnpm dev` serves `:3000` and the app reaches the API through a server function.
6. **CI** — [references/ci.md](references/ci.md): the workflow running install, restore, `pnpm verify` (lint, typecheck, test, build, drift check) with pnpm and .NET caching and a PostgreSQL service/Testcontainers support.
   _Check:_ workflow file lints (`act` or a draft PR).
7. **Feature-work handoff** — do **not** invent a module here. After completing the full gate and project contracts below, use [add-module](../add-module/SKILL.md) for the first real business module, then [add-vertical-slice](../add-vertical-slice/SKILL.md) and [add-web-feature](../add-web-feature/SKILL.md) for the first vertical.
8. **Full gate** — `pnpm verify` passes end to end on the skeleton (with zero modules the OpenAPI documents still generate from the host's registered versions).
9. **Project agent contracts** — create root `AGENTS.md` and `CLAUDE.md` only after the skeleton passes the full gate. Derive their guidance from this application, not the catalog repository's root files.
   - In `AGENTS.md`, record the actual project purpose, workspace layout, verified setup/development/gate commands, pinning surfaces, architecture precedence, and relevant boundary/ADR rules. Link to the target's `docs/architecture.md`, `.agents/rules/README.md`, `.agents/skills/README.md`, `.agents/hooks/README.md`, and `.agents/templates/README.md`; do not use the catalog's source-layout paths (`rules/`, `skills/`, `hooks/`, `templates/`) or its repository-only installation/usage guides.
   - Make `CLAUDE.md` import `@AGENTS.md`; add only genuinely Claude-specific project guidance, not a second copy of the contract.
   - Preserve existing project instructions. If a root contract exists, propose the necessary merge and obtain approval before changing it; never blindly replace it with a template.
   - Keep both contracts project-owned: do not add them to the harness installation manifest.
   _Check:_ both contracts describe files and commands that now exist, every local Markdown link resolves from the project root, and `CLAUDE.md` imports that root `AGENTS.md`.

## Done when

- [ ] A fresh clone needs only `pnpm install`, `dotnet tool restore`, `docker compose up -d db`, `pnpm dev` to run web (`:3000`) + API (`:5000`).
- [ ] All five pinning surfaces exist and agree: `global.json`, `packageManager`, `Directory.Packages.props`, `.config/dotnet-tools.json`, `pnpm-lock.yaml`.
- [ ] `turbo.json` encodes: `@repo/api#build` uncached with `openapi/*.json` outputs; `@repo/api-client#generate` depending on it with `$TURBO_ROOT$` inputs; `@repo/web#build` + `typecheck` depending on generate; `dev` persistent.
- [ ] The drift check runs clean on the skeleton; generated files are git-tracked.
- [ ] CI runs `pnpm verify` green.
- [ ] Root `AGENTS.md` and `CLAUDE.md` were generated or explicitly merged at the end for this application, with valid installed-harness links, no copied catalog contract, and no installer ownership.
- [ ] No business module or product code was invented — the skeleton is product-agnostic.
