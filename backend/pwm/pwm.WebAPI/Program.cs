using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi;
using Scalar.AspNetCore;
using pwm.Services;
using pwm.Services.Database;
using pwm.Services.Database.Seed;
using pwm.WebAPI;
using pwm.WebAPI.Filters;
using pwm.WebAPI.Services.AccessManager;
using pwm.WebAPI.Services.CurrentUser;

// --seed fills the database with test data, --seed --force empties it first.
// Both flags are stripped before the host reads the remaining arguments.
var seedRequested = args.Any(a => a is "--seed" or "seed");
var seedForce = args.Any(a => a is "--force" or "--seed-force");
var hostArgs = args.Where(a => a is not ("--seed" or "seed" or "--force" or "--seed-force")).ToArray();

var builder = WebApplication.CreateBuilder(hostArgs);

builder.Services.AddDbContext<PWMDbContext>(options =>
    options.UseSqlServer(BuildConnectionString(builder.Configuration)));

builder.Services.AddScoped<DataSeeder>();

// Mapster, the validator fallback and every entity service
builder.Services.AddPwmServices();

builder.Services.AddScoped<IAccessManager, AccessManager>();

// Who is calling, read from the token - see ICurrentUser
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<ICurrentUser, CurrentUser>();
AddJwtAuthentication(builder);

builder.Services.AddControllers(options => options.Filters.Add<ExceptionFilter>());
// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
// The bearer scheme is declared so the Scalar UI can send a token from /Access/Login.
builder.Services.AddOpenApi(options => options.AddDocumentTransformer((document, context, cancellationToken) =>
{
    document.Components ??= new OpenApiComponents();
    document.Components.SecuritySchemes ??= new Dictionary<string, IOpenApiSecurityScheme>();
    document.Components.SecuritySchemes["Bearer"] = new OpenApiSecurityScheme
    {
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JSON Web Token",
        In = ParameterLocation.Header,
        Description = "Paste the accesstoken returned by POST /Access/Login.",
    };

    return Task.CompletedTask;
}));

var app = builder.Build();

if (seedRequested)
{
    await RunSeedAsync(app.Services, seedForce);
    return;
}

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    using var scope = app.Services.CreateScope();
    await scope.ServiceProvider.GetRequiredService<PWMDbContext>().Database.MigrateAsync();

    // The fallback policy would otherwise lock the developer out of the API docs
    app.MapOpenApi().AllowAnonymous();
    app.MapScalarApiReference().AllowAnonymous();
}

// Not in Development: on the https launch profile this answers the clients' plain-HTTP
// calls with a 307 to :7138, and Dart's http client will not replay a POST body across it.
if (!app.Environment.IsDevelopment())
{
    app.UseHttpsRedirection();
}

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.Run();

// Every endpoint needs a valid token except the ones marked [AllowAnonymous]
// (sign-in and refresh); roles are checked per action by AuthorizationAttribute.
static void AddJwtAuthentication(WebApplicationBuilder builder)
{
    var jwt = builder.Configuration.GetSection("JwtToken");
    var secretKey = jwt["SecretKey"] ?? Environment.GetEnvironmentVariable("JWT_SECRET")
        ?? throw new InvalidOperationException("JwtToken:SecretKey is not configured.");

    builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
        .AddJwtBearer(options =>
        {
            options.TokenValidationParameters = new TokenValidationParameters
            {
                ValidateIssuer = true,
                ValidateAudience = true,
                ValidateLifetime = true,
                ValidateIssuerSigningKey = true,
                ValidIssuer = jwt["Issuer"],
                ValidAudience = jwt["Audience"],
                IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secretKey)),
                RoleClaimType = ClaimNames.Role,
                NameClaimType = ClaimNames.Email,
                ClockSkew = TimeSpan.FromSeconds(30),
            };
        });

    builder.Services.AddAuthorization(options =>
    {
        if (DevSettings.BypassAuthentication)
        {
            return;
        }

        options.FallbackPolicy = new AuthorizationPolicyBuilder()
            .RequireAuthenticatedUser()
            .Build();
    });
}

// The password lives in backend/.env next to docker-compose.yml, so it is read
// from the DB_PASSWORD environment variable rather than from appsettings.json.
static string BuildConnectionString(IConfiguration configuration)
{
    var connectionString = configuration.GetConnectionString("PWMConnection")
        ?? throw new InvalidOperationException("Connection string 'PWMConnection' is not configured.");

    var password = Environment.GetEnvironmentVariable("DB_PASSWORD");

    if (!string.IsNullOrEmpty(password) && !connectionString.Contains("Password=", StringComparison.OrdinalIgnoreCase))
    {
        connectionString = connectionString.TrimEnd(';') + $";Password={password}";
    }

    return connectionString;
}

static async Task RunSeedAsync(IServiceProvider services, bool force)
{
    using var scope = services.CreateScope();

    var db = scope.ServiceProvider.GetRequiredService<PWMDbContext>();
    var seeder = scope.ServiceProvider.GetRequiredService<DataSeeder>();

    Console.WriteLine("Applying migrations...");
    await db.Database.MigrateAsync();

    if (force)
    {
        Console.WriteLine("Clearing existing data...");
    }

    var seeded = await seeder.SeedAsync(force);

    if (!seeded)
    {
        Console.WriteLine("Database already contains data. Run with --seed --force to replace it.");
        return;
    }

    Console.WriteLine("Seed complete:");
    Console.WriteLine($"  Countries               {await db.Countries.CountAsync()}");
    Console.WriteLine($"  Cities                  {await db.Cities.CountAsync()}");
    Console.WriteLine($"  Companies               {await db.Companies.CountAsync()}");
    Console.WriteLine($"  Users                   {await db.Users.CountAsync()}");
    Console.WriteLine($"  UserOperations          {await db.UserOperations.CountAsync()}");
    Console.WriteLine($"  Projects                {await db.Projects.CountAsync()}");
    Console.WriteLine($"  WorkLogs                {await db.WorkLogs.CountAsync()}");
    Console.WriteLine($"  WorkLogDetails          {await db.WorkLogDetails.CountAsync()}");
    Console.WriteLine($"  TruckLoads              {await db.TruckLoads.CountAsync()}");
    Console.WriteLine($"  TruckLoadDetails        {await db.TruckLoadDetails.CountAsync()}");
    Console.WriteLine($"  MonthlyHourReports      {await db.MonthlyHourReports.CountAsync()}");
    Console.WriteLine($"  MonthlyHourReportDetails{await db.MonthlyHourReportDetails.CountAsync()}");
    Console.WriteLine($"  Notifications           {await db.Notifications.CountAsync()}");
    Console.WriteLine($"  ActivityLogs            {await db.ActivityLogs.CountAsync()}");
    Console.WriteLine($"All seeded users share the password: {DataSeeder.DefaultPassword}");
}
