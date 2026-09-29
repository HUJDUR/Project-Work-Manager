using FluentValidation;
using pwm.Model.Requests;

namespace pwm.Services.Validators
{
    /// <summary>
    /// Mirrored on the desktop by <c>utils/password_rules.dart</c>, so a client
    /// that skips the form still gains nothing by skipping the rules.
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
                .Matches("[0-9]").WithMessage("Needs a number.")
                .Matches("[!@#$%^&*(),.?\":{}|<>]").WithMessage("Needs a special character.");
        }
    }

    /// <summary>
    /// Mirrored on the desktop and mobile pickers, which cap the file they let
    /// the user pick at the same size and offer the same four formats. The bytes
    /// arrive as JSON with no name or MIME type attached, so the format is read
    /// from the file's own signature (its magic bytes) - a renamed file of any
    /// other kind is refused.
    /// </summary>
    public static class PictureRules
    {
        public const int MaxSizeBytes = 5 * 1024 * 1024;

        public static IRuleBuilderOptions<T, byte[]?> Picture<T>(
            this IRuleBuilder<T, byte[]?> rule)
        {
            return rule
                .Must(p => p == null || p.Length <= MaxSizeBytes)
                    .WithMessage("Picture must be 5 MB or smaller.")
                .Must(p => p == null || IsSupportedImage(p))
                    .WithMessage("Picture must be a JPEG, PNG, GIF or WebP image.");
        }

        private static bool IsSupportedImage(byte[] bytes) =>
            StartsWith(bytes, 0xFF, 0xD8, 0xFF)                                        // JPEG
            || StartsWith(bytes, 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)       // PNG
            || StartsWith(bytes, 0x47, 0x49, 0x46, 0x38)                               // GIF8
            || (StartsWith(bytes, 0x52, 0x49, 0x46, 0x46)                              // RIFF....WEBP
                && bytes.Length >= 12
                && bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50);

        private static bool StartsWith(byte[] bytes, params byte[] signature) =>
            bytes.Length >= signature.Length && bytes.AsSpan(0, signature.Length).SequenceEqual(signature);
    }

    /// <summary>
    /// Optional everywhere, but when given it has to look like a phone number.
    /// Mirrored by <c>utils/phone_rules.dart</c> in both apps.
    /// </summary>
    public static class PhoneRules
    {
        public const string Pattern = @"^\+?[0-9][0-9 /-]{5,18}[0-9]$";

        public const string Message =
            "Enter a phone number like +387 61 234 567 - digits, spaces, / or -, with an optional leading +.";
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

            RuleFor(x => x.PhoneNumber)
                .Matches(PhoneRules.Pattern).WithMessage(PhoneRules.Message)
                .When(x => !string.IsNullOrWhiteSpace(x.PhoneNumber));

            RuleFor(x => x.Picture).Picture();
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

            RuleFor(x => x.PhoneNumber)
                .Matches(PhoneRules.Pattern).WithMessage(PhoneRules.Message)
                .When(x => !string.IsNullOrWhiteSpace(x.PhoneNumber));

            RuleFor(x => x.Picture).Picture();
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

            RuleFor(x => x.PhoneNumber)
                .Matches(PhoneRules.Pattern).WithMessage(PhoneRules.Message)
                .When(x => !string.IsNullOrWhiteSpace(x.PhoneNumber));

            RuleFor(x => x.Picture).Picture();
        }
    }
}
