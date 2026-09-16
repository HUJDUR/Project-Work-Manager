namespace pwm.Model.Requests
{
    public class CityUpdateRequest
    {
        public string Name { get; set; } = string.Empty;

        public string PostalCode { get; set; } = string.Empty;

        public int CountryId { get; set; }
    }
}
