using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using ReportKind = pwm.Model.Enums.ReportType;
using pwm.Common.Services.Time;
using pwm.Model.Access;
using pwm.Model.Enums;
using pwm.Model.Exceptions;
using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Services.Database;
using pwm.Services.Interfaces;
using pwm.Services.Messaging;

namespace pwm.Services.Implementations
{
    /// <summary>
    /// Queues a report and records the run; <c>pwm.Worker</c> is the separate
    /// process - off RabbitMQ, never in this one - that actually renders the PDF.
    /// See <c>pwm.Services.Reporting.ReportBuilder</c> for that half of the work,
    /// and <c>GeneratedReport.Status</c> for the state a row moves through.
    /// </summary>
    public class ReportService : IReportService
    {
        private readonly PWMDbContext _dbContext;
        private readonly IReportQueuePublisher _publisher;

        public ReportService(PWMDbContext dbContext, IReportQueuePublisher publisher)
        {
            _dbContext = dbContext;
            _publisher = publisher;
        }

        public async Task<ReportQueuedResponse> MonthlyWorkHoursAsync(
            MonthlyWorkHoursReportRequest request, int generatedById)
        {
            if (request.Month is < 1 or > 12)
            {
                throw new ClientException("Month has to be between 1 and 12.");
            }

            await EnsureReportableMonthAsync(request.Year, request.Month);

            var reportId = await QueueAsync(ReportKind.MonthlyWorkHours, request, generatedById);

            return new ReportQueuedResponse
            {
                GeneratedReportId = reportId,
                Status = ReportStatus.Pending.ToString(),
            };
        }

        public async Task<ReportQueuedResponse> TransportLoadsAsync(
            TransportLoadsReportRequest request, int generatedById)
        {
            if (request.DateFrom.HasValue && request.DateTo.HasValue
                && request.DateFrom > request.DateTo)
            {
                throw new ClientException("The date range starts after it ends.");
            }

            var reportId = await QueueAsync(ReportKind.TransportLoads, request, generatedById);

            return new ReportQueuedResponse
            {
                GeneratedReportId = reportId,
                Status = ReportStatus.Pending.ToString(),
            };
        }

        public async Task<ReportStatusResponse> GetStatusAsync(int generatedReportId, string? callerRole)
        {
            var report = await FindAuthorizedAsync(generatedReportId, callerRole);

            return new ReportStatusResponse
            {
                Id = report.Id,
                Status = report.Status.ToString(),
                ErrorMessage = report.ErrorMessage,
            };
        }

        public async Task<(byte[] Content, string FileName)> DownloadAsync(int generatedReportId, string? callerRole)
        {
            var report = await FindAuthorizedAsync(generatedReportId, callerRole);

            if (report.Status != ReportStatus.Completed || report.Content is null)
            {
                throw new ClientException(report.Status switch
                {
                    ReportStatus.Failed => $"This report could not be generated: {report.ErrorMessage}",
                    ReportStatus.Completed =>
                        "This report predates PDF storage and can no longer be downloaded.",
                    _ => "This report is still being generated. Try again shortly.",
                });
            }

            var fileName = (ReportKind)report.ReportTypeId switch
            {
                ReportKind.MonthlyWorkHours => $"monthly-work-hours-{report.Id}.pdf",
                ReportKind.TransportLoads => $"transport-loads-{report.Id}.pdf",
                _ => $"report-{report.Id}.pdf",
            };

            return (report.Content, fileName);
        }

        /// <summary>
        /// Checked here, before anything is queued, so a period the worker could
        /// never build is a message to fix the input rather than a failed report:
        /// from the year the first hours were booked in up to the current month.
        /// </summary>
        private async Task EnsureReportableMonthAsync(int year, int month)
        {
            var today = SarajevoTime.Today;
            var firstBooked = await _dbContext.WorkLogDetails.MinAsync(x => (DateTime?)x.StartedAt);
            var firstYear = firstBooked is { } first ? SarajevoTime.FromUtc(first).Year : today.Year;

            if (year < firstYear || year > today.Year)
            {
                throw new ClientException(firstYear == today.Year
                    ? $"Pick a month of {today.Year} - work hours have only been booked this year."
                    : $"Pick a year from {firstYear} to {today.Year} - the years work hours have been booked in.");
            }

            if (year == today.Year && month > today.Month)
            {
                throw new ClientException("That month has not started yet - pick this month or an earlier one.");
            }
        }

        /// <summary>
        /// The download route has no report type of its own for <c>[Authorization]</c>
        /// to see, so a project manager is narrowed away from a monthly hours report
        /// here instead, against the type of the report actually being asked for.
        /// </summary>
        private async Task<GeneratedReport> FindAuthorizedAsync(int generatedReportId, string? callerRole)
        {
            var report = await _dbContext.GeneratedReports
                .FirstOrDefaultAsync(x => x.Id == generatedReportId)
                ?? throw new ClientException($"Report {generatedReportId} does not exist.");

            if (callerRole == Roles.ProjectManager && report.ReportTypeId == (int)ReportKind.MonthlyWorkHours)
            {
                throw new ForbiddenException("You cannot download the monthly work hours report.");
            }

            return report;
        }

        /// <summary>
        /// Writes the Pending row and its ActivityLog - who ran it and when, the
        /// same way a synchronous run always recorded it - then hands the row's id
        /// to RabbitMQ. A broker that cannot be reached fails the row rather than
        /// leaving it Pending forever with nothing to ever pick it up.
        /// </summary>
        private async Task<int> QueueAsync(ReportKind type, object request, int generatedById)
        {
            var report = new GeneratedReport
            {
                ReportTypeId = (int)type,
                Parameters = JsonSerializer.Serialize(request),
                Status = ReportStatus.Pending,
            };

            var reportType = await _dbContext.ReportTypes
                .FirstOrDefaultAsync(x => x.Id == (int)type);

            var logTypeName = $"Generated report - {reportType?.Description ?? type.ToString()}";

            var logType = await _dbContext.ActivityLogTypes
                .FirstOrDefaultAsync(x => x.Name == logTypeName);

            _dbContext.GeneratedReports.Add(report);

            if (logType is not null)
            {
                _dbContext.ActivityLogs.Add(new ActivityLog
                {
                    UserId = generatedById,
                    ActivityLogTypeId = logType.Id,
                    // Through the navigation, not the raw id: `report` has none yet,
                    // and this way EF fixes the foreign key up itself once it does,
                    // so both rows commit in the one SaveChangesAsync below rather
                    // than needing a first save just to learn the id.
                    GeneratedReport = report,
                    Date = DateTime.UtcNow,
                });
            }

            await _dbContext.SaveChangesAsync();

            try
            {
                await _publisher.PublishAsync(new ReportGenerationMessage(report.Id));
            }
            catch (Exception ex)
            {
                report.Status = ReportStatus.Failed;
                report.ErrorMessage = "Could not reach the report queue.";
                await _dbContext.SaveChangesAsync();

                throw new ClientException("The report could not be queued. Try again shortly.", ex);
            }

            return report.Id;
        }
    }
}
