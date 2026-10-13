# Boundary checklist

Runs on every review. The architecture is enforced by `internal` visibility, architecture tests, and ESLint boundaries — but each has blind spots (a project reference, a SQL string, a deep import through a re-export), and this checklist covers them. Cite the standard with each finding; the author needs the _why_, which lives there.

Each item ends as a finding or a checked-clean line.

## 1. Slice isolation

One use case per file; `Command`/`Query`, `Response`, `Validator`, `Handler`, `Endpoint` nested in one `internal static class`. No slice names another slice's nested types — the fix for shared behavior is the entity or a duplicated query, never a call into a sibling handler.

Look for: a handler injecting another slice's `IQueryHandler`/`ICommandHandler`; a `Response` reused across slices; helper classes that exist only to share code between two slices. Standard: [rules/dotnet-api/slices.md](../../../rules/dotnet-api/slices.md).

## 2. Module isolation

An implementation project references only its own Contracts, `Common.*`, and sibling **Contracts** projects — never a sibling implementation. Consumers reach a module through its Contracts interface or integration events. `Api` names only `Add{Module}Module` and `Map{Module}Endpoints`.

Look for: a `ProjectReference` to `{OtherModule}/{OtherModule}.csproj`; a `using OtherModule.Features…`; `HttpClient` calls to the API's own routes; a Contracts project referencing anything beyond `Common.SharedKernel`. Standards: [rules/dotnet-api/modules.md](../../../rules/dotnet-api/modules.md), [rules/common/boundaries.md](../../../rules/common/boundaries.md).

## 3. Data ownership

Every table, index, and migration stays in the owning module's schema. No foreign key, join, or raw SQL crosses schemas — external identifiers are plain `uuid` columns. Migrations touch only the module they belong to.

Look for: `AddForeignKey` or `principalSchema:` naming another module's schema in a migration; `FromSqlRaw`/`ExecuteSql` mentioning another schema; a `DbSet` for an entity another module owns. Standard: [rules/dotnet-api/data-ownership.md](../../../rules/dotnet-api/data-ownership.md).

## 4. Cross-module read shapes

A cross-module read is one of the lawful shapes: one Contracts call per record, one batch call per page with an in-memory join, an event-fed projection, or a snapshot taken at write time. A Contracts call inside a loop is a Medium finding even when it works today; it becomes the slowest page in the product.

Look for: `foreach` + `await api.GetAsync`; a projection table written by anything other than the consumer's inbox handler; sorting or filtering a page by a field the module does not own. Standard: [skills/cross-module-communication](../../cross-module-communication/SKILL.md) defines the shapes; [architecture: composing cross-module reads](../../../docs/architecture.md#composing-cross-module-reads) is the authority.

## 5. Web feature isolation

Features import each other only through barrels (`@/features/<name>`); routes validate URL state, prefetch, and render — nothing else; DTOs come from `@repo/api-client` re-exports, never from `components['schemas']` indexing or hand-written copies.

Look for: `@/features/<x>/components/...` deep imports; `fetch`/`apiClient` calls in a route file or component; an interface in `types.ts` that mirrors a generated schema. Standards: [rules/web/features.md](../../../rules/web/features.md), [rules/web/routes.md](../../../rules/web/routes.md), [rules/typescript/types.md](../../../rules/typescript/types.md).

## 6. Shared-code neutrality

`Common.*` and `packages/*` hold only application-neutral code. Something moved there is a finding when it names a module, a product concept, or a feature — the test is whether a second product could use it unchanged.

Look for: a `Common.*` type with a module's vocabulary in its name; `packages/ui` components that know about products or orders; `packages/api-client/client.ts` reading configuration. Standard: [rules/common/boundaries.md](../../../rules/common/boundaries.md).

## 7. Generated-file integrity

`*.gen.ts`, `apps/api/openapi/*.json`, `routeTree.gen.ts`, and applied migrations are never edited by hand, and regenerated outputs land in the same change as their cause.

Look for: a generated file in the diff with no C# or model change explaining it; an edited migration whose timestamp predates the branch; a `// @ts-expect-error` or ESLint disable inside a generated file. Standard: [rules/monorepo/codegen-pipeline.md](../../../rules/monorepo/codegen-pipeline.md).

## Reading the architecture tests

Run them before reading code (`pnpm --filter @repo/api test`, or the `ArchitectureTests` project). A failing test names the edge and the assembly; cite it as evidence rather than re-deriving the violation. A passing suite proves only what the tests assert — items 3 (SQL strings, migration foreign keys), 4, 5, and 6 still need eyes.
