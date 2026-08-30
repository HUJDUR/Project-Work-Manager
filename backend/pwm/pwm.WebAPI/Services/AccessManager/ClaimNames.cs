namespace pwm.WebAPI.Services.AccessManager
{
    /// <summary>Claim types written into the JWT and read back by the authorization filter.</summary>
    public static class ClaimNames
    {
        public const string Id = "Id";
        public const string Name = "Name";
        public const string Surname = "Surname";
        public const string Email = "Email";
        public const string Role = "Role";
        public const string IsActive = "IsActive";
    }
}
