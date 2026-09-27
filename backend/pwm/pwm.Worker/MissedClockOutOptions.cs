namespace pwm.Worker
{
    /// <summary>
    /// Bound from the <c>MissedClockOut</c> configuration section - see
    /// <c>appsettings.json</c>. Both numbers are deliberately configurable rather than
    /// literals in <see cref="MissedClockOutWorker"/>: a shop with longer legitimate
    /// shifts should be able to raise the threshold without a code change.
    /// </summary>
    public class MissedClockOutOptions
    {
        /// <summary>A shift open this long without a clock-out is treated as forgotten.</summary>
        public double ThresholdHours { get; set; } = 16;

        /// <summary>How often the watchdog checks for shifts that crossed the threshold.</summary>
        public int PollIntervalMinutes { get; set; } = 15;
    }
}
