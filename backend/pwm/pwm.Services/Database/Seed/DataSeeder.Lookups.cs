using System;
using System.Linq;
using System.Threading.Tasks;
using ReportKind = pwm.Model.Enums.ReportType;

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
                new CompanyType { Name = "Transport" },
                new CompanyType { Name = "Customer" },
                new CompanyType { Name = "Unload address for customer" },
            ];
            await AddRangeAsync(_companyTypes);

            _userTypes =
            [
                new UserType { Type = "Admin" },
                new UserType { Type = "Work preparation" },
                new UserType { Type = "Finances" },
                new UserType { Type = "Project manager" },
                new UserType { Type = "Production worker" },
            ];
            await AddRangeAsync(_userTypes);

            _operationTypes =
            [
                new OperationType { Name = "CNC operator" },
                new OperationType { Name = "CNC helper" },
                new OperationType { Name = "Logistics" },
                new OperationType { Name = "Grinding" },
                new OperationType { Name = "Assembly" },
                new OperationType { Name = "Welding" },
                new OperationType { Name = "Straightening" },
                new OperationType { Name = "Kid on practice" },
                new OperationType { Name = "Painting" },
                new OperationType { Name = "Shotblasting" },
                new OperationType { Name = "Packing" },
                new OperationType { Name = "Unloading" },
                new OperationType { Name = "Loading" },
                new OperationType { Name = "QC" },
                new OperationType { Name = "Drilling" },
                new OperationType { Name = "Plate bending" },
                new OperationType { Name = "Profile bending" },
                new OperationType { Name = "Profile cutting" },
                new OperationType { Name = "Technical preparation" },
                new OperationType { Name = "Preparation" },
                new OperationType { Name = "Office work" },
            ];
            await AddRangeAsync(_operationTypes);

            _projectCategories =
            [
                new ProjectCategory { Name = "Sections" },
                new ProjectCategory { Name = "Foundations - steel" },
                new ProjectCategory { Name = "Foundations - aluminum" },
                new ProjectCategory { Name = "Heavy ducting - stainless steel" },
                new ProjectCategory { Name = "Heavy ducting - aluminum" },
                new ProjectCategory { Name = "Driptrays - aluminum" },
                new ProjectCategory { Name = "Driptrays - stainless steel" },
                new ProjectCategory { Name = "General steel construction" },
            ];
            await AddRangeAsync(_projectCategories);

            _projectStatuses =
            [
                new ProjectStatusType { Name = "Delivered" },
                new ProjectStatusType { Name = "In production" },
                new ProjectStatusType { Name = "On hold" },
                new ProjectStatusType { Name = "Rejected" },
            ];
            await AddRangeAsync(_projectStatuses);

            _truckLoadStatuses =
            [
                new TruckLoadStatusType { Name = "Ordered" },
                new TruckLoadStatusType { Name = "In transit" },
                new TruckLoadStatusType { Name = "Delivered" },
                new TruckLoadStatusType { Name = "Finished" },
            ];
            await AddRangeAsync(_truckLoadStatuses);

            // Ids have to match pwm.Model.Enums.ReportType - that is what ReportService branches on.
            _reportTypes =
            [
                new ReportType { Id = (int)ReportKind.MonthlyWorkHours, Description = "Monthly Work Hours" },
                new ReportType { Id = (int)ReportKind.TransportLoads, Description = "Transport & Loads" },
            ];
            await AddRangeAsync(_reportTypes);

            // One "Generated report" type per report, so the log says which one was run.
            _activityLogTypes =
            [
                new ActivityLogType { Name = "Log In" },
                new ActivityLogType { Name = "Log out" },
                new ActivityLogType { Name = "Message sent" },
                new ActivityLogType { Name = ReportLogTypeName("Monthly Work Hours") },
                new ActivityLogType { Name = ReportLogTypeName("Transport & Loads") },
                new ActivityLogType { Name = "Marked messages as read" },
            ];
            await AddRangeAsync(_activityLogTypes);
        }

        /// <summary>Mirrors the name <c>ReportService</c> looks up when it records a run.</summary>
        private static string ReportLogTypeName(string reportDescription) =>
            $"Generated report - {reportDescription}";

        private Country FindCountry(string code) => _countries.First(x => x.Code == code);

        private City FindCity(string name) => _cities.First(x => x.Name == name);

        private CompanyType FindCompanyType(string name) => _companyTypes.First(x => x.Name == name);

        private UserType FindUserType(string type) => _userTypes.First(x => x.Type == type);

        private OperationType FindOperation(string name) => _operationTypes.First(x => x.Name == name);

        private ProjectCategory FindCategory(string name) => _projectCategories.First(x => x.Name == name);

        private ProjectStatusType FindStatus(string name) => _projectStatuses.First(x => x.Name == name);

        private TruckLoadStatusType FindLoadStatus(string name) => _truckLoadStatuses.First(x => x.Name == name);

        private ActivityLogType FindLogType(string name) => _activityLogTypes.First(x => x.Name == name);

        private Company FindCompany(string name) => _companies.First(x => x.Name == name);

        private User FindUser(string email) => _users.First(x => x.Email == email);
    }
}
