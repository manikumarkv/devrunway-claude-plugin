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
- Use `record` types for DTOs — immutable, value equality, concise syntax

**Dependency Injection:**
- Register services in `Program.cs` with appropriate lifetime: `AddScoped` (per-request), `AddSingleton`, `AddTransient`
- Inject via constructor — never use `ServiceLocator` or static access
- Use `IOptions<T>` to inject configuration sections — never `IConfiguration` directly in services

**EF Core:**
- Use async methods (`ToListAsync`, `FirstOrDefaultAsync`, `SaveChangesAsync`) exclusively
- Define migrations with `dotnet ef migrations add <Name>` — apply with `dotnet ef database update`
- Never call `SaveChanges()` in a loop — batch operations, then save once

**Middleware:**
- Order matters: `UseExceptionHandler` → `UseHttpsRedirection` → `UseAuthentication` → `UseAuthorization` → endpoints
- Write custom middleware as a class with `InvokeAsync(HttpContext, RequestDelegate)` — not inline lambdas for anything non-trivial

**Configuration:**
- Layer: `appsettings.json` → `appsettings.{Environment}.json` → environment variables → user secrets (dev only)
- Never store secrets in `appsettings.json` committed to source control
- Use Azure Key Vault or AWS Secrets Manager in production

**Never:**
- Use `async void` except for event handlers
- Catch `Exception` and swallow — always log and rethrow or return a typed error
- Return `IActionResult` when `Results<T, U>` or typed minimal API return is possible

**Related skills:** `error-handling`, `api-conventions`, `security-principles`
