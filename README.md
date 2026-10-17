# Agent Harness: TanStack Start + .NET Modular Monolith (Vertical Slices)

Rules, skills, and hooks that equip any coding agent (Copilot, Claude Code, Codex, Cursor) to build a TanStack Start + .NET modular-monolith monorepo — from scaffolding the workspace to planning, implementing, and reviewing every vertical.

## Catalog

| Component                                                          | What it is                                                                                 | Loaded                      | Status |
| ------------------------------------------------------------------ | ------------------------------------------------------------------------------------------ | --------------------------- | ------ |
| [AGENTS.md](AGENTS.md)                                             | This catalog repository's contract; never copied into consuming repositories              | This repository only        | Ready  |
| [CLAUDE.md](CLAUDE.md)                                             | This repository's Claude Code shim — imports `AGENTS.md`                                  | This repository only        | Ready  |
| [docs/architecture.md](docs/architecture.md)                       | The complete normative architecture every artifact cites                                   | On demand                   | Ready  |
| [rules/](rules/README.md)                                          | Durable standards in seven opt-in packs, installed per agent role                          | Always (per installed pack) | Ready  |
| [skills/](skills/README.md)                                        | Procedures for repeatable stack tasks: scaffold, plan, slice, module, migration, codegen, web feature, review, repair | When the task matches       | Ready  |
| [hooks/](hooks/README.md)                                          | Deterministic guards (generated-file edits, contract drift, format, verify)                | On harness/git events       | Ready  |
| [docs/catalog/usage.md](docs/catalog/usage.md), [docs/catalog/install.md](docs/catalog/install.md) | Repository-only usage and installation guides; excluded from installation | Human reference             | Ready  |
| [templates/](templates/README.md)                                  | ADR, glossary, and feature-spec seeds for a consuming repository                           | Copied out                  | Ready  |
| [install.sh](install.sh)                                           | One-command installer: shared skills, native adapters, ownership-aware updates             | Run per consuming repo      | Ready  |

## Installation

One command installs everything into a consuming repository — for Claude Code, GitHub Copilot / VS Code, Codex, and Cursor at once:

```bash
# without cloning
curl -fsSL https://raw.githubusercontent.com/serhiiholushkov/dotnet-tanstack-mono-skills/main/install.sh \
  | bash -s -- --target /path/to/your-repo

# or from a checkout
git clone https://github.com/serhiiholushkov/dotnet-tanstack-mono-skills.git
./dotnet-tanstack-mono-skills/install.sh --target /path/to/your-repo
```

Then review and commit the installed files, symlinks, and catalog-specific ownership manifest. Re-run the same command to safely upgrade unchanged files; local edits are preserved with warnings. `--force` (alias `--hard`) replaces edited catalog-owned files, never files from other catalogs.

Common variations:

```bash
./install.sh --target . --harness claude,copilot        # only some harnesses
./install.sh --target . --packs api                     # API-only role: common+csharp+dotnet-api+testing
./install.sh --target . --hooks --git-hooks             # also wire edit guards and pre-commit/pre-push
./install.sh --target . --dry-run                       # show the plan, write nothing
./install.sh --target . --hard                          # replace edited files owned by this catalog
./install.sh --target . --uninstall                     # remove unchanged owned files; preserve edits
./install.sh --target . --uninstall --force             # also remove edited owned files
```

What it does, in one pass:

1. Installs skills once in `<target>/.agents/skills/`, with neutral rules, hook scripts, and templates alongside them under `.agents/`. Harness documentation goes in the root `docs/` directory, not an extra `harness/` tree. Repository-only guides under `docs/catalog/` are excluded.
2. Leaves root `AGENTS.md` and `CLAUDE.md` untouched. For a new application, [scaffold-workspace](skills/scaffold-workspace/SKILL.md) accepts the installed harness and creates project-specific contracts at the end, after validating the skeleton.
3. Uses the shared skill location directly for Copilot, Codex, and Cursor. Claude receives relative per-skill symlinks, with an automatic copy fallback when real symlinks are unavailable. Native rule adapters translate `applyTo` / `paths` / `globs` and reference the shared rule bodies without duplicating them. Markdown links are rewritten for the installed layout.
4. Records exact owned paths and content/link fingerprints in `.agents/catalogs/dotnet-tanstack-mono-skills/.install-manifest`. Updates and uninstall preserve local edits and unrelated files; force affects only previously owned paths.

Edit shared skills and project docs directly; their local changes survive normal reinstalls. Old copy-based installations require explicit `--force` migration because their manifests have no fingerprints. For an old custom catalog directory, also supply its original `--dir`.

Requirements: bash 3.2+ and standard Unix tools; `git` only when fetching the catalog. Full option reference: `./install.sh --help`; layout, update protection, and migration: [docs/catalog/install.md](docs/catalog/install.md).

## What this framework deliberately excludes

Runtime software is out of scope for a template: memory vaults, continuous-learning loops, eval pipelines, security scanners, and plugin manifests. ECC-style add-ons of that kind can coexist with this catalog — they consume the same `AGENTS.md` contract and rules — but they are products, not template content. The installer is dependency-free, copies and translates the catalog, and runs at install time, never alongside the agent.

## Layout

```text
dotnet-tanstack-mono-skills/
├── README.md            # this file
├── install.sh           # one-command installer (see Installation)
├── AGENTS.md            # this repository only; not installed
├── CLAUDE.md            # this repository only; not installed
├── docs/
│   ├── architecture.md  # the authority
│   └── catalog/         # repository-only documentation; not installed
│       ├── usage.md     # driving the framework
│       └── install.md   # what install.sh generates per harness
├── rules/               # seven packs + README
├── skills/              # eleven procedures + README
├── hooks/               # four guard scripts + README
├── templates/           # ADR, glossary, feature-spec seeds
└── tests/               # install.sh end-to-end tests (run in CI)
```
