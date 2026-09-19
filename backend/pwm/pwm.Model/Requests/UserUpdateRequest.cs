namespace pwm.Model.Requests
{
    public class UserUpdateRequest
    {
        public string Name { get; set; } = string.Empty;

        public string Surname { get; set; } = string.Empty;

        public string? PhoneNumber { get; set; }

        public string? JobTitle { get; set; }

        public string Email { get; set; } = string.Empty;

        public int UserTypeId { get; set; }

        public bool IsActive { get; set; }

        public string? Password { get; set; }
    }
}
