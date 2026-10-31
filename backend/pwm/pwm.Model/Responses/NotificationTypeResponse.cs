namespace pwm.Model.Responses
{
    public class NotificationTypeResponse
    {
        public int Id { get; set; }

        public string Name { get; set; } = string.Empty;

        /// <summary>Raised only by the system - not offered on the send form, and not editable.</summary>
        public bool IsSystem { get; set; }
    }
}
