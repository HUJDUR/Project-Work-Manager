using FluentValidation;
using pwm.Model.Requests;

namespace pwm.Services.Validators
{
    /// <summary>
    /// Every request behind the desktop's Administration screen - the six lookup
    /// tables it can edit, a screen `AppRoles` opens only to an administrator. The columns are all `NOT NULL`
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

    public abstract class NotificationTypeRequestValidator<TRequest> : AbstractValidator<TRequest>
        where TRequest : NotificationTypeInsertRequest
    {
        protected NotificationTypeRequestValidator()
        {
            RuleFor(x => x.Name)
                .NotEmpty().WithMessage("A notification type needs a name.")
                .MaximumLength(100).WithMessage("Keep the name to 100 characters or fewer.");
        }
    }

    public class NotificationTypeInsertRequestValidator : NotificationTypeRequestValidator<NotificationTypeInsertRequest>
    {
    }

    public class NotificationTypeUpdateRequestValidator : NotificationTypeRequestValidator<NotificationTypeUpdateRequest>
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
            RuleFor(x => x.CountryId).GreaterThan(0).WithMessage("Pick a country.");
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
