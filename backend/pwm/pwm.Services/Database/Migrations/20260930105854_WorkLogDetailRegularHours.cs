using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace pwm.Services.Database.Migrations
{
    /// <inheritdoc />
    public partial class WorkLogDetailRegularHours : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<double>(
                name: "RegularHours",
                table: "WorkLogDetails",
                type: "float",
                nullable: false,
                defaultValue: 0.0);

            // Every existing block's regular part, by the same rule as OvertimeRules:
            // the first 8 hours of a worker's Sarajevo day, handed out in start order.
            migrationBuilder.Sql("""
                WITH Ordered AS (
                    SELECT Id, Hours,
                           SUM(Hours) OVER (
                               PARTITION BY UserId,
                                   CAST(CAST(StartedAt AT TIME ZONE 'UTC' AT TIME ZONE 'Central European Standard Time' AS datetime2) AS date)
                               ORDER BY StartedAt, Id ROWS UNBOUNDED PRECEDING) - Hours AS UsedBefore
                    FROM WorkLogDetails
                )
                UPDATE d
                SET RegularHours = ROUND(CASE WHEN 8 - o.UsedBefore <= 0 THEN 0
                                              WHEN 8 - o.UsedBefore >= o.Hours THEN o.Hours
                                              ELSE 8 - o.UsedBefore END, 2)
                FROM WorkLogDetails d
                JOIN Ordered o ON o.Id = d.Id;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "RegularHours",
                table: "WorkLogDetails");
        }
    }
}
