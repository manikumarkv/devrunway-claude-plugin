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

// Mount endpoint groups
app.MapGroup("/users").MapUserEndpoints().RequireAuthorization();

app.Run();
```

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

    private static async Task<Ok<IEnumerable<UserDto>>> GetAllUsers(
        IUserService service) =>
        TypedResults.Ok(await service.GetAllAsync());

    private static async Task<Results<Ok<UserDto>, NotFound>> GetUser(
        Guid id, IUserService service)
    {
        var user = await service.GetByIdAsync(id);
        return user is null ? TypedResults.NotFound() : TypedResults.Ok(user);
    }

    private static async Task<Results<Created<UserDto>, ValidationProblem>> CreateUser(
        CreateUserRequest request, IUserService service)
    {
        if (string.IsNullOrWhiteSpace(request.Email))
            return TypedResults.ValidationProblem(new Dictionary<string, string[]>
            {
                ["email"] = ["Email is required"]
            });

        var user = await service.CreateAsync(request);
        return TypedResults.Created($"/users/{user.Id}", user);
    }

    private static async Task<Results<NoContent, NotFound>> DeleteUser(
        Guid id, IUserService service)
    {
        var deleted = await service.DeleteAsync(id);
        return deleted ? TypedResults.NoContent() : TypedResults.NotFound();
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
            logger.LogWarning(ex, "Resource not found");
            ctx.Response.StatusCode = StatusCodes.Status404NotFound;
            await ctx.Response.WriteAsJsonAsync(new { error = ex.Message });
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Unhandled exception");
            ctx.Response.StatusCode = StatusCodes.Status500InternalServerError;
            await ctx.Response.WriteAsJsonAsync(new { error = "Internal server error" });
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
- [ ] No `SaveChanges()` inside loops
