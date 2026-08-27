using System;

namespace pwm.Model.Responses
{
    public class WorkLogResponse
    {
        public int Id { get; set; }

        public int UserId { get; set; }

        public DateTime ClockedIn { get; set; }

        public DateTime? ClockedOut { get; set; }

        public double Hours { get; set; }
    }
}
