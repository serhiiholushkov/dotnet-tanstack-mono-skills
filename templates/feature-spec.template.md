# Feature spec: {{FEATURE_NAME}}

<!-- Written for a human to approve and an agent to plan from (the plan-feature skill consumes this). Precise enough that the plan's ownership, contract, and data sections are derivable — not an implementation design. -->

- **Status:** {{Draft | Approved | Shipped}}
- **Owner:** {{NAME}}
- **Glossary terms used:** {{TERMS — every domain word here must exist in the glossary}}

## Problem

{{Who has the problem, when it occurs, and the cost of not solving it. One paragraph.}}

## Desired behavior

{{What the user can do once this ships, as observable behavior, not UI mockups. Use the glossary vocabulary.}}

- As a {{ACTOR}}, I can {{ACTION}} so that {{OUTCOME}}.
- …

## Acceptance criteria

<!-- Each criterion should map to at least one test in the eventual test plan. -->

- [ ] {{Given/when/then in domain terms}}
- [ ] {{Error and permission cases: what a non-owner sees, what invalid input produces}}
- [ ] {{Performance/volume expectations, if any — e.g. list pages stay one query per module}}

## Scope boundaries

- **Owning capability:** {{Which business capability this belongs to — hints the owning module/feature without prescribing code}}
- **Out of scope:** {{explicitly excluded behavior, deferred follow-ups}}

## Known constraints and open questions

- {{Regulatory, migration, or compatibility constraints; unresolved product questions the plan must surface rather than assume}}
