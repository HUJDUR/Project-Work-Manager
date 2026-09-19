namespace pwm.Model.Requests
{
    public class TransportLoadsReportRequest
    {
        /// <summary>Null for every project.</summary>
        public int? ProjectId { get; set; }

        public DateTime? DateFrom { get; set; }

        public DateTime? DateTo { get; set; }
    }
}
