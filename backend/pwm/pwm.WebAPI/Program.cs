using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi;
using Scalar.AspNetCore;
using pwm.Common.Services.Hosting;
using pwm.Model.Access;
using pwm.Services;
using pwm.Services.Database;
using pwm.Services.Database.Seed;
using pwm.Services.Interfaces;
using pwm.WebAPI.Filters;
using pwm.WebAPI.Json;
using pwm.WebAPI.Services.AccessManager;
using pwm.WebAPI.Services.CurrentUser;

// --seed fills the database with test data, --seed --force empties it first.
// Both flags are stripped before the host reads the remaining arguments.
var seedRequested = args.Any(a => a is "--seed" or "seed");
var seedForce = args.Any(a => a is "--force" or "--seed-force");
var hostArgs = args.Where(a => a is not ("--seed" or "seed" or "--force" or "--seed-force")).ToArray();

// Every secret and environment-specific value lives in one file, backend/.env,
// rather than appsettings.json or a value the shell has to be told to export by
// hand. docker-compose already reads that file natively; this is what gives the
// API and the seeder the same view of it.
EnvironmentConfig.LoadDotEnvFile();

var builder = WebApplication.CreateBuilder(hostArgs);

builder.Services.AddDbContext<PWMDbContext>(options =>
    options.UseSqlServer(EnvironmentConfig.BuildConnectionString()));

builder.Services.AddScoped<DataSeeder>();

// Mapster, the validator fallback, every entity service, and the RabbitMQ
// publisher reports are queued through
builder.Services.AddPwmServices(builder.Configuration);

builder.Services.AddScoped<IAccessManager, AccessManager>();

// Who is calling, read from the token - see ICurrentUser
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<ICurrentUser, CurrentUser>();
AddJwtAuthentication(builder);

builder.Services.AddControllers(options => options.Filters.Add<ExceptionFilter>())
    // Every DateTime this API reads or writes is UTC by convention - see
    // UtcDateTimeConverter for why that has to be forced explicitly.
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.Converters.Add(new UtcDateTimeConverter());
        options.JsonSerializerOptions.Converters.Add(new UtcNullableDateTimeConverter());
    });
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
    // Every JWT value - the signing key, issuer, audience and lifetimes - comes
    // from backend/.env (via LoadDotEnvFile); appsettings.json carries none of them.
    var secretKey = EnvironmentConfig.Require("JWT_SECRET");
    var issuer = EnvironmentConfig.Require("JwtToken__Issuer");
    var audience = EnvironmentConfig.Require("JwtToken__Audience");

    builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
        .AddJwtBearer(options =>
        {
            options.TokenValidationParameters = new TokenValidationParameters
            {
                ValidateIssuer = true,
                ValidateAudience = true,
                ValidateLifetime = true,
                ValidateIssuerSigningKey = true,
                ValidIssuer = issuer,
                ValidAudience = audience,
                IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secretKey)),
                RoleClaimType = ClaimNames.Role,
                NameClaimType = ClaimNames.Email,
                ClockSkew = TimeSpan.FromSeconds(30),
            };

            // The signature check above only proves this token was genuinely issued by
            // us at some point - it says nothing about whether it has since been
            // revoked. Logout can't touch an already-handed-out access token directly
            // (it's a self-contained JWT, not a row in a table), so it bumps the
            // account's TokenVersion instead; this is what actually enforces that,
            // on every request, by rejecting a token whose embedded version has fallen
            // behind the account's current one.
            options.Events = new JwtBearerEvents
            {
                OnTokenValidated = async context =>
                {
                    var principal = context.Principal;
                    var idClaim = principal?.FindFirst(ClaimNames.Id)?.Value;
                    var tokenVersionClaim = principal?.FindFirst(ClaimNames.TokenVersion)?.Value;

                    if (!int.TryParse(idClaim, out var userId) ||
                        !int.TryParse(tokenVersionClaim, out var tokenVersion))
                    {
                        context.Fail("Token is missing required claims.");
                        return;
                    }

                    var userService = context.HttpContext.RequestServices.GetRequiredService<IUserService>();
                    var currentVersion = await userService.GetTokenVersionAsync(userId);

                    if (currentVersion is null || currentVersion.Value != tokenVersion)
                    {
                        context.Fail("This session has been signed out. Please sign in again.");
                    }
                },
            };
        });

    builder.Services.AddAuthorization(options =>
    {
        options.FallbackPolicy = new AuthorizationPolicyBuilder()
            .RequireAuthenticatedUser()
            .Build();
    });
}


static async Task RunSeedAsync(IServiceProvider services, bool force)
{
    using var scope = services.CreateScope();

    var db = scope.ServiceProvider.GetRequiredService<PWMDbContext>();
    var seeder = scope.ServiceProvider.GetRequiredService<DataSeeder>();
    var logger = scope.ServiceProvider.GetRequiredService<ILogger<Program>>();

    logger.LogInformation("Applying migrations...");
    await db.Database.MigrateAsync();

    if (force)
    {
        logger.LogInformation("Clearing existing data...");
    }

    var seeded = await seeder.SeedAsync(force);

    if (!seeded)
    {
        logger.LogInformation("Database already contains data. Run with --seed --force to replace it.");
        return;
    }

    logger.LogInformation(
        "Seed complete: Countries={Countries} Cities={Cities} Companies={Companies} Users={Users} " +
        "UserOperations={UserOperations} Projects={Projects} ProjectStatusChanges={ProjectStatusChanges} " +
        "WorkLogs={WorkLogs} WorkLogDetails={WorkLogDetails} TruckLoads={TruckLoads} TruckLoadDetails={TruckLoadDetails} " +
        "TruckLoadStatusChanges={TruckLoadStatusChanges} MonthlyHourReports={MonthlyHourReports} " +
        "MonthlyHourReportDetails={MonthlyHourReportDetails} Notifications={Notifications} ActivityLogs={ActivityLogs}",
        await db.Countries.CountAsync(),
        await db.Cities.CountAsync(),
        await db.Companies.CountAsync(),
        await db.Users.CountAsync(),
        await db.UserOperations.CountAsync(),
        await db.Projects.CountAsync(),
        await db.ProjectStatusChanges.CountAsync(),
        await db.WorkLogs.CountAsync(),
        await db.WorkLogDetails.CountAsync(),
        await db.TruckLoads.CountAsync(),
        await db.TruckLoadDetails.CountAsync(),
        await db.TruckLoadStatusChanges.CountAsync(),
        await db.MonthlyHourReports.CountAsync(),
        await db.MonthlyHourReportDetails.CountAsync(),
        await db.Notifications.CountAsync(),
        await db.ActivityLogs.CountAsync());

    logger.LogInformation("All seeded users share the password: {DefaultPassword}", DataSeeder.DefaultPassword);
}
