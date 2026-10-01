namespace pwm.Model.Requests
{
    /// <summary>
    /// What a worker picks to clock in: the project and the operation. Nothing else
    /// - who is clocking in comes from the token, and when from the server's clock.
    /// </summary>
    public class ClockInRequest
    {
        public int ProjectId { get; set; }

        public int OperationTypeId { get; set; }

        /// <summary>Optional; blank is stored as none.</summary>
        public string? Note { get; set; }
    }
}
