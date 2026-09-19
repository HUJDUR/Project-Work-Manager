namespace pwm.Model.Responses
{
    public class ActivityLogResponse
    {
        public int Id { get; set; }

        public int UserId { get; set; }

        public int ActivityLogTypeId { get; set; }

        /// <summary>Set only on a "Generated report" entry.</summary>
        public int? GeneratedReportId { get; set; }

        public DateTime Date { get; set; }
    }
}
