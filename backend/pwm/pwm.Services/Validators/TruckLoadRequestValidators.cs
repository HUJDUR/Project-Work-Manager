using FluentValidation;
using pwm.Model.Requests;

namespace pwm.Services.Validators
{
    /// <summary>
    /// The driver and registration columns are NOT NULL, which an empty string
    /// satisfies - so the fields the Transport Details screen marks as required
    /// are checked here as well. A truck also cannot weigh less loaded than empty.
    /// </summary>
    public class TruckLoadInsertRequestValidator : AbstractValidator<TruckLoadInsertRequest>
    {
        public TruckLoadInsertRequestValidator()
        {
            RuleFor(x => x.DriverName)
                .NotEmpty().WithMessage("The driver needs a name.")
                .MaximumLength(50);

            RuleFor(x => x.DriverSurname)
                .NotEmpty().WithMessage("The driver needs a surname.")
                .MaximumLength(50);

            RuleFor(x => x.VehicleRegistration)
                .NotEmpty().WithMessage("Every load has a vehicle registration.")
                .MaximumLength(20);

            RuleFor(x => x.TransportCompanyId).GreaterThan(0).WithMessage("Pick a carrier.");

            RuleFor(x => x.EmptyWeight)
                .GreaterThanOrEqualTo(0).WithMessage("Empty weight cannot be negative.");

            RuleFor(x => x.FullWeight)
                .GreaterThanOrEqualTo(x => x.EmptyWeight)
                .WithMessage("Full weight cannot be below the empty weight.");

            RuleFor(x => x.Price)
                .GreaterThan(0).WithMessage("The invoice amount cannot be zero or negative.")
                .When(x => x.Price != null);
        }
    }

    public class TruckLoadUpdateRequestValidator : AbstractValidator<TruckLoadUpdateRequest>
    {
        public TruckLoadUpdateRequestValidator()
        {
            RuleFor(x => x.DriverName)
                .NotEmpty().WithMessage("The driver needs a name.")
                .MaximumLength(50);

            RuleFor(x => x.DriverSurname)
                .NotEmpty().WithMessage("The driver needs a surname.")
                .MaximumLength(50);

            RuleFor(x => x.VehicleRegistration)
                .NotEmpty().WithMessage("Every load has a vehicle registration.")
                .MaximumLength(20);

            RuleFor(x => x.TransportCompanyId).GreaterThan(0).WithMessage("Pick a carrier.");

            RuleFor(x => x.EmptyWeight)
                .GreaterThanOrEqualTo(0).WithMessage("Empty weight cannot be negative.");

            RuleFor(x => x.FullWeight)
                .GreaterThanOrEqualTo(x => x.EmptyWeight)
                .WithMessage("Full weight cannot be below the empty weight.");

            RuleFor(x => x.Price)
                .GreaterThan(0).WithMessage("The invoice amount cannot be zero or negative.")
                .When(x => x.Price != null);
        }
    }
}
