using System;

namespace pwm.Model.Requests
{
    public class TruckLoadDetailUpdateRequest
    {
        public int TruckLoadId { get; set; }

        public int ProjectId { get; set; }

        public double BrutoWeight { get; set; }

        public double NetoWeight { get; set; }

        public int UnloadPriority { get; set; }

        public string UnloadColor { get; set; } = string.Empty;
    }
}
