namespace pwm.Common.Services.Time
{
    /// <summary>
    /// The shop runs on Sarajevo time. The database and the API's JSON stay in UTC
    /// (a <c>Z</c> on every value, see <c>UtcDateTimeConverter</c>); anything that
    /// depends on the calendar - which day a block of work belongs to, where a month
    /// or a report period starts, a time printed on a PDF - goes through here.
    /// </summary>
    public static class SarajevoTime
    {
        /// <summary>Europe/Sarajevo: CET, and CEST in summer.</summary>
        public static readonly TimeZoneInfo Zone = TimeZoneInfo.FindSystemTimeZoneById("Europe/Sarajevo");

        /// <summary>A UTC instant as Sarajevo wall-clock time.</summary>
        public static DateTime FromUtc(DateTime utc) =>
            TimeZoneInfo.ConvertTimeFromUtc(DateTime.SpecifyKind(utc, DateTimeKind.Utc), Zone);

        /// <summary>A Sarajevo wall-clock time as the UTC instant it names.</summary>
        public static DateTime ToUtc(DateTime sarajevo) =>
            TimeZoneInfo.ConvertTimeToUtc(DateTime.SpecifyKind(sarajevo, DateTimeKind.Unspecified), Zone);

        public static DateTime Now => FromUtc(DateTime.UtcNow);

        public static DateTime Today => Now.Date;

        /// <summary>The Sarajevo calendar day a UTC instant falls on.</summary>
        public static DateTime DayOf(DateTime utc) => FromUtc(utc).Date;

        /// <summary>The UTC instant a Sarajevo calendar day starts at.</summary>
        public static DateTime StartOfDayUtc(DateTime sarajevoDay) => ToUtc(sarajevoDay.Date);
    }
}
