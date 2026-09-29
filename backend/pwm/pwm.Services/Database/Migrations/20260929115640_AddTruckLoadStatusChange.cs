using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace pwm.Services.Database.Migrations
{
    /// <inheritdoc />
    public partial class AddTruckLoadStatusChange : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<decimal>(
                name: "Price",
                table: "TruckLoads",
                type: "decimal(10,2)",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "TruckLoadStatusChanges",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    TruckLoadId = table.Column<int>(type: "int", nullable: false),
                    FromStatusId = table.Column<int>(type: "int", nullable: true),
                    ToStatusId = table.Column<int>(type: "int", nullable: false),
                    ChangedByUserId = table.Column<int>(type: "int", nullable: false),
                    ChangedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TruckLoadStatusChanges", x => x.Id);
                    table.ForeignKey(
                        name: "FK_TruckLoadStatusChanges_TruckLoadStatusTypes_FromStatusId",
                        column: x => x.FromStatusId,
                        principalTable: "TruckLoadStatusTypes",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_TruckLoadStatusChanges_TruckLoadStatusTypes_ToStatusId",
                        column: x => x.ToStatusId,
                        principalTable: "TruckLoadStatusTypes",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_TruckLoadStatusChanges_TruckLoads_TruckLoadId",
                        column: x => x.TruckLoadId,
                        principalTable: "TruckLoads",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_TruckLoadStatusChanges_Users_ChangedByUserId",
                        column: x => x.ChangedByUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_TruckLoadStatusChanges_ChangedByUserId",
                table: "TruckLoadStatusChanges",
                column: "ChangedByUserId");

            migrationBuilder.CreateIndex(
                name: "IX_TruckLoadStatusChanges_FromStatusId",
                table: "TruckLoadStatusChanges",
                column: "FromStatusId");

            migrationBuilder.CreateIndex(
                name: "IX_TruckLoadStatusChanges_ToStatusId",
                table: "TruckLoadStatusChanges",
                column: "ToStatusId");

            migrationBuilder.CreateIndex(
                name: "IX_TruckLoadStatusChanges_TruckLoadId",
                table: "TruckLoadStatusChanges",
                column: "TruckLoadId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "TruckLoadStatusChanges");

            migrationBuilder.DropColumn(
                name: "Price",
                table: "TruckLoads");
        }
    }
}
