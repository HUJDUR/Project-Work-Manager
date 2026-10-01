namespace pwm.Worker
{
    /// <summary>Bound from the <c>AbsenceCheck__*</c> values in <c>backend/.env</c>.</summary>
    public class AbsenceCheckOptions
    {
        /// <summary>Sarajevo time of day the list is made, as HH:mm.</summary>
        public string TimeOfDay { get; set; } = "07:30";
    }
}
