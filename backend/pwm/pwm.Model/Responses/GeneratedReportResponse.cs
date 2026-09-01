using System;
using pwm.Model.Enums;

namespace pwm.Model.Responses
{
    public class GeneratedReportResponse
    {
        public int Id { get; set; }

        public ReportType Type { get; set; }

        public string Parameters { get; set; } = string.Empty;

        public DateTime GeneratedAt { get; set; }

        public int GeneratedById { get; set; }
    }
}
