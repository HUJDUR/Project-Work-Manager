using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace pwm.Services.Database
{
    public class User
    {
        [Key]
        public int Id { get; set; }

        [Required]
        [MaxLength(50)]
        public string Name { get; set; } = string.Empty;

        [Required]
        [MaxLength(50)]
        public string Surname { get; set; } = string.Empty;

        [Phone]
        [MaxLength(20)]
        public string? PhoneNumber { get; set; }

        /// <summary>Null falls back to the name-letters avatar the apps render.</summary>
        public byte[]? Picture { get; set; }

        [Required]
        [MaxLength(100)]
        [EmailAddress]
        public string Email { get; set; } = string.Empty;

        public int UserTypeId { get; set; }

        [ForeignKey(nameof(UserTypeId))]
        [Required]
        public UserType UserType { get; set; } = null!;

        public bool IsActive { get; set; } = true;

        [Required]
        public string PasswordHash { get; set; } = string.Empty;

        [Required]
        public string PasswordSalt { get; set; } = string.Empty;

        /// <summary>
        /// Embedded in every access token issued to this account and checked against
        /// on every authenticated request (see <c>OnTokenValidated</c> in
        /// <c>Program.cs</c>) - bumping it is what makes logout actually invalidate a
        /// still-unexpired access token server-side, rather than only deleting the
        /// refresh token and leaving the short-lived one usable until it expires on
        /// its own.
        /// </summary>
        public int TokenVersion { get; set; }
    }
}
