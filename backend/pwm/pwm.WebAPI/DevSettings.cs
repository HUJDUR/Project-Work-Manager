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
        /// Must stay <c>false</c> outside a local, throwaway debugging session: this is an
        /// authentication kill switch, not a feature flag.
        /// </summary>
        public const bool BypassAuthentication = false;
    }
}
