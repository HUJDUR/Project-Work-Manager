using System;
using System.Threading.Tasks;
using pwm.Services.Database;

namespace pwm.Services.Interfaces
{
    /// <summary>
    /// Storage for refresh tokens. Not a CRUD service: nothing outside sign-in touches these rows,
    /// so they have no controller and no DTOs.
    /// </summary>
    public interface IRefreshTokenService
    {
        Task IssueAsync(int userId, string token, DateTime expiresAt);

        Task<RefreshToken?> GetStoredTokenAsync(string token);

        Task DeleteAllUserRefreshTokensAsync(int userId);
    }
}
