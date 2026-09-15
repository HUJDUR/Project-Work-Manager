namespace pwm.Model.Requests
{
    /// <summary>The office's three inputs on the Recommendations screen.</summary>
    public class RecommendationRequest
    {
        public int ProjectCategoryId { get; set; }

        /// <summary>Expected tonnage of the new project, in tonnes.</summary>
        public double Tonnes { get; set; }

        /// <summary>The deadline the office wants to hit, in working days.</summary>
        public int WorkingDays { get; set; }
    }
}
