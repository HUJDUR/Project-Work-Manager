namespace pwm.Model.Requests
{
    /// <summary>
    /// Marks notifications read. The rows always belong to the caller - the id
    /// comes from the token, never from the body - so this only says *which* of
    /// their own. Null or empty <see cref="NotificationIds"/> means every unread
    /// one, which is what the mobile screen's "Mark all as read" sends.
    /// </summary>
    public class NotificationMarkReadRequest
    {
        public List<int>? NotificationIds { get; set; }
    }
}
