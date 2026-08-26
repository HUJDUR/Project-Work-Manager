using System;
using System.Linq;
using System.Threading.Tasks;

namespace pwm.Services.Database.Seed
{
    public partial class DataSeeder
    {
        private async Task SeedLookupsAsync()
        {
            _countries =
            [
                new Country { Name = "Bosnia and Herzegovina", Code = "BA" },
                new Country { Name = "Germany", Code = "DE" },
                new Country { Name = "Austria", Code = "AT" },
                new Country { Name = "Croatia", Code = "HR" },
                new Country { Name = "Slovenia", Code = "SI" },
            ];
            await AddRangeAsync(_countries);

            _cities =
            [
                new City { Name = "Sarajevo", PostalCode = "71000", CountryId = FindCountry("BA").Id },
                new City { Name = "Tuzla", PostalCode = "75000", CountryId = FindCountry("BA").Id },
                new City { Name = "Zenica", PostalCode = "72000", CountryId = FindCountry("BA").Id },
                new City { Name = "Gradacac", PostalCode = "76250", CountryId = FindCountry("BA").Id },
                new City { Name = "Munich", PostalCode = "80331", CountryId = FindCountry("DE").Id },
                new City { Name = "Hamburg", PostalCode = "20095", CountryId = FindCountry("DE").Id },
                new City { Name = "Stuttgart", PostalCode = "70173", CountryId = FindCountry("DE").Id },
                new City { Name = "Vienna", PostalCode = "1010", CountryId = FindCountry("AT").Id },
                new City { Name = "Zagreb", PostalCode = "10000", CountryId = FindCountry("HR").Id },
                new City { Name = "Ljubljana", PostalCode = "1000", CountryId = FindCountry("SI").Id },
            ];
            await AddRangeAsync(_cities);

            _companyTypes =
            [
                new CompanyType { Name = "Customer" },
                new CompanyType { Name = "Transport" },
                new CompanyType { Name = "Supplier" },
            ];
            await AddRangeAsync(_companyTypes);

            _userTypes =
            [
                new UserType { Type = "Administrator" },
                new UserType { Type = "Manager" },
                new UserType { Type = "Worker" },
            ];
            await AddRangeAsync(_userTypes);

            _operationTypes =
            [
                new OperationType { Name = "Cutting" },
                new OperationType { Name = "Bending" },
                new OperationType { Name = "Drilling" },
                new OperationType { Name = "Welding" },
                new OperationType { Name = "Grinding" },
                new OperationType { Name = "Painting" },
                new OperationType { Name = "Assembly" },
                new OperationType { Name = "Quality control" },
                new OperationType { Name = "Packing" },
            ];
            await AddRangeAsync(_operationTypes);

            _projectCategories =
            [
                new ProjectCategory { Name = "Steel construction" },
                new ProjectCategory { Name = "Sheet metal parts" },
                new ProjectCategory { Name = "Welded assemblies" },
                new ProjectCategory { Name = "Machined parts" },
                new ProjectCategory { Name = "Handrails and stairs" },
            ];
            await AddRangeAsync(_projectCategories);

            _projectStatuses =
            [
                new ProjectStatusType { Name = "New" },
                new ProjectStatusType { Name = "In preparation" },
                new ProjectStatusType { Name = "In production" },
                new ProjectStatusType { Name = "Ready for delivery" },
                new ProjectStatusType { Name = "Delivered" },
                new ProjectStatusType { Name = "Cancelled" },
            ];
            await AddRangeAsync(_projectStatuses);

            _activityLogTypes =
            [
                new ActivityLogType { Name = "Login" },
                new ActivityLogType { Name = "Logout" },
                new ActivityLogType { Name = "Clock in" },
                new ActivityLogType { Name = "Clock out" },
                new ActivityLogType { Name = "Project created" },
                new ActivityLogType { Name = "Project status changed" },
                new ActivityLogType { Name = "Truck load created" },
                new ActivityLogType { Name = "Report generated" },
            ];
            await AddRangeAsync(_activityLogTypes);
        }

        private Country FindCountry(string code) => _countries.First(x => x.Code == code);

        private City FindCity(string name) => _cities.First(x => x.Name == name);

        private CompanyType FindCompanyType(string name) => _companyTypes.First(x => x.Name == name);

        private UserType FindUserType(string type) => _userTypes.First(x => x.Type == type);

        private OperationType FindOperation(string name) => _operationTypes.First(x => x.Name == name);

        private ProjectCategory FindCategory(string name) => _projectCategories.First(x => x.Name == name);

        private ProjectStatusType FindStatus(string name) => _projectStatuses.First(x => x.Name == name);

        private ActivityLogType FindLogType(string name) => _activityLogTypes.First(x => x.Name == name);

        private Company FindCompany(string name) => _companies.First(x => x.Name == name);

        private User FindUser(string email) => _users.First(x => x.Email == email);
    }
}
