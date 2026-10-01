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

builder.Services.AddDbContext<PWMDbContext>((services, options) => options
    .UseSqlServer(EnvironmentConfig.BuildConnectionString())
    .AddInterceptors(services.GetRequiredService<NotificationPushInterceptor>()));

builder.Services.AddScoped<ReportBuilder>();

var rabbitMqOptions = new RabbitMqOptions();
builder.Configuration.GetSection("RabbitMq").Bind(rabbitMqOptions);
builder.Services.AddSingleton(rabbitMqOptions);

// The notifications this process writes (missed clock-outs) are pushed to their
// accounts' apps too - via the API, over RabbitMQ, since only it holds the
// SignalR connections. See NotificationPushRelay there.
builder.Services.AddSingleton<RabbitMqPublisher>();
builder.Services.AddSingleton<INotificationPushPublisher, RabbitMqNotificationPushPublisher>();
builder.Services.AddScoped<NotificationPushInterceptor>();

var absenceCheckOptions = new AbsenceCheckOptions();
builder.Configuration.GetSection("AbsenceCheck").Bind(absenceCheckOptions);
builder.Services.AddSingleton(absenceCheckOptions);

var missedClockOutOptions = new MissedClockOutOptions();
builder.Configuration.GetSection("MissedClockOut").Bind(missedClockOutOptions);
builder.Services.AddSingleton(missedClockOutOptions);

builder.Services.AddHostedService<ReportGenerationWorker>();
builder.Services.AddHostedService<MissedClockOutWorker>();
builder.Services.AddHostedService<AbsenceCheckWorker>();

var host = builder.Build();
host.Run();
