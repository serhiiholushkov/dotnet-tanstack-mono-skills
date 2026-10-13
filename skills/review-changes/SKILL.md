---
name: review-changes
description: 'Read-only review of a change set against this architecture, producing a findings report with file:line citations and a pass/fail verdict. Three checklists, selected by what the diff touches: boundaries (slice/module/schema/web-feature isolation, shared-code neutrality, generated files), the OpenAPI contract diff (metadata completeness, backward compatibility, versioning, C#→TypeScript type traps), and security (server-function trust boundary, authorization inside handlers, secrets, leak paths). Use before merging, when asked to review or audit a PR, branch, or diff, when a change touches more than one slice, module, or feature, or whenever apps/api/openapi, endpoints, Response types, auth, configuration, or server functions changed. Trigger terms: review, audit, PR review, code review, pre-merge check, boundary check, contract review, security review, findings.'
---

# Review changes

Reviews a change set and returns a report; it never edits. Standards are cited, not restated — every checklist item links to the rule or architecture section it enforces, so a finding can say _which_ standard was violated and the author can read why.

**Keep review and repair separate.** When the harness supports delegating to a read-only subagent or opening a fresh context, run this skill there: a reviewer that still holds the author's reasoning in context tends to confirm it. When running inline, finish the whole report before fixing anything — a review that stops at the first finding to patch it misses the second.

## Which checklists apply

| The diff touches…                                                                                | Run                                                                 |
| ------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------- |
| Anything (always)                                                                                | [Boundary checklist](references/boundary-checklist.md)              |
| `apps/api/openapi/*.json`, an `Endpoint`, a `Response` record, `packages/api-client`             | [Contract checklist](references/contract-checklist.md)              |
| Endpoints, handlers, server functions, `lib/` config, auth, `Program.cs`, compose/CI secrets     | [Security checklist](references/security-checklist.md)              |

When asked for a specific review ("security review this", "is this contract change breaking?"), run that checklist plus the boundary checklist; the boundary pass is cheap and catches the violations the other two assume away.

## Procedure

1. **Establish the diff.** Default to the working tree against the default branch (`git diff origin/main...HEAD` plus `git status --porcelain` for uncommitted work); accept an explicit range or PR when given. List the touched paths — the checklist selection and every finding cite them.
2. **Select checklists** from the table. State the selection in the report so a skipped checklist is a visible decision, not an omission.
3. **Gather mechanical evidence before reading code.** These are the facts the checklists lean on, and they are cheaper than inference:
   - API changed → run the architecture tests (`pnpm --filter @repo/api test`, or the `ArchitectureTests` project alone). A red architecture test is a High boundary finding with the test name as evidence.
   - Contract checklist selected → run the drift check (`pnpm turbo run build generate && git diff --exit-code -- apps/api/openapi packages/api-client/src`, also packaged as [hooks/scripts/check-contract-drift](../../hooks/scripts/check-contract-drift)). A non-empty diff is a High contract finding: the committed documents do not describe the code under review. Regeneration rewrites stale files, so prefer a separate worktree (`git worktree add ../review <ref>`); in the author's own tree, record the finding and leave the rewritten files for the author to commit rather than reverting on their behalf.
   - Generated paths in the diff (`*.gen.ts`, `openapi/*.json`, `routeTree.gen.ts`, `**/Database/Migrations/*.cs`) → check whether a C# or model change in the same diff explains them; a generated file that changed alone was hand-edited.
4. **Walk each selected checklist item by item.** Every item ends as either a finding or a "checked clean" line naming what was inspected. No silent skips — a reader must be able to tell "not applicable" from "not looked at".
5. **Classify severity** per item: **High** — a boundary crossed, a breaking contract change inside an active version, an exploitable or data-leaking path, a hand-edited generated file; **Medium** — a control weakened (missing status declaration, per-row Contracts call, missing timeout, incomplete ownership predicate); **Low** — hygiene (naming, a missing summary, test placement).
6. **Check ADR coverage.** A deliberate exception to a rule is fine when an ADR records it ([architecture: ADR triggers](../../docs/architecture.md#adr-triggers)); verify the ADR exists and cite it. An exception without one is a finding at the severity of the rule it bends.
7. **Emit the report** in the format below and stop. Suggested directions name the owning module, feature, or lawful pattern; they are not patches.

## Report format

```markdown
## Review: <range or PR>

**Checklists run.** boundary | boundary + contract | boundary + security | all — <one line on why>
**Verdict.** pass | fail — fail on any High finding, or any breaking contract change without a new version.
**Contract classification.** none | additive | breaking → <operations affected> (contract checklist only)

### Findings

| #   | Severity | Checklist | File:line or document/operation | Violation / risk | Standard | Suggested direction |
| --- | -------- | --------- | ------------------------------- | ---------------- | -------- | ------------------- |

### Checked clean

- <checklist item> — inspected <what>, no findings

### Evidence

- architecture tests: <pass/fail + names> · drift check: <clean/diff> · ADRs cited: <ids or none>
```

Every finding cites a real location from the diff (file and line, or document and operation id). Security findings name the risk and the standard — never an exploit payload.

## Done when

- [ ] The report states which checklists ran and why; the boundary checklist always ran.
- [ ] Mechanical evidence (architecture tests, drift check where applicable) was gathered and recorded, not assumed.
- [ ] Every item of every selected checklist appears as a finding or a checked-clean line.
- [ ] Each finding has a severity, a location from the diff, the standard it violates, and a direction toward the lawful shape.
- [ ] Nothing was edited; the author receives the report and decides.
