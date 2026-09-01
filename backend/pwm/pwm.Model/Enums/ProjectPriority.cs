namespace pwm.Model.Enums
{
    /// <summary>
    /// How urgent a project is. Hardcoded rather than a lookup table: the four levels
    /// are fixed by the business, not data the office maintains. Stored as the int.
    /// </summary>
    public enum ProjectPriority
    {
        Low = 1,
        Medium = 2,
        High = 3,
        VeryHigh = 4,
    }
}
