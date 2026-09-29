namespace pwm.Services.Business
{
    /// <summary>
    /// The whole life cycle a project's status can move through - a centralized
    /// business-process state machine with an audit trail (see
    /// <see cref="Database.ProjectStatusChange"/>), rather than
    /// <c>ProjectStatusId</c> being a plain settable field with no rules. Every
    /// legal jump is listed here and nowhere else; the generic CRUD update path
    /// never touches <c>ProjectStatusId</c> at all (see
    /// <c>ProjectService.UpdateAsync</c>) - <c>ChangeStatusAsync</c> is the only door.
    /// </summary>
    public static class ProjectStatusRules
    {
        public const string Potential = "Potential";
        public const string InProduction = "In production";
        public const string OnHold = "On hold";
        public const string Delivered = "Delivered";
        public const string Rejected = "Rejected";

        /// <summary>Permanent - nothing but Notes changes from here on, and no further
        /// status change is ever allowed.</summary>
        private static readonly string[] Terminal = [Delivered, Rejected];

        /// <summary>Delivered, Rejected and On hold all lock every field but Notes -
        /// the difference is only that On hold can still move on from here.</summary>
        private static readonly string[] EditLocked = [Delivered, Rejected, OnHold];

        /// <summary>The two operations quoting/drawing work is booked against - the
        /// only kind of hours a project still being quoted (Potential) may take.
        /// Mirrored on the desktop by <c>AppRoles.officeOperations</c>.</summary>
        private static readonly string[] OfficeOperationNames = ["Office work", "Technical preparation"];

        public static bool IsTerminal(string status) => Terminal.Contains(status);

        public static bool IsEditLocked(string status) => EditLocked.Contains(status);

        public static bool IsOfficeOperation(string operationName) =>
            OfficeOperationNames.Contains(operationName);

        /// <summary>Whether a new WorkLogDetail/TruckLoadDetail may be booked against a
        /// project in this status at all. On hold, Delivered and Rejected are all frozen -
        /// nothing new is booked against a project that is not actively being worked.</summary>
        public static bool CanBookAnything(string status) => status is Potential or InProduction;

        /// <summary>Within Potential, only office operations (quoting, drawings) may log
        /// hours - the shop floor has not been told to start yet.</summary>
        public static bool RequiresOfficeOperationOnly(string status) => status == Potential;

        /// <summary>
        /// The statuses <paramref name="current"/> may move to next.
        ///
        /// On hold is the one stop that is not one-way: it resumes to whichever side
        /// of the shop floor it was paused from, told apart by whether production had
        /// already started - which is exactly what <paramref name="hasStartedProduction"/>
        /// (a project's <c>ProductionStartDate</c> being set) already records, so no
        /// separate "paused from" column is needed.
        /// </summary>
        public static IReadOnlySet<string> AllowedNext(string current, bool hasStartedProduction) =>
            current switch
            {
                Potential => new HashSet<string> { InProduction, OnHold, Rejected },
                InProduction => new HashSet<string> { OnHold, Delivered, Rejected },
                OnHold => new HashSet<string> { hasStartedProduction ? InProduction : Potential },
                _ => new HashSet<string>(),
            };
    }
}
