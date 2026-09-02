using FluentValidation;
using pwm.Model.Requests;

namespace pwm.Services.Validators
{
    /// <summary>
    /// What a password has to satisfy. **Mirrored on the desktop** by
    /// <c>utils/password_rules.dart</c>, so a password the form refuses is
    /// refused here too and a client that skips the form gains nothing.
    /// </summary>
    public static class PasswordRules
    {
        public const int MinLength = 8;

        public static IRuleBuilderOptions<T, string?> Password<T>(
            this IRuleBuilder<T, string?> rule)
        {
            return rule
                .MinimumLength(MinLength)
                    .WithMessage($"At least {MinLength} characters.")
                .Matches("[A-Z]").WithMessage("Needs an upper-case letter.")
                .Matches("[a-z]").WithMessage("Needs a lower-case letter.")
                .Matches("[0-9]").WithMessage("Needs a number.");
        }
    }

    /// <summary>
    /// The columns are NOT NULL, which an empty string satisfies - so the fields
    /// the Worker Details screen marks as required are checked here as well.
    /// </summary>
    public class UserInsertRequestValidator : AbstractValidator<UserInsertRequest>
    {
        public UserInsertRequestValidator()
        {
            RuleFor(x => x.Name)
                .NotEmpty().WithMessage("A first name is required.")
                .MaximumLength(50);

            RuleFor(x => x.Surname)
                .NotEmpty().WithMessage("A surname is required.")
                .MaximumLength(50);

            RuleFor(x => x.Email)
                .NotEmpty().WithMessage("Sign-in needs an e-mail address.")
                .EmailAddress().WithMessage("That is not an e-mail address.")
                .MaximumLength(100);

            RuleFor(x => x.UserTypeId).GreaterThan(0).WithMessage("Pick a role.");

            RuleFor(x => x.Password)
                .NotEmpty().WithMessage("A new account needs a password.")
                .Password();
        }
    }

    public class UserUpdateRequestValidator : AbstractValidator<UserUpdateRequest>
    {
        public UserUpdateRequestValidator()
        {
            RuleFor(x => x.Name)
                .NotEmpty().WithMessage("A first name is required.")
                .MaximumLength(50);

            RuleFor(x => x.Surname)
                .NotEmpty().WithMessage("A surname is required.")
                .MaximumLength(50);

            RuleFor(x => x.Email)
                .NotEmpty().WithMessage("Sign-in needs an e-mail address.")
                .EmailAddress().WithMessage("That is not an e-mail address.")
                .MaximumLength(100);

            RuleFor(x => x.UserTypeId).GreaterThan(0).WithMessage("Pick a role.");

            // Null means "keep the current one", so the rules only bite on a
            // password that was actually typed.
            RuleFor(x => x.Password)
                .Password()
                .When(x => !string.IsNullOrEmpty(x.Password));
        }
    }

    /// <summary>
    /// What a signed-in user may change about their own account. Deliberately
    /// has no role and no active flag - see <c>UserController.UpdateMe</c>.
    /// </summary>
    public class UserProfileUpdateRequestValidator
        : AbstractValidator<UserProfileUpdateRequest>
    {
        public UserProfileUpdateRequestValidator()
        {
            RuleFor(x => x.Name)
                .NotEmpty().WithMessage("A first name is required.")
                .MaximumLength(50);

            RuleFor(x => x.Surname)
                .NotEmpty().WithMessage("A surname is required.")
                .MaximumLength(50);

            RuleFor(x => x.Email)
                .NotEmpty().WithMessage("Sign-in needs an e-mail address.")
                .EmailAddress().WithMessage("That is not an e-mail address.")
                .MaximumLength(100);

            RuleFor(x => x.NewPassword)
                .Password()
                .When(x => !string.IsNullOrEmpty(x.NewPassword));

            RuleFor(x => x.CurrentPassword)
                .NotEmpty()
                .WithMessage("Type your current password to change it.")
                .When(x => !string.IsNullOrEmpty(x.NewPassword));
        }
    }
}
