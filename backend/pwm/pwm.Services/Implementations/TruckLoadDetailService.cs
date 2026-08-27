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
    public class TruckLoadDetailService
        : BaseCRUDService<TruckLoadDetail, TruckLoadDetailResponse, TruckLoadDetailSearchObject, TruckLoadDetailInsertRequest, TruckLoadDetailUpdateRequest>, ITruckLoadDetailService
    {
        public TruckLoadDetailService(
            PWMDbContext dbContext,
            IMapper mapper,
            IValidator<TruckLoadDetailInsertRequest> insertValidator,
            IValidator<TruckLoadDetailUpdateRequest> updateValidator)
            : base(dbContext, mapper, insertValidator, updateValidator)
        {
        }

        protected override IEnumerable<TruckLoadDetail> ApplyFilters(IEnumerable<TruckLoadDetail> query, TruckLoadDetailSearchObject? search)
        {
            if (search == null)
            {
                return query;
            }

            if (search.TruckLoadId.HasValue)
            {
                query = query.Where(x => x.TruckLoadId == search.TruckLoadId.Value);
            }

            if (search.ProjectId.HasValue)
            {
                query = query.Where(x => x.ProjectId == search.ProjectId.Value);
            }

            return query;
        }
    }
}
