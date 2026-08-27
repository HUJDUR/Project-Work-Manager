using System;

namespace pwm.Model.SearchObjects
{
    public class CitySearchObject : BaseSearchObject
    {
        public string? Name { get; set; }

        public string? PostalCode { get; set; }

        public int? CountryId { get; set; }
    }
}
