using Microsoft.EntityFrameworkCore;
using pwm.Model.Access;
using pwm.Model.Responses;
using pwm.Services.Business;
using pwm.Services.Database;
using pwm.Services.Interfaces;
using pwm.Common.Services.Time;

namespace pwm.Services.Implementations
{
    /// <summary>
    /// The Dashboard's numbers, charts and short lists, each one query - counts and
    /// sums in SQL, the charts as <c>GroupBy</c> - so the desktop makes one request
    /// instead of downloading the tables behind them.
    /// </summary>
    public class DashboardService : IDashboardService
    {
        public const int WindowDays = 30;

        private const int ListLength = 5;
        private const int ProjectsInChart = 6;
        private const int OperationsInChart = 6;

        private readonly PWMDbContext _dbContext;

        public DashboardService(PWMDbContext dbContext)
        {
            _dbContext = dbContext;
        }

        public async Task<DashboardResponse> GetAsync(bool includeActivity)
        {
            var windowStart = SarajevoTime.StartOfDayUtc(SarajevoTime.Today.AddDays(-WindowDays));

            var recentWork = _dbContext.WorkLogDetails.Where(x => x.StartedAt > windowStart);
            var recentLoads = _dbContext.TruckLoads.Where(x => x.LoadDate > windowStart);

            var byOperation = await recentWork
                .GroupBy(x => x.OperationType.Name)
                .Select(g => new DashboardSliceResponse { Label = g.Key, Value = g.Sum(x => x.Hours) })
                .OrderByDescending(x => x.Value)
                .ToListAsync();

            return new DashboardResponse
            {
                WindowDays = WindowDays,
                HoursLogged = await recentWork.SumAsync(x => x.Hours),
                ActiveProjects = await _dbContext.Projects.CountAsync(x =>
                    x.ProjectStatus.Name != ProjectStatusRules.Delivered
                    && x.ProjectStatus.Name != ProjectStatusRules.Rejected),
                InProduction = await _dbContext.Projects.CountAsync(x =>
                    x.ProjectStatus.Name == ProjectStatusRules.InProduction),
                ActiveWorkers = await _dbContext.Users.CountAsync(x =>
                    x.IsActive && x.UserType.Type == Roles.ProductionWorker),
                WorkersWithBookings = await recentWork.Select(x => x.WorkLog.UserId).Distinct().CountAsync(),
                Transports = await recentLoads.CountAsync(),
                ShippedWeight = await recentLoads.SumAsync(x =>
                    x.FullWeight > x.EmptyWeight ? x.FullWeight - x.EmptyWeight : 0),
                HoursByProject = await recentWork
                    .GroupBy(x => new { x.ProjectId, x.Project.Name, x.Project.Code })
                    .Select(g => new DashboardSliceResponse
                    {
                        Label = g.Key.Name,
                        ShortLabel = g.Key.Code,
                        Value = g.Sum(x => x.Hours),
                    })
                    .OrderByDescending(x => x.Value)
                    .Take(ProjectsInChart)
                    .ToListAsync(),
                HoursByOperation = TopWithRemainder(byOperation, OperationsInChart),
                RecentWork = await RecentWorkAsync(),
                RecentTransports = await _dbContext.TruckLoads
                    .OrderByDescending(x => x.LoadDate)
                    .Take(ListLength)
                    .Select(x => new DashboardTransportResponse
                    {
                        DriverName = (x.DriverName + " " + x.DriverSurname).Trim(),
                        VehicleRegistration = x.VehicleRegistration,
                        CarrierName = x.TransportCompany.Name,
                        LoadDate = x.LoadDate,
                        NetWeight = x.FullWeight > x.EmptyWeight ? x.FullWeight - x.EmptyWeight : 0,
                    })
                    .ToListAsync(),
                RecentActivity = includeActivity
                    ? await _dbContext.ActivityLogs
                        .OrderByDescending(x => x.Date)
                        .Take(ListLength)
                        .Select(x => new DashboardActivityResponse
                        {
                            Title = x.ActivityLogType.Name,
                            ActorName = (x.User.Name + " " + x.User.Surname).Trim(),
                            Date = x.Date,
                        })
                        .ToListAsync()
                    : [],
            };
        }

        private async Task<List<DashboardWorkResponse>> RecentWorkAsync()
        {
            var rows = await _dbContext.WorkLogDetails
                .OrderByDescending(x => x.StartedAt)
                .Take(ListLength)
                .Select(x => new
                {
                    x.WorkLog.User.Name,
                    x.WorkLog.User.Surname,
                    ProjectName = x.Project.Name,
                    OperationName = x.OperationType.Name,
                    x.Hours,
                    x.StartedAt,
                })
                .ToListAsync();

            return rows
                .Select(x => new DashboardWorkResponse
                {
                    WorkerName = $"{x.Name} {x.Surname}".Trim(),
                    WorkerInitials = Initials(x.Name, x.Surname),
                    ProjectName = x.ProjectName,
                    OperationName = x.OperationName,
                    Hours = x.Hours,
                    StartedAt = x.StartedAt,
                })
                .ToList();
        }

        /// <summary>The largest <paramref name="limit"/> slices, the rest folded into
        /// "Other" - unless that would fold away just one slice.</summary>
        private static List<DashboardSliceResponse> TopWithRemainder(List<DashboardSliceResponse> ranked, int limit)
        {
            if (ranked.Count <= limit + 1)
            {
                return ranked;
            }

            return
            [
                .. ranked.Take(limit),
                new DashboardSliceResponse { Label = "Other", Value = ranked.Skip(limit).Sum(x => x.Value) },
            ];
        }

        private static string Initials(string name, string surname)
        {
            var initials = string.Concat(name.Take(1).Concat(surname.Take(1))).ToUpperInvariant();
            return initials.Length == 0 ? "?" : initials;
        }
    }
}
