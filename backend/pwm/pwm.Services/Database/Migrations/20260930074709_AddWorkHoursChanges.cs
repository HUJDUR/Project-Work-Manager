using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace pwm.Services.Database.Migrations
{
    /// <inheritdoc />
    public partial class AddWorkHoursChanges : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "WorkHoursChanges",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    WorkLogDetailId = table.Column<int>(type: "int", nullable: true),
                    WorkerId = table.Column<int>(type: "int", nullable: false),
                    ChangedByUserId = table.Column<int>(type: "int", nullable: false),
                    ChangedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    Action = table.Column<int>(type: "int", nullable: false),
                    Before = table.Column<string>(type: "nvarchar(300)", maxLength: 300, nullable: true),
                    After = table.Column<string>(type: "nvarchar(300)", maxLength: 300, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_WorkHoursChanges", x => x.Id);
                    table.ForeignKey(
                        name: "FK_WorkHoursChanges_Users_ChangedByUserId",
                        column: x => x.ChangedByUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_WorkHoursChanges_Users_WorkerId",
                        column: x => x.WorkerId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_WorkHoursChanges_WorkLogDetails_WorkLogDetailId",
                        column: x => x.WorkLogDetailId,
                        principalTable: "WorkLogDetails",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateIndex(
                name: "IX_WorkHoursChanges_ChangedByUserId",
                table: "WorkHoursChanges",
                column: "ChangedByUserId");

            migrationBuilder.CreateIndex(
                name: "IX_WorkHoursChanges_WorkerId",
                table: "WorkHoursChanges",
                column: "WorkerId");

            migrationBuilder.CreateIndex(
                name: "IX_WorkHoursChanges_WorkLogDetailId",
                table: "WorkHoursChanges",
                column: "WorkLogDetailId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "WorkHoursChanges");
        }
    }
}
