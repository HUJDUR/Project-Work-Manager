using FluentValidation;
using pwm.Model.Requests;

namespace pwm.Services.Validators
{
    /// <summary>
    /// Every request behind the desktop's Administration screen - the eleven lookup
    /// tables `AppRoles` opens only to an administrator. The columns are all `NOT NULL`
    /// strings, which an empty string satisfies, so each one gets a `NotEmpty` rule here
    /// the way `Project.Name` and `Project.Code` do. `Company`, `OperationType` and
    /// `ProjectCategory` were CRUD before this screen existed but had no dedicated
    /// validator yet - this is also where that gap closes.
    ///
    /// An insert and its update share the same rules for every one of these tables, so
    /// each gets one abstract rule-holder rather than two copies of the same RuleFor
    /// calls; <c>TRequest</c> is constrained to the entity's InsertRequest because every
    /// UpdateRequest here already inherits from it.
    /// </summary>
    public abstract class ActivityLogTypeRequestValidator<TRequest> : AbstractValidator<TRequest>
        where TRequest : ActivityLogTypeInsertRequest
    {
        protected ActivityLogTypeRequestValidator()
        {
            RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
        }
    }

    public class ActivityLogTypeInsertRequestValidator : ActivityLogTypeRequestValidator<ActivityLogTypeInsertRequest>
    {
    }

    public class ActivityLogTypeUpdateRequestValidator : ActivityLogTypeRequestValidator<ActivityLogTypeUpdateRequest>
    {
    }

    public abstract class UserTypeRequestValidator<TRequest> : AbstractValidator<TRequest>
        where TRequest : UserTypeInsertRequest
    {
        protected UserTypeRequestValidator()
        {
            RuleFor(x => x.Type).NotEmpty().MaximumLength(50);
        }
    }

    public class UserTypeInsertRequestValidator : UserTypeRequestValidator<UserTypeInsertRequest>
    {
    }

    public class UserTypeUpdateRequestValidator : UserTypeRequestValidator<UserTypeUpdateRequest>
    {
    }

    public abstract class CountryRequestValidator<TRequest> : AbstractValidator<TRequest>
        where TRequest : CountryInsertRequest
    {
        protected CountryRequestValidator()
        {
            RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
            RuleFor(x => x.Code).NotEmpty().MaximumLength(3);
        }
    }

    public class CountryInsertRequestValidator : CountryRequestValidator<CountryInsertRequest>
    {
    }

    public class CountryUpdateRequestValidator : CountryRequestValidator<CountryUpdateRequest>
    {
    }

    public abstract class CityRequestValidator<TRequest> : AbstractValidator<TRequest>
        where TRequest : CityInsertRequest
    {
        protected CityRequestValidator()
        {
            RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
            RuleFor(x => x.PostalCode).NotEmpty().MaximumLength(20);
            RuleFor(x => x.CountryId).GreaterThan(0).WithMessage("Pick a country.");
        }
    }

    public class CityInsertRequestValidator : CityRequestValidator<CityInsertRequest>
    {
    }

    public class CityUpdateRequestValidator : CityRequestValidator<CityUpdateRequest>
    {
    }

    public abstract class CompanyTypeRequestValidator<TRequest> : AbstractValidator<TRequest>
        where TRequest : CompanyTypeInsertRequest
    {
        protected CompanyTypeRequestValidator()
        {
            RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
        }
    }

    public class CompanyTypeInsertRequestValidator : CompanyTypeRequestValidator<CompanyTypeInsertRequest>
    {
    }

    public class CompanyTypeUpdateRequestValidator : CompanyTypeRequestValidator<CompanyTypeUpdateRequest>
    {
    }

    public abstract class ProjectStatusTypeRequestValidator<TRequest> : AbstractValidator<TRequest>
        where TRequest : ProjectStatusTypeInsertRequest
    {
        protected ProjectStatusTypeRequestValidator()
        {
            RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
        }
    }

