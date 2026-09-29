namespace pwm.Model.Requests
{
    /// <summary>
    /// Deliberately carries no <c>TruckLoadStatusId</c>: a transport always
    /// starts life "Ordered" and only ever moves on through
    /// <c>TruckLoadController.ChangeStatus</c>. <c>Price</c> rides along for
    /// <see cref="TruckLoadUpdateRequest"/>'s sake (only ever honoured while
    /// "Delivered" - see <c>TruckLoadService.UpdateAsync</c>) but is always
    /// ignored on insert; nothing is ever invoiced before a load exists.
    /// </summary>
    public class TruckLoadInsertRequest
    {
        public int TransportCompanyId { get; set; }

        public DateTime LoadDate { get; set; }

        public string DriverName { get; set; } = string.Empty;

        public string DriverSurname { get; set; } = string.Empty;

        public string VehicleRegistration { get; set; } = string.Empty;

        public double EmptyWeight { get; set; }

        public double FullWeight { get; set; }

        public string? Note { get; set; }

        public decimal? Price { get; set; }
    }
}
