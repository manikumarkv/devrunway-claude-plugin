---
name: dotnet
description: .NET 8 ASP.NET Core — minimal APIs, DI, EF Core, middleware, configuration
user-invocable: false
stack: backend/dotnet
paths:
  - "**/*.cs"
  - "**/*.csproj"
  - "**/appsettings*.json"
  - "**/Program.cs"
  - "**/Startup.cs"
---

Full standards in [dotnet.md](dotnet.md). Always-on summary:

**Project Structure:**
- Use minimal APIs in `Program.cs` for new services; Controllers for complex CRUD with filters
- Separate concerns: `Endpoints/`, `Services/`, `Repositories/`, `Models/`, `DTOs/`
- Use `record ` types for DTOs — e.g. `public record CreateProductRequest(string Name, decimal Price)` — immutable, value equality, concise syntax

**Dependency Injection:**
- Register services in `Program.cs` with appropriate lifetime: `AddScoped<IUserService, UserService>()` (per-request), `AddSingleton`, `AddTransient`
- Inject via constructor — never use `ServiceLocator` or static access
- Use `IOptions<T>` to inject configuration sections — never `IConfiguration` directly in services

**EF Core:**
- Use async methods — always `async Task<T>` with `await` on every DB call: `await context.Users.FirstOrDefaultAsync(u => u.Id == id)`
- Define migrations with `dotnet ef migrations add <Name>` — apply with `dotnet ef database update`
- Never call `SaveChanges()` in a loop — batch operations, then save once

**Middleware:**
- Order matters: `UseExceptionHandler` → `UseHttpsRedirection` → `UseAuthentication` → `UseAuthorization` → endpoints
- Write custom middleware as a class with `InvokeAsync(HttpContext, RequestDelegate)` — not inline lambdas for anything non-trivial

**Configuration:**
- Layer: `appsettings.json` → `appsettings.{Environment}.json` → environment variables → user secrets (dev only)
- Never store secrets in `appsettings.json` committed to source control
- Use Azure Key Vault or AWS Secrets Manager in production

**API responses — one envelope, defined by `api-conventions`:**
- Every JSON body is `{ success, data | error, meta }` — build it with
  `ApiResponse<T>.Ok(data, ctx)` / `ApiResponse<T>.Fail(code, message, ctx)`.
  `204 No Content` is the only response without a body
- Errors carry a stable `Code` string the client can branch on — `NOT_FOUND`,
  `VALIDATION_ERROR`, `INTERNAL_ERROR`. The HTTP status is on the status line and is
  never duplicated in the body
- Never send the exception's message, `ToString()` or stack to the client. Log the
  exception object (`logger.LogError(ex, "...")`) and return a fixed message with a
  stable code — exception text leaks table names, connection strings and file paths
- Mount every route group versioned: `app.MapGroup("/api/v1/users")`. An unversioned
  group breaks every client the day the shape changes
- Choose the envelope **or** RFC 7807 problem documents — never both in one API. This
  layer uses the envelope, so the RFC 7807 result helpers are not used

**Never:**
- Avoid fire-and-forget methods — use `async Task<T>` return types; only event handlers may use void return
- Catch `Exception` and swallow — always log and rethrow or return a typed error
- Return `IActionResult` when `Results<T, U>` or typed minimal API return is possible

**Related skills:** `error-handling`, `api-conventions`, `security-principles`
