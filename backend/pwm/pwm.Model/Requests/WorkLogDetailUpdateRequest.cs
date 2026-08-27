using System;

namespace pwm.Model.Requests
{
    public class WorkLogDetailUpdateRequest
    {
        public int WorkLogId { get; set; }

        public int OperationTypeId { get; set; }

        public int ProjectId { get; set; }

        public DateTime StartedAt { get; set; }

        public DateTime? FinishedAt { get; set; }

        public double Hours { get; set; }
    }
}
