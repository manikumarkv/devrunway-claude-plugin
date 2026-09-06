# .NET 8 ASP.NET Core Standards

## Program.cs Bootstrap

```csharp
// Program.cs
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// Configuration via IOptions<T>
builder.Services.Configure<DatabaseOptions>(
    builder.Configuration.GetSection("Database"));

// DI registration
builder.Services.AddScoped<IUserRepository, UserRepository>();
builder.Services.AddScoped<IUserService, UserService>();
builder.Services.AddDbContext<AppDbContext>(opts =>
    opts.UseNpgsql(builder.Configuration.GetConnectionString("Default")));

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(opts =>
    {
        opts.Authority = builder.Configuration["Auth:Authority"];
        opts.Audience = builder.Configuration["Auth:Audience"];
    });
builder.Services.AddAuthorization();

var app = builder.Build();

// Middleware order is critical
app.UseExceptionHandler("/error");
app.UseHttpsRedirection();
app.UseAuthentication();
app.UseAuthorization();

// Mount endpoint groups — versioned from day one (api-conventions)
app.MapGroup("/api/v1/users").MapUserEndpoints().RequireAuthorization();

app.Run();
```

## Response Envelope

Every JSON body this service returns uses the one shape defined by `api-conventions`:
`{ success, data | error, meta }`. Minimal APIs serialise with `JsonSerializerDefaults.Web`,
so these PascalCase members come out camelCase on the wire.

```csharp
// Common/ApiResponse.cs
public record ApiErrorDetail(string Field, string Message);
public record ApiError(string Code, string Message, IReadOnlyList<ApiErrorDetail>? Details = null);
public record ApiMeta(string RequestId, DateTimeOffset Timestamp);

public record ApiResponse<T>
{
    public bool Success { get; init; }
    public T? Data { get; init; }
    public ApiError? Error { get; init; }
    public ApiMeta Meta { get; init; } = default!;

    public static ApiResponse<T> Ok(T data, HttpContext ctx) =>
        new() { Success = true, Data = data, Meta = MetaFor(ctx) };

    public static ApiResponse<T> Fail(
        string code, string message, HttpContext ctx,
        IReadOnlyList<ApiErrorDetail>? details = null) =>
        new() { Success = false, Error = new ApiError(code, message, details), Meta = MetaFor(ctx) };

    private static ApiMeta MetaFor(HttpContext ctx) =>
        new(ctx.TraceIdentifier, DateTimeOffset.UtcNow);
}
```

The error `Code` is a stable string the client can branch on (`NOT_FOUND`,
`VALIDATION_ERROR`, `INTERNAL_ERROR`). The HTTP status lives on the status line and is
never duplicated in the body. `204 No Content` is the only response without a body.

Pick this envelope **or** RFC 7807 problem documents — never both in one API. This
service uses the envelope, so the RFC 7807 helpers are not used anywhere below.

## Minimal API Endpoint Group

