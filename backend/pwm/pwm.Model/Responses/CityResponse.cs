namespace pwm.Model.Responses
{
    public class CityResponse
    {
        public int Id { get; set; }

        public string Name { get; set; } = string.Empty;

        public string PostalCode { get; set; } = string.Empty;

        public int CountryId { get; set; }
    }
}
