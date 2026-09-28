namespace pwm.Model.Requests
{
    public class UserInsertRequest
    {
        public string Name { get; set; } = string.Empty;

        public string Surname { get; set; } = string.Empty;

        public string? PhoneNumber { get; set; }

        /// <summary>Null leaves the account on the name-letters avatar.</summary>
        public byte[]? Picture { get; set; }

        public string Email { get; set; } = string.Empty;

        public int UserTypeId { get; set; }

        public bool IsActive { get; set; }

        public string Password { get; set; } = string.Empty;
    }
}
