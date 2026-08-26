using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace pwm.Services.Database
{
    public class WorkLog
    {
        [Key]
        public int Id { get; set; }

        public int UserId { get; set; }

        [ForeignKey(nameof(UserId))]
        [Required]
        public User User { get; set; } = null!;

        [Required]
        public DateTime ClockedIn { get; set; }

        [Required]
        public DateTime? ClockedOut { get; set; }

        [Required]
        public double Hours { get; set; }
    }
}
