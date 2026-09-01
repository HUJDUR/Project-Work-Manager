namespace pwm.Model.SearchObjects
{
    public class BaseSearchObject
    {
        /// <summary>
        /// The most rows one request may return. A list endpoint without a ceiling
        /// can be asked for the whole table, so <see cref="PageSize"/> is clamped to
        /// this by the read service - a client that wants everything pages for it.
        /// </summary>
        public const int MaxPageSize = 100;

        public const int DefaultPageSize = 10;

        public int? Page { get; set; } = 1;

        public int? PageSize { get; set; } = DefaultPageSize;

        public bool? IncludeTotalCount { get; set; } = false;
        public string? SortBy { get; set; } 
    }
}
