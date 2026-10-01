namespace pwm.Model.SearchObjects
{
    /// <summary>
    /// The mobile My Hours screen: the signed-in worker's own days in a period -
    /// see <c>WorkLogDetailService.GetMyDaysAsync</c>.
    /// </summary>
    public class MyWorkDaysSearchObject : BaseSearchObject
    {
        /// <summary>The start of the period, inclusive.</summary>
        public DateTime? DateFrom { get; set; }

        /// <summary>The end of the period, exclusive.</summary>
        public DateTime? DateTo { get; set; }
    }
}
