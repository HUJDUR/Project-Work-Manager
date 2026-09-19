namespace pwm.Model.Responses
{
    /// <summary>
    /// One estimate: the totals, the per-work-type breakdown, and what the estimate is
    /// explained by - how many past projects it drew on and how well the model fit them.
    /// </summary>
    public class RecommendationResponse
    {
        /// <summary>
        /// False when the category has fewer than the minimum number of delivered
        /// projects to learn from - see <c>RecommendationService.MinSampleSize</c>.
        /// No other field is trustworthy when this is false.
        /// </summary>
        public bool HasEstimate { get; set; }

        /// <summary>Set only when <see cref="HasEstimate"/> is false, explaining why.</summary>
        public string? Message { get; set; }

        /// <summary>
        /// Set only when <see cref="HasEstimate"/> is true: a plain-language account of what
        /// the estimate is based on and how well it fits, so the number is never just handed
        /// over without saying where it came from.
        /// </summary>
        public string? Explanation { get; set; }

        /// <summary>How many past delivered projects of this category the estimate is based on.</summary>
        public int SampleSize { get; set; }

        /// <summary>
        /// Rough accuracy of the hours-vs-tonnage relationship for this category, as the
        /// R-squared of the fit against the sample, 0-100.
        /// </summary>
        public double AccuracyPercent { get; set; }

        public double TotalHours { get; set; }

        /// <summary>Workers needed to finish within the requested deadline.</summary>
        public int EstimatedWorkers { get; set; }

        /// <summary>How long the project would normally take with this category's typical crew size.</summary>
        public int EstimatedDurationDays { get; set; }

        public List<RecommendationWorkTypeResponse> WorkTypes { get; set; } = new();
    }
}
