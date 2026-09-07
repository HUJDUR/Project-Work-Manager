using FluentValidation;
using Mapster;
using MapsterMapper;
using Microsoft.Extensions.DependencyInjection;
using pwm.Common.Services.CryptoService;
using pwm.Model.Requests;
using pwm.Services.Implementations;
using pwm.Services.Interfaces;
using pwm.Services.Validators;

namespace pwm.Services
{
    public static class ServiceRegistration
    {
        public static IServiceCollection AddPwmServices(this IServiceCollection services)
        {
            // QuestPDF is free below the revenue threshold this project sits under.
            QuestPDF.Settings.License = QuestPDF.Infrastructure.LicenseType.Community;

            services.AddSingleton(TypeAdapterConfig.GlobalSettings);
            services.AddSingleton<ICryptoService, CryptoService>();
            services.AddScoped<IMapper, ServiceMapper>();

            // Fallback validator for every request type without a dedicated one
            services.AddTransient(typeof(IValidator<>), typeof(DefaultValidator<>));

            // Registered after the fallback, so these take over for their types
            services.AddTransient<IValidator<ProjectInsertRequest>, ProjectInsertRequestValidator>();
            services.AddTransient<IValidator<ProjectUpdateRequest>, ProjectUpdateRequestValidator>();
            services.AddTransient<IValidator<TruckLoadInsertRequest>, TruckLoadInsertRequestValidator>();
            services.AddTransient<IValidator<TruckLoadUpdateRequest>, TruckLoadUpdateRequestValidator>();
            services.AddTransient<IValidator<NotificationSendRequest>, NotificationSendRequestValidator>();
            services.AddTransient<IValidator<UserInsertRequest>, UserInsertRequestValidator>();
            services.AddTransient<IValidator<UserUpdateRequest>, UserUpdateRequestValidator>();
            services.AddTransient<IValidator<UserProfileUpdateRequest>,
                UserProfileUpdateRequestValidator>();

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
            services.AddScoped<IMonthlyHourReportDetailService, MonthlyHourReportDetailService>();

            return services;
        }
    }
}
