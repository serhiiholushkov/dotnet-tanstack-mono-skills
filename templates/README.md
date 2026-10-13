# Templates

Seed documents a consuming repository copies out and fills in. These are the only files in the catalog that use `{{PLACEHOLDER}}` tokens — everywhere else, placeholder syntax is a defect.

| Template                                             | Copy to (suggested)          | Purpose                                                                |
| ---------------------------------------------------- | ---------------------------- | ---------------------------------------------------------------------- |
| [adr.template.md](adr.template.md)                   | `docs/adr/NNNN-<slug>.md`    | Record a decision listed under the architecture's ADR Triggers         |
| [glossary.template.md](glossary.template.md)         | `docs/glossary.md`           | Pin the product's ubiquitous language before names spread through code |
| [feature-spec.template.md](feature-spec.template.md) | `docs/features/<feature>.md` | Describe a feature precisely enough that `plan-feature` produces a good plan |

Usage: copy the file, replace every `{{TOKEN}}`, delete the guidance comments, commit. Number ADRs sequentially and never edit an accepted ADR — supersede it with a new one that links back.
