namespace pwm.Model.Requests
{
    /// <summary>What the Project Details overview's status controls send - the one
    /// legal way <c>ProjectStatusId</c> is ever allowed to change.</summary>
    public class ProjectStatusChangeRequest
    {
        public int ProjectStatusId { get; set; }

        /// <summary>Why - required when moving to "Rejected", ignored otherwise.</summary>
        public string? Reason { get; set; }
    }
}
