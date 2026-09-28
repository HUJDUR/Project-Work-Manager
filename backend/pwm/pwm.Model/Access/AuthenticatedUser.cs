using pwm.Model.Responses;

namespace pwm.Model.Access
{
    /// <summary>
    /// A verified account plus its role name. <c>UserResponse</c> only carries
    /// <c>UserTypeId</c>, and the token needs the name to put in the role claim - and,
    /// likewise, never carries <see cref="TokenVersion"/>, which is internal to how a
    /// token gets revoked and has no business in a response a client reads.
    /// </summary>
    public class AuthenticatedUser
    {
        public UserResponse User { get; set; } = null!;

        public string Role { get; set; } = string.Empty;

        public int TokenVersion { get; set; }
    }
}
