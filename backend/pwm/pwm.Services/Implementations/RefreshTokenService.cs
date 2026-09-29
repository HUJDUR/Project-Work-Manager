using Microsoft.EntityFrameworkCore;
using pwm.Services.Database;
using pwm.Services.Interfaces;

namespace pwm.Services.Implementations
{
    public class RefreshTokenService : IRefreshTokenService
    {
        private readonly PWMDbContext _dbContext;

        public RefreshTokenService(PWMDbContext dbContext)
        {
            _dbContext = dbContext;
        }

        public async Task RotateAsync(int userId, string token, DateTime expiresAt)
        {
            // The drop and the new token commit in one SaveChangesAsync rather than two.
            await RemoveStaleTokensAsync(userId);

            _dbContext.RefreshTokens.Add(new RefreshToken
            {
                UserId = userId,
                Token = token,
                ExpiresAt = expiresAt,
                CreatedAt = DateTime.UtcNow,
            });

            await _dbContext.SaveChangesAsync();
        }

        public async Task<RefreshToken?> GetStoredTokenAsync(string token)
        {
            return await _dbContext.RefreshTokens.FirstOrDefaultAsync(x => x.Token == token);
        }

        /// <summary>
        /// Stages the user's own tokens, plus anything expired for anyone, for removal -
        /// a rotate adds the new token before its one save.
        /// </summary>
        private async Task RemoveStaleTokensAsync(int userId)
        {
            var stale = await _dbContext.RefreshTokens
                .Where(x => x.UserId == userId || x.ExpiresAt < DateTime.UtcNow)
                .ToListAsync();

            if (stale.Count > 0)
            {
                _dbContext.RefreshTokens.RemoveRange(stale);
            }
        }
    }
}
