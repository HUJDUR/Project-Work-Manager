using System;

namespace pwm.Model.SearchObjects
{
    public class NotificationSearchObject : BaseSearchObject
    {
        public int? UserId { get; set; }

        public bool? IsRead { get; set; }

        public string? Title { get; set; }
    }
}
