namespace pwm.Model.Access
{
    /// <summary>
    /// Who is calling, read from the token rather than from the route or the body.
    /// Declared here rather than in pwm.WebAPI so the service layer can enforce
    /// ownership itself (a worker writing only their own shift) instead of a
    /// controller doing it - pwm.Services cannot depend on pwm.WebAPI, since the
    /// reference already runs the other way. The implementation, which needs
    /// IHttpContextAccessor, still lives in pwm.WebAPI.
    /// </summary>
    public interface ICurrentUser
    {
        int? Id { get; }

        string? Role { get; }

        /// <summary>Shop floor: may write their own work logs and nobody else's.</summary>
        bool IsWorker { get; }
    }
}
