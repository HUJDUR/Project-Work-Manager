using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace pwm.Services.Database.Migrations
{
    /// <inheritdoc />
    public partial class ProjectDetailFieldsAndTruckLoadStatus : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "TruckLoadStatusId",
                table: "TruckLoads",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<string>(
                name: "Code",
                table: "Projects",
                type: "nvarchar(50)",
                maxLength: 50,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "CreatedByUserId",
                table: "Projects",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<string>(
                name: "Description",
                table: "Projects",
                type: "nvarchar(1000)",
                maxLength: 1000,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Notes",
                table: "Projects",
                type: "nvarchar(1000)",
                maxLength: 1000,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "Priority",
                table: "Projects",
                type: "int",
                nullable: false,
                // ProjectPriority.Medium - 0 is not one of the four levels.
                defaultValue: 2);

            migrationBuilder.CreateTable(
                name: "TruckLoadStatusTypes",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Name = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TruckLoadStatusTypes", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_TruckLoads_TruckLoadStatusId",
                table: "TruckLoads",
                column: "TruckLoadStatusId");

            migrationBuilder.CreateIndex(
                name: "IX_Projects_CreatedByUserId",
                table: "Projects",
                column: "CreatedByUserId");

            migrationBuilder.CreateIndex(
                name: "IX_TruckLoadStatusTypes_Name",
                table: "TruckLoadStatusTypes",
                column: "Name",
                unique: true);

            migrationBuilder.Sql(@"
                IF EXISTS (SELECT 1 FROM [Projects]) AND EXISTS (SELECT 1 FROM [Users])
                    UPDATE [Projects]
                    SET [CreatedByUserId] = (SELECT MIN([Id]) FROM [Users])
                    WHERE [CreatedByUserId] = 0;");

            migrationBuilder.Sql(@"
                IF EXISTS (SELECT 1 FROM [TruckLoads])
                BEGIN
                    IF NOT EXISTS (SELECT 1 FROM [TruckLoadStatusTypes])
                        INSERT INTO [TruckLoadStatusTypes] ([Name])
                        VALUES (N'Planned'), (N'Loading'), (N'Loaded'),
                               (N'In transit'), (N'Delivered'), (N'Cancelled');

                    UPDATE [TruckLoads]
                    SET [TruckLoadStatusId] = (SELECT MIN([Id]) FROM [TruckLoadStatusTypes])
                    WHERE [TruckLoadStatusId] = 0;
                END");

            migrationBuilder.AddForeignKey(
                name: "FK_Projects_Users_CreatedByUserId",
                table: "Projects",
                column: "CreatedByUserId",
                principalTable: "Users",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_TruckLoads_TruckLoadStatusTypes_TruckLoadStatusId",
                table: "TruckLoads",
                column: "TruckLoadStatusId",
                principalTable: "TruckLoadStatusTypes",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Projects_Users_CreatedByUserId",
                table: "Projects");

            migrationBuilder.DropForeignKey(
                name: "FK_TruckLoads_TruckLoadStatusTypes_TruckLoadStatusId",
                table: "TruckLoads");

            migrationBuilder.DropTable(
                name: "TruckLoadStatusTypes");

            migrationBuilder.DropIndex(
                name: "IX_TruckLoads_TruckLoadStatusId",
                table: "TruckLoads");

            migrationBuilder.DropIndex(
                name: "IX_Projects_CreatedByUserId",
                table: "Projects");

            migrationBuilder.DropColumn(
                name: "TruckLoadStatusId",
                table: "TruckLoads");

            migrationBuilder.DropColumn(
                name: "Code",
                table: "Projects");

            migrationBuilder.DropColumn(
                name: "CreatedByUserId",
                table: "Projects");

            migrationBuilder.DropColumn(
                name: "Description",
                table: "Projects");

            migrationBuilder.DropColumn(
                name: "Notes",
                table: "Projects");

            migrationBuilder.DropColumn(
                name: "Priority",
                table: "Projects");
        }
    }
}
