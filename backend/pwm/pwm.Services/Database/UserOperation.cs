using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace pwm.Services.Database
{
    public class UserOperation
    {
        [Key]
        public int Id { get; set; }

        public int OperationTypeId { get; set; }

        [ForeignKey(nameof(OperationTypeId))]
        [Required]
        public OperationType OperationType { get; set; } = null!;

        public int UserId { get; set; }

        [ForeignKey(nameof(UserId))]
        [Required]
        public User User { get; set; } = null!;
    }
}
