using System;

namespace pwm.Model.SearchObjects
{
    public class WorkLogDetailSearchObject : BaseSearchObject
    {
        public int? WorkLogId { get; set; }

        public int? ProjectId { get; set; }

        public int? OperationTypeId { get; set; }
    }
}
