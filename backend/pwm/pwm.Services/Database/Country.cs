using System.ComponentModel.DataAnnotations;

namespace pwm.Services.Database
{
    public class Country
    {
        [Key]
        public int Id { get; set; }

        [Required]
        [MaxLength(100)]
        public string Name { get; set; } = string.Empty;

        [Required]
        [MaxLength(3)]
        public string Code { get; set; } = string.Empty;
    }
}
