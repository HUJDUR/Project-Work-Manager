using FluentValidation;
using pwm.Model.Requests;

namespace pwm.Services.Validators
{
    /// <summary>
    /// The columns are NOT NULL, but an empty string satisfies that - so the fields
    /// the Project Details screen marks as required are checked here as well.
    /// </summary>
    public class ProjectInsertRequestValidator : AbstractValidator<ProjectInsertRequest>
    {
        public ProjectInsertRequestValidator()
        {
            RuleFor(x => x.Name)
                .NotEmpty().WithMessage("A project needs a name.")
                .MaximumLength(200);

            RuleFor(x => x.Code)
                .NotEmpty().WithMessage("Every project has a code.")
                .MaximumLength(50);

            RuleFor(x => x.Weight)
                .GreaterThanOrEqualTo(0).WithMessage("Weight cannot be negative.");

            RuleFor(x => x.CustomerId).GreaterThan(0).WithMessage("Pick a customer.");
            RuleFor(x => x.ProjectCategoryId).GreaterThan(0).WithMessage("Pick a category.");

            RuleFor(x => x.Priority).IsInEnum().WithMessage("Pick a priority.");
        }
    }

    public class ProjectUpdateRequestValidator : AbstractValidator<ProjectUpdateRequest>
    {
        public ProjectUpdateRequestValidator()
        {
            RuleFor(x => x.Name)
                .NotEmpty().WithMessage("A project needs a name.")
                .MaximumLength(200);

            RuleFor(x => x.Code)
                .NotEmpty().WithMessage("Every project has a code.")
                .MaximumLength(50);

            RuleFor(x => x.Weight)
                .GreaterThanOrEqualTo(0).WithMessage("Weight cannot be negative.");

            RuleFor(x => x.CustomerId).GreaterThan(0).WithMessage("Pick a customer.");
            RuleFor(x => x.ProjectCategoryId).GreaterThan(0).WithMessage("Pick a category.");

            RuleFor(x => x.Priority).IsInEnum().WithMessage("Pick a priority.");
        }
    }
}
