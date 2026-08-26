using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace pwm.Services.Database
{
    public class ActivityLogType
    {
        [Key]
        public int Id { get; set; }

        [Required]
        [MaxLength(100)]
        public string Name { get; set; } = string.Empty;

    }
}
