using Microsoft.EntityFrameworkCore;
using pwm.Services.Database;
using pwm.Services.Database.Seed;

// --seed fills the database with test data, --seed --force empties it first.
// Both flags are stripped before the host reads the remaining arguments.
var seedRequested = args.Any(a => a is "--seed" or "seed");
var seedForce = args.Any(a => a is "--force" or "--seed-force");
var hostArgs = args.Where(a => a is not ("--seed" or "seed" or "--force" or "--seed-force")).ToArray();

var builder = WebApplication.CreateBuilder(hostArgs);

builder.Services.AddDbContext<PWMDbContext>(options =>
    options.UseSqlServer(BuildConnectionString(builder.Configuration)));

builder.Services.AddScoped<DataSeeder>();

builder.Services.AddControllers();
// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
builder.Services.AddOpenApi();

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

    app.MapOpenApi();
}

app.UseHttpsRedirection();

app.UseAuthorization();

app.MapControllers();

app.Run();

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
