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
    public class GeneratedReportService
        : BaseReadService<GeneratedReport, GeneratedReportResponse, GeneratedReportSearchObject>, IGeneratedReportService
    {
        public GeneratedReportService(PWMDbContext dbContext, IMapper mapper)
            : base(mapper, dbContext)
        {
        }

        protected override IEnumerable<GeneratedReport> ApplyFilters(IEnumerable<GeneratedReport> query, GeneratedReportSearchObject? search)
        {
            if (search == null)
            {
                return query;
            }

            if (search.Type.HasValue)
            {
                query = query.Where(x => x.Type == search.Type.Value);
            }

            if (search.GeneratedById.HasValue)
            {
                query = query.Where(x => x.GeneratedById == search.GeneratedById.Value);
            }

            return query;
        }
    }
}
