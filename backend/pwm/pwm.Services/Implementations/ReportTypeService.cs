using System;
using System.Collections.Generic;
using System.Linq;
using MapsterMapper;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Database;
using pwm.Services.Interfaces;

namespace pwm.Services.Implementations
{
    public class ReportTypeService
        : BaseReadService<ReportType, ReportTypeResponse, ReportTypeSearchObject>, IReportTypeService
    {
        public ReportTypeService(PWMDbContext dbContext, IMapper mapper)
            : base(mapper, dbContext)
        {
        }

        protected override IEnumerable<ReportType> ApplyFilters(IEnumerable<ReportType> query, ReportTypeSearchObject? search)
        {
            if (search == null)
            {
                return query;
            }

            if (!string.IsNullOrWhiteSpace(search.Description))
            {
                var description = search.Description;
                query = query.Where(x => x.Description.Contains(description, StringComparison.OrdinalIgnoreCase));
            }

            return query;
        }
    }
}
