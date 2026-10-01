using FluentValidation;
using pwm.Model.Requests;
using pwm.Services.Business;

namespace pwm.Services.Validators
{
    /// <summary>A shift - one worker's day - as the office enters or corrects it.</summary>
    public abstract class WorkLogRequestValidator<TRequest> : AbstractValidator<TRequest>
        where TRequest : WorkLogInsertRequest
    {
        protected WorkLogRequestValidator()
        {
            RuleFor(x => x.UserId).GreaterThan(0).WithMessage("Pick a worker.");

            RuleFor(x => x.ClockedIn).NotEqual(default(DateTime))
                .WithMessage("Give the time the shift started.");

            RuleFor(x => x.ClockedOut)
                .GreaterThan(x => x.ClockedIn).WithMessage("A shift has to end after it starts.")
                .Must((request, end) => (end!.Value - request.ClockedIn).TotalHours <= WorkBookingRules.MaxHours)
                    .WithMessage($"A shift can be at most {WorkBookingRules.MaxHours} hours long.")
                .When(x => x.ClockedOut.HasValue);

            RuleFor(x => x.Hours).InclusiveBetween(0, WorkBookingRules.MaxHours)
                .WithMessage($"Hours have to be between 0 and {WorkBookingRules.MaxHours}.");
        }
    }

    public class WorkLogInsertRequestValidator : WorkLogRequestValidator<WorkLogInsertRequest>
    {
    }

    public class WorkLogUpdateRequestValidator : WorkLogRequestValidator<WorkLogUpdateRequest>
    {
    }

    /// <summary>
    /// A block of work on a shift. Its hours are not checked here because they are
    /// not taken from the request at all - <c>WorkLogDetailService</c> works them
    /// out from the two times.
    /// </summary>
    public abstract class WorkLogDetailRequestValidator<TRequest> : AbstractValidator<TRequest>
        where TRequest : WorkLogDetailInsertRequest
    {
        protected WorkLogDetailRequestValidator()
        {
            RuleFor(x => x.WorkLogId).GreaterThan(0).WithMessage("Pick the shift this work belongs to.");
            RuleFor(x => x.ProjectId).GreaterThan(0).WithMessage("Pick a project.");
            RuleFor(x => x.OperationTypeId).GreaterThan(0).WithMessage("Pick an operation.");

            RuleFor(x => x.StartedAt).NotEqual(default(DateTime))
                .WithMessage("Give the time the work started.");

            RuleFor(x => x.FinishedAt)
                .GreaterThan(x => x.StartedAt).WithMessage("Work has to finish after it starts.")
                .Must((request, end) => (end!.Value - request.StartedAt).TotalHours <= WorkBookingRules.MaxHours)
                    .WithMessage($"One block of work can be at most {WorkBookingRules.MaxHours} hours long.")
                .When(x => x.FinishedAt.HasValue);

            RuleFor(x => x.Note)
                .Must(note => WorkBookingRules.CleanNote(note) is not { Length: > WorkBookingRules.NoteMaxLength })
                .WithMessage(WorkBookingRules.NoteTooLong);
        }
    }

    public class WorkLogDetailInsertRequestValidator : WorkLogDetailRequestValidator<WorkLogDetailInsertRequest>
    {
    }

    public class WorkLogDetailUpdateRequestValidator : WorkLogDetailRequestValidator<WorkLogDetailUpdateRequest>
    {
    }

    /// <summary>One line of cargo on a transport.</summary>
    public abstract class TruckLoadDetailRequestValidator<TRequest> : AbstractValidator<TRequest>
        where TRequest : TruckLoadDetailInsertRequest
    {
        protected TruckLoadDetailRequestValidator()
        {
            RuleFor(x => x.TruckLoadId).GreaterThan(0).WithMessage("Pick the transport this cargo is on.");
            RuleFor(x => x.ProjectId).GreaterThan(0).WithMessage("Pick a project.");

            RuleFor(x => x.BrutoWeight).GreaterThan(0)
                .WithMessage("Gross weight has to be more than 0 kg.");

            RuleFor(x => x.NetoWeight)
                .GreaterThan(0).WithMessage("Net weight has to be more than 0 kg.")
                .LessThanOrEqualTo(x => x.BrutoWeight).WithMessage("Net weight cannot be more than the gross weight.");

            RuleFor(x => x.UnloadPriority).GreaterThanOrEqualTo(1)
                .WithMessage("Unload order starts at 1.");

            RuleFor(x => x.UnloadColor)
                .NotEmpty().WithMessage("Pick an unload colour.")
                .MaximumLength(20).WithMessage("Keep the unload colour to 20 characters or fewer.");
        }
    }

    public class TruckLoadDetailInsertRequestValidator : TruckLoadDetailRequestValidator<TruckLoadDetailInsertRequest>
    {
    }

    public class TruckLoadDetailUpdateRequestValidator : TruckLoadDetailRequestValidator<TruckLoadDetailUpdateRequest>
    {
    }

    /// <summary>A qualification: this worker may book this operation.</summary>
    public abstract class UserOperationRequestValidator<TRequest> : AbstractValidator<TRequest>
        where TRequest : UserOperationInsertRequest
    {
        protected UserOperationRequestValidator()
        {
            RuleFor(x => x.UserId).GreaterThan(0).WithMessage("Pick a worker.");
            RuleFor(x => x.OperationTypeId).GreaterThan(0).WithMessage("Pick an operation.");
        }
    }

    public class UserOperationInsertRequestValidator : UserOperationRequestValidator<UserOperationInsertRequest>
    {
    }

    public class UserOperationUpdateRequestValidator : UserOperationRequestValidator<UserOperationUpdateRequest>
    {
    }
}
