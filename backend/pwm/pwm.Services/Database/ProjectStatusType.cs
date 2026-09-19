using System.ComponentModel.DataAnnotations;

namespace pwm.Services.Database
{
    public class ProjectStatusType
    {
        [Key]
        public int Id { get; set; }

        [Required]
        [MaxLength(100)]
        public string Name { get; set; } = string.Empty;
    }
}
