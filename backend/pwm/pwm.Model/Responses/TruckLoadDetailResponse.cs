namespace pwm.Model.Responses
{
    public class TruckLoadDetailResponse
    {
        public int Id { get; set; }

        public int TruckLoadId { get; set; }

        public int ProjectId { get; set; }

        public double BrutoWeight { get; set; }

        public double NetoWeight { get; set; }

        public int UnloadPriority { get; set; }

        public string UnloadColor { get; set; } = string.Empty;
    }
}
