using pwm.Model.Enums;

namespace pwm.Model.SearchObjects
{
    /// <summary>The Work Hours screen's filters - see <c>WorkLogDetailService.GetHoursAsync</c>.</summary>
    public class WorkHoursSearchObject : BaseSearchObject
    {
        /// <summary>Part of the worker's name.</summary>
        public string? Search { get; set; }

        public int? ProjectId { get; set; }

        /// <summary>The first day included; only its date counts.</summary>
        public DateTime? DateFrom { get; set; }

        /// <summary>The last day included; only its date counts.</summary>
        public DateTime? DateTo { get; set; }

        public WorkHoursFilter? HoursFilter { get; set; }
    }
}
