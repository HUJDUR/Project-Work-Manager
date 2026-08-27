using System;

namespace pwm.Model.SearchObjects
{
    public class UserSearchObject : BaseSearchObject
    {
        public string? Name { get; set; }

        public string? Surname { get; set; }

        public string? Email { get; set; }

        public int? UserTypeId { get; set; }

        public bool? IsActive { get; set; }
    }
}
