using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace pwm.Services.Database.Migrations
{
    /// <inheritdoc />
    public partial class AddReportGenerationState : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<byte[]>(
                name: "Content",
                table: "GeneratedReports",
                type: "varbinary(max)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ErrorMessage",
                table: "GeneratedReports",
                type: "nvarchar(1000)",
                maxLength: 1000,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "Status",
                table: "GeneratedReports",
                type: "int",
                nullable: false,
                defaultValue: 0);

            // Every row that already exists at this point was generated the old,
            // synchronous way - genuinely done, just with no PDF stored for it.
            // Only a row queued after this migration should ever start Pending.
            migrationBuilder.Sql("UPDATE [GeneratedReports] SET [Status] = 2;");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Content",
                table: "GeneratedReports");

            migrationBuilder.DropColumn(
                name: "ErrorMessage",
                table: "GeneratedReports");

            migrationBuilder.DropColumn(
                name: "Status",
                table: "GeneratedReports");
        }
    }
}
