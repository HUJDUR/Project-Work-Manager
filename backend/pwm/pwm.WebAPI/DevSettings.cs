namespace pwm.WebAPI
{
    /// <summary>
    /// TEMPORARY development switches. Nothing outside development should depend on these.
    /// </summary>
    public static class DevSettings
    {
        /// <summary>
        /// Flip this to enable <see cref="BypassAuthentication"/> for a local debugging session.
        /// Kept separate from that property so a stray commit of <c>true</c> here still can't
        /// switch auth off anywhere but a Development environment.
        /// </summary>
        private const bool BypassAuthenticationRequested = false;

        /// <summary>
        /// While true, every endpoint answers without a token and no role is checked — so the
        /// desktop and mobile apps can be built without signing in. The whole JWT setup stays
        /// wired (tokens are still issued and accepted); set <see cref="BypassAuthenticationRequested"/>
        /// to <c>false</c> and the fallback policy plus every <c>[Authorization]</c> role check come
        /// back on. Also requires <c>ASPNETCORE_ENVIRONMENT=Development</c>, so this can never
        /// disable auth in a deployed environment even if the flag above is left on by mistake.
        /// </summary>
        public static bool BypassAuthentication =>
            BypassAuthenticationRequested && string.Equals(
                Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT"),
                "Development",
                StringComparison.OrdinalIgnoreCase);
    }
}
