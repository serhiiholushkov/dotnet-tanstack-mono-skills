---
name: plan-feature
description: 'Turn a feature request into a reviewable implementation plan before any code: owning module and web feature, affected layers, contract impact, data impact, ADR triggers, and a test plan. Use when starting nontrivial work, when asked to plan, estimate, design, or break down a feature, when a request spans the API and the web app or more than one slice, or when it is unclear which module owns the data — even if the user asks you to "just implement it". Read-only; produces the plan artifact only. Trigger terms: plan, break down, design, feature request, scope, implementation plan, approach.'
---

# Plan a feature

Produces a plan artifact a human can approve before implementation. Authority for every classification: [../../docs/architecture.md](../../docs/architecture.md).

## Ground rules

- **Read-only.** Inspect the workspace, rules, and architecture; change nothing. Planning that edits "just the obvious part" removes the human's chance to redirect it cheaply. When the harness supports delegating to a read-only subagent or a fresh context, plan there — a planner that is also about to implement tends to plan around its own shortcuts.
- **Ownership is assigned, never guessed.** Every piece of work goes to the module or feature that owns the data and rules; when that is unclear, it is an open question in the plan.
- **Surface, do not decide.** ADR triggers become approval points. Where the architecture is silent, say so and propose options with trade-offs — do not invent policy.
- **One artifact.** Return exactly the `## Plan` block below: no code, no diffs, no commentary around it. Approved steps are then executed by the skills the plan names, and the result reviewed with [review-changes](../review-changes/SKILL.md) before merge.

## Procedure

1. **Restate the requirement** in one paragraph: actor, action, outcome, constraints. Name the unknowns explicitly instead of assuming.
2. **Assign ownership.**
   - API: which existing module owns the data and rules? If none does, that is an ADR-gated new-module decision ([add-module](../add-module/SKILL.md)) — flag it, do not default to "add a module".
   - Web: which product-concept feature folder? New folder or extension?
3. **Enumerate affected layers**, one line each — only what actually changes: API slices (per use case: new slice / new endpoint version / none), entities + domain rules, schema (migration?), Contracts (new method/event? which consumers?), cache keys, web adapters, queries, components, routes.
4. **Classify contract impact** — exactly one of:
   - none (internal change; no OpenAPI diff expected)
   - additive (new operation or optional field; same version)
   - breaking (route [version-endpoint](../version-endpoint/SKILL.md); requires a version and a migration path for web callers)
5. **Classify data impact:** none / new columns-tables in the owning schema (list migrations) / cross-module read (which table row of the read-composition table applies) / cross-module write (ADR required — stop and surface).
6. **Scan ADR triggers** ([architecture](../../docs/architecture.md#adr-triggers)): new module, new dependency, cross-module write strategy, boundary exception, new major version, shared-code promotion. List each hit with a one-line proposed decision; these are approval points, not plan steps.
7. **Write the test plan** from the test-type tables ([api-testing](../../rules/testing/api-testing.md), [web-testing](../../rules/testing/web-testing.md)): which validator/handler/integration tests per slice; which adapter/query/component tests per web change; cache and event tests where those exist.
8. **Sequence the work** as skill invocations in pipeline order, e.g. `add-ef-migration` → `add-vertical-slice` (×N) → `regenerate-api-client` → `add-web-feature` → `pnpm verify`. One vertical at a time; each step ends verifiable.
9. **Emit the plan** in this format:

```markdown
## Plan: <feature name>

**Requirement.** <one paragraph + open questions>

**Ownership.** API: <module> (existing|new+ADR). Web: <feature folder> (existing|new).

**Contract impact.** none | additive | breaking → <operations affected>

**Data impact.** <none | migrations list | cross-module read shape | cross-module write + ADR>

**ADR triggers.** <none | list with proposed decisions>

**Steps.**

1. <skill / action> — <what and where>
2. …

**Tests.** <per-layer list>

**Out of scope.** <explicitly excluded>
```

## Done when

- [ ] Every affected layer is enumerated with its owning module/feature; no step edits code outside them.
- [ ] Contract and data impact are classified in the plan's vocabulary (none/additive/breaking; read-shape table row).
- [ ] Every ADR trigger is surfaced as an approval point, not silently decided.
- [ ] The test plan names concrete test classes/files, not "add tests".
- [ ] Steps map to skills in pipeline order and end with `pnpm verify`.
- [ ] Open questions are listed rather than assumed away.
