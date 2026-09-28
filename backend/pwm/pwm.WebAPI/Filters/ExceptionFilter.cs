using pwm.Model.Exceptions;
using FluentValidation;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using System.Net;

namespace pwm.WebAPI.Filters
{
    public class ExceptionFilter : ExceptionFilterAttribute
    {
        private readonly ILogger<ExceptionFilter> _logger;

        public ExceptionFilter(ILogger<ExceptionFilter> logger)
        {
            _logger = logger;
        }

        public override void OnException(ExceptionContext context)
        {
            // FluentValidation exceptions should be converted into model state errors
            if (context.Exception is FluentValidation.ValidationException fvEx)
            {
                foreach (var error in fvEx.Errors)
                {
                    // use property name (empty string for general errors) to key the message
                    context.ModelState.AddModelError(error.PropertyName ?? string.Empty, error.ErrorMessage);
                }

                context.HttpContext.Response.StatusCode = (int)HttpStatusCode.BadRequest;
                _logger.LogWarning(context.Exception, "Validation failed for request.");
            }
            else if (context.Exception is ForbiddenException fe)
            {
                context.ModelState.AddModelError("forbidden", fe.Message);
                context.HttpContext.Response.StatusCode = (int)HttpStatusCode.Forbidden;
                _logger.LogWarning("Forbidden: {Message}", fe.Message);
            }
            else if (context.Exception is ClientException ce)
            {
                context.ModelState.AddModelError("clientError", ce.Message);
                context.HttpContext.Response.StatusCode = (int)HttpStatusCode.BadRequest;
                _logger.LogWarning("Client rule: {Message}", ce.Message);
            }
            else if (context.Exception is NotFoundException nfe)
            {
                context.ModelState.AddModelError("notFound", nfe.Message);
                context.HttpContext.Response.StatusCode = (int)HttpStatusCode.NotFound;
                _logger.LogWarning("Not found: {Message}", nfe.Message);
            }
            else if (context.Exception is DbUpdateException dbEx && IsForeignKeyViolation(dbEx))
            {
                // A record still referenced elsewhere: the DB enforced it (Restrict),
                // and the generic 500 branch below would otherwise be the only thing a
                // client sees. `Entries` says whether this write was a delete, so the
                // message can name the actual problem instead of a generic conflict.
                var wasDelete = dbEx.Entries.Any(e => e.State == EntityState.Deleted);
                var conflictMessage = wasDelete
                    ? "This record is still used by other data and cannot be deleted."
                    : "This action conflicts with related data and could not be completed.";

                context.ModelState.AddModelError("conflict", conflictMessage);
                context.HttpContext.Response.StatusCode = (int)HttpStatusCode.Conflict;
                _logger.LogWarning(dbEx, "Foreign key conflict ({Operation}).", wasDelete ? "delete" : "write");
            }
            else
            {
                // Never the real exception message here: it can carry a stack trace,
                // a connection string, or some other internal detail a client has no
                // business seeing. That detail still reaches the log, just not the response.
                context.ModelState.AddModelError("serverError", "Server side error, please check logs.");
                context.HttpContext.Response.StatusCode = (int)HttpStatusCode.InternalServerError;
                _logger.LogError(context.Exception, "Unhandled exception.");
            }

            var list = context.ModelState
                .Where(c => c.Value is { Errors.Count: > 0 })
                .ToDictionary(
                    c => c.Key,
                    c => c.Value!.Errors.Select(z => z.ErrorMessage).ToList());

            // Single human-readable line for mobile/clients; "clientError" is used for ClientException.
            var allMessages = list.Values.SelectMany(v => v).Where(m => !string.IsNullOrWhiteSpace(m)).ToList();
            var message = allMessages.FirstOrDefault()
                ?? (context.Exception is ClientException ? context.Exception.Message : null)
                ?? "Request could not be processed.";

            context.Result = new JsonResult(new
            {
                message,
                errors = list
            });
        }

        /// <summary>
        /// SQL Server error 547 is a REFERENCE constraint conflict - either a delete
        /// blocked by a child row that still points at it, or an insert/update
        /// pointing at an id that does not exist. Both are represented the same way
        /// at the ADO.NET level, so this is the only reliable way to tell "the FK
        /// rejected this" apart from any other <see cref="DbUpdateException"/>.
        /// </summary>
        private static bool IsForeignKeyViolation(DbUpdateException exception) =>
            exception.InnerException is SqlException { Number: 547 };
    }
}
