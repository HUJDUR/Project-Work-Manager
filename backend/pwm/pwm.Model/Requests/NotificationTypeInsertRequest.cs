namespace pwm.Model.Requests
{
    /// <summary>A type the office sends by hand - the system's own cannot be made here.</summary>
    public class NotificationTypeInsertRequest
    {
        public string Name { get; set; } = string.Empty;
    }
}
