using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace pwm.Services.Database.Migrations
{
    /// <inheritdoc />
    public partial class StatusChangeReasonAndNoDelete : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_ProjectStatusChanges_Projects_ProjectId",
                table: "ProjectStatusChanges");

            migrationBuilder.DropForeignKey(
                name: "FK_TruckLoadStatusChanges_TruckLoads_TruckLoadId",
                table: "TruckLoadStatusChanges");

            migrationBuilder.AddColumn<string>(
                name: "Reason",
                table: "TruckLoadStatusChanges",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Reason",
                table: "ProjectStatusChanges",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddForeignKey(
                name: "FK_ProjectStatusChanges_Projects_ProjectId",
                table: "ProjectStatusChanges",
                column: "ProjectId",
                principalTable: "Projects",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_TruckLoadStatusChanges_TruckLoads_TruckLoadId",
                table: "TruckLoadStatusChanges",
                column: "TruckLoadId",
                principalTable: "TruckLoads",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_ProjectStatusChanges_Projects_ProjectId",
                table: "ProjectStatusChanges");

            migrationBuilder.DropForeignKey(
                name: "FK_TruckLoadStatusChanges_TruckLoads_TruckLoadId",
                table: "TruckLoadStatusChanges");

            migrationBuilder.DropColumn(
                name: "Reason",
                table: "TruckLoadStatusChanges");

            migrationBuilder.DropColumn(
                name: "Reason",
                table: "ProjectStatusChanges");

            migrationBuilder.AddForeignKey(
                name: "FK_ProjectStatusChanges_Projects_ProjectId",
                table: "ProjectStatusChanges",
                column: "ProjectId",
                principalTable: "Projects",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_TruckLoadStatusChanges_TruckLoads_TruckLoadId",
                table: "TruckLoadStatusChanges",
                column: "TruckLoadId",
                principalTable: "TruckLoads",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }
    }
}
