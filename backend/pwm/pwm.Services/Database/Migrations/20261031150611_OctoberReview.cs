using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace pwm.Services.Database.Migrations
{
    /// <inheritdoc />
    public partial class OctoberReview : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // A shift is the sum of its blocks from now on - bring the ones already
            // stored in line, and drop any left without a block.
            migrationBuilder.Sql(@"
DELETE w FROM WorkLogs w WHERE NOT EXISTS (SELECT 1 FROM WorkLogDetails d WHERE d.WorkLogId = w.Id);
UPDATE w SET
    ClockedIn = b.FirstStart,
    ClockedOut = CASE WHEN b.Running > 0 THEN NULL ELSE b.LastFinish END,
    Hours = ROUND(b.Total, 2)
FROM WorkLogs w
JOIN (SELECT WorkLogId,
             MIN(StartedAt) AS FirstStart,
             MAX(FinishedAt) AS LastFinish,
             SUM(CASE WHEN FinishedAt IS NULL THEN 1 ELSE 0 END) AS Running,
             SUM(Hours) AS Total
      FROM WorkLogDetails GROUP BY WorkLogId) b ON b.WorkLogId = w.Id;");

            // Accounts that already exist sign in with their name and surname run
            // together, as before; a clash between two of them keeps the id apart.
            migrationBuilder.AddColumn<string>(
                name: "Username",
                table: "Users",
                type: "nvarchar(50)",
                maxLength: 50,
                nullable: false,
                defaultValue: "");

            migrationBuilder.Sql(@"
UPDATE Users SET Username = LEFT(LOWER(REPLACE(Name + Surname, ' ', '')), 40);
UPDATE u SET Username = u.Username + CAST(u.Id AS nvarchar(10))
FROM Users u
WHERE EXISTS (SELECT 1 FROM Users o WHERE o.Username = u.Username AND o.Id < u.Id);");

            migrationBuilder.CreateIndex(
                name: "IX_Users_Username",
                table: "Users",
                column: "Username",
                unique: true);

            // An existing project's planned start is taken to be its actual one, or
            // the day it was raised - never after its planned delivery.
            migrationBuilder.AddColumn<DateTime>(
                name: "PlannedStartDate",
                table: "Projects",
                type: "datetime2",
                nullable: true);

            migrationBuilder.Sql(@"
UPDATE Projects SET PlannedStartDate =
    CASE WHEN DeliveryDate IS NOT NULL AND COALESCE(ProductionStartDate, CreationDate) > DeliveryDate
         THEN DeliveryDate
         ELSE COALESCE(ProductionStartDate, CreationDate) END;");

            migrationBuilder.CreateTable(
                name: "NotificationTypes",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Name = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    IsSystem = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_NotificationTypes", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_NotificationTypes_Name",
                table: "NotificationTypes",
                column: "Name",
                unique: true);

            // A fresh database gets its types from DataSeeder after this runs; one
            // that already holds data is never seeded again, so it gets them here.
            migrationBuilder.Sql(@"
IF EXISTS (SELECT 1 FROM Users)
INSERT INTO NotificationTypes (Name, IsSystem) VALUES
    ('General', 0), ('Reminder', 0), ('Safety', 0), ('Schedule', 0),
    ('Missed clock-out', 1), ('Absence', 1), ('Work hours change', 1),
    ('Project status', 1), ('Transport status', 1), ('Password reset', 1);");

            migrationBuilder.AddColumn<int>(
                name: "NotificationTypeId",
                table: "Notifications",
                type: "int",
                nullable: false,
                defaultValue: 0);

            // Notifications already sent get the type their title says they are.
            migrationBuilder.Sql(@"
UPDATE n SET NotificationTypeId = t.Id
FROM Notifications n
JOIN NotificationTypes t ON t.Name =
    CASE
        WHEN n.Title = 'Missed clock-out' THEN 'Missed clock-out'
        WHEN n.Title = 'Not at work today' THEN 'Absence'
        WHEN n.Title IN ('Work hours added', 'Work hours changed', 'Work hours deleted') THEN 'Work hours change'
        WHEN n.Title IN ('Project status changed', 'Project rejected') THEN 'Project status'
        WHEN n.Title IN ('Transport status changed', 'Transport rejected') THEN 'Transport status'
        WHEN n.Title = 'Password reset requested' THEN 'Password reset'
        ELSE 'General'
    END;");

            migrationBuilder.CreateIndex(
                name: "IX_Notifications_NotificationTypeId",
                table: "Notifications",
                column: "NotificationTypeId");

            migrationBuilder.AddForeignKey(
                name: "FK_Notifications_NotificationTypes_NotificationTypeId",
                table: "Notifications",
                column: "NotificationTypeId",
                principalTable: "NotificationTypes",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Notifications_NotificationTypes_NotificationTypeId",
                table: "Notifications");

            migrationBuilder.DropTable(
                name: "NotificationTypes");

            migrationBuilder.DropIndex(
                name: "IX_Users_Username",
                table: "Users");

            migrationBuilder.DropIndex(
                name: "IX_Notifications_NotificationTypeId",
                table: "Notifications");

            migrationBuilder.DropColumn(
                name: "Username",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "PlannedStartDate",
                table: "Projects");

            migrationBuilder.DropColumn(
                name: "NotificationTypeId",
                table: "Notifications");
        }
    }
}
