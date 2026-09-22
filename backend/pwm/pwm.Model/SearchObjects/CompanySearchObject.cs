namespace pwm.Model.SearchObjects
{
    public class CompanySearchObject : BaseSearchObject
    {
        public string? Name { get; set; }

        public int? CountryId { get; set; }

        public int? CityId { get; set; }

        public int? CompanyTypeId { get; set; }
    }
}
