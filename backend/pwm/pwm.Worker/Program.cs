using Microsoft.EntityFrameworkCore;
using pwm.Common.Services.Hosting;
using pwm.Services.Database;
using pwm.Services.Messaging;
using pwm.Services.Reporting;
using pwm.Worker;

// QuestPDF is free below the revenue threshold this project sits under. This
// is the process that actually renders documents now, so it - not just
// pwm.WebAPI's own copy of this line - has to declare it before ReportBuilder
// ever touches QuestPDF.
QuestPDF.Settings.License = QuestPDF.Infrastructure.LicenseType.Community;

// Same file, same convention as pwm.WebAPI/Program.cs: every secret lives in
// backend/.env, read into the process environment before configuration is
// built, so both processes and docker-compose agree on it.
EnvironmentConfig.LoadDotEnvFile();

var builder = Host.CreateApplicationBuilder(args);

builder.Services.AddDbContext<PWMDbContext>(options =>
    options.UseSqlServer(EnvironmentConfig.BuildConnectionString(builder.Configuration)));

builder.Services.AddScoped<ReportBuilder>();

var rabbitMqOptions = new RabbitMqOptions();
builder.Configuration.GetSection("RabbitMq").Bind(rabbitMqOptions);
builder.Services.AddSingleton(rabbitMqOptions);

builder.Services.AddHostedService<ReportGenerationWorker>();

var host = builder.Build();
host.Run();
