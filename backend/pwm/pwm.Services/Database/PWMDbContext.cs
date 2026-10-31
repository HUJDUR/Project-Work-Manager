using Microsoft.EntityFrameworkCore;

namespace pwm.Services.Database
{
    public class PWMDbContext : DbContext
    {
        public PWMDbContext(DbContextOptions<PWMDbContext> options) : base(options)
        {
        }

        public DbSet<Country> Countries { get; set; }
        public DbSet<City> Cities { get; set; }
        public DbSet<CompanyType> CompanyTypes { get; set; }
        public DbSet<Company> Companies { get; set; }
        public DbSet<UserType> UserTypes { get; set; }
        public DbSet<User> Users { get; set; }
        public DbSet<RefreshToken> RefreshTokens { get; set; }
        public DbSet<OperationType> OperationTypes { get; set; }
        public DbSet<UserOperation> UserOperations { get; set; }
        public DbSet<ActivityLogType> ActivityLogTypes { get; set; }
        public DbSet<ActivityLog> ActivityLogs { get; set; }
        public DbSet<Notification> Notifications { get; set; }
        public DbSet<NotificationType> NotificationTypes { get; set; }
        public DbSet<ProjectCategory> ProjectCategories { get; set; }
        public DbSet<ProjectStatusType> ProjectStatusTypes { get; set; }
        public DbSet<TruckLoadStatusType> TruckLoadStatusTypes { get; set; }
        public DbSet<Project> Projects { get; set; }
        public DbSet<ProjectStatusChange> ProjectStatusChanges { get; set; }
        public DbSet<WorkLog> WorkLogs { get; set; }
        public DbSet<WorkLogDetail> WorkLogDetails { get; set; }
        public DbSet<WorkHoursChange> WorkHoursChanges { get; set; }
        public DbSet<TruckLoad> TruckLoads { get; set; }
        public DbSet<TruckLoadDetail> TruckLoadDetails { get; set; }
        public DbSet<TruckLoadStatusChange> TruckLoadStatusChanges { get; set; }
        public DbSet<ReportType> ReportTypes { get; set; }
        public DbSet<GeneratedReport> GeneratedReports { get; set; }
        public DbSet<MonthlyHourReport> MonthlyHourReports { get; set; }
        public DbSet<MonthlyHourReportDetail> MonthlyHourReportDetails { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            ConfigureTableNames(modelBuilder);
            ConfigureIndexes(modelBuilder);
            ConfigureRelationships(modelBuilder);
        }

        private static void ConfigureTableNames(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<Country>().ToTable("Countries");
            modelBuilder.Entity<City>().ToTable("Cities");
            modelBuilder.Entity<CompanyType>().ToTable("CompanyTypes");
            modelBuilder.Entity<Company>().ToTable("Companies");

            modelBuilder.Entity<UserType>().ToTable("UserTypes");
            modelBuilder.Entity<User>().ToTable("Users");
            modelBuilder.Entity<RefreshToken>().ToTable("RefreshTokens");
            modelBuilder.Entity<OperationType>().ToTable("OperationTypes");
            modelBuilder.Entity<UserOperation>().ToTable("UserOperations");

            modelBuilder.Entity<ActivityLogType>().ToTable("ActivityLogTypes");
            modelBuilder.Entity<ActivityLog>().ToTable("ActivityLogs");
            modelBuilder.Entity<Notification>().ToTable("Notifications");
            modelBuilder.Entity<NotificationType>().ToTable("NotificationTypes");

            modelBuilder.Entity<ProjectCategory>().ToTable("ProjectCategories");
            modelBuilder.Entity<ProjectStatusType>().ToTable("ProjectStatusTypes");
            modelBuilder.Entity<TruckLoadStatusType>().ToTable("TruckLoadStatusTypes");
            modelBuilder.Entity<Project>().ToTable("Projects");
            modelBuilder.Entity<ProjectStatusChange>().ToTable("ProjectStatusChanges");

            modelBuilder.Entity<WorkLog>().ToTable("WorkLogs");
            modelBuilder.Entity<WorkLogDetail>().ToTable("WorkLogDetails");
            modelBuilder.Entity<WorkHoursChange>().ToTable("WorkHoursChanges");

            modelBuilder.Entity<TruckLoad>().ToTable("TruckLoads");
            modelBuilder.Entity<TruckLoadDetail>().ToTable("TruckLoadDetails");
            modelBuilder.Entity<TruckLoadStatusChange>().ToTable("TruckLoadStatusChanges");

            modelBuilder.Entity<ReportType>().ToTable("ReportTypes");
            modelBuilder.Entity<GeneratedReport>().ToTable("GeneratedReports");
            modelBuilder.Entity<MonthlyHourReport>().ToTable("MonthlyHourReports");
            modelBuilder.Entity<MonthlyHourReportDetail>().ToTable("MonthlyHourReportDetails");
        }

