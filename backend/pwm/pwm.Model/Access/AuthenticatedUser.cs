using pwm.Model.Responses;

namespace pwm.Model.Access
{
    /// <summary>
    /// A verified account plus its role name. <c>UserResponse</c> only carries
    /// <c>UserTypeId</c>, and the token needs the name to put in the role claim.
    /// </summary>
    public class AuthenticatedUser
    {
        public UserResponse User { get; set; } = null!;

        public string Role { get; set; } = string.Empty;
    }
}
