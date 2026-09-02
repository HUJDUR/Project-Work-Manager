using System;

namespace pwm.Model.SearchObjects
{
    public class TruckLoadSearchObject : BaseSearchObject
    {
        /// <summary>
        /// What the Transport Overview search box sends: matches the driver,
        /// the vehicle registration or the carrier.
        /// </summary>
        public string? Search { get; set; }

        public int? TruckLoadStatusId { get; set; }

        public int? TransportCompanyId { get; set; }

        public string? VehicleRegistration { get; set; }

        public DateTime? DateFrom { get; set; }

        public DateTime? DateTo { get; set; }
    }
}
