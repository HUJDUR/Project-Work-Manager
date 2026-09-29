namespace pwm.Model.Responses
{
    public class TruckLoadResponse
    {
        public int Id { get; set; }

        public int TransportCompanyId { get; set; }

        public int TruckLoadStatusId { get; set; }

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
