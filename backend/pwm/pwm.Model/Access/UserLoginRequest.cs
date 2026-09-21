namespace pwm.Model.Access
{
    /// <summary>
    /// <see cref="EmailOrUsername"/> is matched against either the account's e-mail or
    /// its username (the account's first + last name, space-insensitive) - there is no
    /// separate stored username, so renaming a user changes what they sign in with.
    /// </summary>
    public class UserLoginRequest
    {
        public string EmailOrUsername { get; set; } = string.Empty;

        public string Password { get; set; } = string.Empty;
    }
}
