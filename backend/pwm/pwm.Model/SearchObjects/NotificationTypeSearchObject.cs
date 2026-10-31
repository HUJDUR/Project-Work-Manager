namespace pwm.Model.SearchObjects
{
    public class NotificationTypeSearchObject : BaseSearchObject
    {
        public string? Name { get; set; }

        /// <summary>False for the types the send form offers.</summary>
        public bool? IsSystem { get; set; }
    }
}
