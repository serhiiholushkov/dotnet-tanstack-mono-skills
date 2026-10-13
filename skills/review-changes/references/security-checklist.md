# Security checklist

Runs when the diff touches endpoints, handlers, server functions, web `lib/` configuration, authentication, `Program.cs`, or compose/CI files. The trust model of this architecture is specific: the browser trusts only the web app, the web app holds the API credential server-side, and every handler is its own last line of defense because no layer above a slice can enforce ownership for it. Review against that model, not a generic checklist.

Standards: [rules/common/security.md](../../../rules/common/security.md), [architecture: security baseline](../../../docs/architecture.md#security-baseline), [rules/web/server-functions.md](../../../rules/web/server-functions.md).

Each item ends as a finding or a checked-clean line. Name the risk and the standard — never include an exploit payload in the report.

## 1. Trust boundary

The browser never receives the API base URL, a bearer token, or a direct path to the API. Every new web→API call goes through a TanStack server function that uses the generated client from `@/lib/api-client`. Server-only configuration (`API_BASE_URL`, service credentials) never enters client-bundled code or a `VITE_`-prefixed variable.

Look for: `fetch(`/`apiClient` in a component or route; `import.meta.env.VITE_API…`; a server function returning the upstream `ProblemDetails` or response headers verbatim to the browser.

## 2. Endpoint authorization

Every protected endpoint calls `RequireAuthorization` with a real policy. An anonymous endpoint is explicitly intended (`AllowAnonymous` with a reason in the PR), not forgotten. There is no middleware that compensates for a missing call, so a missing one is High.

## 3. Handler-level ownership

A handler that reads or mutates principal-owned data filters by `IUserContext` inside the query (`&& p.OwnerId == userContext.UserId`), never from an id supplied by the request. A missing row and a row owned by someone else return the same 404; a 403 that reveals existence is a Medium finding.

Look for: `OwnerId` taken from the command; a `SingleAsync(p => p.Id == id)` followed by a separate ownership `if`; a Contracts implementation that bypasses the module's slice (and therefore its ownership predicate).

## 4. Input trust

Validators bound size and format on every external input (`MaximumLength`, ranges, allowed values). Nothing interpolates user input into SQL (`FromSqlRaw` with concatenation), response headers, file paths, or log message templates — logging uses structured fields only, so a crafted input cannot forge log lines.

## 5. Secrets and configuration

No secret in code, test fixtures, committed configuration, or compose files beyond local-only defaults. New settings bind to validated typed options (`ValidateOnStart`), not `IConfiguration["..."]` reads in slices. Secrets never appear in a `Response` record, `ProblemDetails`, or a log field.

## 6. Leak paths

No stack trace, driver message, connection string, or internal identifier reaches a client: handlers return `Result`, endpoints map through `CustomResults.Problem`, and the global exception handler replaces every 5xx message. `Authorization`, `Cookie`, and password/secret fields are redacted from logs; EF Core sensitive-data logging stays off outside local development.

Look for: `ex.Message` in a problem detail; `EnableSensitiveDataLogging()` without an environment guard in `Program.cs`; a catch block that returns `Results.Problem(ex.ToString())`.

## 7. Edge configuration drift

Changes to CORS, forwarded headers, rate limiting, Kestrel limits, or security headers match the baseline. CORS is registered only if a browser calls the API directly — the default path (server functions, server-to-server) needs none, so a new CORS policy is a question before it is a finding. `UseForwardedHeaders` names its known proxies. Rate limiting beyond one process, a gateway, or a distributed store is ADR-gated: flag it, do not design it.

## Severity guide

**High** — exploitable, or leaks data or secrets: a missing `RequireAuthorization`, an ownership predicate that trusts the request, a credential reaching the browser, a secret in the diff. **Medium** — a control weakened: unbounded input, existence-revealing 403, a server function without a timeout, CORS opened without a browser caller. **Low** — hygiene: a redundant check, an anonymous endpoint without a stated reason.
