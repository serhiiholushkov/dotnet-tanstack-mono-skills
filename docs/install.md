# Installation guide — `install.sh`

The catalog is harness-agnostic; harnesses read from harness-specific locations with harness-specific frontmatter. `install.sh` (at the catalog root) does that translation in one pass for Claude Code, GitHub Copilot / VS Code, Codex, and Cursor.

**The single-source rule.** The catalog is canonical. Installed copies are disposable build outputs: regenerate them by re-running the installer, never edit them in place, and never let them drift into a second source of truth. Treat a hand-edited installed copy the same way this architecture treats a hand-edited generated client — revert and regenerate.

## Quick start

```bash
# without cloning
curl -fsSL https://raw.githubusercontent.com/serhiiholushkov/dotnet-tanstack-mono-skills/main/install.sh \
  | bash -s -- --target /path/to/your-repo

# or from a checkout
./install.sh --target /path/to/your-repo
```

Review the diff, commit it. Requirements: bash 3.2+, `awk`, `sed`, `find`; `git` only when the catalog has to be fetched.

## Options

| Option            | Default            | Effect                                                                                                                      |
| ----------------- | ------------------ | --------------------------------------------------------------------------------------------------------------------------- |
| `--target DIR`    | current directory  | Consuming repository root. Refuses to install the catalog into itself.                                                     |
| `--harness LIST`  | `all`              | Comma list of `claude`, `copilot` (alias `vscode`), `codex`, `cursor`.                                                      |
| `--packs LIST`    | `all`              | Always-on rule packs: `all`, a role (`api`, `web`, `reviewer`), or a comma list of pack names. See [rules](../rules/README.md#packs). |
| `--dir NAME`      | `harness`          | Folder name for the vendored catalog inside the target.                                                                     |
| `--hooks`         | off                | Write harness hook configs when absent: `.claude/settings.json`, `.github/hooks/guards.json`, `.cursor/hooks.json`.         |
| `--git-hooks`     | off                | Install `pre-commit` (generated-file guard + format gate) and `pre-push` (verify gate) into `.git/hooks`.                    |
| `--no-root`       | off                | Leave `AGENTS.md` / `CLAUDE.md` at the target root alone.                                                                   |
| `--force`         | off                | Overwrite an existing root `AGENTS.md` / `CLAUDE.md` that the installer did not generate.                                   |
| `--source DIR`    | script's directory | Use another catalog checkout as the source.                                                                                 |
| `--ref REF`       | default branch     | Branch or tag to clone when fetching (`curl \| bash` mode).                                                                 |
| `--dry-run`       | off                | Print every path that would be written; change nothing.                                                                     |
| `--uninstall`     | off                | Remove everything recorded in `<dir>/.install-manifest` from the previous run.                                              |
| `HARNESS_REPO`    | this repository    | Environment variable: clone URL used when the catalog is fetched.                                                           |

Role shortcuts for `--packs`: `api` = `common,csharp,dotnet-api,testing`; `web` = `common,typescript,web,testing`; `reviewer` = `common,monorepo`.

## What lands where

Everything below is relative to `--target`; `harness/` is the `--dir` name.

| Artifact | Canonical            | `harness/` (always) | Claude Code                    | GitHub Copilot / VS Code                                      | Codex                                   | Cursor                                   |
| -------- | -------------------- | ------------------- | ------------------------------ | ------------------------------------------------------------- | --------------------------------------- | ---------------------------------------- |
| Contract | `AGENTS.md`          | `harness/AGENTS.md` | `CLAUDE.md` → `@AGENTS.md`     | root `AGENTS.md` (native)                                     | root `AGENTS.md` (native)               | root `AGENTS.md` (native)                |
| Rules    | `rules/<pack>/*.md`  | verbatim            | `.claude/rules/<pack>-<name>.md` (`paths`) | `.github/instructions/<pack>-<name>.instructions.md` (`applyTo`) | linked from `AGENTS.md` only   | `.cursor/rules/<pack>-<name>.mdc` (`globs`, `alwaysApply`) |
| Skills   | `skills/<name>/`     | verbatim            | `.claude/skills/<name>/`       | `.github/skills/<name>/`                                      | `.agents/skills/<name>/`                | `.cursor/skills/<name>/`                 |
| Hooks    | `hooks/scripts/`     | verbatim, executable | `.claude/settings.json` (`--hooks`) | `.github/hooks/guards.json` (`--hooks`, Preview)        | git hooks (`--git-hooks`)               | `.cursor/hooks.json` (`--hooks`)         |

Skills are the only task-level artifact: procedures for building (`add-vertical-slice`, `add-web-feature`, …), planning (`plan-feature`), and reviewing (`review-changes`) all ship in the same shape, so every harness exposes the same names. There is no separate command or subagent layer to translate — a harness that supports subagents can still delegate the read-only skills to one, and a harness that supports slash invocation can call any skill by name.

The root `AGENTS.md` is the catalog contract with its links re-pointed into `harness/`; the first line is a marker comment so the installer can tell its own copy from a hand-written one.

## What the installer translates

**Frontmatter.** The catalog uses one neutral shape per kind; the installer rewrites the keys each harness expects and leaves the body untouched.

| Kind     | Canonical keys                             | Claude Code                                                    | Copilot / VS Code                              | Cursor                                                          |
| -------- | ------------------------------------------ | -------------------------------------------------------------- | ---------------------------------------------- | --------------------------------------------------------------- |
| Rule     | `title`, `description`, `appliesTo` (CSV)  | `description`, `paths:` list; `**/*` rules get no `paths` (always loaded) | `description`, `applyTo: '<csv>'`   | `description`, `globs: <csv>` + `alwaysApply: false`; `**/*` → `alwaysApply: true` |
| Skill    | `name`, `description`                      | unchanged                                                      | unchanged                                      | unchanged                                                       |

**Links.** Every artifact cross-references the rest of the catalog by relative path (`../../docs/architecture.md`, `../common/security.md`). A copied file would break those, so the installer resolves each relative link against the vendored catalog and rewrites it relative to the generated file's location — e.g. `.claude/skills/add-module/SKILL.md` links to `../../../harness/docs/architecture.md`. Links that stay inside a skill folder (`references/…`) are kept as they are. URLs, anchors, and absolute paths are never touched. The test suite asserts that every generated link resolves.

**Root files.** `AGENTS.md` and `CLAUDE.md` at the target root are written only when absent or when the installer generated them (marker comment). A hand-written file is left alone with a warning; use `--force` to take it over. For an unmanaged `CLAUDE.md`, adding the single line `@AGENTS.md` is enough.

## Hooks

`--hooks` writes each harness's hook config only when the file does not exist; an existing config is never merged — the installer prints the snippet to paste instead. `--git-hooks` installs `pre-commit` and `pre-push` into `.git/hooks` unless `core.hooksPath` is set (husky, lefthook) or an unmanaged hook already exists, in which case it prints what to add. Script behaviour, the support matrix, and the CI wiring live in [../hooks/README.md](../hooks/README.md). Codex has no pinned hook schema; use git hooks and CI there.

## Updating, re-installing, uninstalling

Every path the installer writes is recorded in `harness/.install-manifest` together with the source revision and the options used. On the next run the installer first removes everything from that manifest, then installs fresh — renamed or removed catalog files do not linger. `--uninstall` performs only the first half.

Safety rules on removal: root `AGENTS.md`/`CLAUDE.md` and git hooks are removed only if they still carry the installer's marker; a hook config (`.claude/settings.json`, …) is removed only if it is byte-identical to what the installer generated. Anything you changed stays, with a warning.

To pin a version, pass `--ref <tag-or-branch>` in `curl | bash` mode or run the script from a checkout at that revision.

## Multi-harness installs

Installing into several harnesses simultaneously is the default and the reason the catalog is a single source. Where two harnesses can read the same location (Cursor also loads `.claude/skills/` and `.agents/skills/`; every harness reads `AGENTS.md`), the installer still writes one copy per selected harness so that each can be removed independently; pass a narrower `--harness` list if you prefer shared copies.

## Harness notes (verified 2026-09)

Harness formats change quickly; re-verify before relying on anything marked Preview or deprecated. These notes explain the choices encoded in the installer and double as the manual procedure if you cannot run it.

**GitHub Copilot / VS Code.** `AGENTS.md` at the root is read natively (`chat.useAgentsMdFile`); `CLAUDE.md` is also detected, so the shim causes no conflict. Instructions discovery is recursive under `.github/instructions/`; `applyTo` takes comma-separated globs relative to the workspace root. Skills in `.github/skills/<name>/` are the task-level artifact (prompt files under `.github/prompts/` are deprecated for Agent Host sessions, which is one reason the catalog has no command layer). If the repo is opened from a subfolder, enable `chat.useCustomizationsInParentRepositories`. Hooks (`.github/hooks/*.json`) are Preview: matchers are ignored and tool input uses camelCase `filePath` — the guard script reads both spellings.

**Claude Code.** `CLAUDE.md` imports `AGENTS.md`. Rules in `.claude/rules/*.md` scope by the `paths` list and load unconditionally without it. Skills are native and can be invoked by name. To run `plan-feature` or `review-changes` in isolation, delegate to a subagent with read-only tools — the skill body states the constraint; the harness enforces it. Hooks wire through `.claude/settings.json`; `PreToolUse` with matcher `Edit|Write` → `guard-generated-files --stdin-json` (exit 2 blocks the edit).

**Codex.** `AGENTS.md` is the native format (root merged with nested files down to the working directory, ~32 KiB combined budget; personal defaults in `~/.codex/AGENTS.md`). No glob-scoped rule mechanism is pinned, so rules stay in `harness/rules/` and are reached through the contract's links — link, do not inline, to respect the byte budget. Skills live in `.agents/skills/<name>/` (scanned from the working directory up to the repo root; user-level `~/.agents/skills/`) and are invoked with `$<name>` or `/skills`. Hook schema not pinned; use git hooks and CI.

**Cursor.** `AGENTS.md` at the root is read natively. Rules require the `.mdc` extension; `globs` is comma-separated; `alwaysApply: true` is used only for the `**/*` rules. Skills are invoked with `/<name>` or `@<name>` — slash commands merged into skills, so every skill is also a command. Hooks: `.cursor/hooks.json` (`version: 1`, `preToolUse`, exit 2 = deny).

**Generic `AGENTS.md`-reading harness.** `install.sh --harness codex --no-root` gives the minimum: the vendored catalog plus skills in `.agents/skills/`. Point your harness at `harness/AGENTS.md` (or copy it to the root yourself); the contract links to rules, skills, and the architecture by relative path, so any harness that reads `AGENTS.md` and can follow links gets the full framework without further translation.
