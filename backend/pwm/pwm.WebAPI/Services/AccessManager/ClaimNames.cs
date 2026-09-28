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

        /// <summary>Read back by <c>OnTokenValidated</c> in <c>Program.cs</c> and compared
        /// against the account's current value - a mismatch means the token was revoked
        /// (by logout) since it was issued.</summary>
        public const string TokenVersion = "TokenVersion";
    }
}
