namespace pwm.Model.Requests
{
    public class ReportTypeUpdateRequest : IReportTypeRequest
    {
        public string Description { get; set; } = string.Empty;
    }
}
