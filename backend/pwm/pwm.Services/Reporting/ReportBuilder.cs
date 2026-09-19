using Microsoft.EntityFrameworkCore;
using pwm.Model.Requests;
using pwm.Services.Database;

namespace pwm.Services.Reporting
{
    /// <summary>
    /// Renders the actual PDF bytes for a report. Pulled out of <c>ReportService</c>
    /// so <c>pwm.Worker</c> - which is what now calls this, having taken the request
    /// off RabbitMQ - can use the exact same query and layout code the API used to
    /// run inline, rather than a second copy of it.
    /// </summary>
    public class ReportBuilder
    {
        /// <summary>
        /// A worker's day is regular up to this many hours; everything over eight
        /// hours on a date is overtime. The rule lives here, on the server, because
        /// the monthly report and the desktop have to agree about it.
        /// </summary>
        public const double RegularHoursPerDay = 8;

        private readonly PWMDbContext _dbContext;

        public ReportBuilder(PWMDbContext dbContext)
        {
            _dbContext = dbContext;
        }

        public async Task<byte[]> BuildMonthlyWorkHoursAsync(MonthlyWorkHoursReportRequest request)
        {
            var from = new DateTime(request.Year, request.Month, 1);
            var to = from.AddMonths(1);

            var blocks = await _dbContext.WorkLogDetails
                .Include(x => x.WorkLog).ThenInclude(x => x.User)
                .Include(x => x.Project)
                .Include(x => x.OperationType)
                .Where(x => x.StartedAt >= from && x.StartedAt < to)
                .Where(x => request.UserId == null || x.WorkLog.UserId == request.UserId)
                .Where(x => request.ProjectId == null || x.ProjectId == request.ProjectId)
                .OrderBy(x => x.StartedAt)
                .ToListAsync();

            var rows = SplitRegularAndOvertime(blocks)
                .GroupBy(x => x.Block.WorkLog.User)
                .Select(worker => new MonthlyWorkHoursRow
                {
                    WorkerName = $"{worker.Key.Name} {worker.Key.Surname}".Trim(),
                    RegularHours = Round(worker.Sum(x => x.Regular)),
                    OvertimeHours = Round(worker.Sum(x => x.Overtime)),
                    ByProject = worker
                        .GroupBy(x => x.Block.Project.Name)
                        .Select(project => new MonthlyWorkHoursProjectRow
                        {
                            ProjectName = project.Key,
                            Hours = Round(project.Sum(x => x.Block.Hours)),
                        })
                        .OrderByDescending(project => project.Hours)
                        .ToList(),
                })
                .OrderBy(row => row.WorkerName)
                .ToList();

            var worker = request.UserId is null
                ? "All workers"
                : await NameOfUserAsync(request.UserId.Value);
            var project = request.ProjectId is null
                ? "All projects"
                : await NameOfProjectAsync(request.ProjectId.Value);

            return MonthlyWorkHoursDocument.Render(from, worker, project, rows);
        }

        public async Task<byte[]> BuildTransportLoadsAsync(TransportLoadsReportRequest request)
        {
            var details = await _dbContext.TruckLoadDetails
                .Include(x => x.TruckLoad).ThenInclude(x => x.TransportCompany)
                .Include(x => x.TruckLoad).ThenInclude(x => x.TruckLoadStatus)
                .Include(x => x.Project)
                .Where(x => request.ProjectId == null || x.ProjectId == request.ProjectId)
                .Where(x => request.DateFrom == null || x.TruckLoad.LoadDate >= request.DateFrom)
                .Where(x => request.DateTo == null || x.TruckLoad.LoadDate <= request.DateTo)
                .OrderByDescending(x => x.TruckLoad.LoadDate)
                .ToListAsync();

            var rows = details
                .Select(detail => new TransportLoadRow
                {
                    LoadDate = detail.TruckLoad.LoadDate,
                    ProjectName = detail.Project.Name,
                    ProjectCode = detail.Project.Code,
                    CarrierName = detail.TruckLoad.TransportCompany.Name,
                    DriverName =
                        $"{detail.TruckLoad.DriverName} {detail.TruckLoad.DriverSurname}".Trim(),
                    VehicleRegistration = detail.TruckLoad.VehicleRegistration,
                    NetWeight = detail.NetoWeight,
                    Status = detail.TruckLoad.TruckLoadStatus.Name,
                })
                .ToList();

            var project = request.ProjectId is null
                ? "All projects"
                : await NameOfProjectAsync(request.ProjectId.Value);

            return TransportLoadsDocument.Render(
                request.DateFrom, request.DateTo, project, rows);
        }

        /// <summary>
        /// Walks each worker's day in start order, handing out the first eight hours as
        /// regular and everything after as overtime. A block that straddles the boundary
        /// is split across both.
        /// </summary>
        private static IEnumerable<(WorkLogDetail Block, double Regular, double Overtime)>
            SplitRegularAndOvertime(IEnumerable<WorkLogDetail> blocks)
        {
            var usedPerWorkerDay = new Dictionary<(int UserId, DateTime Day), double>();

            foreach (var block in blocks.OrderBy(x => x.StartedAt))
            {
                var key = (block.WorkLog.UserId, block.StartedAt.Date);
                var used = usedPerWorkerDay.GetValueOrDefault(key);

                var regular = Math.Clamp(RegularHoursPerDay - used, 0, block.Hours);
                usedPerWorkerDay[key] = used + block.Hours;

                yield return (block, regular, block.Hours - regular);
            }
        }

        private static double Round(double value) => Math.Round(value, 2);

        private async Task<string> NameOfUserAsync(int id)
        {
            var user = await _dbContext.Users.FirstOrDefaultAsync(x => x.Id == id);

            return user is null ? $"User {id}" : $"{user.Name} {user.Surname}".Trim();
        }

        private async Task<string> NameOfProjectAsync(int id)
        {
            var project = await _dbContext.Projects.FirstOrDefaultAsync(x => x.Id == id);

            return project is null ? $"Project {id}" : $"{project.Code} - {project.Name}";
        }
    }
}
