using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace pwm.Services.Database
{
    public class Company
    {
        [Key]
        public int Id { get; set; }

        [Required]
        [MaxLength(200)]
        public string Name { get; set; } = string.Empty;

        public int CityId { get; set; }

        [ForeignKey(nameof(CityId))]
        [Required]
        public City City { get; set; } = null!;

        [Required]
        [MaxLength(200)]
        public string Address { get; set; } = string.Empty;

        [MaxLength(50)]
        public string? VAT { get; set; }

        [MaxLength(50)]
        public string? EORI { get; set; }

        public int CompanyTypeId { get; set; }

        [ForeignKey(nameof(CompanyTypeId))]
        [Required]
        public CompanyType CompanyType { get; set; } = null!;
    }
}
