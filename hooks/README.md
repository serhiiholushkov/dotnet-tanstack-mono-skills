# Hooks

Hooks are deterministic guards that run outside the model — scripts a harness or git executes at fixed events. They cannot be argued with: a hook that rejects an edit rejects it no matter how the agent was prompted. Nothing in the rules or skills depends on hooks being installed; they are a hard backstop, not the mechanism of the framework.

All scripts are dependency-free POSIX sh (git + standard Unix tools only), live in [scripts/](scripts/), are executable, and support `--help`.

## Catalog

| Script                                                 | Enforces                                                                                                      | Typical wiring                           |
| ------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------- | ---------------------------------------- |
| [guard-generated-files](scripts/guard-generated-files) | No hand edits to `*.gen.ts`, `apps/api/openapi/*.json`, or applied migrations (`**/Database/Migrations/*.cs`) | Agent pre-edit hook; git pre-commit      |
| [check-contract-drift](scripts/check-contract-drift)   | Committed OpenAPI docs + generated client match the code: `build generate` then `git diff --exit-code`        | CI; agent session-end; pre-push          |
| [format-gate](scripts/format-gate)                     | `dotnet format --verify-no-changes` + Prettier `--check` on staged (or all) files                             | git pre-commit; CI                       |
| [verify-gate](scripts/verify-gate)                     | The full PR gate: `pnpm verify`                                                                               | git pre-push; agent stop/session-end; CI |

Each script prints what to do on failure and exits non-zero (the guard uses exit `2`, the blocking code both Claude Code and VS Code honor).

## Support matrix — honest edition

Verify against each harness's current documentation before wiring; hook runtimes change quickly. State as verified 2026-09:

| Wiring                | Works                                     | Notes                                                                                                                                                                                                                      |
| --------------------- | ----------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **CI**                | Always                                    | Run `check-contract-drift` and `verify-gate` (or `pnpm verify` directly) as jobs. The only wiring every team gets for free                                                                                                 |
| **git hooks**         | Always, any harness                       | `pre-commit` → `guard-generated-files --staged` + `format-gate`; `pre-push` → `verify-gate`. Local hooks are skippable with `--no-verify` — CI remains the authority                                                       |
| **Claude Code**       | Yes — full support                        | `.claude/settings.json` `hooks` key; `PreToolUse` with matcher `Edit\|Write` → `guard-generated-files --stdin-json` (reads `tool_input.file_path`; exit 2 blocks the edit); `Stop`/`SessionEnd` can run gates              |
| **VS Code / Copilot** | Yes — Preview                             | `.github/hooks/*.json`, same config shape as Claude Code, **but matchers are ignored** (hooks fire on every tool) and tool input uses camelCase `filePath` — the guard reads both spellings and exits 0 for non-file tools |
| **Codex**             | Hook runtime exists — verify current docs | Wiring and event schema not pinned here; use git hooks + CI as the portable path and consult the Codex hooks documentation when installing                                                                                 |
| **Cursor**            | Yes                                       | `.cursor/hooks.json` (`version: 1`); `preToolUse`/`afterFileEdit` command hooks, stdin JSON, exit 2 = deny; also loads Claude Code hook configs for compatibility                                                          |

## Wiring snippets

`install.sh --hooks` writes the three harness configs below when they do not exist yet, and `--git-hooks` installs the git pre-commit / pre-push pair; both print the snippet instead of touching a file you already own. The snippets are kept here for manual wiring and for merging into existing configs.

**git pre-commit** (any harness, `.git/hooks/pre-commit` or a hook manager):

```sh
#!/bin/sh
harness/hooks/scripts/guard-generated-files --staged || exit 1
harness/hooks/scripts/format-gate || exit 1
```

**Claude Code** (`.claude/settings.json`) — block agent edits to generated files:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/harness/hooks/scripts/guard-generated-files --stdin-json"
          }
        ]
      }
    ]
  }
}
```

**VS Code / Copilot** (`.github/hooks/guards.json`) — same idea; the script ignores non-file payloads since matchers do not filter:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "type": "command",
        "command": "harness/hooks/scripts/guard-generated-files --stdin-json"
      }
    ]
  }
}
```

**Cursor** (`.cursor/hooks.json`):

```json
{
  "version": 1,
  "hooks": {
    "preToolUse": [
      { "command": "harness/hooks/scripts/guard-generated-files --stdin-json" }
    ]
  }
}
```

Paths assume the catalog lives at `harness/` in the consuming repository (the installer's default `--dir`); adjust when it is copied elsewhere. `verify-gate` on pre-push or session-end is a cost/latency trade-off each team makes — CI runs it regardless.
