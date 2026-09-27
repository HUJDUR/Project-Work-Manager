using System.Globalization;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

namespace pwm.Services.Reporting
{
    /// <summary>
    /// The bits both PDFs share: the page frame, the header and footer, and the
    /// handful of colours and number formats the tables use.
    /// </summary>
    internal static class ReportTheme
    {
        public const string Accent = "#2563EB";
        public const string HeaderBackground = "#EAF1FE";
        public const string Muted = "#6B7280";
        public const string Line = "#E6E8EC";

        private static readonly CultureInfo Culture = CultureInfo.InvariantCulture;

        public static string Hours(double value) => value.ToString("N2", Culture);

        public static string Tonnes(double kilograms) =>
            (kilograms / 1000).ToString("N2", Culture);

        public static string Kilograms(double value) => value.ToString("N2", Culture);

        public static string Date(System.DateTime value) =>
            value.ToString("d MMM yyyy", Culture);

        public static void Page(IDocumentContainer container, string title, string subtitle,
            System.Action<IContainer> body)
        {
            container.Page(page =>
            {
                page.Size(PageSizes.A4);
                page.Margin(30);
                page.DefaultTextStyle(text => text.FontSize(9).FontColor(Colors.Black));

                page.Header().Element(header => Header(header, title, subtitle));
                page.Content().PaddingVertical(14).Element(body);
                page.Footer().Element(Footer);
            });
        }

        private static void Header(IContainer container, string title, string subtitle)
        {
            container.Column(column =>
            {
                column.Item().Row(row =>
                {
                    row.RelativeItem().Column(left =>
                    {
                        left.Item().Text(title).FontSize(16).SemiBold();
                        left.Item().PaddingTop(2).Text(subtitle).FontSize(9).FontColor(Muted);
                    });

                    row.ConstantItem(150).AlignRight().Column(right =>
                    {
                        right.Item().Text("Project Work Manager").FontSize(10).SemiBold()
                            .FontColor(Accent);
                        right.Item().Text("Metal fabrication shop").FontSize(8).FontColor(Muted);
                    });
                });

                column.Item().PaddingTop(10).LineHorizontal(1).LineColor(Line);
            });
        }

        private static void Footer(IContainer container)
        {
            container.Row(row =>
            {
                row.RelativeItem()
                    .Text($"Generated {Date(System.DateTime.UtcNow)}")
                    .FontSize(8).FontColor(Muted);

                row.RelativeItem().AlignRight().Text(text =>
                {
                    text.DefaultTextStyle(style => style.FontSize(8).FontColor(Muted));
                    text.Span("Page ");
                    text.CurrentPageNumber();
                    text.Span(" of ");
                    text.TotalPages();
                });
            });
        }

        public static void HeaderCell(IContainer container, string text)
        {
            container
                .Background(HeaderBackground)
                .PaddingVertical(6).PaddingHorizontal(6)
                .Text(text).FontSize(8).SemiBold().FontColor(Accent);
        }

        public static IContainer BodyCell(IContainer container) => container
            .BorderBottom(1).BorderColor(Line)
            .PaddingVertical(5).PaddingHorizontal(6);
    }
}
