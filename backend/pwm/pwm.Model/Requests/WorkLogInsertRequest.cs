using System;

namespace pwm.Model.Requests
{
    public class WorkLogInsertRequest
    {
        public int UserId { get; set; }

        public DateTime ClockedIn { get; set; }

        public DateTime? ClockedOut { get; set; }

        public double Hours { get; set; }
    }
}
