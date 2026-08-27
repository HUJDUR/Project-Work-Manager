using System;

namespace pwm.Model.Responses
{
    public class ActivityLogResponse
    {
        public int Id { get; set; }

        public int UserId { get; set; }

        public int ActivityLogTypeId { get; set; }

        public DateTime Date { get; set; }
    }
}