        private static void ConfigureIndexes(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<Country>().HasIndex(x => x.Code).IsUnique();
            modelBuilder.Entity<CompanyType>().HasIndex(x => x.Name).IsUnique();

            modelBuilder.Entity<User>().HasIndex(x => x.Email).IsUnique();
            modelBuilder.Entity<User>().HasIndex(x => x.Username).IsUnique();
            modelBuilder.Entity<UserType>().HasIndex(x => x.Type).IsUnique();
            modelBuilder.Entity<RefreshToken>().HasIndex(x => x.Token).IsUnique();
            modelBuilder.Entity<OperationType>().HasIndex(x => x.Name).IsUnique();

            modelBuilder.Entity<UserOperation>()
                .HasIndex(x => new { x.UserId, x.OperationTypeId })
                .IsUnique();

            modelBuilder.Entity<ActivityLogType>().HasIndex(x => x.Name).IsUnique();
            modelBuilder.Entity<NotificationType>().HasIndex(x => x.Name).IsUnique();
            modelBuilder.Entity<ProjectCategory>().HasIndex(x => x.Name).IsUnique();
            modelBuilder.Entity<ProjectStatusType>().HasIndex(x => x.Name).IsUnique();
            modelBuilder.Entity<TruckLoadStatusType>().HasIndex(x => x.Name).IsUnique();

            modelBuilder.Entity<TruckLoad>().HasIndex(x => x.LoadDate);
            modelBuilder.Entity<ReportType>().HasIndex(x => x.Description).IsUnique();

            // Fixed rows whose Ids mirror pwm.Model.Enums.ReportType, so they are
            // written as given rather than handed out by an identity column.
            modelBuilder.Entity<ReportType>().Property(x => x.Id).ValueGeneratedNever();
            modelBuilder.Entity<WorkLog>().HasIndex(x => new { x.UserId, x.ClockedIn });

            modelBuilder.Entity<MonthlyHourReport>()
                .HasIndex(x => new { x.Year, x.Month })
                .IsUnique();

            modelBuilder.Entity<MonthlyHourReportDetail>()
                .HasIndex(x => new { x.MonthlyHourReportId, x.UserId })
                .IsUnique();
        }

