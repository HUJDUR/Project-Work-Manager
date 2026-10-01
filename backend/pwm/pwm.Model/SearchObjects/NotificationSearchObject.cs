namespace pwm.Model.SearchObjects
{
    public class NotificationSearchObject : BaseSearchObject
    {
        /// <summary>Ignored: a notification list is always the token's own account.</summary>
        public int? UserId { get; set; }

        public bool? IsRead { get; set; }

        public string? Title { get; set; }
    }
}
