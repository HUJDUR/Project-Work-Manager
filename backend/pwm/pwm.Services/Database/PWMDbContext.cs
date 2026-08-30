using System;
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
        public DbSet<ProjectCategory> ProjectCategories { get; set; }
        public DbSet<ProjectStatusType> ProjectStatusTypes { get; set; }
        public DbSet<Project> Projects { get; set; }
        public DbSet<WorkLog> WorkLogs { get; set; }
        public DbSet<WorkLogDetail> WorkLogDetails { get; set; }
        public DbSet<TruckLoad> TruckLoads { get; set; }
        public DbSet<TruckLoadDetail> TruckLoadDetails { get; set; }
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

            modelBuilder.Entity<ProjectCategory>().ToTable("ProjectCategories");
            modelBuilder.Entity<ProjectStatusType>().ToTable("ProjectStatusTypes");
            modelBuilder.Entity<Project>().ToTable("Projects");

            modelBuilder.Entity<WorkLog>().ToTable("WorkLogs");
            modelBuilder.Entity<WorkLogDetail>().ToTable("WorkLogDetails");

            modelBuilder.Entity<TruckLoad>().ToTable("TruckLoads");
            modelBuilder.Entity<TruckLoadDetail>().ToTable("TruckLoadDetails");

            modelBuilder.Entity<MonthlyHourReport>().ToTable("MonthlyHourReports");
            modelBuilder.Entity<MonthlyHourReportDetail>().ToTable("MonthlyHourReportDetails");
        }

        private static void ConfigureIndexes(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<Country>().HasIndex(x => x.Code).IsUnique();
            modelBuilder.Entity<CompanyType>().HasIndex(x => x.Name).IsUnique();

            modelBuilder.Entity<User>().HasIndex(x => x.Email).IsUnique();
            modelBuilder.Entity<UserType>().HasIndex(x => x.Type).IsUnique();
            modelBuilder.Entity<RefreshToken>().HasIndex(x => x.Token).IsUnique();
            modelBuilder.Entity<OperationType>().HasIndex(x => x.Name).IsUnique();

            modelBuilder.Entity<UserOperation>()
                .HasIndex(x => new { x.UserId, x.OperationTypeId })
                .IsUnique();

            modelBuilder.Entity<ActivityLogType>().HasIndex(x => x.Name).IsUnique();
            modelBuilder.Entity<ProjectCategory>().HasIndex(x => x.Name).IsUnique();
            modelBuilder.Entity<ProjectStatusType>().HasIndex(x => x.Name).IsUnique();

            modelBuilder.Entity<TruckLoad>().HasIndex(x => x.LoadDate);
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

            modelBuilder.Entity<ActivityLog>()
                .HasOne(x => x.User)
                .WithMany()
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<ActivityLog>()
                .HasOne(x => x.ActivityLogType)
                .WithMany()
                .HasForeignKey(x => x.ActivityLogTypeId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<Notification>()
                .HasOne(x => x.User)
                .WithMany()
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.Cascade);

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

            modelBuilder.Entity<WorkLog>()
                .HasOne(x => x.User)
                .WithMany()
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<WorkLogDetail>()
                .HasOne(x => x.WorkLog)
                .WithMany()
                .HasForeignKey(x => x.WorkLogId)
                .OnDelete(DeleteBehavior.Cascade);

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
