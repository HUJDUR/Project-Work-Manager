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
    /// </summary>
    public class ActivityLogTypeInsertRequestValidator : AbstractValidator<ActivityLogTypeInsertRequest>
    {
        public ActivityLogTypeInsertRequestValidator()
        {
            RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
        }
    }

    public class ActivityLogTypeUpdateRequestValidator : AbstractValidator<ActivityLogTypeUpdateRequest>
    {
        public ActivityLogTypeUpdateRequestValidator()
        {
            RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
        }
    }

    public class UserTypeInsertRequestValidator : AbstractValidator<UserTypeInsertRequest>
    {
        public UserTypeInsertRequestValidator()
        {
            RuleFor(x => x.Type).NotEmpty().MaximumLength(50);
        }
    }

    public class UserTypeUpdateRequestValidator : AbstractValidator<UserTypeUpdateRequest>
    {
        public UserTypeUpdateRequestValidator()
        {
            RuleFor(x => x.Type).NotEmpty().MaximumLength(50);
        }
    }

    public class CountryInsertRequestValidator : AbstractValidator<CountryInsertRequest>
    {
        public CountryInsertRequestValidator()
        {
            RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
            RuleFor(x => x.Code).NotEmpty().MaximumLength(3);
        }
    }

    public class CountryUpdateRequestValidator : AbstractValidator<CountryUpdateRequest>
    {
        public CountryUpdateRequestValidator()
        {
            RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
            RuleFor(x => x.Code).NotEmpty().MaximumLength(3);
        }
    }

    public class CityInsertRequestValidator : AbstractValidator<CityInsertRequest>
    {
        public CityInsertRequestValidator()
        {
            RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
            RuleFor(x => x.PostalCode).NotEmpty().MaximumLength(20);
            RuleFor(x => x.CountryId).GreaterThan(0).WithMessage("Pick a country.");
        }
    }

    public class CityUpdateRequestValidator : AbstractValidator<CityUpdateRequest>
    {
        public CityUpdateRequestValidator()
        {
            RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
            RuleFor(x => x.PostalCode).NotEmpty().MaximumLength(20);
            RuleFor(x => x.CountryId).GreaterThan(0).WithMessage("Pick a country.");
        }
    }

    public class CompanyTypeInsertRequestValidator : AbstractValidator<CompanyTypeInsertRequest>
    {
        public CompanyTypeInsertRequestValidator()
        {
            RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
        }
    }

    public class CompanyTypeUpdateRequestValidator : AbstractValidator<CompanyTypeUpdateRequest>
    {
        public CompanyTypeUpdateRequestValidator()
        {
            RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
        }
    }

    public class ProjectStatusTypeInsertRequestValidator : AbstractValidator<ProjectStatusTypeInsertRequest>
    {
        public ProjectStatusTypeInsertRequestValidator()
        {
            RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
        }
    }

    public class ProjectStatusTypeUpdateRequestValidator : AbstractValidator<ProjectStatusTypeUpdateRequest>
    {
        public ProjectStatusTypeUpdateRequestValidator()
        {
            RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
        }
    }

    public class TruckLoadStatusTypeInsertRequestValidator : AbstractValidator<TruckLoadStatusTypeInsertRequest>
    {
        public TruckLoadStatusTypeInsertRequestValidator()
        {
            RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
        }
    }

    public class TruckLoadStatusTypeUpdateRequestValidator : AbstractValidator<TruckLoadStatusTypeUpdateRequest>
    {
        public TruckLoadStatusTypeUpdateRequestValidator()
        {
            RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
        }
    }

    public class ReportTypeInsertRequestValidator : AbstractValidator<ReportTypeInsertRequest>
    {
        public ReportTypeInsertRequestValidator()
        {
            RuleFor(x => x.Id).GreaterThan(0).WithMessage("Every report type needs an id.");
            RuleFor(x => x.Description).NotEmpty().MaximumLength(100);
        }
    }

    public class ReportTypeUpdateRequestValidator : AbstractValidator<ReportTypeUpdateRequest>
    {
        public ReportTypeUpdateRequestValidator()
        {
            RuleFor(x => x.Description).NotEmpty().MaximumLength(100);
        }
    }

    public class OperationTypeInsertRequestValidator : AbstractValidator<OperationTypeInsertRequest>
    {
        public OperationTypeInsertRequestValidator()
        {
            RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
        }
    }

    public class OperationTypeUpdateRequestValidator : AbstractValidator<OperationTypeUpdateRequest>
    {
        public OperationTypeUpdateRequestValidator()
        {
            RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
        }
    }

    public class ProjectCategoryInsertRequestValidator : AbstractValidator<ProjectCategoryInsertRequest>
    {
        public ProjectCategoryInsertRequestValidator()
        {
            RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
        }
    }

    public class ProjectCategoryUpdateRequestValidator : AbstractValidator<ProjectCategoryUpdateRequest>
    {
        public ProjectCategoryUpdateRequestValidator()
        {
            RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
        }
    }

    public class CompanyInsertRequestValidator : AbstractValidator<CompanyInsertRequest>
    {
        public CompanyInsertRequestValidator()
        {
            RuleFor(x => x.Name).NotEmpty().MaximumLength(200);
            RuleFor(x => x.Address).NotEmpty().MaximumLength(200);
            RuleFor(x => x.CityId).GreaterThan(0).WithMessage("Pick a city.");
            RuleFor(x => x.CompanyTypeId).GreaterThan(0).WithMessage("Pick a company type.");
        }
    }

    public class CompanyUpdateRequestValidator : AbstractValidator<CompanyUpdateRequest>
    {
        public CompanyUpdateRequestValidator()
        {
            RuleFor(x => x.Name).NotEmpty().MaximumLength(200);
            RuleFor(x => x.Address).NotEmpty().MaximumLength(200);
            RuleFor(x => x.CityId).GreaterThan(0).WithMessage("Pick a city.");
            RuleFor(x => x.CompanyTypeId).GreaterThan(0).WithMessage("Pick a company type.");
        }
    }
}
