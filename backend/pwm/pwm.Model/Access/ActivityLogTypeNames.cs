namespace pwm.Model.Access
{
    /// <summary>
    /// The seeded <c>ActivityLogTypes.Name</c> values that application code (rather than
    /// only <c>DataSeeder</c>) writes rows against. One constant per name, so the string
    /// a caller passes to <c>IActivityLogService.RecordAsync</c> can never drift from
    /// what the seeder put in the lookup table - see <see cref="pwm.Model.Access.Roles"/>
    /// for the same pattern applied to role names.
    ///
    /// The two "Generated report - ..." rows are not here: <c>ReportService</c> builds
    /// that name from the report type's own description, which already can't drift since
    /// both come from the same <c>ReportTypes</c> row.
    /// </summary>
    public static class ActivityLogTypeNames
    {
        public const string LogIn = "Log In";
        public const string LogOut = "Log out";
        public const string MessageSent = "Message sent";
        public const string MarkedMessagesAsRead = "Marked messages as read";
        public const string PasswordResetRequested = "Password reset requested";
    }
}
