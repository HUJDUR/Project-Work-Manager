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
    public class ReportTypeService
        : BaseCRUDService<ReportType, ReportTypeResponse, ReportTypeSearchObject, ReportTypeInsertRequest, ReportTypeUpdateRequest>, IReportTypeService
    {
        public ReportTypeService(
            PWMDbContext dbContext,
            IMapper mapper,
            IValidator<ReportTypeInsertRequest> insertValidator,
            IValidator<ReportTypeUpdateRequest> updateValidator)
            : base(dbContext, mapper, insertValidator, updateValidator)
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
