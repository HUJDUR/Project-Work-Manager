using FluentValidation;
using Mapster;
using MapsterMapper;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Caching.Memory;
using pwm.Common.Services.CryptoService;
using pwm.Model.Requests;
using pwm.Services.Implementations;
using pwm.Services.Interfaces;
using pwm.Services.Messaging;
using pwm.Services.Validators;

namespace pwm.Services
{
    public static class ServiceRegistration
    {
        public static IServiceCollection AddPwmServices(this IServiceCollection services, IConfiguration configuration)
        {
            // QuestPDF is free below the revenue threshold this project sits under.
            QuestPDF.Settings.License = QuestPDF.Infrastructure.LicenseType.Community;

            services.AddSingleton(TypeAdapterConfig.GlobalSettings);
            services.AddSingleton<ICryptoService, CryptoService>();
            services.AddScoped<IMapper, ServiceMapper>();

            // Backs CachedLookupService - one singleton cache shared by every reference
            // table's service, not per-request state.
            services.AddMemoryCache();

            // pwm.Worker is the only thing that ever builds a report - see ReportBuilder -
            // so only the publisher half of the queue is registered here.
            var rabbitMqOptions = new RabbitMqOptions();
            configuration.GetSection("RabbitMq").Bind(rabbitMqOptions);
            services.AddSingleton(rabbitMqOptions);
            services.AddSingleton<RabbitMqPublisher>();
            services.AddSingleton<IReportQueuePublisher, RabbitMqReportPublisher>();

            // Attached to the DbContext by each host (see its Program.cs), which also
            // supplies the INotificationPushPublisher it pushes through.
            services.AddScoped<Database.NotificationPushInterceptor>();

            // Fallback validator for every request type without a dedicated one
            services.AddTransient(typeof(IValidator<>), typeof(DefaultValidator<>));

            // Registered after the fallback, so these take over for their types
            services.AddTransient<IValidator<ProjectInsertRequest>, ProjectInsertRequestValidator>();
            services.AddTransient<IValidator<ProjectUpdateRequest>, ProjectUpdateRequestValidator>();
            services.AddTransient<IValidator<TruckLoadInsertRequest>, TruckLoadInsertRequestValidator>();
            services.AddTransient<IValidator<TruckLoadUpdateRequest>, TruckLoadUpdateRequestValidator>();
            services.AddTransient<IValidator<NotificationSendRequest>, NotificationSendRequestValidator>();
            services.AddTransient<IValidator<WorkLogInsertRequest>, WorkLogInsertRequestValidator>();
            services.AddTransient<IValidator<WorkLogUpdateRequest>, WorkLogUpdateRequestValidator>();
            services.AddTransient<IValidator<WorkLogDetailInsertRequest>, WorkLogDetailInsertRequestValidator>();
            services.AddTransient<IValidator<WorkLogDetailUpdateRequest>, WorkLogDetailUpdateRequestValidator>();
            services.AddTransient<IValidator<TruckLoadDetailInsertRequest>, TruckLoadDetailInsertRequestValidator>();
            services.AddTransient<IValidator<TruckLoadDetailUpdateRequest>, TruckLoadDetailUpdateRequestValidator>();
            services.AddTransient<IValidator<UserOperationInsertRequest>, UserOperationInsertRequestValidator>();
            services.AddTransient<IValidator<UserOperationUpdateRequest>, UserOperationUpdateRequestValidator>();
            services.AddTransient<IValidator<UserInsertRequest>, UserInsertRequestValidator>();
            services.AddTransient<IValidator<UserUpdateRequest>, UserUpdateRequestValidator>();
            services.AddTransient<IValidator<UserProfileUpdateRequest>,
                UserProfileUpdateRequestValidator>();

            // The six editable lookup tables behind the desktop's Administration screen
            services.AddTransient<IValidator<CountryInsertRequest>, CountryInsertRequestValidator>();
            services.AddTransient<IValidator<CountryUpdateRequest>, CountryUpdateRequestValidator>();
            services.AddTransient<IValidator<CityInsertRequest>, CityInsertRequestValidator>();
            services.AddTransient<IValidator<CityUpdateRequest>, CityUpdateRequestValidator>();
            services.AddTransient<IValidator<CompanyTypeInsertRequest>, CompanyTypeInsertRequestValidator>();
            services.AddTransient<IValidator<CompanyTypeUpdateRequest>, CompanyTypeUpdateRequestValidator>();
            services.AddTransient<IValidator<OperationTypeInsertRequest>, OperationTypeInsertRequestValidator>();
            services.AddTransient<IValidator<OperationTypeUpdateRequest>, OperationTypeUpdateRequestValidator>();
            services.AddTransient<IValidator<ProjectCategoryInsertRequest>, ProjectCategoryInsertRequestValidator>();
            services.AddTransient<IValidator<ProjectCategoryUpdateRequest>, ProjectCategoryUpdateRequestValidator>();
            services.AddTransient<IValidator<CompanyInsertRequest>, CompanyInsertRequestValidator>();
            services.AddTransient<IValidator<CompanyUpdateRequest>, CompanyUpdateRequestValidator>();

            services.AddScoped<ICountryService, CountryService>();
            services.AddScoped<ICityService, CityService>();
            services.AddScoped<ICompanyTypeService, CompanyTypeService>();
            services.AddScoped<ICompanyService, CompanyService>();
            services.AddScoped<IUserTypeService, UserTypeService>();
            services.AddScoped<IUserService, UserService>();
            services.AddScoped<IRefreshTokenService, RefreshTokenService>();
            services.AddScoped<IOperationTypeService, OperationTypeService>();
            services.AddScoped<IUserOperationService, UserOperationService>();
            services.AddScoped<IActivityLogTypeService, ActivityLogTypeService>();
            services.AddScoped<IActivityLogService, ActivityLogService>();
            services.AddScoped<INotificationService, NotificationService>();
            services.AddScoped<IProjectCategoryService, ProjectCategoryService>();
            services.AddScoped<IProjectStatusTypeService, ProjectStatusTypeService>();
            services.AddScoped<ITruckLoadStatusTypeService, TruckLoadStatusTypeService>();
            services.AddScoped<IReportTypeService, ReportTypeService>();
            services.AddScoped<IGeneratedReportService, GeneratedReportService>();
            services.AddScoped<IReportService, ReportService>();
            services.AddScoped<IProjectService, ProjectService>();
            services.AddScoped<IWorkLogService, WorkLogService>();
            services.AddScoped<IWorkLogDetailService, WorkLogDetailService>();
            services.AddScoped<ITruckLoadService, TruckLoadService>();
            services.AddScoped<ITruckLoadDetailService, TruckLoadDetailService>();
            services.AddScoped<IMonthlyHourReportService, MonthlyHourReportService>();
            services.AddScoped<IRecommendationService, RecommendationService>();
            services.AddScoped<IDashboardService, DashboardService>();

            return services;
        }
    }
}
