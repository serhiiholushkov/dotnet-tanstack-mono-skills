# Agents

Agents are scoped workers an orchestrating agent (or a human) delegates to: one planner and three read-only reviewers. Each runs with its own context window, a narrow tool set, and an explicit output contract — so a review is a report you can act on, not a conversation.

Reviewers never edit. Their `tools` frontmatter grants `read` and `search`, plus `execute` only where read-only commands are needed (`git diff`, running the architecture tests, regenerating documents to confirm freshness). The planner produces a plan artifact; implementation stays with the main agent, following [../skills/](../skills/README.md).

## Format

One file per agent with frontmatter and an output contract:

```yaml
---
name: boundary-auditor
description: 'What it reviews and when to delegate to it — written for discovery.'
tools: read, search, execute
---
```

The `tools` list is canonical shorthand; installation maps it to each harness's permission mechanism. The body defines the scope of review (citing rules — never restating them) and the exact report format the agent must return.

## Catalog

| Agent                                        | Delegate when                                                                | Output                                            |
| -------------------------------------------- | ---------------------------------------------------------------------------- | ------------------------------------------------- |
| [planner.md](planner.md)                     | A feature needs a reviewable plan before code                                | The plan artifact defined by `plan-feature`       |
| [boundary-auditor.md](boundary-auditor.md)   | A diff touches more than one slice/module/feature, or pre-merge              | Findings table (file:line) + clean areas checked  |
| [contract-reviewer.md](contract-reviewer.md) | A diff touches `apps/api/openapi`, endpoints, or `Response` types            | Verdict + per-operation findings + classification |
| [security-reviewer.md](security-reviewer.md) | A diff touches endpoints, handlers, server functions, configuration, or auth | Findings with severity + checked-clean list       |

Typical review pass on a full vertical: `boundary-auditor` always, `contract-reviewer` when the OpenAPI diff is non-empty, `security-reviewer` when auth/config/server functions changed. Findings route back to the main agent; a High finding blocks completion.

## Installation

The catalog here is canonical; installed copies are regenerated, never edited. `install.sh` maps the canonical `tools` shorthand per harness:

- **GitHub Copilot** — `.github/agents/<name>.agent.md`; `read`, `search`, `execute` are native tool aliases and pass through.
- **Claude Code** — `.claude/agents/<name>.md`; `read`→`Read`, `search`→`Grep, Glob`, `execute`→`Bash`.
- **Codex** — no subagent directory; each agent becomes a skill in `.agents/skills/<name>/` with its read-only scope stated in the body.
- **Cursor** — no agent-file directory; each agent becomes a skill in `.cursor/skills/<name>/` the same way.

Details live in [../docs/install.md](../docs/install.md).
