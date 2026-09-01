using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace pwm.Services.Database.Migrations
{
    /// <inheritdoc />
    public partial class RequiredProjectCodeAndGeneratedReports : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // A project with no code would otherwise become one with an empty code.
            migrationBuilder.Sql(@"
                UPDATE [Projects]
                SET [Code] = CONCAT(N'P-', [Id])
                WHERE [Code] IS NULL OR LTRIM(RTRIM([Code])) = N'';");

            migrationBuilder.AlterColumn<string>(
                name: "Code",
                table: "Projects",
                type: "nvarchar(50)",
                maxLength: 50,
                nullable: false,
                defaultValue: "",
                oldClrType: typeof(string),
                oldType: "nvarchar(50)",
                oldMaxLength: 50,
                oldNullable: true);

            migrationBuilder.AddColumn<double>(
                name: "OvertimeHours",
                table: "MonthlyHourReportDetails",
                type: "float",
                nullable: false,
                defaultValue: 0.0);

            migrationBuilder.AddColumn<double>(
                name: "RegularHours",
                table: "MonthlyHourReportDetails",
                type: "float",
                nullable: false,
                defaultValue: 0.0);

            migrationBuilder.CreateTable(
                name: "GeneratedReports",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Type = table.Column<int>(type: "int", nullable: false),
                    Parameters = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: false),
                    GeneratedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    GeneratedById = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_GeneratedReports", x => x.Id);
                    table.ForeignKey(
                        name: "FK_GeneratedReports_Users_GeneratedById",
                        column: x => x.GeneratedById,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_GeneratedReports_GeneratedAt",
                table: "GeneratedReports",
                column: "GeneratedAt");

            migrationBuilder.CreateIndex(
                name: "IX_GeneratedReports_GeneratedById",
                table: "GeneratedReports",
                column: "GeneratedById");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "GeneratedReports");

            migrationBuilder.DropColumn(
                name: "OvertimeHours",
                table: "MonthlyHourReportDetails");

            migrationBuilder.DropColumn(
                name: "RegularHours",
                table: "MonthlyHourReportDetails");

            migrationBuilder.AlterColumn<string>(
                name: "Code",
                table: "Projects",
                type: "nvarchar(50)",
                maxLength: 50,
                nullable: true,
                oldClrType: typeof(string),
                oldType: "nvarchar(50)",
                oldMaxLength: 50);
        }
    }
}
