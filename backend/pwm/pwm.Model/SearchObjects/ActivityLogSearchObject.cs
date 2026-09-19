namespace pwm.Model.SearchObjects
{
    public class ActivityLogSearchObject : BaseSearchObject
    {
        public int? UserId { get; set; }

        public int? ActivityLogTypeId { get; set; }

        public int? GeneratedReportId { get; set; }

        public DateTime? DateFrom { get; set; }

        public DateTime? DateTo { get; set; }
    }
}
