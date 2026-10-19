# Installation guide — `install.sh`

The catalog is harness-agnostic. `install.sh` installs one shared source for skills, rules, hooks, and templates for Claude Code, GitHub Copilot / VS Code, Codex, and Cursor, plus the native references each needs. This guide and [usage.md](usage.md) describe the catalog repository; nothing under `docs/catalog/` is installed.

**One editable source.** Skills, rules, hook scripts, and templates live under `.agents/`, and harness documentation lives in the consuming repository's root `docs/` directory. Edit those files directly. Normal reinstalls update unchanged catalog-owned files and preserve local edits with warnings. `--force` (alias `--hard`) replaces edited files only when this catalog already owns their paths; it never takes over unmanaged files or manages root contracts.

## Quick start

```bash
# without cloning
curl -fsSL https://raw.githubusercontent.com/serhiiholushkov/dotnet-tanstack-mono-skills/main/install.sh \
  | bash -s -- --target /path/to/your-repo

# or from a checkout
./install.sh --target /path/to/your-repo
```

Review the diff and commit the installed files, symlinks, and ownership manifest. Requirements: bash 3.2+ and standard Unix tools, including `awk`, `sed`, `find`, `cksum`, `readlink`, and `ln`; `git` is needed only when fetching the catalog. No package installation or running agent service is required.

For a new application, invoke [scaffold-workspace](../../skills/scaffold-workspace/SKILL.md) next. It accepts a harness-only repository and creates project-specific root `AGENTS.md` and `CLAUDE.md` files at the end, after validating the skeleton. Installation never copies this catalog's root contracts. For an existing application, keep its contracts and link them to the installed architecture and shared catalog.

## Options

