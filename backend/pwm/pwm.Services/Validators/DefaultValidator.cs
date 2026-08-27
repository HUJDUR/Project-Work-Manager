using FluentValidation;

namespace pwm.Services.Validators
{
    /// <summary>
    /// BaseCRUDService requires an IValidator for every request type. This one
    /// carries no rules and is registered as the open-generic fallback, so any
    /// request without a dedicated validator still resolves. Register a concrete
    /// AbstractValidator&lt;T&gt; after this to take over for that type.
    /// </summary>
    public class DefaultValidator<T> : AbstractValidator<T>
    {
    }
}
