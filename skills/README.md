# Skills

Skills are on-demand procedures for repeatable tasks in this stack. A skill owns the _how_ — decision points, steps, a worked example, and a done-when checklist. It never restates standards: those live in [../rules/](../rules/README.md) and [../docs/architecture.md](../docs/architecture.md), which skills cite.

Skills are the only task-level artifact in the catalog. Procedures that build (`add-vertical-slice`, `add-web-feature`, …), the one that plans (`plan-feature`), and the one that reviews (`review-changes`) share the same shape, so every harness exposes the same names. The two read-only skills say so in their body; a harness with subagents can run them in an isolated, read-only context, and one without simply follows the instruction not to edit.

## Format and discovery

Each skill is a folder with a `SKILL.md`:

```yaml
---
name: add-vertical-slice
description: 'Purpose, "use when" guidance, and trigger terms — written for the harness to match against the task.'
---
```

The body stays under ~150 lines: decision points, the procedure, a stack-correct example, and "done when". Depth beyond that lives in `references/*.md` inside the same folder (progressive disclosure — read them only when the body points there). Explain the _why_ next to each instruction rather than stacking imperatives: an agent that understands the reason generalizes to the case the skill did not foresee.

Harnesses discover skills by their frontmatter `description`, so a description states what the skill does **and** the situations that should trigger it, including phrasings that do not name the skill. When a task matches a skill, follow the skill instead of improvising; when two skills apply (an API slice plus its web feature), run them in pipeline order — API first, regenerate, then web.

## Index

| Skill                                                              | Use when                                                           |
| ------------------------------------------------------------------ | ------------------------------------------------------------------ |
| [scaffold-workspace/](scaffold-workspace/SKILL.md)                 | Bootstrapping the whole repository from an empty folder            |
| [plan-feature/](plan-feature/SKILL.md)                             | Turning a feature request into a reviewable plan before any code   |
| [add-module/](add-module/SKILL.md)                                 | Creating a new business module (ADR-gated)                         |
| [add-vertical-slice/](add-vertical-slice/SKILL.md)                 | Adding one use case (endpoint) to an existing module               |
| [add-ef-migration/](add-ef-migration/SKILL.md)                     | Changing a module's schema                                         |
| [cross-module-communication/](cross-module-communication/SKILL.md) | One module needs another module's data or must react to it         |
| [regenerate-api-client/](regenerate-api-client/SKILL.md)           | Refreshing OpenAPI docs + TypeScript client; fixing drift failures |
| [add-web-feature/](add-web-feature/SKILL.md)                       | Adding the web side: feature folder, adapters, queries, UI, route  |
| [version-endpoint/](version-endpoint/SKILL.md)                     | Making a breaking change to a released endpoint                    |
| [review-changes/](review-changes/SKILL.md)                         | Read-only review of a diff: boundaries, contract, security         |
| [fix-verify-failures/](fix-verify-failures/SKILL.md)               | `pnpm verify` or CI is red and needs triage                        |

A full vertical runs top to bottom: plan → (module) → slice → migration → regenerate → web → review → verify.

## Installation

The catalog here is canonical; installed copies are regenerated, never edited. `install.sh` copies every skill folder (including `references/`) and rewrites links that leave the folder so they point back into the vendored catalog:

- **GitHub Copilot** — `.github/skills/<name>/`.
- **Claude Code** — `.claude/skills/<name>/`.
- **Codex** — `.agents/skills/<name>/` (repo-shared; user-level `~/.agents/skills/` is not managed by the installer).
- **Cursor** — `.cursor/skills/<name>/`.

Details live in [../docs/install.md](../docs/install.md).
