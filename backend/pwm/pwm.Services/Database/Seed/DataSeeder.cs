using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using pwm.Common.Services.CryptoService;

namespace pwm.Services.Database.Seed
{
    /// <summary>
    /// Fills the database with a consistent set of test data.
    /// Run it from the WebAPI with: dotnet run --project pwm.WebAPI -- --seed
    /// </summary>
    public partial class DataSeeder
    {
        // Every seeded user gets this password
        public const string DefaultPassword = "test";

        private readonly PWMDbContext _db;
        private readonly ICryptoService _cryptoService;

        // Anchor for all generated dates, so a seeded database always looks
        // like it has been in use up to today.
        private readonly DateTime _today = DateTime.UtcNow.Date;

        private Country[] _countries = [];
        private City[] _cities = [];
        private CompanyType[] _companyTypes = [];
        private Company[] _companies = [];
        private UserType[] _userTypes = [];
        private User[] _users = [];
        private OperationType[] _operationTypes = [];
        private ActivityLogType[] _activityLogTypes = [];
        private ProjectCategory[] _projectCategories = [];
        private ProjectStatusType[] _projectStatuses = [];
        private Project[] _projects = [];
        private WorkLog[] _workLogs = [];
        private WorkLogDetail[] _workLogDetails = [];
        private TruckLoad[] _truckLoads = [];

        public DataSeeder(PWMDbContext db, ICryptoService cryptoService)
        {
            _db = db;
            _cryptoService = cryptoService;
        }

        /// <summary>
        /// Seeds the database. Does nothing if it already holds data, unless
        /// <paramref name="force"/> is set, in which case every table is emptied first.
        /// </summary>
        public async Task<bool> SeedAsync(bool force = false)
        {
            if (force)
            {
                await ClearAsync();
            }
            else if (await _db.Users.AnyAsync())
            {
                return false;
            }

            await SeedLookupsAsync();
            await SeedCompaniesAsync();
            await SeedUsersAsync();
            await SeedProjectsAsync();
            await SeedWorkLogsAsync();
            await SeedTruckLoadsAsync();
            await SeedMonthlyHourReportsAsync();
            await SeedNotificationsAsync();
            await SeedActivityLogsAsync();

            return true;
        }

        /// <summary>
        /// Empties every table, children first, and restarts the identity counters.
        /// </summary>
        public async Task ClearAsync()
        {
            await _db.ActivityLogs.ExecuteDeleteAsync();
            await _db.Notifications.ExecuteDeleteAsync();
            await _db.MonthlyHourReportDetails.ExecuteDeleteAsync();
            await _db.MonthlyHourReports.ExecuteDeleteAsync();
            await _db.TruckLoadDetails.ExecuteDeleteAsync();
            await _db.TruckLoads.ExecuteDeleteAsync();
            await _db.WorkLogDetails.ExecuteDeleteAsync();
            await _db.WorkLogs.ExecuteDeleteAsync();
            await _db.Projects.ExecuteDeleteAsync();
            await _db.ProjectStatusTypes.ExecuteDeleteAsync();
            await _db.ProjectCategories.ExecuteDeleteAsync();
            await _db.UserOperations.ExecuteDeleteAsync();
            await _db.OperationTypes.ExecuteDeleteAsync();
            await _db.Users.ExecuteDeleteAsync();
            await _db.UserTypes.ExecuteDeleteAsync();
            await _db.ActivityLogTypes.ExecuteDeleteAsync();
            await _db.Companies.ExecuteDeleteAsync();
            await _db.CompanyTypes.ExecuteDeleteAsync();
            await _db.Cities.ExecuteDeleteAsync();
            await _db.Countries.ExecuteDeleteAsync();

            foreach (var table in TableNames())
            {
                await _db.Database.ExecuteSqlAsync(
                    $"IF OBJECTPROPERTY(OBJECT_ID({table}), 'TableHasIdentity') = 1 DBCC CHECKIDENT ({table}, RESEED, 0) WITH NO_INFOMSGS;");
            }
        }

        private IEnumerable<string> TableNames()
        {
            return _db.Model.GetEntityTypes()
                .Select(e => e.GetTableName())
                .Where(name => !string.IsNullOrEmpty(name))
                .Select(name => name!)
                .Distinct();
        }

        private async Task AddRangeAsync<T>(T[] entities) where T : class
        {
            await _db.Set<T>().AddRangeAsync(entities);
            await _db.SaveChangesAsync();
        }

        // Weekdays only, counting back from today
        private DateTime[] WorkingDays(int count)
        {
            var days = new List<DateTime>();
            var day = _today;

            while (days.Count < count)
            {
                if (day.DayOfWeek != DayOfWeek.Saturday && day.DayOfWeek != DayOfWeek.Sunday)
                {
                    days.Add(day);
                }

                day = day.AddDays(-1);
            }

            days.Reverse();
            return days.ToArray();
        }

        // Same hashing the UserService uses, so seeded logins verify
        private (string Hash, string Salt) HashPassword(string password)
        {
            var salt = _cryptoService.GenerateSlat();

            return (_cryptoService.GenerateHash(password, salt), salt);
        }
    }
}
