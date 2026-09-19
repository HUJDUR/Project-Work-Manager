using System.ComponentModel.DataAnnotations;

namespace pwm.Services.Database
{
    public class TruckLoadStatusType
    {
        [Key]
        public int Id { get; set; }

        [Required]
        [MaxLength(100)]
        public string Name { get; set; } = string.Empty;
    }
}
