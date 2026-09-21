namespace pwm.Model.Requests
{
    /// <summary>
    /// What a signed-in user may change about their own account.
    ///
    /// Deliberately **not** <see cref="UserUpdateRequest"/>: that one carries
    /// <c>UserTypeId</c> and <c>IsActive</c>, so letting a worker put their own
    /// record would let them make themselves an administrator. This request
    /// cannot express either, and the id it applies to comes from the token.
    /// </summary>
    public class UserProfileUpdateRequest
    {
        public string Name { get; set; } = string.Empty;

        public string Surname { get; set; } = string.Empty;

        public string Email { get; set; } = string.Empty;

        public string? PhoneNumber { get; set; }

        /// <summary>Required only when <see cref="NewPassword"/> is set.</summary>
        public string? CurrentPassword { get; set; }

        /// <summary>Null to keep the password as it is.</summary>
        public string? NewPassword { get; set; }
    }
}
