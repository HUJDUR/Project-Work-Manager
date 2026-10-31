using Microsoft.EntityFrameworkCore;
using pwm.Model.Requests;
using pwm.Services.Database;
using pwm.Common.Services.Time;

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
        private readonly PWMDbContext _dbContext;

        public ReportBuilder(PWMDbContext dbContext)
        {
            _dbContext = dbContext;
        }

        public async Task<byte[]> BuildMonthlyWorkHoursAsync(MonthlyWorkHoursReportRequest request)
        {
            // The month as the shop lives it: Sarajevo midnight to Sarajevo midnight.
            var month = new DateTime(request.Year, request.Month, 1);
            var from = SarajevoTime.StartOfDayUtc(month);
            var to = SarajevoTime.StartOfDayUtc(month.AddMonths(1));

            var blocks = await _dbContext.WorkLogDetails
                .Include(x => x.WorkLog).ThenInclude(x => x.User)
                .Include(x => x.Project)
                .Include(x => x.OperationType)
                .Where(x => x.StartedAt >= from && x.StartedAt < to)
                .Where(x => request.UserId == null || x.WorkLog.UserId == request.UserId)
                .Where(x => request.ProjectId == null || x.ProjectId == request.ProjectId)
                .OrderBy(x => x.StartedAt)
                .ToListAsync();

            // Each block's regular part as MonthlyHourSummary stored it, worked out over
            // the worker's whole day - not just the blocks of the project picked here,
            // so this PDF agrees with the Work Hours and Monthly Reports screens.
            var rows = blocks
                .GroupBy(x => x.WorkLog.User)
                .Select(worker => new MonthlyWorkHoursRow
                {
                    WorkerName = $"{worker.Key.Name} {worker.Key.Surname}".Trim(),
                    RegularHours = Round(worker.Sum(x => x.RegularHours)),
                    OvertimeHours = Round(worker.Sum(x => x.Hours - x.RegularHours)),
                })
                .OrderBy(row => row.WorkerName)
                .ToList();

            // Every worker's hours for a work type, added together - not one line per
            // worker, and not split out by project.
            var operationTotals = blocks
                .GroupBy(x => x.OperationType.Name)
                .Select(operation => new MonthlyWorkHoursOperationRow
                {
                    OperationTypeName = operation.Key,
                    Hours = Round(operation.Sum(x => x.Hours)),
                })
                .OrderByDescending(operation => operation.Hours)
                .ToList();

            var worker = request.UserId is null
                ? "All workers"
                : await NameOfUserAsync(request.UserId.Value);
            var project = request.ProjectId is null
                ? "All projects"
                : await NameOfProjectAsync(request.ProjectId.Value);

            return MonthlyWorkHoursDocument.Render(month, worker, project, rows, operationTotals);
        }

        public async Task<byte[]> BuildTransportLoadsAsync(TransportLoadsReportRequest request)
        {
            // Whole Sarajevo days, the last one included.
            DateTime? firstDay = request.DateFrom is { } dateFrom ? SarajevoTime.DayOf(dateFrom) : null;
            DateTime? lastDay = request.DateTo is { } dateTo ? SarajevoTime.DayOf(dateTo) : null;
            DateTime? from = firstDay is { } first ? SarajevoTime.StartOfDayUtc(first) : null;
            DateTime? toExclusive = lastDay is { } last ? SarajevoTime.StartOfDayUtc(last.AddDays(1)) : null;

            var details = await _dbContext.TruckLoadDetails
                .Include(x => x.TruckLoad).ThenInclude(x => x.TransportCompany)
                .Include(x => x.TruckLoad).ThenInclude(x => x.TruckLoadStatus)
                .Include(x => x.Project)
                .Where(x => request.ProjectId == null || x.ProjectId == request.ProjectId)
                .Where(x => from == null || x.TruckLoad.LoadDate >= from)
                .Where(x => toExclusive == null || x.TruckLoad.LoadDate < toExclusive)
                .OrderByDescending(x => x.TruckLoad.LoadDate)
                .ToListAsync();

            var rows = details
                .GroupBy(x => x.TruckLoadId)
                .Select(transport =>
                {
                    var truckLoad = transport.First().TruckLoad;

                    return new TransportOverviewRow
                    {
                        LoadDate = SarajevoTime.FromUtc(truckLoad.LoadDate),
                        CarrierName = truckLoad.TransportCompany.Name,
                        DriverName = $"{truckLoad.DriverName} {truckLoad.DriverSurname}".Trim(),
                        VehicleRegistration = truckLoad.VehicleRegistration,
                        Status = truckLoad.TruckLoadStatus.Name,
                        BrutoWeight = Round(transport.Sum(x => x.BrutoWeight)),
                        NetoWeight = Round(transport.Sum(x => x.NetoWeight)),
                        Projects = transport
                            .Select(detail => new TransportProjectRow
                            {
                                ProjectName = detail.Project.Name,
                                ProjectCode = detail.Project.Code,
                                BrutoWeight = Round(detail.BrutoWeight),
                                NetoWeight = Round(detail.NetoWeight),
                            })
                            .OrderByDescending(project => project.NetoWeight)
                            .ToList(),
                    };
                })
                .OrderByDescending(row => row.LoadDate)
                .ToList();

            var project = request.ProjectId is null
                ? "All projects"
                : await NameOfProjectAsync(request.ProjectId.Value);

            return TransportLoadsDocument.Render(firstDay, lastDay, project, rows);
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
