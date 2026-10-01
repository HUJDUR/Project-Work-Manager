namespace pwm.Model.Requests
{
    /// <summary>What the Transport Details overview's status controls send - the
    /// one legal way <c>TruckLoadStatusId</c> is ever allowed to change.</summary>
    public class TruckLoadStatusChangeRequest
    {
        public int TruckLoadStatusId { get; set; }

        /// <summary>The invoice amount in EUR - required only when moving to
        /// "Finished", which is also the only transition that ever writes it.</summary>
        public decimal? Price { get; set; }

        /// <summary>Why - required when moving to "Rejected", ignored otherwise.</summary>
        public string? Reason { get; set; }
    }
}
