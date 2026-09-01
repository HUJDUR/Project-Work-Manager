namespace pwm.Model.Exceptions
{
    /// <summary>
    /// The caller is signed in but may not touch this row - a worker reaching for
    /// someone else's shift, say. The WebAPI <c>ExceptionFilter</c> maps this to HTTP 403
    /// with the same JSON body shape as <see cref="ClinetException"/>, keyed <c>forbidden</c>.
    /// </summary>
    public class ForbiddenException : Exception
    {
        public ForbiddenException(string message) : base(message)
        {
        }
    }
}
