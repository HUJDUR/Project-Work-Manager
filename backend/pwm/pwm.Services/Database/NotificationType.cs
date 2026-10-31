using System.ComponentModel.DataAnnotations;

namespace pwm.Services.Database
{
    /// <summary>
    /// What kind of message a notification is. The office manages the types it sends
    /// by hand; the system ones (<see cref="IsSystem"/>) are what the API and
    /// <c>pwm.Worker</c> stamp on the notifications they raise themselves - see
    /// <c>NotificationTypeRules</c>.
    /// </summary>
    public class NotificationType
    {
        [Key]
        public int Id { get; set; }

        [Required]
        [MaxLength(100)]
        public string Name { get; set; } = string.Empty;

        /// <summary>
        /// Raised only by the system, found by name in code - so it can neither be
        /// picked on the send form nor renamed or deleted.
        /// </summary>
        public bool IsSystem { get; set; }
    }
}
