namespace pwm.Services.Business
{
    /// <summary>
    /// The whole life cycle a transport's status can move through - the same
    /// centralized state-machine-plus-audit-trail shape as
    /// <see cref="ProjectStatusRules"/>. Every legal jump is listed here and
    /// nowhere else; the generic CRUD update path never touches
    /// <c>TruckLoadStatusId</c> at all (see <c>TruckLoadService.UpdateAsync</c>) -
    /// <c>ChangeStatusAsync</c> is the only door.
    /// </summary>
    public static class TruckLoadStatusRules
    {
        public const string Ordered = "Ordered";
        public const string Delivered = "Delivered";
        public const string Finished = "Finished";
        public const string Rejected = "Rejected";

        /// <summary>Finished and Rejected are both permanent - nothing changes from
        /// here on, not even Notes.</summary>
        private static readonly string[] Terminal = [Finished, Rejected];

        public static bool IsTerminal(string status) => Terminal.Contains(status);

        /// <summary>Everything but Notes and Price - only while still Ordered, the
        /// one status a load's own details (carrier, driver, weights...) can change.</summary>
        public static bool CanEditGeneralFields(string status) => status == Ordered;

        /// <summary>Price is only ever hand-edited while Delivered - there is
        /// nothing to invoice before that, and once Finished or Rejected it is
        /// permanently fixed (Finished sets it for good; Rejected never reaches it).</summary>
        public static bool CanEditPrice(string status) => status == Delivered;

        /// <summary>Notes is the one field every status leaves open, Rejected
        /// included - it is the one thing left to say about a load nothing else
        /// can change any more.</summary>
        public static bool CanEditNotes(string status) => true;

        /// <summary>Cargo can only be added, changed or removed while still Ordered -
        /// never during creation (the load has to be saved first) and never once it
        /// has moved on.</summary>
        public static bool CanEditCargo(string status) => status == Ordered;

        /// <summary>The statuses <paramref name="current"/> may move to next.</summary>
        public static IReadOnlySet<string> AllowedNext(string current) => current switch
        {
            Ordered => new HashSet<string> { Delivered, Rejected },
            Delivered => new HashSet<string> { Finished },
            _ => new HashSet<string>(),
        };
    }
}
