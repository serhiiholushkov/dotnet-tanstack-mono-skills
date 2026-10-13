# Contract checklist

Runs when the diff touches `apps/api/openapi/*.json`, an `Endpoint`, a `Response` record, or `packages/api-client`. The committed OpenAPI documents are the reviewable form of every contract change — review the `git diff -- apps/api/openapi` first and the C# second, because the generator only emits what the endpoint declares, and what it emits is what the web app compiles against.

Authority: [architecture: HTTP contracts](../../../docs/architecture.md#http-contracts); standard: [rules/dotnet-api/endpoints-openapi.md](../../../rules/dotnet-api/endpoints-openapi.md).

Each item ends as a finding or a checked-clean line.

## 1. Documents are current

Regenerating (`pnpm turbo run build generate`) produces no further diff, and `packages/api-client/src/*.gen.ts` changed in the same commit as the documents. A non-empty drift diff is High: the review would otherwise be of a contract the code does not implement.

## 2. Metadata completeness

Every added or changed operation declares: a unique, version-suffixed operation id (`WithName("getCatalogProductV1")`); exactly one group name (it belongs to one document); the module tag; a summary; and a typed schema for every success and error status it can return. An `unknown` or untyped response schema in the generated TypeScript means `Results.Ok(...)` without `Produces<T>` — Medium, because the web side loses the type and the compiler stops protecting the caller.

## 3. Schema quality

Schema names are slice-prefixed (`GetProductResponse`), not `Response`, `Response2`, …; no entity, EF Core projection with navigation properties, or domain type appears as a transport schema. Degraded names mean `CreateSchemaReferenceId` in `Common.Presentation` was bypassed or broken — one fix, not per-endpoint patches.

## 4. Compatibility classification

Classify every operation change and the diff as a whole:

| Change                                                                                                               | Class    |
| -------------------------------------------------------------------------------------------------------------------- | -------- |
| New operation; new optional response field a generated consumer can ignore                                           | additive |
| Removed or renamed field or operation; type or nullability change; optional input made required                      | breaking |
| Status-semantics change (a 404 that becomes a 200 with `null`); path change; new enum member on a switched-on union  | breaking |

A breaking change inside an active version's document, without a new version beside it, is High ([architecture: endpoint versioning](../../../docs/architecture.md#endpoint-versioning)). Route the author to [version-endpoint](../../version-endpoint/SKILL.md).

## 5. Versioning policy

New majors are URL-versioned (`/api/v2/...`) with their own document and generated module; superseded operations carry `deprecated` metadata, and a scheduled retirement returns `Deprecation`, `Sunset`, and successor `Link` headers; an operation deleted from a document had a completed deprecation window recorded in an ADR.

## 6. Type-mapping traps

Flag anything that silently corrupts data between C# and TypeScript ([architecture: type mapping](../../../docs/architecture.md#type-mapping-across-the-boundary)): `decimal` or `long` surfacing as a JSON number (precision loss — use integer minor units or a documented string); numeric enums (`JsonStringEnumConverter` missing); `DateTime` without an offset; a required property that became nullable or vice versa without a version; per-endpoint overrides of the global naming or null-ignore policy.

## 7. Surface hygiene

Health routes and the reference UI do not appear in any public document. No operation appears in every document — that is an endpoint mapped outside a versioned route group. Operation ids are unique across all documents (the OpenAPI boot test asserts this; cite its result).

## Reporting

Set **Contract classification** in the report header to the diff's overall class — `none`, `additive`, or `breaking` with the operations named — using the same vocabulary [plan-feature](../../plan-feature/SKILL.md) uses, so the plan's prediction and the review's verdict can be compared.
