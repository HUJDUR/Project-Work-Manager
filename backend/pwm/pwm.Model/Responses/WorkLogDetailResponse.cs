using System;

namespace pwm.Model.Responses
{
    public class WorkLogDetailResponse
    {
        public int Id { get; set; }

        public int WorkLogId { get; set; }

        public int OperationTypeId { get; set; }

        public int ProjectId { get; set; }

        public DateTime StartedAt { get; set; }

        public DateTime? FinishedAt { get; set; }

        public double Hours { get; set; }
    }
}
