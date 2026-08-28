namespace pwm.Model.Exceptions
{
    /// <summary>
    /// User-facing business rule violation. The WebAPI <c>ExceptionFilter</c> maps this to HTTP 400
    /// with a JSON body: <c>{ "message": "...", "errors": { "clientError": ["..."] } }</c> for clients.
    /// </summary>
    public class ClinetException : Exception
    {
        public ClinetException(string message) : base(message)
        {
        }

        public ClinetException(string message, Exception inner) : base(message, inner)
        {
        }
    }
}
