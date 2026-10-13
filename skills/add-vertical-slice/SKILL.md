---
name: add-vertical-slice
description: 'Add one use case to an existing API module as a vertical slice: one file with nested Command/Query, Response, Validator, Handler, and Endpoint, full OpenAPI metadata, errors, caching, events, and tests. Use when adding an endpoint, use case, query, command, or CRUD operation to the .NET API. Trigger terms: new endpoint, add use case, slice, feature on the API, GET/POST/PUT/DELETE route, handler.'
---

# Add a vertical slice

Adds one use case to an existing module. For a brand-new module, run [add-module](../add-module/SKILL.md) first. Standards this skill assumes: [slices](../../rules/dotnet-api/slices.md), [endpoints-openapi](../../rules/dotnet-api/endpoints-openapi.md), [results](../../rules/csharp/results.md), [ef-core](../../rules/csharp/ef-core.md).

## Decision points

| Question                                            | Answer decides                                                                                                                                    |
| --------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| Does it change state?                               | `Command` (+ `Validator`, decorated validation) vs `Query` (validate in-handler if needed)                                                        |
| Who owns the data?                                  | The owning module hosts the slice; needing another module's data → [cross-module-communication](../cross-module-communication/SKILL.md)          |
| Does anything react to this change?                 | Raise a domain event on the entity (outbox picks it up)                                                                                           |
| Is the read hot or expensive?                       | `HybridCache` in the handler + key in `{Module}CacheKeys` + invalidation in every write path                                                      |
| Does the schema change?                             | Run [add-ef-migration](../add-ef-migration/SKILL.md) alongside                                                                                    |
| Is this a breaking change to an existing operation? | Stop — use [version-endpoint](../version-endpoint/SKILL.md)                                                                                       |

## Procedure

1. Create `apps/api/src/Modules/{Module}/{Module}/Features/{Entity}/{UseCase}.cs` — one `internal static class {UseCase}` holding all nested types. Nothing else is created or registered; the module's scan finds handler, validator, and endpoint.
2. Write the input record (`Command`/`Query`) and `Response` record. `Response` is the transport contract TypeScript will be generated from — no entities, no navigation properties.
3. Write the `Validator` for input shape only; business rules go in the handler or entity. Promote a rule to the entity when a second slice needs it.
4. Write the `Handler`:
   - inject the module's `DbContext` and ports; forward the `CancellationToken` everywhere;
   - ownership is part of the query predicate, from `IUserContext` — never from the request;
   - queries project straight to `Response`; commands mutate via entity methods, assign ids before raising events, call `SaveChangesAsync` once;
   - every expected failure returns `Result.Failure({Entity}Errors.X(...))`;
   - invalidate affected cache keys after the successful save.
5. Write the `Endpoint`: relative route, `Version => ApiVersions.V1`, inject the handler interface, `result.Match(TypedResults.…, CustomResults.Problem)`, and the full metadata block — `WithName` (unique, version-suffixed), `WithSummary`, `Produces<…>`/`ProducesProblem` for every status, `RequireAuthorization` with the real policy. The route group already applies prefix, tag, and group name.
6. Add tests mirroring the slice ([api-testing](../../rules/testing/api-testing.md)): validator tests (one per rule), handler tests (happy path + every failure branch, decorators bypassed), and a module integration test for the HTTP contract.
7. Regenerate and review the contract: run [regenerate-api-client](../regenerate-api-client/SKILL.md); the `openapi/*.json` diff is the contract change — check the new operation id, schema names, and statuses.
8. Run `pnpm verify`.

## Example

Command slice skeleton (full command and query examples with request mapping: [references/slice-examples.md](references/slice-examples.md)):

```csharp
namespace Catalog.Features.Products;

internal static class ArchiveProduct
{
    internal sealed record Command(Guid ProductId) : ICommand;

    internal sealed class Validator : AbstractValidator<Command>
    {
        public Validator() => RuleFor(c => c.ProductId).NotEmpty();
    }

    internal sealed class Handler(CatalogDbContext context, HybridCache cache) : ICommandHandler<Command>
    {
        public async Task<Result> Handle(Command command, CancellationToken cancellationToken)
        {
            Product? product = await context.Products
                .SingleOrDefaultAsync(p => p.Id == command.ProductId, cancellationToken);

            if (product is null)
            {
                return Result.Failure(ProductErrors.NotFound(command.ProductId));
            }

            Result result = product.Archive();   // rule lives on the entity; raises ProductArchivedDomainEvent

            if (result.IsFailure)
            {
                return result;
            }

            await context.SaveChangesAsync(cancellationToken);
            await cache.RemoveAsync(ProductCacheKeys.ById(product.Id), cancellationToken);

            return Result.Success();
        }
    }

    internal sealed class Endpoint : IEndpoint
    {
        public string Version => ApiVersions.V1;

        public void MapEndpoint(IEndpointRouteBuilder app) =>
            app.MapPut("products/{id:guid}/archive", async (
                Guid id, ICommandHandler<Command> handler, CancellationToken cancellationToken) =>
            {
                Result result = await handler.Handle(new Command(id), cancellationToken);

                return result.Match(TypedResults.NoContent, CustomResults.Problem);
            })
            .WithName("archiveCatalogProductV1")
            .WithSummary("Archive a catalog product")
            .Produces(StatusCodes.Status204NoContent)
            .ProducesProblem(StatusCodes.Status401Unauthorized)
            .ProducesProblem(StatusCodes.Status404NotFound)
            .ProducesProblem(StatusCodes.Status409Conflict)
            .RequireAuthorization();
    }
}
```

## Done when

- [ ] The whole use case — input, validation, rules, data access, endpoint — is in one file inside the owning module.
- [ ] No reference to another slice's nested types or another module's implementation.
- [ ] Endpoint declares operation id, summary, and every success/error status; protected routes require authorization; ownership enforced in the handler's query.
- [ ] Validator, handler (all failure branches), and integration tests added; cache and event effects tested where present.
- [ ] `openapi/*.json` + generated client regenerated, reviewed, committed together with the slice.
- [ ] `pnpm verify` passes.
