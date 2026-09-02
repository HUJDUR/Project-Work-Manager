using FluentValidation;
using pwm.Model.Requests;

namespace pwm.Services.Validators
{
    /// <summary>
    /// Title and Message are NOT NULL, which an empty string satisfies - so the
    /// two fields the Send Notification screen marks as required are checked here.
    /// </summary>
    public class NotificationSendRequestValidator : AbstractValidator<NotificationSendRequest>
    {
        public NotificationSendRequestValidator()
        {
            RuleFor(x => x.Title)
                .NotEmpty().WithMessage("A notification needs a title.")
                .MaximumLength(200);

            RuleFor(x => x.Message)
                .NotEmpty().WithMessage("A notification needs a message.")
                .MaximumLength(1000);
        }
    }
}
