using System;

namespace pwm.Model.SearchObjects
{
    public class WorkLogSearchObject : BaseSearchObject
    {
        public int? UserId { get; set; }

        public DateTime? DateFrom { get; set; }

        public DateTime? DateTo { get; set; }
    }
}
