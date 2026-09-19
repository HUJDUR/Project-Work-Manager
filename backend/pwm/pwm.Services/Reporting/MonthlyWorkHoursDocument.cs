using System.Globalization;
using QuestPDF.Fluent;
using QuestPDF.Infrastructure;

namespace pwm.Services.Reporting
{
    /// <summary>
    /// Hours per worker for a month, split into regular and overtime, with the
    /// projects each worker's hours went to underneath. The payroll basis.
    /// </summary>
    internal static class MonthlyWorkHoursDocument
    {
        public static byte[] Render(
            DateTime month, string worker, string project, IReadOnlyList<MonthlyWorkHoursRow> rows)
        {
            var period = month.ToString("MMMM yyyy", CultureInfo.InvariantCulture);

            return Document.Create(container => ReportTheme.Page(
                container,
                "Monthly Work Hours",
                $"{period}  ·  {worker}  ·  {project}",
                body => Body(body, rows))).GeneratePdf();
        }

        private static void Body(IContainer container, IReadOnlyList<MonthlyWorkHoursRow> rows)
        {
            container.Column(column =>
            {
                column.Spacing(14);

                if (rows.Count == 0)
                {
                    column.Item().Text("No hours were booked in this period.")
                        .FontColor(ReportTheme.Muted);
                    return;
                }

                column.Item().Element(table => Summary(table, rows));

                foreach (var row in rows.Where(row => row.ByProject.Count > 0))
                {
                    column.Item().Element(breakdown => Breakdown(breakdown, row));
                }
            });
        }

        private static void Summary(IContainer container, IReadOnlyList<MonthlyWorkHoursRow> rows)
        {
            container.Table(table =>
            {
                table.ColumnsDefinition(columns =>
                {
                    columns.RelativeColumn(3);
                    columns.RelativeColumn();
                    columns.RelativeColumn();
                    columns.RelativeColumn();
                });

                table.Header(header =>
                {
                    header.Cell().Element(cell => ReportTheme.HeaderCell(cell, "Worker"));
                    header.Cell().AlignRight()
                        .Element(cell => ReportTheme.HeaderCell(cell, "Regular"));
                    header.Cell().AlignRight()
                        .Element(cell => ReportTheme.HeaderCell(cell, "Overtime"));
                    header.Cell().AlignRight()
                        .Element(cell => ReportTheme.HeaderCell(cell, "Total"));
                });

                foreach (var row in rows)
                {
                    table.Cell().Element(ReportTheme.BodyCell).Text(row.WorkerName);
                    table.Cell().Element(ReportTheme.BodyCell).AlignRight()
                        .Text(ReportTheme.Hours(row.RegularHours));
                    table.Cell().Element(ReportTheme.BodyCell).AlignRight()
                        .Text(ReportTheme.Hours(row.OvertimeHours));
                    table.Cell().Element(ReportTheme.BodyCell).AlignRight()
                        .Text(ReportTheme.Hours(row.TotalHours)).SemiBold();
                }

                table.Cell().Element(ReportTheme.BodyCell).Text("Total").SemiBold();
                table.Cell().Element(ReportTheme.BodyCell).AlignRight()
                    .Text(ReportTheme.Hours(rows.Sum(row => row.RegularHours))).SemiBold();
                table.Cell().Element(ReportTheme.BodyCell).AlignRight()
                    .Text(ReportTheme.Hours(rows.Sum(row => row.OvertimeHours))).SemiBold();
                table.Cell().Element(ReportTheme.BodyCell).AlignRight()
                    .Text(ReportTheme.Hours(rows.Sum(row => row.TotalHours))).SemiBold();
            });
        }

        private static void Breakdown(IContainer container, MonthlyWorkHoursRow row)
        {
            container.Column(column =>
            {
                column.Item().PaddingBottom(4)
                    .Text($"{row.WorkerName} — by project").FontSize(9).SemiBold();

                column.Item().Table(table =>
                {
                    table.ColumnsDefinition(columns =>
                    {
                        columns.RelativeColumn(4);
                        columns.RelativeColumn();
                    });

                    foreach (var project in row.ByProject)
                    {
                        table.Cell().Element(ReportTheme.BodyCell)
                            .Text(project.ProjectName).FontSize(8);
                        table.Cell().Element(ReportTheme.BodyCell).AlignRight()
                            .Text(ReportTheme.Hours(project.Hours)).FontSize(8);
                    }
                });
            });
        }
    }
}