    public class ProjectStatusTypeInsertRequestValidator : ProjectStatusTypeRequestValidator<ProjectStatusTypeInsertRequest>
    {
    }

    public class ProjectStatusTypeUpdateRequestValidator : ProjectStatusTypeRequestValidator<ProjectStatusTypeUpdateRequest>
    {
    }

    public abstract class TruckLoadStatusTypeRequestValidator<TRequest> : AbstractValidator<TRequest>
        where TRequest : TruckLoadStatusTypeInsertRequest
    {
        protected TruckLoadStatusTypeRequestValidator()
        {
            RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
        }
    }

    public class TruckLoadStatusTypeInsertRequestValidator : TruckLoadStatusTypeRequestValidator<TruckLoadStatusTypeInsertRequest>
    {
    }

    public class TruckLoadStatusTypeUpdateRequestValidator : TruckLoadStatusTypeRequestValidator<TruckLoadStatusTypeUpdateRequest>
    {
    }

    /// <summary>
    /// Unlike the other ten, <see cref="ReportTypeUpdateRequest"/> does not inherit
    /// <see cref="ReportTypeInsertRequest"/> - the insert alone carries <c>Id</c> (see its
    /// own doc comment) - so the shared rule is expressed against <see cref="IReportTypeRequest"/>
    /// instead of a base request class, and the insert-only <c>Id</c> rule is added on top of it.
    /// </summary>
    public abstract class ReportTypeRequestValidator<TRequest> : AbstractValidator<TRequest>
        where TRequest : IReportTypeRequest
    {
        protected ReportTypeRequestValidator()
        {
            RuleFor(x => x.Description).NotEmpty().MaximumLength(100);
        }
    }

    public class ReportTypeInsertRequestValidator : ReportTypeRequestValidator<ReportTypeInsertRequest>
    {
        public ReportTypeInsertRequestValidator()
        {
            RuleFor(x => x.Id).GreaterThan(0).WithMessage("Every report type needs an id.");
        }
    }

    public class ReportTypeUpdateRequestValidator : ReportTypeRequestValidator<ReportTypeUpdateRequest>
    {
    }

    public abstract class OperationTypeRequestValidator<TRequest> : AbstractValidator<TRequest>
        where TRequest : OperationTypeInsertRequest
    {
        protected OperationTypeRequestValidator()
        {
            RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
        }
    }

    public class OperationTypeInsertRequestValidator : OperationTypeRequestValidator<OperationTypeInsertRequest>
    {
    }

    public class OperationTypeUpdateRequestValidator : OperationTypeRequestValidator<OperationTypeUpdateRequest>
    {
    }

    public abstract class ProjectCategoryRequestValidator<TRequest> : AbstractValidator<TRequest>
        where TRequest : ProjectCategoryInsertRequest
    {
        protected ProjectCategoryRequestValidator()
        {
            RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
        }
    }

    public class ProjectCategoryInsertRequestValidator : ProjectCategoryRequestValidator<ProjectCategoryInsertRequest>
    {
    }

    public class ProjectCategoryUpdateRequestValidator : ProjectCategoryRequestValidator<ProjectCategoryUpdateRequest>
    {
    }

    public abstract class CompanyRequestValidator<TRequest> : AbstractValidator<TRequest>
        where TRequest : CompanyInsertRequest
    {
        protected CompanyRequestValidator()
        {
            RuleFor(x => x.Name).NotEmpty().MaximumLength(200);
            RuleFor(x => x.Address).NotEmpty().MaximumLength(200);
            RuleFor(x => x.CityId).GreaterThan(0).WithMessage("Pick a city.");
            RuleFor(x => x.CompanyTypeId).GreaterThan(0).WithMessage("Pick a company type.");
        }
    }

    public class CompanyInsertRequestValidator : CompanyRequestValidator<CompanyInsertRequest>
    {
    }

    public class CompanyUpdateRequestValidator : CompanyRequestValidator<CompanyUpdateRequest>
    {
    }
}
