using Microsoft.EntityFrameworkCore;
using pwm.Common.Services.CryptoService;
using pwm.Common.Services.Time;

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
        // like it has been in use up to today. Sarajevo's today: every date the
        // seeder makes up is Sarajevo wall-clock time until AddRangeAsync stores it.
        private readonly DateTime _today = SarajevoTime.Today;

        private Country[] _countries = [];
        private City[] _cities = [];
        private CompanyType[] _companyTypes = [];
        private Company[] _companies = [];
        private UserType[] _userTypes = [];
        private User[] _users = [];
        private byte[][] _pictures = [];
        private OperationType[] _operationTypes = [];
        private ActivityLogType[] _activityLogTypes = [];
        private ProjectCategory[] _projectCategories = [];
        private ProjectStatusType[] _projectStatuses = [];
        private TruckLoadStatusType[] _truckLoadStatuses = [];
        private ReportType[] _reportTypes = [];
        private GeneratedReport[] _generatedReports = [];
        private Notification[] _notifications = [];
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
            await SeedStatusHistoryAsync();
            await SeedMonthlyHourReportsAsync();
            await SeedGeneratedReportsAsync();
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
            await _db.GeneratedReports.ExecuteDeleteAsync();
            await _db.ReportTypes.ExecuteDeleteAsync();
            await _db.MonthlyHourReportDetails.ExecuteDeleteAsync();
            await _db.MonthlyHourReports.ExecuteDeleteAsync();
            await _db.TruckLoadStatusChanges.ExecuteDeleteAsync();
            await _db.TruckLoadDetails.ExecuteDeleteAsync();
            await _db.TruckLoads.ExecuteDeleteAsync();
            await _db.TruckLoadStatusTypes.ExecuteDeleteAsync();
            await _db.WorkLogDetails.ExecuteDeleteAsync();
            await _db.WorkLogs.ExecuteDeleteAsync();
            await _db.ProjectStatusChanges.ExecuteDeleteAsync();
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
            foreach (var entity in entities)
            {
                StoreDatesAsUtc(entity);
            }

            await _db.Set<T>().AddRangeAsync(entities);
            await _db.SaveChangesAsync();
        }

        /// <summary>
        /// The seeder writes its dates the way the shop reads them - "07:00 on a
        /// weekday" is 07:00 in Sarajevo - and the database stores UTC, so every
        /// date is converted once, here, on its way in. A value that is already UTC
        /// (one taken from <see cref="DateTime.UtcNow"/>, or copied from a row this
        /// has already stored) is left alone, which is what its Kind says.
        /// </summary>
        private static void StoreDatesAsUtc(object entity)
        {
            foreach (var property in entity.GetType().GetProperties())
            {
                if (!property.CanWrite
                    || (property.PropertyType != typeof(DateTime) && property.PropertyType != typeof(DateTime?)))
                {
                    continue;
                }

                if (property.GetValue(entity) is DateTime value && value.Kind != DateTimeKind.Utc)
                {
                    property.SetValue(entity, SarajevoTime.ToUtc(value));
                }
            }
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

        /// <summary>
        /// One deterministic source of randomness for everything the seeder makes up,
        /// so a reseeded database always holds the same numbers.
        /// </summary>
        private readonly Random _random = new(20260826);

        private T Pick<T>(IReadOnlyList<T> items) => items[_random.Next(items.Count)];

        private static readonly string[] PictureFileNames =
        [
            "Male 1.jpg", "Male 2.jpg", "Female 1.jpg", "Female 2.jpg",
        ];

        /// <summary>
        /// Reads the four stand-in avatars from <c>Database/Pictures</c>. Searches
        /// upward from the working directory - like <c>EnvironmentConfig.LoadDotEnvFile</c>
        /// - since <c>dotnet run --project</c> and an IDE's own launch profile do not
        /// agree on what that directory is. Returns empty if the folder cannot be
        /// found, in which case seeded users simply get no picture.
        /// </summary>
        private static byte[][] LoadPictures()
        {
            for (var directory = new DirectoryInfo(Directory.GetCurrentDirectory());
                directory != null;
                directory = directory.Parent)
            {
                var candidate = Path.Combine(directory.FullName, "pwm.Services", "Database", "Pictures");
                if (!Directory.Exists(candidate))
                {
                    continue;
                }

                return PictureFileNames
                    .Select(name => File.ReadAllBytes(Path.Combine(candidate, name)))
                    .ToArray();
            }

            return [];
        }

        // Same hashing the UserService uses, so seeded logins verify
        private (string Hash, string Salt) HashPassword(string password)
        {
            var salt = _cryptoService.GenerateSalt();

            return (_cryptoService.GenerateHash(password, salt), salt);
        }
    }
}
