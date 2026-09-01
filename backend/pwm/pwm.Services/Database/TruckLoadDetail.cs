using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace pwm.Services.Database
{
    public class TruckLoadDetail
    {
        [Key]
        public int Id { get; set; }

        public int TruckLoadId { get; set; }

        [ForeignKey(nameof(TruckLoadId))]
        [Required]
        public TruckLoad TruckLoad { get; set; } = null!;

        public int ProjectId { get; set; }

        [ForeignKey(nameof(ProjectId))]
        [Required]
        public Project Project { get; set; } = null!;

        public double BrutoWeight { get; set; }

        public double NetoWeight { get; set; }

        public int UnloadPriority { get; set; }

        [MaxLength(20)]
        public string UnloadColor { get; set; } = string.Empty;
    }
}
