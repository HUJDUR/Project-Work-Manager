using System.Text.Json;
using System.Text.Json.Serialization;

namespace pwm.WebAPI.Json
{
    /// <summary>
    /// Every stamp in the database is written as <c>DateTime.UtcNow</c>, but SQL
    /// Server's <c>datetime2</c> columns carry no zone, so EF Core always reads one
    /// back with <c>Kind == Unspecified</c>. Left alone, the default serializer then
    /// writes it with no <c>Z</c>/offset either, so a client has no way to tell it
    /// apart from a value that was always meant to be read as its own local time -
    /// Dart, for one, parses it as local and is then off by whatever this machine's
    /// UTC offset happens to be. This forces the zone back on both ways, since by
    /// convention every <c>DateTime</c> this API reads or writes is UTC.
    /// </summary>
    public class UtcDateTimeConverter : JsonConverter<DateTime>
    {
        public override DateTime Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
            => DateTime.SpecifyKind(reader.GetDateTime(), DateTimeKind.Utc);

        public override void Write(Utf8JsonWriter writer, DateTime value, JsonSerializerOptions options)
            => writer.WriteStringValue(DateTime.SpecifyKind(value, DateTimeKind.Utc));
    }

    public class UtcNullableDateTimeConverter : JsonConverter<DateTime?>
    {
        public override DateTime? Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
            => reader.TokenType == JsonTokenType.Null
                ? null
                : DateTime.SpecifyKind(reader.GetDateTime(), DateTimeKind.Utc);

        public override void Write(Utf8JsonWriter writer, DateTime? value, JsonSerializerOptions options)
        {
            if (value is null)
            {
                writer.WriteNullValue();
            }
            else
            {
                writer.WriteStringValue(DateTime.SpecifyKind(value.Value, DateTimeKind.Utc));
            }
        }
    }
}
