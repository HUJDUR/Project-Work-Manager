using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace pwm.Services.Database.Migrations
{
    /// <summary>
    /// Rejections recorded before <c>Reason</c> existed have none, and a rejection
    /// is never shown without one. Where the project or transport's own notes say
    /// why, that is the reason; otherwise the row says honestly that none was
    /// recorded, rather than inventing one.
    /// </summary>
    public partial class BackfillRejectionReasons : Migration
    {
        private const string NotRecorded = "Not recorded - rejected before a reason was required.";

        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql($"""
                UPDATE c
                SET Reason = LEFT(COALESCE(NULLIF(LTRIM(RTRIM(p.Notes)), ''), N'{NotRecorded}'), 500)
                FROM ProjectStatusChanges c
                JOIN ProjectStatusTypes s ON s.Id = c.ToStatusId
                JOIN Projects p ON p.Id = c.ProjectId
                WHERE s.Name = N'Rejected' AND c.Reason IS NULL;
                """);

            migrationBuilder.Sql($"""
                UPDATE c
                SET Reason = LEFT(COALESCE(NULLIF(LTRIM(RTRIM(t.Note)), ''), N'{NotRecorded}'), 500)
                FROM TruckLoadStatusChanges c
                JOIN TruckLoadStatusTypes s ON s.Id = c.ToStatusId
                JOIN TruckLoads t ON t.Id = c.TruckLoadId
                WHERE s.Name = N'Rejected' AND c.Reason IS NULL;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Nothing to undo: which reasons were backfilled is not recorded, and a
            // reason on a rejection is what the schema expects anyway.
        }
    }
}
