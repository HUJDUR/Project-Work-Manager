using System;

namespace pwm.Model.SearchObjects
{
    public class WorkLogDetailSearchObject : BaseSearchObject
    {
        public int? WorkLogId { get; set; }

        public int? UserId { get; set; }

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
