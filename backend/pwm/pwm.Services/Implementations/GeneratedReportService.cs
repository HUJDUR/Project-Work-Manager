using MapsterMapper;
using Microsoft.EntityFrameworkCore;
using pwm.Model.Access;
using pwm.Model.Exceptions;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Database;
using pwm.Services.Interfaces;
using ReportKind = pwm.Model.Enums.ReportType;

namespace pwm.Services.Implementations
{
    /// <summary>
    /// The "Recent Reports" list. Who ran a report and when is the <see cref="ActivityLog"/>
    /// entry <c>ReportService</c> writes with it, joined in here - so the Reports screen
    /// gets it without reading the activity log, which only an admin may.
    /// </summary>
    public class GeneratedReportService
        : BaseReadService<GeneratedReport, GeneratedReportResponse, GeneratedReportSearchObject>, IGeneratedReportService
    {
        private readonly ICurrentUser _currentUser;

        public GeneratedReportService(PWMDbContext dbContext, IMapper mapper, ICurrentUser currentUser)
            : base(mapper, dbContext)
        {
            _currentUser = currentUser;
        }

        /// <summary>Lists never carry the PDF itself - only what the list shows.</summary>
        protected override IQueryable<GeneratedReportResponse> ProjectForList(IQueryable<GeneratedReport> query) =>
            query.Select(x => new
                {
                    Report = x,
                    Run = _dbContext.ActivityLogs
                        .Where(a => a.GeneratedReportId == x.Id)
                        .OrderBy(a => a.Date)
                        .Select(a => new { a.UserId, a.User.Name, a.User.Surname, a.Date })
                        .FirstOrDefault(),
                })
                .Select(x => new GeneratedReportResponse
                {
                    Id = x.Report.Id,
                    ReportTypeId = x.Report.ReportTypeId,
                    Parameters = x.Report.Parameters,
                    Status = x.Report.Status.ToString(),
                    ErrorMessage = x.Report.ErrorMessage,
                    GeneratedByUserId = x.Run == null ? null : x.Run.UserId,
                    GeneratedByName = x.Run == null ? null : (x.Run.Name + " " + x.Run.Surname).Trim(),
                    GeneratedAt = x.Run == null ? null : x.Run.Date,
                });

        public override async Task<GeneratedReportResponse> GetByIdAsync(int id)
        {
            var report = await ProjectForList(ApplyFilters(_dbContext.GeneratedReports.Where(x => x.Id == id), null))
                .FirstOrDefaultAsync();

            return report ?? throw new NotFoundException($"GeneratedReport with id {id} not found.");
        }

        /// <summary>
        /// A project manager runs transport reports only, so the monthly hours reports
        /// - whose parameters name a worker - are not theirs to list either; the same
        /// rule <c>ReportService</c> applies to downloading one.
        /// </summary>
        protected override IQueryable<GeneratedReport> ApplyFilters(IQueryable<GeneratedReport> query, GeneratedReportSearchObject? search)
        {
            if (_currentUser.Role == Roles.ProjectManager)
            {
                query = query.Where(x => x.ReportTypeId != (int)ReportKind.MonthlyWorkHours);
            }

            if (search?.ReportTypeId is { } reportTypeId)
            {
                query = query.Where(x => x.ReportTypeId == reportTypeId);
            }

            return query;
        }
    }
}
