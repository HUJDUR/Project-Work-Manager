using Microsoft.EntityFrameworkCore;
using pwm.Model.Exceptions;
using pwm.Services.Database;

namespace pwm.Services.Business
{
    /// <summary>
    /// What a company has to be to be picked for something. A deactivated company
    /// stays on everything it is already on, but nothing new may point at it - the
    /// same way a deactivated worker keeps their history. And each role takes its
    /// kind of company: a customer orders projects, a transport company hauls them.
    /// </summary>
    public static class CompanyRules
    {
        /// <summary>The seeded <c>CompanyTypes.Name</c> the rules below recognise a customer by.</summary>
        public const string CustomerType = "Customer";

        /// <summary>The seeded <c>CompanyTypes.Name</c> the rules below recognise a carrier by.</summary>
        public const string TransportType = "Transport";

        /// <summary>The company types the rules depend on, which therefore keep their names.</summary>
        public static readonly string[] ProtectedTypes = [CustomerType, TransportType];

        /// <summary>
        /// Throws when <paramref name="newId"/> names a deactivated company, unless it
        /// is the one already there (<paramref name="currentId"/>) - an edit that
        /// leaves the field alone still saves.
        /// </summary>
        public static async Task EnsureSelectableAsync(PWMDbContext db, int? newId, int? currentId, string role)
        {
            if (newId is not { } id || id == currentId)
            {
                return;
            }

            var company = await db.Companies
                .Where(x => x.Id == id)
                .Select(x => new { x.Name, x.IsActive })
                .FirstOrDefaultAsync();

            if (company is { IsActive: false })
            {
                throw new ClientException($"{company.Name} is deactivated, so it cannot be picked as the {role}.");
            }
        }

        /// <summary>
        /// Throws unless <paramref name="newId"/> names a company of type
        /// <paramref name="typeName"/> - or, with <paramref name="mustBe"/> false, of
        /// any other type. The one already there (<paramref name="currentId"/>) is let
        /// through, as in <see cref="EnsureSelectableAsync"/>.
        /// </summary>
        public static async Task EnsureTypeAsync(
            PWMDbContext db, int? newId, int? currentId, string typeName, bool mustBe, string role)
        {
            if (newId is not { } id || id == currentId)
            {
                return;
            }

            var company = await db.Companies
                    .Where(x => x.Id == id)
                    .Select(x => new { x.Name, Type = x.CompanyType.Name })
                    .FirstOrDefaultAsync()
                ?? throw new NotFoundException($"Company with id {id} not found.");

            var isType = string.Equals(company.Type, typeName, StringComparison.OrdinalIgnoreCase);

            if (isType != mustBe)
            {
                throw new ClientException(mustBe
                    ? $"{company.Name} is a \"{company.Type}\" company - only a \"{typeName}\" company can be picked as the {role}."
                    : $"{company.Name} is a \"{typeName}\" company, so it cannot be picked as the {role}.");
            }
        }

        /// <summary>A company's city has to be in the country it is given.</summary>
        public static async Task EnsureCityInCountryAsync(PWMDbContext db, int cityId, int countryId)
        {
            var city = await db.Cities
                    .Where(x => x.Id == cityId)
                    .Select(x => new { x.Name, x.CountryId })
                    .FirstOrDefaultAsync()
                ?? throw new ClientException("That city does not exist.");

            if (city.CountryId == countryId)
            {
                return;
            }

            var country = await db.Countries
                    .Where(x => x.Id == countryId)
                    .Select(x => x.Name)
                    .FirstOrDefaultAsync()
                ?? throw new ClientException("That country does not exist.");

            throw new ClientException($"{city.Name} is not in {country} - pick a city of the chosen country.");
        }
    }
}
