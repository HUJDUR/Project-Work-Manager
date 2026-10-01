namespace pwm.Model.SearchObjects
{
    public class WorkLogDetailSearchObject : BaseSearchObject
    {
        public int? WorkLogId { get; set; }

        public int? UserId { get; set; }

        /// <summary>
        /// The signed-in account's own rows - taken from the token, so a client never
        /// sends its own id. A production worker gets only their own rows either way.
        /// </summary>
        public bool? Mine { get; set; }

        public int? ProjectId { get; set; }

        public int? OperationTypeId { get; set; }

        /// <summary>
        /// Bounds on <c>StartedAt</c>. The mobile dashboard asks for one worker's
        /// current week rather than their whole history.
        /// </summary>
        public DateTime? DateFrom { get; set; }

        public DateTime? DateTo { get; set; }
    }
}
