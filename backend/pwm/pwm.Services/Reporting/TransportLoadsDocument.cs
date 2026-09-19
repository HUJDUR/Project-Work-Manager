using QuestPDF.Fluent;
using QuestPDF.Infrastructure;

namespace pwm.Services.Reporting
{
    /// <summary>
    /// Every truck load for a project or a date range: when it went, who carried it,
    /// on which vehicle and how much left the yard.
    /// </summary>
    internal static class TransportLoadsDocument
    {
        public static byte[] Render(
            DateTime? from, DateTime? to, string project, IReadOnlyList<TransportLoadRow> rows)
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
                "Transport & Loads",
                $"{project}  ·  {period}",
                body => Body(body, rows))).GeneratePdf();
        }

        private static void Body(IContainer container, IReadOnlyList<TransportLoadRow> rows)
        {
            container.Column(column =>
            {
                if (rows.Count == 0)
                {
                    column.Item().Text("No loads were registered in this period.")
                        .FontColor(ReportTheme.Muted);
                    return;
                }

                column.Item().Table(table =>
                {
                    table.ColumnsDefinition(columns =>
                    {
                        columns.RelativeColumn(2);
                        columns.RelativeColumn(3);
                        columns.RelativeColumn(3);
                        columns.RelativeColumn(3);
                        columns.RelativeColumn(2);
                        columns.RelativeColumn(2);
                        columns.RelativeColumn(2);
                    });

                    table.Header(header =>
                    {
                        header.Cell().Element(cell => ReportTheme.HeaderCell(cell, "Load date"));
                        header.Cell().Element(cell => ReportTheme.HeaderCell(cell, "Project"));
                        header.Cell().Element(cell => ReportTheme.HeaderCell(cell, "Carrier"));
                        header.Cell().Element(cell => ReportTheme.HeaderCell(cell, "Driver"));
                        header.Cell().Element(cell => ReportTheme.HeaderCell(cell, "Vehicle"));
                        header.Cell().AlignRight()
                            .Element(cell => ReportTheme.HeaderCell(cell, "Net (t)"));
                        header.Cell().Element(cell => ReportTheme.HeaderCell(cell, "Status"));
                    });

                    foreach (var row in rows)
                    {
                        table.Cell().Element(ReportTheme.BodyCell)
                            .Text(ReportTheme.Date(row.LoadDate));
                        table.Cell().Element(ReportTheme.BodyCell)
                            .Text($"{row.ProjectCode} - {row.ProjectName}");
                        table.Cell().Element(ReportTheme.BodyCell).Text(row.CarrierName);
                        table.Cell().Element(ReportTheme.BodyCell).Text(row.DriverName);
                        table.Cell().Element(ReportTheme.BodyCell)
                            .Text(row.VehicleRegistration);
                        table.Cell().Element(ReportTheme.BodyCell).AlignRight()
                            .Text(ReportTheme.Tonnes(row.NetWeight));
                        table.Cell().Element(ReportTheme.BodyCell).Text(row.Status);
                    }

                    table.Cell().ColumnSpan(5).Element(ReportTheme.BodyCell)
                        .Text($"{rows.Count} load(s)").SemiBold();
                    table.Cell().Element(ReportTheme.BodyCell).AlignRight()
                        .Text(ReportTheme.Tonnes(rows.Sum(row => row.NetWeight))).SemiBold();
                    table.Cell().Element(ReportTheme.BodyCell).Text(string.Empty);
                });
            });
        }
    }
}
