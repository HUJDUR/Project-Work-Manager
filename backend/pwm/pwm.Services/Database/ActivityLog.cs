using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace pwm.Services.Database
{
    public class ActivityLog
    {
        [Key]
        public int Id { get; set; }

        public int UserId { get; set; }

        [ForeignKey(nameof(UserId))]
        [Required]
        public User User { get; set; } = null!;

        public int ActivityLogTypeId { get; set; }

        [ForeignKey(nameof(ActivityLogTypeId))]
        [Required]
        public ActivityLogType ActivityLogType { get; set; } = null!;

        [Required]
        public DateTime Date { get; set; } = DateTime.UtcNow;
    }
}
