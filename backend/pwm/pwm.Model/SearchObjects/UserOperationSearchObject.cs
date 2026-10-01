namespace pwm.Model.SearchObjects
{
    public class UserOperationSearchObject : BaseSearchObject
    {
        public int? UserId { get; set; }

        /// <summary>
        /// The signed-in account's own rows - taken from the token, so a client never
        /// sends its own id. A production worker gets only their own rows either way.
        /// </summary>
        public bool? Mine { get; set; }

        public int? OperationTypeId { get; set; }
    }
}
