namespace pwm.Model.Access
{
    /// <summary>
    /// The "Reset password" link's whole request - the same identifier
    /// <see cref="UserLoginRequest.EmailOrUsername"/> matches, since this is for
    /// someone who cannot supply a password at all. Never a password of any kind:
    /// this does not reset anything itself, it only tells the office someone asked.
    /// </summary>
    public class PasswordResetRequest
    {
        public string EmailOrUsername { get; set; } = string.Empty;
    }
}
