using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace pwm.Services.Database
{
    public class TruckLoad
    {
        [Key]
        public int Id { get; set; }

        public int TransportCompanyId { get; set; }

        [ForeignKey(nameof(TransportCompanyId))]
        [Required]
        public Company TransportCompany { get; set; } = null!;

        public DateTime LoadDate { get; set; }

        [Required]
        [MaxLength(50)]
        public string DriverName { get; set; } = string.Empty;

        [Required]
        [MaxLength(50)]
        public string DriverSurname { get; set; } = string.Empty;

        [Required]
        [MaxLength(20)]
        public string VehicleRegistration { get; set; } = string.Empty;

        public double EmptyWeight { get; set; }

        public double FullWeight { get; set; }

        [MaxLength(1000)]
        public string? Note { get; set; }
    }
}
