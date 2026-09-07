namespace pwm.Model.Access
{
    /// <summary>The seeded <c>UserTypes.Type</c> values, as used in the role claim.</summary>
    public static class Roles
    {
        public const string Admin = "Admin";
        public const string WorkPreparation = "Work preparation";
        public const string Finances = "Finances";
        public const string ProjectManager = "Project manager";
        public const string ProductionWorker = "Production worker";

        /// <summary>Everyone who works from the desktop app - the shop floor is the exception.</summary>
        public static readonly string[] Office =
            [Admin, WorkPreparation, Finances, ProjectManager];
    }
}
