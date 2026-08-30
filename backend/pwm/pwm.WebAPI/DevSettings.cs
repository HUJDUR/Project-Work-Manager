namespace pwm.WebAPI
{
    /// <summary>
    /// TEMPORARY development switches. Nothing outside development should depend on these.
    /// </summary>
    public static class DevSettings
    {
        /// <summary>
        /// While true, every endpoint answers without a token and no role is checked — so the
        /// desktop and mobile apps can be built without signing in. The whole JWT setup stays
        /// wired (tokens are still issued and accepted); set this to <c>false</c> and the
        /// fallback policy plus every <c>[Authorization]</c> role check come back on.
        /// </summary>
        public const bool BypassAuthentication = true;
    }
}
