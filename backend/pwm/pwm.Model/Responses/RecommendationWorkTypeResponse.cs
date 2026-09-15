namespace pwm.Model.Responses
{
    /// <summary>One row of the estimate's work-type breakdown.</summary>
    public class RecommendationWorkTypeResponse
    {
        public int OperationTypeId { get; set; }

        public string OperationTypeName { get; set; } = string.Empty;

        public double EstimatedHours { get; set; }

        /// <summary>Share of the total estimated hours, 0-100.</summary>
        public double SharePercent { get; set; }
    }
}
