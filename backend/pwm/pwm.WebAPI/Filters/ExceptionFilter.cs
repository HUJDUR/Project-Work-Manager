using FluentValidation;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;

namespace pwm.WebAPI.Filters
{
    /// <summary>
    /// Turns the exceptions the base services throw into proper status codes
    /// instead of a 500 with a stack trace.
    /// </summary>
    public class ExceptionFilter : IExceptionFilter
    {
        public void OnException(ExceptionContext context)
        {
            switch (context.Exception)
            {
                case KeyNotFoundException notFound:
                    context.Result = new NotFoundObjectResult(new { error = notFound.Message });
                    context.ExceptionHandled = true;
                    break;

                case ValidationException validation:
                    context.Result = new BadRequestObjectResult(new
                    {
                        error = "Validation failed",
                        errors = validation.Errors.Select(e => new { e.PropertyName, e.ErrorMessage }),
                    });
                    context.ExceptionHandled = true;
                    break;
            }
        }
    }
}
