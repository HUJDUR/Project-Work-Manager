namespace pwm.Services.Business
{
    /// <summary>What every status change - project or transport - has in common.</summary>
    public static class StatusChangeRules
    {
        public const int ReasonMaxLength = 500;

        /// <summary>
        /// A rejection has to say why; any other move carries no reason at all.
        /// Returns the trimmed reason to store, or throws with what is wrong.
        /// </summary>
        public static string? ReasonFor(bool isRejection, string? reason, string noun)
        {
            if (!isRejection)
            {
                return null;
            }

            var trimmed = reason?.Trim();

            if (string.IsNullOrEmpty(trimmed))
            {
                throw new Model.Exceptions.ClientException($"Give a reason for rejecting this {noun}.");
            }

            if (trimmed.Length > ReasonMaxLength)
            {
                throw new Model.Exceptions.ClientException(
                    $"Keep the reason to {ReasonMaxLength} characters or fewer.");
            }

            return trimmed;
        }
    }
}
