# Agent Harness: TanStack Start + .NET Modular Monolith (Vertical Slices)

Rules, skills, and hooks that equip any coding agent (Copilot, Claude Code, Codex, Cursor) to build a TanStack Start + .NET modular-monolith monorepo — from scaffolding the workspace to planning, implementing, and reviewing every vertical.

## Catalog

| Component                                                          | What it is                                                                                 | Loaded                      | Status |
| ------------------------------------------------------------------ | ------------------------------------------------------------------------------------------ | --------------------------- | ------ |
| [AGENTS.md](AGENTS.md)                                             | The slim always-on contract: precedence, stack, commands, boundary digest, completion gate | Always                      | Ready  |
| [CLAUDE.md](CLAUDE.md)                                             | Claude Code shim — imports `AGENTS.md`                                                     | Always (Claude)             | Ready  |
| [docs/architecture.md](docs/architecture.md)                       | The complete normative architecture every artifact cites                                   | On demand                   | Ready  |
| [rules/](rules/README.md)                                          | Durable standards in seven opt-in packs, installed per agent role                          | Always (per installed pack) | Ready  |
| [skills/](skills/README.md)                                        | Procedures for repeatable stack tasks: scaffold, plan, slice, module, migration, codegen, web feature, review, repair | When the task matches       | Ready  |
| [hooks/](hooks/README.md)                                          | Deterministic guards (generated-file edits, contract drift, format, verify)                | On harness/git events       | Ready  |
| [docs/usage.md](docs/usage.md), [docs/install.md](docs/install.md) | How to drive the framework; what `install.sh` generates per harness                        | Human reference             | Ready  |
| [templates/](templates/README.md)                                  | ADR, glossary, and feature-spec seeds for a consuming repository                           | Copied out                  | Ready  |
| [install.sh](install.sh)                                           | One-command installer: vendors the catalog and generates every harness-specific copy       | Run per consuming repo      | Ready  |

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

Then review and commit the generated files. Re-run the same command to upgrade; `--uninstall` removes exactly what was installed.

Common variations:

```bash
./install.sh --target . --harness claude,copilot        # only some harnesses
./install.sh --target . --packs api                     # API-only role: common+csharp+dotnet-api+testing
./install.sh --target . --hooks --git-hooks             # also wire edit guards and pre-commit/pre-push
./install.sh --target . --dry-run                       # show the plan, write nothing
./install.sh --target . --uninstall                     # remove everything from the last run
```

What it does, in one pass:

1. Vendors the canonical catalog into `<target>/harness/` (`AGENTS.md`, `docs/`, `rules/`, `skills/`, `hooks/`, `templates/`). This stays the single source of truth inside your repo.
2. Writes the always-on contract at the root: `AGENTS.md` (Copilot, Codex, Cursor read it natively) and `CLAUDE.md` (`@AGENTS.md`). Existing, hand-written root files are never overwritten without `--force`.
3. Generates each harness's native copies — rules with translated frontmatter (`applyTo` / `paths` / `globs`) and skills — and rewrites every relative link so it points back into `harness/`.
4. Records every path in `harness/.install-manifest`, so re-runs replace stale files and `--uninstall` is exact.

Requirements: bash 3.2+, `awk`, `sed`, `find`; `git` only when the catalog is fetched. Full option reference: `./install.sh --help`; what lands where, per harness: [docs/install.md](docs/install.md).

## What this framework deliberately excludes

Runtime software is out of scope for a template: memory vaults, continuous-learning loops, eval pipelines, security scanners, and plugin manifests. ECC-style add-ons of that kind can coexist with this catalog — they consume the same `AGENTS.md` contract and rules — but they are products, not template content. The only executable here is `install.sh`, a dependency-free generator that copies and translates the catalog; it runs at install time, never alongside the agent.

## Layout

```text
dotnet-tanstack-mono-skills/
├── README.md            # this file
├── install.sh           # one-command installer (see Installation)
├── AGENTS.md            # always-on contract
├── CLAUDE.md            # @AGENTS.md import
├── docs/
│   ├── architecture.md  # the authority
│   ├── usage.md         # driving the framework
│   └── install.md       # what install.sh generates per harness
├── rules/               # seven packs + README
├── skills/              # eleven procedures + README
├── hooks/               # four guard scripts + README
├── templates/           # ADR, glossary, feature-spec seeds
└── tests/               # install.sh end-to-end tests (run in CI)
```
