# Refactor note — drop `commands/` and `agents/`

**For the next agent.** Remove the `commands/` and `agents/` artifact kinds from the catalog. Skills already carry the procedures; commands are thin routers that collide with skill names (`add-module`, `version-endpoint`), and agents only exist as native files on two of four harnesses (Codex and Cursor already receive them as skills). Fold anything worth keeping into skills and delete the rest.

## Steps

1. **Catalog** — delete `commands/` and `agents/`. Move the planner's procedure note into `skills/plan-feature/SKILL.md` and the three reviewers' checklists into a `skills/review-*/` skill (or one `review` skill with sections) if they are still wanted; otherwise drop them.
2. **Installer** — in `install.sh`, remove `install_agents`, `install_commands`, their calls in `run_install`, the `agents`/`commands` entries in `CATALOG_ITEMS`, the `n_agents`/`n_commands` counters, and the collision warning. Remove `.claude/commands`, `.claude/agents`, `.github/agents` from the generated layout.
3. **Tests** — in `tests/install.test.sh`, delete the agent/command assertions (`.claude/agents`, `.github/agents`, `.claude/commands`, `*/skills/plan`, `*/skills/planner`, the collision log check) and adjust the expected counts.
4. **Docs** — update `AGENTS.md` (Catalog table, "Follow the matching skill" wording), `README.md` (Catalog table, Layout tree), `docs/install.md` (mapping and translation tables, harness notes), `docs/usage.md`, `rules/README.md`, `skills/README.md`, `templates/README.md`, and `templates/feature-spec.template.md` — all reference `commands/`, `agents/`, `/plan`, or the reviewer names.
5. **Verify** — `shellcheck -s bash install.sh tests/install.test.sh` and `bash tests/install.test.sh` must pass; the suite asserts every generated link resolves, so any stale reference to a removed file will surface there.

Delete this file when done.
