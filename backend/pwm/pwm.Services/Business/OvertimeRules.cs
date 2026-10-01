using pwm.Common.Services.Time;

namespace pwm.Services.Business
{
    /// <summary>
    /// The one overtime rule, used by everything that splits hours - the Work Hours
    /// screen, the Monthly Reports screen and the monthly PDF - so they can never
    /// disagree: the first eight hours a worker books on one Sarajevo day are
    /// regular, everything after is overtime, handed out in start order. A block that
    /// straddles the line is split across both.
    /// </summary>
    public static class OvertimeRules
    {
        public const double RegularHoursPerDay = 8;

        /// <summary>The regular part of every block given, by block id.</summary>
        public static Dictionary<int, double> RegularHours(
            IEnumerable<(int Id, int UserId, DateTime StartedAt, double Hours)> blocks)
        {
            var regularById = new Dictionary<int, double>();

            foreach (var day in blocks.GroupBy(x => (x.UserId, SarajevoTime.DayOf(x.StartedAt))))
            {
                var used = 0.0;

                foreach (var block in day.OrderBy(x => x.StartedAt).ThenBy(x => x.Id))
                {
                    regularById[block.Id] = Math.Clamp(RegularHoursPerDay - used, 0, block.Hours);
                    used += block.Hours;
                }
            }

            return regularById;
        }
    }
}
