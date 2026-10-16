# Installation guide — `install.sh`

The catalog is harness-agnostic. `install.sh` installs one shared skill source for Claude Code, GitHub Copilot / VS Code, Codex, and Cursor, plus the native rule and hook adapters each needs.

**One editable source.** Skills live in `.agents/skills/`, and project documentation lives in the repository's root `docs/` directory. Edit those files directly. Normal reinstalls update unchanged catalog-owned files and preserve local edits with warnings. `--force` (alias `--hard`) replaces edited files only when this catalog already owns their paths; it never takes over unmanaged files.

## Quick start

```bash
# without cloning
curl -fsSL https://raw.githubusercontent.com/serhiiholushkov/dotnet-tanstack-mono-skills/main/install.sh \
  | bash -s -- --target /path/to/your-repo

# or from a checkout
./install.sh --target /path/to/your-repo
```

Review the diff and commit the installed files, symlinks, and ownership manifest. Requirements: bash 3.2+ and standard Unix tools, including `awk`, `sed`, `find`, `cksum`, `readlink`, and `ln`; `git` is needed only when fetching the catalog. No package installation or running agent service is required.

## Options

| Option            | Default            | Effect                                                                                                                      |
| ----------------- | ------------------ | --------------------------------------------------------------------------------------------------------------------------- |
| `--target DIR`    | current directory  | Consuming repository root. Refuses to install the catalog into itself.                                                     |
| `--harness LIST`  | `all`              | Comma list of `claude`, `copilot` (alias `vscode`), `codex`, `cursor`.                                                      |
| `--packs LIST`    | `all`              | Always-on rule packs: `all`, a role (`api`, `web`, `reviewer`), or a comma list of pack names. See [rules](../rules/README.md#packs). |
| `--dir NAME`      | `harness`          | Legacy catalog directory to migrate or uninstall. Does not relocate the new shared layout.                                |
| `--hooks`         | off                | Install native hook configs, subject to the same ownership and local-edit protection as other files.                      |
| `--git-hooks`     | off                | Install `pre-commit` (generated-file guard + format gate) and `pre-push` (verify gate) into `.git/hooks`.                    |
| `--no-root`       | off                | Leave `AGENTS.md` / `CLAUDE.md` at the target root alone.                                                                   |
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
├── AGENTS.md
├── CLAUDE.md                         # imports @AGENTS.md when Claude is selected
├── docs/                             # architecture, usage, installation guide
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
│   └── rules/                        # generated native rule adapters
├── .github/instructions/             # generated native rule adapters
└── .cursor/rules/                    # generated native rule adapters
```

Only the selected agents receive native adapters. The shared skills and neutral rule packs are installed once regardless of the selection; `--packs` filters native rule adapters, not the shared reference material. No extra `harness/` payload or Copilot/Cursor skill copies are created.

| Artifact | Shared location | Native entry points |
| -------- | --------------- | ------------------- |
| Contract | root `AGENTS.md` | Copilot, Codex, and Cursor read it; Claude uses root `CLAUDE.md` importing `@AGENTS.md` |
| Documentation | root `docs/` | Linked from the contract, rules, and skills |
| Skills | `.agents/skills/<name>/` | Copilot, Codex, and Cursor read the shared path; Claude receives per-skill symlinks or fallback copies |
| Rules | `.agents/rules/<pack>/*.md` | `.claude/rules/*.md`, `.github/instructions/*.instructions.md`, `.cursor/rules/*.mdc`; Codex follows contract links |
| Hook scripts | `.agents/hooks/scripts/` | Optional `.claude/settings.json`, `.github/hooks/guards.json`, `.cursor/hooks.json`, and git hooks |
| Templates | `.agents/templates/` | Copy and fill in project documents under `docs/` |

Skills are the only task-level artifact: procedures for building (`add-vertical-slice`, `add-web-feature`, …), planning (`plan-feature`), and reviewing (`review-changes`) all ship in the same shape, so every harness exposes the same names. There is no separate command or subagent layer to translate — a harness that supports subagents can still delegate the read-only skills to one, and a harness that supports slash invocation can call any skill by name.

The root `AGENTS.md` is the catalog contract with its links adjusted to the installed layout. Existing unmanaged contracts or project documents are left untouched, even with `--force`; merge the guidance manually instead. The manifest, not a marker comment or matching filename, establishes ownership.

## Symlinks and copy fallback

The installer probes the actual Claude skill destination for real symlink support. When supported, each `.claude/skills/<name>` is a relative directory symlink to `.agents/skills/<name>`. Links remain valid when moving or cloning the repository. Existing unrelated Claude skills are not replaced.

If creating a real symlink fails, including shells that emulate `ln -s` by copying, the installer warns and copies the shared skill into Claude's directory. Copilot, Codex, and Cursor still use the one shared directory; no redundant aliases are added for them.

With symlinks, edits are immediately visible through either path. With fallback copies, re-run the installer to refresh Claude's copy from the effective shared files. Locally edited fallback files are protected just like other owned files. A later reinstall converts owned copies to links when symlinks become available, but preserves a copied directory containing local edits or untracked additions; `--force` authorizes replacing owned edits, never deleting untracked additions.

Different clients can discover overlapping paths. The installer minimizes compatibility aliases, but a single physical source is not a promise that every client version will show exactly one selector entry.

## What the installer translates

**Frontmatter.** The catalog uses one neutral shape per kind; the installer rewrites the keys each harness expects and leaves the body untouched.

| Kind     | Canonical keys                             | Claude Code                                                    | Copilot / VS Code                              | Cursor                                                          |
| -------- | ------------------------------------------ | -------------------------------------------------------------- | ---------------------------------------------- | --------------------------------------------------------------- |
| Rule     | `title`, `description`, `appliesTo` (CSV)  | `description`, `paths:` list; `**/*` rules get no `paths` (always loaded) | `description`, `applyTo: '<csv>'`   | `description`, `globs: <csv>` + `alwaysApply: false`; `**/*` → `alwaysApply: true` |
| Skill    | `name`, `description`                      | unchanged                                                      | unchanged                                      | unchanged                                                       |

**Links.** Relative Markdown links are resolved against the source catalog and rewritten for the new layout. For example, the installed `add-module` skill links to `../../../docs/architecture.md`. Links within a skill folder (`references/...`) stay unchanged. Shared and Claude skill locations have the same depth, so both entry points resolve the same links. URLs, anchors, and absolute paths are untouched. Tests check links through both real directories and skill aliases.

**Rules.** Native rule adapters are generated because the clients require different filenames and scoping keys. Prefer editing the shared neutral rules; unchanged adapters regenerate on reinstall. Local edits made directly to an adapter are also preserved unless forced.

## Hooks

`--hooks` installs each selected client's config when absent and safely updates its own unchanged configs. Unmanaged JSON is never merged or replaced: the installer prints a snippet to merge manually. Edited owned JSON is preserved without attempting a merge.

`--git-hooks` installs executable `pre-commit` and `pre-push` hooks unless `core.hooksPath` is set or an unmanaged hook occupies the path. Hook scripts use `.agents/hooks/scripts/`. Script behavior, the support matrix, and manual wiring live in [../hooks/README.md](../hooks/README.md). Codex has no pinned hook schema here; use git hooks and CI.

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

`--no-root` leaves root contracts untouched, including on reinstall. Changing the selected agents, packs, or hook flags removes only obsolete unchanged owned artifacts; edited obsolete artifacts remain tracked until explicitly forced.

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

## Migrating version 1 installations

Old installations have a path-only manifest under `harness/.install-manifest` (or the old custom `--dir`). Without fingerprints, the installer cannot distinguish original files from local edits. A normal run therefore stops before changing the target.

Review or back up edits, then explicitly authorize migration:

```bash
./install.sh --target /path/to/repo --force --dry-run
./install.sh --target /path/to/repo --force
# For a catalog previously installed with --dir .harness:
./install.sh --target /path/to/repo --dir .harness --force
```

Migration removes only paths listed in the legacy manifest, installs the shared layout, and writes the catalog-specific fingerprint manifest. Unlisted files, including additions under the old catalog directory or agent skill directories, stay in place. The old directory disappears only if empty. Existing root-level documentation not owned by the legacy installation is not overwritten. `--dir` now identifies a legacy location only; it does not change the new layout. Legacy uninstall also requires `--force`.

## Harness notes (verified 2026-09)

Harness formats change quickly; re-verify before relying on anything marked Preview or deprecated. These notes explain the choices encoded in the installer and double as the manual procedure if you cannot run it.

**GitHub Copilot / VS Code.** `AGENTS.md` at the root is read natively (`chat.useAgentsMdFile`). Skills are discovered directly in `.agents/skills/`; no `.github/skills/` copy is needed. Instructions discovery is recursive under `.github/instructions/`; `applyTo` takes comma-separated globs relative to the workspace root. If the repo is opened from a subfolder, enable `chat.useCustomizationsInParentRepositories`. Hooks (`.github/hooks/*.json`) are Preview: matchers are ignored and tool input uses camelCase `filePath` - the guard script reads both spellings.

**Claude Code.** `CLAUDE.md` imports `AGENTS.md`. Its `.claude/skills/<name>` entries link to the shared skill folders, or contain fallback copies. Rules in `.claude/rules/*.md` scope by `paths` and load unconditionally without it. To run `plan-feature` or `review-changes` in isolation, delegate to a read-only subagent. Hooks wire through `.claude/settings.json`; `PreToolUse` with matcher `Edit|Write` invokes the guard.

**Codex.** `AGENTS.md` is the native format. Neutral rules stay in `.agents/rules/` and are reached through contract links. Skills live in `.agents/skills/<name>/` and are invoked with `$<name>` or `/skills`. Hook schema is not pinned here; use git hooks and CI.

**Cursor.** `AGENTS.md` at the root is read natively. Skills are discovered directly in `.agents/skills/`; no `.cursor/skills/` copy is needed. Rules require `.mdc`; `globs` is comma-separated and `alwaysApply: true` is used for `**/*` rules. Hooks use `.cursor/hooks.json`.

**Generic `AGENTS.md`-reading harness.** `install.sh --harness codex` installs the shared catalog, root contract, and documentation without native rule adapters. Add `--no-root` when maintaining your own root contract, and link it to the installed architecture, rules, and skills.

Discovery references: [Agent Skills integration](https://agentskills.io/client-implementation/adding-skills-support), [Claude Code](https://code.claude.com/docs/en/skills), [VS Code](https://code.visualstudio.com/docs/agent-customization/agent-skills), [Codex](https://developers.openai.com/codex/skills), [Cursor](https://cursor.com/docs/skills).