```csharp
// Endpoints/UserEndpoints.cs
public static class UserEndpoints
{
    public static RouteGroupBuilder MapUserEndpoints(this RouteGroupBuilder group)
    {
        group.MapGet("/", GetAllUsers);
        group.MapGet("/{id:guid}", GetUser);
        group.MapPost("/", CreateUser);
        group.MapDelete("/{id:guid}", DeleteUser);
        return group;
    }

    private static async Task<Ok<ApiResponse<IEnumerable<UserDto>>>> GetAllUsers(
        IUserService service, HttpContext ctx) =>
        TypedResults.Ok(ApiResponse<IEnumerable<UserDto>>.Ok(await service.GetAllAsync(), ctx));

    private static async Task<Results<Ok<ApiResponse<UserDto>>, NotFound<ApiResponse<UserDto>>>> GetUser(
        Guid id, IUserService service, HttpContext ctx)
    {
        var user = await service.GetByIdAsync(id);
        return user is null
            ? TypedResults.NotFound(ApiResponse<UserDto>.Fail("NOT_FOUND", "User not found", ctx))
            : TypedResults.Ok(ApiResponse<UserDto>.Ok(user, ctx));
    }

    private static async Task<Results<Created<ApiResponse<UserDto>>, BadRequest<ApiResponse<UserDto>>>> CreateUser(
        CreateUserRequest request, IUserService service, HttpContext ctx)
    {
        if (string.IsNullOrWhiteSpace(request.Email))
            return TypedResults.BadRequest(ApiResponse<UserDto>.Fail(
                "VALIDATION_ERROR", "Request validation failed", ctx,
                [new ApiErrorDetail("email", "Email is required")]));

        var user = await service.CreateAsync(request);
        return TypedResults.Created(
            $"/api/v1/users/{user.Id}", ApiResponse<UserDto>.Ok(user, ctx));
    }

    private static async Task<Results<NoContent, NotFound<ApiResponse<object>>>> DeleteUser(
        Guid id, IUserService service, HttpContext ctx)
    {
        var deleted = await service.DeleteAsync(id);
        return deleted
            ? TypedResults.NoContent()
            : TypedResults.NotFound(ApiResponse<object>.Fail("NOT_FOUND", "User not found", ctx));
    }
}
```

## DTOs with Records

```csharp
// DTOs/UserDto.cs
public record UserDto(Guid Id, string Email, string Name, DateTimeOffset CreatedAt);

public record CreateUserRequest(string Email, string Name, string Password);
```

## EF Core Entity and DbContext

```csharp
// Models/User.cs
public class User
{
    public Guid Id { get; private set; } = Guid.NewGuid();
    public string Email { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    public DateTimeOffset CreatedAt { get; private set; } = DateTimeOffset.UtcNow;
}

// Data/AppDbContext.cs
public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<User> Users => Set<User>();

    protected override void OnModelCreating(ModelBuilder mb)
    {
        mb.Entity<User>(e =>
        {
            e.HasKey(u => u.Id);
            e.HasIndex(u => u.Email).IsUnique();
            e.Property(u => u.Email).HasMaxLength(255).IsRequired();
        });
    }
}
```

## Repository Pattern

```csharp
// Repositories/UserRepository.cs
public interface IUserRepository
{
    Task<User?> GetByIdAsync(Guid id, CancellationToken ct = default);
    Task<IEnumerable<User>> GetAllAsync(CancellationToken ct = default);
    Task AddAsync(User user, CancellationToken ct = default);
    Task<bool> DeleteAsync(Guid id, CancellationToken ct = default);
    Task SaveChangesAsync(CancellationToken ct = default);
}

public class UserRepository : IUserRepository
{
    private readonly AppDbContext _db;

    public UserRepository(AppDbContext db) => _db = db;

    public Task<User?> GetByIdAsync(Guid id, CancellationToken ct = default) =>
        _db.Users.FirstOrDefaultAsync(u => u.Id == id, ct);

    public async Task<IEnumerable<User>> GetAllAsync(CancellationToken ct = default) =>
        await _db.Users.AsNoTracking().ToListAsync(ct);

    public async Task AddAsync(User user, CancellationToken ct = default) =>
        await _db.Users.AddAsync(user, ct);

    public async Task<bool> DeleteAsync(Guid id, CancellationToken ct = default)
    {
        var user = await _db.Users.FindAsync([id], ct);
        if (user is null) return false;
        _db.Users.Remove(user);
        return true;
    }

    public Task SaveChangesAsync(CancellationToken ct = default) =>
        _db.SaveChangesAsync(ct);
}
```

## Custom Exception Middleware

