using System.ComponentModel.DataAnnotations;

namespace pwm.Services.Database
{
    public class UserType
    {
        [Key]
        public int Id { get; set; }

        [Required]
        [MaxLength(50)]
        public string Type { get; set; } = string.Empty;
    }
}
