namespace pwm.Model.Responses
{
    public class NotificationMarkReadResponse
    {
        /// <summary>
        /// How many rows actually changed. One already read is not counted, so a
        /// second press of "Mark all as read" answers zero rather than repeating
        /// the first press's number.
        /// </summary>
        public int MarkedCount { get; set; }
    }
}
