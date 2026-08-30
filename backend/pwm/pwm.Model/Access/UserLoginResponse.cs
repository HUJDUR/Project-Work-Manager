using System;
using pwm.Model.Responses;

namespace pwm.Model.Access
{
    /// <summary>
    /// What a successful sign-in hands back: the JWT the client sends on every later call,
    /// the refresh token that buys a new one, and the account behind them.
    /// </summary>
    public class UserLoginResponse
    {
        public string Accesstoken { get; set; } = string.Empty;

        public string Refreshtoken { get; set; } = string.Empty;

        public DateTime ExpiresAt { get; set; }

        /// <summary>Name of the user's <c>UserType</c>: Administrator, Manager or Worker.</summary>
        public string Role { get; set; } = string.Empty;

        public UserResponse User { get; set; } = null!;
    }
}
