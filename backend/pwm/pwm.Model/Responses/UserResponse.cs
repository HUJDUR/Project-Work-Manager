namespace pwm.Model.Responses
{
    public class UserResponse
    {
        public int Id { get; set; }

        public string Name { get; set; } = string.Empty;

        public string Surname { get; set; } = string.Empty;

        public string? PhoneNumber { get; set; }

        public byte[]? Picture { get; set; }

        public string Email { get; set; } = string.Empty;

        public int UserTypeId { get; set; }

        public bool IsActive { get; set; }
    }
}
