namespace pwm.Model.SearchObjects
{
    public class UserSearchObject : BaseSearchObject
    {
        /// <summary>
        /// Matches name, surname or e-mail: what the desktop search box sends.
        /// The single-field filters below stay exact-purpose.
        /// </summary>
        public string? Search { get; set; }

        public string? Name { get; set; }

        public string? Surname { get; set; }

        public string? Email { get; set; }

        public int? UserTypeId { get; set; }

        public bool? IsActive { get; set; }
    }
}
