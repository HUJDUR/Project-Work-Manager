using System;

namespace pwm.Model.SearchObjects
{
    public class TruckLoadSearchObject : BaseSearchObject
    {
        public int? TransportCompanyId { get; set; }

        public string? VehicleRegistration { get; set; }

        public DateTime? DateFrom { get; set; }

        public DateTime? DateTo { get; set; }
    }
}
