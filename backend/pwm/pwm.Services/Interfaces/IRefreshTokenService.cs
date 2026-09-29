using pwm.Services.Database;

namespace pwm.Services.Interfaces
{
    /// <summary>
    /// Storage for refresh tokens. Not a CRUD service: nothing outside sign-in touches these rows,
    /// so they have no controller and no DTOs.
    /// </summary>
    public interface IRefreshTokenService
    {
        /// <summary>
        /// Drops the user's stale tokens and issues the new one in the same save, so
        /// a sign-in can never commit the delete without the token that replaces it.
        /// </summary>
        Task RotateAsync(int userId, string token, DateTime expiresAt);

        Task<RefreshToken?> GetStoredTokenAsync(string token);
    }
}