| Option            | Default            | Effect                                                                                                                      |
| ----------------- | ------------------ | --------------------------------------------------------------------------------------------------------------------------- |
| `--target DIR`    | current directory  | Consuming repository root. Refuses to install the catalog into itself.                                                     |
| `--harness LIST`  | `all`              | Comma list of `claude`, `copilot` (alias `vscode`), `codex`, `cursor`.                                                      |
| `--packs LIST`    | `all`              | Rule packs: `all`, a role (`api`, `web`, `reviewer`), or a comma list of pack names. See [rules](../../rules/README.md#packs). |
| `--dir NAME`      | `harness`          | Legacy catalog directory to migrate or uninstall. Does not relocate the new shared layout.                                |
| `--hooks`         | off                | Install native hook configs, subject to the same ownership and local-edit protection as other files.                      |
| `--git-hooks`     | off                | Install `pre-commit` (generated-file guard + format gate) and `pre-push` (verify gate) into `.git/hooks`.                    |
| `--no-root`       | unnecessary        | Compatibility no-op. Root `AGENTS.md` / `CLAUDE.md` are always left untouched, including with `--force` or `--uninstall`. |
| `--force`, `--hard` | off              | Replace or remove edited catalog-owned files; also authorize legacy migration. Never overwrite unmanaged content.         |
| `--source DIR`    | script's directory | Use another catalog checkout as the source.                                                                                 |
| `--ref REF`       | default branch     | Branch or tag to clone when fetching (`curl \| bash` mode).                                                                 |
| `--dry-run`       | off                | Print every path that would be written; change nothing.                                                                     |
| `--uninstall`     | off                | Remove unchanged owned paths. Preserve edited paths and their ownership records unless `--force` is supplied.              |
| `HARNESS_REPO`    | this repository    | Environment variable: clone URL used when the catalog is fetched.                                                           |

Role shortcuts for `--packs`: `api` = `common,csharp,dotnet-api,testing`; `web` = `common,typescript,web,testing`; `reviewer` = `common,monorepo`.

## What lands where

Everything below is relative to `--target`:

```text
repo/
├── docs/
│   └── architecture.md               # harness docs only; no docs/catalog/ guides
├── .agents/
│   ├── skills/<name>/                # sole physical skill source
│   ├── rules/                        # canonical neutral rule packs
│   ├── hooks/                        # shared hook scripts and documentation
│   ├── templates/                    # seeds for project documents
│   └── catalogs/dotnet-tanstack-mono-skills/
│       ├── .install-manifest         # this catalog's owned paths and fingerprints
│       └── LICENSE
├── .claude/
│   ├── skills/<name> -> ../../.agents/skills/<name>
│   └── rules/                        # scoped references to shared rules
├── .github/instructions/             # scoped references to shared rules
└── .cursor/rules/                    # scoped references to shared rules
```

Only the selected agents receive native adapters. The shared skills and neutral rule packs are installed once regardless of the selection; `--packs` filters native rule adapters, not the shared reference material. No extra `harness/` payload or Copilot/Cursor skill copies are created.

| Artifact | Shared location | Native entry points |
| -------- | --------------- | ------------------- |
| Contract | root `AGENTS.md`, created by scaffolding, not installation | Copilot, Codex, and Cursor read it; Claude uses scaffolded root `CLAUDE.md` importing `@AGENTS.md` |
| Documentation | root `docs/`, excluding the source-only `docs/catalog/` | Linked from the project contract, rules, and skills |
| Skills | `.agents/skills/<name>/` | Copilot, Codex, and Cursor read the shared path; Claude receives per-skill symlinks or fallback copies |
| Rules | `.agents/rules/<pack>/*.md` | Scoped, reference-only `.claude/rules/*.md`, `.github/instructions/*.instructions.md`, `.cursor/rules/*.mdc`; Codex follows project-contract links |
| Hook scripts | `.agents/hooks/scripts/` | Optional `.claude/settings.json`, `.github/hooks/guards.json`, `.cursor/hooks.json`, and git hooks |
| Templates | `.agents/templates/` | Copy and fill in project documents under `docs/` |

Skills are the only task-level artifact: procedures for building (`add-vertical-slice`, `add-web-feature`, …), planning (`plan-feature`), and reviewing (`review-changes`) all ship in the same shape, so every harness exposes the same names. There is no separate command or subagent layer to translate — a harness that supports subagents can still delegate the read-only skills to one, and a harness that supports slash invocation can call any skill by name.

Root contracts are project-owned and are never added to the installation manifest. Existing contracts are left untouched, even with `--force` or `--uninstall`. Other unmanaged project documents are also preserved; the manifest, not a marker comment or matching filename, establishes catalog ownership.

## Symlinks and copy fallback

The installer probes the actual Claude skill destination for real symlink support. When supported, each `.claude/skills/<name>` is a relative directory symlink to `.agents/skills/<name>`. Links remain valid when moving or cloning the repository. Existing unrelated Claude skills are not replaced.

If creating a real symlink fails, including shells that emulate `ln -s` by copying, the installer warns and copies the shared skill into Claude's directory. Copilot, Codex, and Cursor still use the one shared directory; no redundant aliases are added for them.

With symlinks, edits are immediately visible through either path. With fallback copies, re-run the installer to refresh Claude's copy from the effective shared files. Locally edited fallback files are protected just like other owned files. A later reinstall converts owned copies to links when symlinks become available, but preserves a copied directory containing local edits or untracked additions; `--force` authorizes replacing owned edits, never deleting untracked additions.

Different clients can discover overlapping paths. The installer minimizes compatibility aliases, but a single physical source is not a promise that every client version will show exactly one selector entry.

## What the installer translates

**Frontmatter.** The catalog uses one neutral shape per kind; the installer translates rule metadata into the keys each harness expects. Each rule adapter's body instructs the agent to read and follow the canonical rule, rather than duplicating its contents.

| Kind     | Canonical keys                             | Claude Code                                                    | Copilot / VS Code                              | Cursor                                                          |
| -------- | ------------------------------------------ | -------------------------------------------------------------- | ---------------------------------------------- | --------------------------------------------------------------- |
| Rule     | `title`, `description`, `appliesTo` (CSV)  | `description`, `paths:` list; `**/*` rules get no `paths` (always loaded) | `description`, `applyTo: '<csv>'`   | `description`, `globs: <csv>` + `alwaysApply: false`; `**/*` → `alwaysApply: true` |
| Skill    | `name`, `description`                      | unchanged                                                      | unchanged                                      | unchanged                                                       |

**Links.** Relative Markdown links are resolved against the source catalog and rewritten for the new layout. For example, the installed `add-module` skill links to `../../../docs/architecture.md`. Links within a skill folder (`references/...`) stay unchanged. Shared and Claude skill locations have the same depth, so both entry points resolve the same links. URLs, anchors, and absolute paths are untouched. Tests check links through both real directories and skill aliases.

**Rules.** Native adapters contain only scoping metadata and a relative Markdown reference with an explicit instruction to read and follow the shared rule before working on matching files. File references are supported by [VS Code](https://code.visualstudio.com/docs/agent-customization/custom-instructions), [Claude Code](https://code.claude.com/docs/en/memory), and [Cursor](https://cursor.com/docs/rules). These are agent-read references, not a promise that every client automatically inlines linked content. Rule bodies are never copied into adapters, even when filesystem symlinks are unavailable.

Edit rule bodies in `.agents/rules/`; agents read those edits without regenerating copies. Reinstall after changing scoping metadata so native frontmatter stays current. Local edits made directly to an adapter are preserved unless forced; this also means an edited adapter from an old copy-based installation can remain until reviewed and replaced with `--force`.

## Hooks

`--hooks` installs each selected client's config when absent and safely updates its own unchanged configs. Unmanaged JSON is never merged or replaced: the installer prints a snippet to merge manually. Edited owned JSON is preserved without attempting a merge.

`--git-hooks` installs executable `pre-commit` and `pre-push` hooks unless `core.hooksPath` is set or an unmanaged hook occupies the path. Hook scripts use `.agents/hooks/scripts/`. Script behavior, the support matrix, and manual wiring live in [../../hooks/README.md](../../hooks/README.md). Codex has no pinned hook schema here; use git hooks and CI.

## Updating, re-installing, uninstalling

Ownership is recorded in `.agents/catalogs/dotnet-tanstack-mono-skills/.install-manifest`. Commit it with the installed content. Each non-comment row contains an exact relative path and a tab-separated fingerprint: file contents plus executable status, or a symlink's target text. Fingerprints detect changes; they are not cryptographic signatures.

The catalog identifier prevents this installer from treating another catalog's manifest as its own. A same-name unmanaged skill is skipped as a whole rather than combining two repositories' skill resources.

| Existing path | Normal reinstall | `--force` / `--hard` |
| ------------- | ---------------- | ------------------- |
| Missing desired file | Install or restore it | Same |
| Owned and unchanged | Update it; remove it if obsolete or deselected | Same |
| Owned and locally edited | Preserve it and warn; retain its original fingerprint | Replace or remove the owned path |
| Unmanaged, including another catalog's files | Preserve and warn; do not adopt ownership | Same |
| A directory substituted for an owned file, or a symlinked parent directory | Preserve and warn; never recursively replace or follow it | Same |

If a preserved edit already equals the new upstream file, it can become the new baseline without changing its contents. Unknown files added inside an owned directory are never recursively deleted.

Root contracts are always left untouched, including on reinstall and uninstall. Changing the selected agents, packs, or hook flags removes only obsolete unchanged owned artifacts; edited obsolete artifacts remain tracked until explicitly forced.

`--uninstall` follows the same protection rules. If edited paths remain, their manifest remains too, so a subsequent `--uninstall --force` can remove only those owned paths. Other catalogs, unrelated documentation, and untracked additions remain in place. An interrupted installation saves the ownership state of completed writes so a retry can safely continue.

```bash
./install.sh --target /path/to/repo                  # safe update
./install.sh --target /path/to/repo --dry-run --hard # preview replacing owned edits
./install.sh --target /path/to/repo --hard           # replace owned edits
./install.sh --target /path/to/repo --uninstall      # preserve edited owned files
./install.sh --target /path/to/repo --uninstall --force
```

Review or commit local changes before forcing; force is not a backup mechanism. Update and uninstall processes should not run concurrently against the same repository.

To pin a version, pass `--ref <tag-or-branch>` in `curl | bash` mode or run the script from a checkout at that revision.

## Migrating earlier installations

Version 2 fingerprint manifests upgrade normally. Root `AGENTS.md` and `CLAUDE.md` entries are released from installer ownership without changing or deleting the files, even under `--force` or direct uninstall. Review old catalog-derived contracts and adapt them to the application. Previously installed `docs/install.md` and `docs/usage.md` become obsolete and are removed only under the usual ownership/edit-protection rules. Unchanged full-body rule adapters become references to the shared rules.

Old installations have a path-only manifest under `harness/.install-manifest` (or the old custom `--dir`). Without fingerprints, the installer cannot distinguish original files from local edits. A normal run therefore stops before changing the target.

Review or back up edits, then explicitly authorize migration:

```bash
./install.sh --target /path/to/repo --force --dry-run
./install.sh --target /path/to/repo --force
# For a catalog previously installed with --dir .harness:
./install.sh --target /path/to/repo --dir .harness --force
```

Migration removes only paths listed in the legacy manifest, except root contracts, which are preserved and released from ownership. It installs the shared layout and writes the catalog-specific fingerprint manifest. Unlisted files, including additions under the old catalog directory or agent skill directories, stay in place. The old directory disappears only if empty. Existing root-level documentation not owned by the legacy installation is not overwritten. `--dir` now identifies a legacy location only; it does not change the new layout. Legacy uninstall also requires `--force`.

## Harness notes (verified 2026-10)

Harness formats change quickly; re-verify before relying on anything marked Preview or deprecated. These notes explain the choices encoded in the installer and double as the manual procedure if you cannot run it.

**GitHub Copilot / VS Code.** `AGENTS.md` at the root is read natively (`chat.useAgentsMdFile`). Skills are discovered directly in `.agents/skills/`; no `.github/skills/` copy is needed. Instructions discovery is recursive under `.github/instructions/`; `applyTo` takes comma-separated globs relative to the workspace root. If the repo is opened from a subfolder, enable `chat.useCustomizationsInParentRepositories`. Hooks (`.github/hooks/*.json`) are Preview: matchers are ignored and tool input uses camelCase `filePath` - the guard script reads both spellings.

**Claude Code.** `CLAUDE.md` imports `AGENTS.md`. Its `.claude/skills/<name>` entries link to the shared skill folders, or contain fallback copies. Rules in `.claude/rules/*.md` scope by `paths` and load unconditionally without it. To run `plan-feature` or `review-changes` in isolation, delegate to a read-only subagent. Hooks wire through `.claude/settings.json`; `PreToolUse` with matcher `Edit|Write` invokes the guard.

**Codex.** `AGENTS.md` is the native format. Neutral rules stay in `.agents/rules/` and are reached through contract links. Skills live in `.agents/skills/<name>/` and are invoked with `$<name>` or `/skills`. Hook schema is not pinned here; use git hooks and CI.

**Cursor.** `AGENTS.md` at the root is read natively. Skills are discovered directly in `.agents/skills/`; no `.cursor/skills/` copy is needed. Rules require `.mdc`; `globs` is comma-separated and `alwaysApply: true` is used for `**/*` rules. Hooks use `.cursor/hooks.json`.

**Generic `AGENTS.md`-reading harness.** `install.sh --harness codex` installs the shared catalog and harness documentation without native rule adapters. Scaffolding creates the root contract for a new application. For an existing application, link its own contract to the installed architecture, rules, and skills; no `--no-root` flag is necessary.

Discovery references: [Agent Skills integration](https://agentskills.io/client-implementation/adding-skills-support), [Claude Code](https://code.claude.com/docs/en/skills), [VS Code](https://code.visualstudio.com/docs/agent-customization/agent-skills), [Codex](https://developers.openai.com/codex/skills), [Cursor](https://cursor.com/docs/skills).

## Testing the installer

From the catalog checkout, run `bash tests/install.test.sh` (or `/bin/bash tests/install.test.sh` to explicitly exercise macOS Bash 3.2). The suite prints elapsed seconds at each section and the total duration, and fails if it reaches 600 seconds (10 minutes). It does not scaffold an application or invoke package managers, containers, or model evaluations.

Full-catalog scenarios cover the exact documentation payload, absent root contracts, shared skills/rule bodies/hook scripts/templates, reference adapters, idempotency, scoped packs, link integrity, and piped installation from a local Git fixture containing the current catalog files. A small representative catalog covers updates, conflicts, root ownership release, migrations, copy fallback, and failure recovery without repeatedly installing unrelated catalog content. Snapshot checksums and Markdown link extraction are batched, and manifest lookups use literal in-process keys instead of launching a utility per path. No network access, platform skips, or additional runtime dependencies are needed.

CI runs the same suite on Ubuntu, macOS, and Windows Git Bash. The checkout action uses its Node 24 runtime; the shell-only suite does not require a separate Node setup step.
