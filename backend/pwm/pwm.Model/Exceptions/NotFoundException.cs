namespace pwm.Model.Exceptions
{
    /// <summary>
    /// No row exists for the id a client asked for. The WebAPI <c>ExceptionFilter</c>
    /// maps this to HTTP 404 with the same JSON body shape as <see cref="ClientException"/>,
    /// keyed <c>notFound</c>.
    /// </summary>
    public class NotFoundException : Exception
    {
        public NotFoundException(string message) : base(message)
        {
        }
    }
}
