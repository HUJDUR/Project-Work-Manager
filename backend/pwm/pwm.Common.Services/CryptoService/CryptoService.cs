using System.Security.Cryptography;
using System.Text;

namespace pwm.Common.Services.CryptoService
{
    public class CryptoService : ICryptoService
    {
        // OWASP's current PBKDF2-HMAC-SHA256 floor, with a 32-byte derived key.
        private const int CurrentIterations = 600_000;
        private const int CurrentKeyLength = 32;

        // What every hash in the database was generated with before this became
        // configurable. A stored hash carries no metadata of its own, so a value
        // with no "iterations." prefix (see GenerateHash) is assumed to be one of
        // these - changing these constants would silently lock out every existing
        // account instead of just weakening new ones.
        private const int LegacyIterations = 10_000;
        private const int LegacyKeyLength = 20;

        public string GenerateHash(string password, string salt)
        {
            var hash = Rfc2898DeriveBytes.Pbkdf2(
                Encoding.UTF8.GetBytes(password),
                Encoding.UTF8.GetBytes(salt),
                CurrentIterations,
                HashAlgorithmName.SHA256,
                CurrentKeyLength);

            return $"{CurrentIterations}.{Convert.ToBase64String(hash)}";
        }

        public string GenerateSalt()
        {
            return Convert.ToBase64String(RandomNumberGenerator.GetBytes(16));
        }

        public bool Verify(string hash, string salt, string password)
        {
            var (iterations, keyLength, storedHash) = ParseHash(hash);

            var computedHash = Rfc2898DeriveBytes.Pbkdf2(
                Encoding.UTF8.GetBytes(password),
                Encoding.UTF8.GetBytes(salt),
                iterations,
                HashAlgorithmName.SHA256,
                keyLength);

            return CryptographicOperations.FixedTimeEquals(computedHash, storedHash);
        }

        /// <summary>
        /// A hash from <see cref="GenerateHash"/> is "{iterations}.{base64}"; a base64
        /// string never contains '.', so its absence unambiguously marks a pre-upgrade,
        /// unprefixed hash instead.
        /// </summary>
        private static (int Iterations, int KeyLength, byte[] Hash) ParseHash(string stored)
        {
            var separator = stored.IndexOf('.');
            if (separator < 0)
            {
                return (LegacyIterations, LegacyKeyLength, Convert.FromBase64String(stored));
            }

            var iterations = int.Parse(stored[..separator]);
            var hashBytes = Convert.FromBase64String(stored[(separator + 1)..]);
            return (iterations, hashBytes.Length, hashBytes);
        }
    }
}