```csharp
// Middleware/ExceptionMiddleware.cs
public class ExceptionMiddleware(RequestDelegate next, ILogger<ExceptionMiddleware> logger)
{
    public async Task InvokeAsync(HttpContext ctx)
    {
        try
        {
            await next(ctx);
        }
        catch (NotFoundException ex)
        {
            // The exception object goes to the log; only a fixed message and a stable
            // code go to the client. Exception text leaks table names, connection
            // strings and file paths.
            logger.LogWarning(ex, "Resource not found");
            ctx.Response.StatusCode = StatusCodes.Status404NotFound;
            await ctx.Response.WriteAsJsonAsync(
                ApiResponse<object>.Fail("NOT_FOUND", "Resource not found", ctx));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Unhandled exception");
            ctx.Response.StatusCode = StatusCodes.Status500InternalServerError;
            await ctx.Response.WriteAsJsonAsync(
                ApiResponse<object>.Fail("INTERNAL_ERROR", "Internal server error", ctx));
        }
    }
}

// Register: app.UseMiddleware<ExceptionMiddleware>();
```

## IOptions Configuration

```csharp
public class DatabaseOptions
{
    public string ConnectionString { get; set; } = string.Empty;
    public int MaxRetries { get; set; } = 3;
}

// In a service
public class UserService(IOptions<DatabaseOptions> dbOpts, IUserRepository repo)
{
    // dbOpts.Value.ConnectionString
}
```

## EF Migrations

```bash
dotnet ef migrations add InitialCreate --project src/Infrastructure --startup-project src/Api
dotnet ef database update --project src/Infrastructure --startup-project src/Api
```

## Checklist

- [ ] All DB calls use async variants with `CancellationToken`
- [ ] DTOs are `record` types, not mutable classes
- [ ] Secrets loaded from environment / Key Vault — not `appsettings.json`
- [ ] Middleware registered in correct order (auth before authorization)
- [ ] Typed results used on minimal API handlers (`Results<Ok<T>, NotFound>`)
- [ ] Every JSON body is the `ApiResponse<T>` envelope; `204` is the only bodiless response
- [ ] No exception text or stack reaches the client — fixed message plus a stable error code
- [ ] Route groups mounted under `/api/v1/`
- [ ] No `SaveChanges()` inside loops

## Common mistakes

| Mistake | Fix |
|---|---|
| Calling `SaveChanges()` inside a loop | Batch all changes, then call `SaveChangesAsync()` once outside the loop to avoid excessive round-trips |
| Using mutable classes for DTOs | Use `record` types (`public record UserDto(...)`) — they are immutable, value-equal, and ideal for API contracts |
| Registering `DbContext` as `Singleton` | EF Core `DbContext` is not thread-safe; register with `AddDbContext` (default `Scoped`) — one context per request |
| Missing `CancellationToken` on async database calls | Pass `CancellationToken` to all `async` EF methods so long-running queries can be cancelled on client disconnect |
| Returning `IQueryable<T>` from repository methods | Returning `IQueryable` leaks EF Core concerns out of the repository; return `IEnumerable<T>` or `List<T>` instead |
| Storing secrets in `appsettings.json` | Load secrets from environment variables or Azure Key Vault via `AddEnvironmentVariables()` / `AddAzureKeyVault()` |
| Registering middleware in the wrong order | Authentication must come before Authorization; Exception handler must be first; see the documented middleware pipeline order |
| Returning the exception text to the caller | Log the exception object with `logger.LogError(ex, "...")` and return `ApiResponse<T>.Fail(code, "Internal server error", ctx)`. Exception text leaks table names, connection strings and file paths to anyone who can trigger a 500 |
| Returning a bare `new { error = ... }` body | Every response is the `{ success, data \| error, meta }` envelope from `api-conventions`. A bare error object gives the client nothing stable to branch on |
| Mounting route groups unversioned | Mount under `/api/v1/` from the first commit — adding a version later breaks every existing client |
| Not using `AsNoTracking()` for read-only queries | EF Core tracks all returned entities by default; use `.AsNoTracking()` for read-only lists to skip change tracking overhead |
