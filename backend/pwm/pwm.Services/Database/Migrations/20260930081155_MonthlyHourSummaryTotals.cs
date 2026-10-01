using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace pwm.Services.Database.Migrations
{
    /// <inheritdoc />
    public partial class MonthlyHourSummaryTotals : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<double>(
                name: "OvertimeHours",
                table: "MonthlyHourReports",
                type: "float",
                nullable: false,
                defaultValue: 0.0);

            migrationBuilder.AddColumn<double>(
                name: "RegularHours",
                table: "MonthlyHourReports",
                type: "float",
                nullable: false,
                defaultValue: 0.0);

            migrationBuilder.AddColumn<int>(
                name: "WorkerCount",
                table: "MonthlyHourReports",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<int>(
                name: "DaysWorked",
                table: "MonthlyHourReportDetails",
                type: "int",
                nullable: false,
                defaultValue: 0);

            // Until now only the seeder wrote these, once, so they no longer match
            // the work actually booked. Rebuilt here from WorkLogDetails with the same
            // rule MonthlyHourSummary uses from now on: per worker and Sarajevo day,
            // the first eight hours in start order are regular, the rest overtime.
            migrationBuilder.Sql("""
                DELETE FROM MonthlyHourReportDetails;
                DELETE FROM MonthlyHourReports;

                WITH Blocks AS (
                    SELECT d.Id, d.UserId, d.Hours,
                           CAST(d.StartedAt AT TIME ZONE 'UTC' AT TIME ZONE 'Central European Standard Time' AS datetime2) AS LocalStart
                    FROM WorkLogDetails d
                ),
                Ordered AS (
                    SELECT UserId, Hours, CAST(LocalStart AS date) AS LocalDay,
                           SUM(Hours) OVER (PARTITION BY UserId, CAST(LocalStart AS date)
                                            ORDER BY LocalStart, Id ROWS UNBOUNDED PRECEDING) - Hours AS UsedBefore
                    FROM Blocks
                ),
                Split AS (
                    SELECT UserId, LocalDay, Hours,
                           CASE WHEN 8 - UsedBefore <= 0 THEN 0
                                WHEN 8 - UsedBefore >= Hours THEN Hours
                                ELSE 8 - UsedBefore END AS Regular
                    FROM Ordered
                )
                SELECT UserId, YEAR(LocalDay) AS [Year], MONTH(LocalDay) AS [Month],
                       ROUND(SUM(Hours), 2) AS Total, ROUND(SUM(Regular), 2) AS Regular,
                       COUNT(DISTINCT LocalDay) AS Days
                INTO #MonthlyWorkers
                FROM Split
                GROUP BY UserId, YEAR(LocalDay), MONTH(LocalDay);

                INSERT INTO MonthlyHourReports ([Year], [Month], TotalHours, RegularHours, OvertimeHours, WorkerCount)
                SELECT [Year], [Month], ROUND(SUM(Total), 2), ROUND(SUM(Regular), 2),
                       ROUND(SUM(Total) - SUM(Regular), 2), COUNT(*)
                FROM #MonthlyWorkers
                GROUP BY [Year], [Month];

                INSERT INTO MonthlyHourReportDetails (MonthlyHourReportId, UserId, TotalHours, RegularHours, OvertimeHours, DaysWorked)
                SELECT r.Id, w.UserId, w.Total, w.Regular, ROUND(w.Total - w.Regular, 2), w.Days
                FROM #MonthlyWorkers w
                JOIN MonthlyHourReports r ON r.[Year] = w.[Year] AND r.[Month] = w.[Month];

                DROP TABLE #MonthlyWorkers;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "OvertimeHours",
                table: "MonthlyHourReports");

            migrationBuilder.DropColumn(
                name: "RegularHours",
                table: "MonthlyHourReports");

            migrationBuilder.DropColumn(
                name: "WorkerCount",
                table: "MonthlyHourReports");

            migrationBuilder.DropColumn(
                name: "DaysWorked",
                table: "MonthlyHourReportDetails");
        }
    }
}
