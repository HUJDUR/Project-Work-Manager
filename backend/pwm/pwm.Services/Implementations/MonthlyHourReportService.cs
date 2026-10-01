using MapsterMapper;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Database;
using pwm.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using pwm.Common.Services.Time;

namespace pwm.Services.Implementations
{
    public class MonthlyHourReportService
        : BaseReadService<MonthlyHourReport, MonthlyHourReportResponse, MonthlyHourReportSearchObject>, IMonthlyHourReportService
    {
        public MonthlyHourReportService(PWMDbContext dbContext, IMapper mapper)
            : base(mapper, dbContext)
        {
        }

        /// <summary>
        /// One month opened: its totals, every worker's hours (kept up to date by
        /// <c>MonthlyHourSummary</c>), and the hours per work type across all workers,
        /// grouped straight from the month's blocks of work.
        /// </summary>
        public async Task<MonthlyHourReportOverviewResponse> GetOverviewAsync(int id)
        {
            var month = await GetByIdAsync(id);

            var first = new DateTime(month.Year, month.Month, 1);
            var from = SarajevoTime.StartOfDayUtc(first);
            var to = SarajevoTime.StartOfDayUtc(first.AddMonths(1));

            return new MonthlyHourReportOverviewResponse
            {
                Month = month,
                Workers = await _dbContext.MonthlyHourReportDetails
                    .Where(x => x.MonthlyHourReportId == id)
                    .OrderBy(x => x.User.Surname).ThenBy(x => x.User.Name)
                    .Select(x => new MonthlyHourReportWorkerResponse
                    {
                        UserId = x.UserId,
                        WorkerName = (x.User.Name + " " + x.User.Surname).Trim(),
                        DaysWorked = x.DaysWorked,
                        RegularHours = x.RegularHours,
                        OvertimeHours = x.OvertimeHours,
                        TotalHours = x.TotalHours,
                    })
                    .ToListAsync(),
                Operations = await _dbContext.WorkLogDetails
                    .Where(x => x.StartedAt >= from && x.StartedAt < to)
                    .GroupBy(x => x.OperationType.Name)
                    .Select(g => new MonthlyHourReportOperationResponse
                    {
                        OperationName = g.Key,
                        Hours = Math.Round(g.Sum(x => x.Hours), 2),
                    })
                    .OrderByDescending(x => x.Hours)
                    .ToListAsync(),
            };
        }

        protected override IQueryable<MonthlyHourReport> ApplyFilters(IQueryable<MonthlyHourReport> query, MonthlyHourReportSearchObject? search)
        {
            if (search == null)
            {
                return query;
            }

            if (search.Year.HasValue)
            {
                query = query.Where(x => x.Year == search.Year.Value);
            }

            if (search.Month.HasValue)
            {
                query = query.Where(x => x.Month == search.Month.Value);
            }

            return query;
        }
    }
}
