using System;
using System.Linq;
using System.Threading.Tasks;
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

        public async Task IssueAsync(int userId, string token, DateTime expiresAt)
        {
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

        public async Task DeleteAllUserRefreshTokensAsync(int userId)
        {
            // Also clears anything left behind by an abandoned session
            var tokens = await _dbContext.RefreshTokens
                .Where(x => x.UserId == userId || x.ExpiresAt < DateTime.UtcNow)
                .ToListAsync();

            if (tokens.Count == 0)
            {
                return;
            }

            _dbContext.RefreshTokens.RemoveRange(tokens);
            await _dbContext.SaveChangesAsync();
        }
    }
}
