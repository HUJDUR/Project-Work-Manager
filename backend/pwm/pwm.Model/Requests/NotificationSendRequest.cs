namespace pwm.Model.Requests
{
    /// <summary>
    /// One message the office sends to the shop floor. It fans out into one
    /// <c>Notifications</c> row per recipient - the table has no notion of a
    /// message sent to many people.
    /// </summary>
    public class NotificationSendRequest
    {
        public string Title { get; set; } = string.Empty;

        public string Message { get; set; } = string.Empty;

        /// <summary>Null or empty for every account that still works.</summary>
        public List<int>? UserIds { get; set; }
    }
}
