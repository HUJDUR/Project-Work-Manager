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
    public class WorkLogDetailService
        : BaseCRUDService<WorkLogDetail, WorkLogDetailResponse, WorkLogDetailSearchObject, WorkLogDetailInsertRequest, WorkLogDetailUpdateRequest>, IWorkLogDetailService
    {
        public WorkLogDetailService(
            PWMDbContext dbContext,
            IMapper mapper,
            IValidator<WorkLogDetailInsertRequest> insertValidator,
            IValidator<WorkLogDetailUpdateRequest> updateValidator)
            : base(dbContext, mapper, insertValidator, updateValidator)
        {
        }

        protected override IEnumerable<WorkLogDetail> ApplyFilters(IEnumerable<WorkLogDetail> query, WorkLogDetailSearchObject? search)
        {
            if (search == null)
            {
                return query;
            }

            if (search.WorkLogId.HasValue)
            {
                query = query.Where(x => x.WorkLogId == search.WorkLogId.Value);
            }

            if (search.UserId.HasValue)
            {
                query = query.Where(x => x.UserId == search.UserId.Value);
            }

            if (search.ProjectId.HasValue)
            {
                query = query.Where(x => x.ProjectId == search.ProjectId.Value);
            }

            if (search.OperationTypeId.HasValue)
            {
                query = query.Where(x => x.OperationTypeId == search.OperationTypeId.Value);
            }

            if (search.DateFrom.HasValue)
            {
                query = query.Where(x => x.StartedAt >= search.DateFrom.Value);
            }

            if (search.DateTo.HasValue)
            {
                query = query.Where(x => x.StartedAt <= search.DateTo.Value);
            }

            return query;
        }
    }
}
