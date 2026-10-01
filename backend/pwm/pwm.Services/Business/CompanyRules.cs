using Microsoft.EntityFrameworkCore;
using pwm.Model.Exceptions;
using pwm.Services.Database;

namespace pwm.Services.Business
{
    /// <summary>
    /// A deactivated company stays on everything it is already on, but nothing new
    /// may point at it - the same way a deactivated worker keeps their history.
    /// </summary>
    public static class CompanyRules
    {
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
    }
}
