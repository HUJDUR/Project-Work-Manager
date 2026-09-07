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
    public class ActivityLogService
        : BaseReadService<ActivityLog, ActivityLogResponse, ActivityLogSearchObject>, IActivityLogService
    {
        public ActivityLogService(PWMDbContext dbContext, IMapper mapper)
            : base(mapper, dbContext)
        {
        }

        protected override IEnumerable<ActivityLog> ApplyFilters(IEnumerable<ActivityLog> query, ActivityLogSearchObject? search)
        {
            if (search == null)
            {
                return query;
            }

            if (search.UserId.HasValue)
            {
                query = query.Where(x => x.UserId == search.UserId.Value);
            }

            if (search.ActivityLogTypeId.HasValue)
            {
                query = query.Where(x => x.ActivityLogTypeId == search.ActivityLogTypeId.Value);
            }

            if (search.GeneratedReportId.HasValue)
            {
                query = query.Where(x => x.GeneratedReportId == search.GeneratedReportId.Value);
            }

            if (search.DateFrom.HasValue)
            {
                query = query.Where(x => x.Date >= search.DateFrom.Value);
            }

            if (search.DateTo.HasValue)
            {
                query = query.Where(x => x.Date <= search.DateTo.Value);
            }

            return query;
        }
    }
}