        private static void ConfigureRelationships(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<City>()
                .HasOne(x => x.Country)
                .WithMany()
                .HasForeignKey(x => x.CountryId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<Company>()
                .HasOne(x => x.Country)
                .WithMany()
                .HasForeignKey(x => x.CountryId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<Company>()
                .HasOne(x => x.City)
                .WithMany()
                .HasForeignKey(x => x.CityId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<Company>()
                .HasOne(x => x.CompanyType)
                .WithMany()
                .HasForeignKey(x => x.CompanyTypeId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<User>()
                .HasOne(x => x.UserType)
                .WithMany()
                .HasForeignKey(x => x.UserTypeId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<RefreshToken>()
                .HasOne(x => x.User)
                .WithMany()
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<UserOperation>()
                .HasOne(x => x.User)
                .WithMany()
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<UserOperation>()
                .HasOne(x => x.OperationType)
                .WithMany()
                .HasForeignKey(x => x.OperationTypeId)
                .OnDelete(DeleteBehavior.Restrict);

            // Restrict, not Cascade: an ActivityLog row is an audit trail entry, not
            // personal data that should vanish with the account. Hard-deleting a User
            // who has ever done anything logged (sent a notification, signed in, and
            // so on) is refused rather than silently erasing that history - the app
            // already steers the office toward deactivating an account instead.
            modelBuilder.Entity<ActivityLog>()
                .HasOne(x => x.User)
                .WithMany()
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<ActivityLog>()
                .HasOne(x => x.ActivityLogType)
                .WithMany()
                .HasForeignKey(x => x.ActivityLogTypeId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<ActivityLog>()
                .HasOne(x => x.GeneratedReport)
                .WithMany()
                .HasForeignKey(x => x.GeneratedReportId)
                .IsRequired(false)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<Notification>()
                .HasOne(x => x.User)
                .WithMany()
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<Notification>()
                .HasOne(x => x.NotificationType)
                .WithMany()
                .HasForeignKey(x => x.NotificationTypeId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<Project>()
                .HasOne(x => x.Customer)
                .WithMany()
                .HasForeignKey(x => x.CustomerId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<Project>()
                .HasOne(x => x.DeliveryCompany)
                .WithMany()
                .HasForeignKey(x => x.DeliveryCompanyId)
                .IsRequired(false)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<Project>()
                .HasOne(x => x.ProjectCategory)
                .WithMany()
                .HasForeignKey(x => x.ProjectCategoryId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<Project>()
                .HasOne(x => x.ProjectStatus)
                .WithMany()
                .HasForeignKey(x => x.ProjectStatusId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<Project>()
                .HasOne(x => x.CreatedBy)
                .WithMany()
                .HasForeignKey(x => x.CreatedByUserId)
                .OnDelete(DeleteBehavior.Restrict);

            // Restrict: a project is never deleted (it ends as Delivered or
            // Rejected), so its status history - the audit trail - can never be
            // taken away with it either.
            modelBuilder.Entity<ProjectStatusChange>()
                .HasOne(x => x.Project)
                .WithMany()
                .HasForeignKey(x => x.ProjectId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<ProjectStatusChange>()
                .HasOne(x => x.FromStatus)
                .WithMany()
                .HasForeignKey(x => x.FromStatusId)
                .IsRequired(false)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<ProjectStatusChange>()
                .HasOne(x => x.ToStatus)
                .WithMany()
                .HasForeignKey(x => x.ToStatusId)
                .OnDelete(DeleteBehavior.Restrict);

            // Restrict, same reasoning as ActivityLog/WorkLog.User: this is audit
            // history, not personal data that should vanish with the account.
            modelBuilder.Entity<ProjectStatusChange>()
                .HasOne(x => x.ChangedByUser)
                .WithMany()
                .HasForeignKey(x => x.ChangedByUserId)
                .OnDelete(DeleteBehavior.Restrict);

            // Restrict, not Cascade: a WorkLog is a shift the shop paid for, not
            // personal data that should vanish with the account. Hard-deleting a User
            // who has ever clocked in is refused rather than silently erasing their
            // production/payroll history - deactivating the account is the intended path.
            modelBuilder.Entity<WorkLog>()
                .HasOne(x => x.User)
                .WithMany()
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<WorkLogDetail>()
                .HasOne(x => x.WorkLog)
                .WithMany()
                .HasForeignKey(x => x.WorkLogId)
                .OnDelete(DeleteBehavior.Cascade);

            // Also Restrict on its own terms now (WorkLog.User no longer cascades
            // either, so this was never at risk of the old multi-cascade-path SQL
            // Server error 1785 in the first place) - a WorkLogDetail's User is the
            // same protected history WorkLog.User is.
            modelBuilder.Entity<WorkLogDetail>()
                .HasOne(x => x.User)
                .WithMany()
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<WorkLogDetail>()
                .HasOne(x => x.OperationType)
                .WithMany()
                .HasForeignKey(x => x.OperationTypeId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<WorkLogDetail>()
                .HasOne(x => x.Project)
                .WithMany()
                .HasForeignKey(x => x.ProjectId)
                .OnDelete(DeleteBehavior.Restrict);

            // SetNull, not Cascade: deleting a block of work must not take its own
            // history with it - the "Deleted" row is exactly what has to remain.
            modelBuilder.Entity<WorkHoursChange>()
                .HasOne(x => x.WorkLogDetail)
                .WithMany()
                .HasForeignKey(x => x.WorkLogDetailId)
                .IsRequired(false)
                .OnDelete(DeleteBehavior.SetNull);

            // Restrict, as for every other audit trail: history is not personal
            // data that should vanish with an account.
            modelBuilder.Entity<WorkHoursChange>()
                .HasOne(x => x.Worker)
                .WithMany()
                .HasForeignKey(x => x.WorkerId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<WorkHoursChange>()
                .HasOne(x => x.ChangedByUser)
                .WithMany()
                .HasForeignKey(x => x.ChangedByUserId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<GeneratedReport>()
                .HasOne(x => x.ReportType)
                .WithMany()
                .HasForeignKey(x => x.ReportTypeId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<TruckLoad>()
                .HasOne(x => x.TruckLoadStatus)
                .WithMany()
                .HasForeignKey(x => x.TruckLoadStatusId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<TruckLoad>()
                .HasOne(x => x.TransportCompany)
                .WithMany()
                .HasForeignKey(x => x.TransportCompanyId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<TruckLoadDetail>()
                .HasOne(x => x.TruckLoad)
                .WithMany()
                .HasForeignKey(x => x.TruckLoadId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<TruckLoadDetail>()
                .HasOne(x => x.Project)
                .WithMany()
                .HasForeignKey(x => x.ProjectId)
                .OnDelete(DeleteBehavior.Restrict);

            // Restrict, as for projects: a transport is never deleted, so its
            // status history cannot be taken away with it.
            modelBuilder.Entity<TruckLoadStatusChange>()
                .HasOne(x => x.TruckLoad)
                .WithMany()
                .HasForeignKey(x => x.TruckLoadId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<TruckLoadStatusChange>()
                .HasOne(x => x.FromStatus)
                .WithMany()
                .HasForeignKey(x => x.FromStatusId)
                .IsRequired(false)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<TruckLoadStatusChange>()
                .HasOne(x => x.ToStatus)
                .WithMany()
                .HasForeignKey(x => x.ToStatusId)
                .OnDelete(DeleteBehavior.Restrict);

            // Restrict, same reasoning as ProjectStatusChange.ChangedByUser: this
            // is audit history, not personal data that should vanish with the account.
            modelBuilder.Entity<TruckLoadStatusChange>()
                .HasOne(x => x.ChangedByUser)
                .WithMany()
                .HasForeignKey(x => x.ChangedByUserId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<MonthlyHourReportDetail>()
                .HasOne(x => x.MonthlyHourReport)
                .WithMany()
                .HasForeignKey(x => x.MonthlyHourReportId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<MonthlyHourReportDetail>()
                .HasOne(x => x.User)
                .WithMany()
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.Restrict);
        }
    }
}
