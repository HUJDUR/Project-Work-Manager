using QuestPDF.Fluent;
using QuestPDF.Infrastructure;

namespace pwm.Services.Reporting
{
    /// <summary>
    /// Every transport for a project or a date range: two month-level totals up top,
    /// then one block per truck - who carried it, when, its bruto/neto weight, and
    /// which projects were on it.
    /// </summary>
    internal static class TransportLoadsDocument
    {
        public static byte[] Render(
            DateTime? from, DateTime? to, string project, IReadOnlyList<TransportOverviewRow> rows)
        {
            var period = (from, to) switch
            {
                (null, null) => "All dates",
                (not null, null) => $"From {ReportTheme.Date(from.Value)}",
                (null, not null) => $"Until {ReportTheme.Date(to.Value)}",
                _ => $"{ReportTheme.Date(from!.Value)} - {ReportTheme.Date(to!.Value)}",
            };

            return Document.Create(container => ReportTheme.Page(
                container,
                "Transport Overview",
                $"{project}  ·  {period}",
                body => Body(body, rows))).GeneratePdf();
        }

        private static void Body(IContainer container, IReadOnlyList<TransportOverviewRow> rows)
        {
            container.Column(column =>
            {
                column.Spacing(14);

                if (rows.Count == 0)
                {
                    column.Item().Text("No loads were registered in this period.")
                        .FontColor(ReportTheme.Muted);
                    return;
                }

                column.Item().Element(summary => Summary(summary, rows));

                foreach (var row in rows)
                {
                    column.Item().Element(block => Transport(block, row));
                }
            });
        }

        /// <summary>The two month-level numbers: how many trucks left, and how much project weight they carried.</summary>
        private static void Summary(IContainer container, IReadOnlyList<TransportOverviewRow> rows)
        {
            var totalNeto = rows.Sum(row => row.NetoWeight);

            container.Row(row =>
            {
                row.RelativeItem().Element(cell => SummaryStat(cell, "Total Transports", rows.Count.ToString()));
                row.RelativeItem().Element(cell => SummaryStat(
                    cell, "Total Neto Project Weight Shipped", $"{ReportTheme.Kilograms(totalNeto)} kg"));
            });
        }

        private static void SummaryStat(IContainer container, string label, string value)
        {
            container.Column(column =>
            {
                column.Item().Text(label).FontSize(8).FontColor(ReportTheme.Muted);
                column.Item().PaddingTop(2).Text(value).FontSize(14).SemiBold();
            });
        }

        private static void Transport(IContainer container, TransportOverviewRow row)
        {
            container.Column(column =>
            {
                column.Spacing(4);

                column.Item().Row(header =>
                {
                    header.RelativeItem(3)
                        .Text($"{ReportTheme.Date(row.LoadDate)}  ·  {row.CarrierName}  ·  {row.DriverName}")
                        .FontSize(9).SemiBold();
                    header.RelativeItem().AlignRight()
                        .Text(row.Status).FontSize(8).FontColor(ReportTheme.Muted);
                });

                column.Item().Row(meta =>
                {
                    meta.RelativeItem()
                        .Text($"Vehicle {row.VehicleRegistration}").FontSize(8).FontColor(ReportTheme.Muted);
                    meta.RelativeItem().AlignRight()
                        .Text($"Bruto {ReportTheme.Kilograms(row.BrutoWeight)} kg  ·  " +
                              $"Neto {ReportTheme.Kilograms(row.NetoWeight)} kg")
                        .FontSize(8).SemiBold();
                });

                column.Item().PaddingTop(2).Table(table =>
                {
                    table.ColumnsDefinition(columns =>
                    {
                        columns.RelativeColumn(4);
                        columns.RelativeColumn();
                        columns.RelativeColumn();
                    });

                    table.Header(header =>
                    {
                        header.Cell().Element(cell => ReportTheme.HeaderCell(cell, "Project"));
                        header.Cell().AlignRight()
                            .Element(cell => ReportTheme.HeaderCell(cell, "Bruto (kg)"));
                        header.Cell().AlignRight()
                            .Element(cell => ReportTheme.HeaderCell(cell, "Neto (kg)"));
                    });

                    foreach (var project in row.Projects)
                    {
                        table.Cell().Element(ReportTheme.BodyCell)
                            .Text($"{project.ProjectCode} - {project.ProjectName}").FontSize(8);
                        table.Cell().Element(ReportTheme.BodyCell).AlignRight()
                            .Text(ReportTheme.Kilograms(project.BrutoWeight)).FontSize(8);
                        table.Cell().Element(ReportTheme.BodyCell).AlignRight()
                            .Text(ReportTheme.Kilograms(project.NetoWeight)).FontSize(8);
                    }
                });
            });
        }
    }
}
