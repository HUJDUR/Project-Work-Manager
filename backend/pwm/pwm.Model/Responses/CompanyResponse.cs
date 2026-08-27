using System;

namespace pwm.Model.Responses
{
    public class CompanyResponse
    {
        public int Id { get; set; }

        public string Name { get; set; } = string.Empty;

        public int CityId { get; set; }

        public string Address { get; set; } = string.Empty;

        public string? VAT { get; set; }

        public string? EORI { get; set; }

        public int CompanyTypeId { get; set; }
    }
}
