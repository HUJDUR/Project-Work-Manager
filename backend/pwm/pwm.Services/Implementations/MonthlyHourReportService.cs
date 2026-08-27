using System;
using System.Collections.Generic;
using System.Linq;
using FluentValidation;
using MapsterMapper;
using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Database;
using pwm.Services.Interfaces;

namespace pwm.Services.Implementations
{
    public class MonthlyHourReportService
        : BaseReadService<MonthlyHourReport, MonthlyHourReportResponse, MonthlyHourReportSearchObject>, IMonthlyHourReportService
    {
        public MonthlyHourReportService(PWMDbContext dbContext, IMapper mapper)
            : base(mapper, dbContext)
        {
        }

        protected override IEnumerable<MonthlyHourReport> ApplyFilters(IEnumerable<MonthlyHourReport> query, MonthlyHourReportSearchObject? search)
        {
            if (search == null)
            {
                return query;
            }

            if (search.Year.HasValue)
            {
                query = query.Where(x => x.Year == search.Year.Value);
            }

            if (search.Month.HasValue)
            {
                query = query.Where(x => x.Month == search.Month.Value);
            }

            return query;
        }
    }
}
