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
    public class WorkLogService
        : BaseCRUDService<WorkLog, WorkLogResponse, WorkLogSearchObject, WorkLogInsertRequest, WorkLogUpdateRequest>, IWorkLogService
    {
        public WorkLogService(
            PWMDbContext dbContext,
            IMapper mapper,
            IValidator<WorkLogInsertRequest> insertValidator,
            IValidator<WorkLogUpdateRequest> updateValidator)
            : base(dbContext, mapper, insertValidator, updateValidator)
        {
        }

        protected override IEnumerable<WorkLog> ApplyFilters(IEnumerable<WorkLog> query, WorkLogSearchObject? search)
        {
            if (search == null)
            {
                return query;
            }

            if (search.UserId.HasValue)
            {
                query = query.Where(x => x.UserId == search.UserId.Value);
            }

            if (search.DateFrom.HasValue)
            {
                query = query.Where(x => x.ClockedIn >= search.DateFrom.Value);
            }

            if (search.DateTo.HasValue)
            {
                query = query.Where(x => x.ClockedIn <= search.DateTo.Value);
            }

            return query;
        }
    }
}
