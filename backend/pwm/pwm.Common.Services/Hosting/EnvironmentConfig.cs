using Microsoft.Extensions.Configuration;

namespace pwm.Common.Services.Hosting
{
    /// <summary>
    /// Shared between <c>pwm.WebAPI</c> and <c>pwm.Worker</c>'s <c>Program.cs</c> -
    /// both processes read the same <c>backend/.env</c> file and build the same
    /// connection string from it, so a secret's resolution can never quietly
    /// drift between the two.
    /// </summary>
    public static class EnvironmentConfig
    {
        /// <summary>
        /// Reads <c>backend/.env</c> - the same file docker-compose feeds the
        /// container from - into this process's environment. Searches upward from
        /// the working directory rather than assuming one fixed relative path,
        /// since <c>dotnet run --project</c> and an IDE's own launch profile do not
        /// agree on what that directory is. A variable the real environment
        /// already set (CI, a container, an explicit export) is left alone.
        /// </summary>
        public static void LoadDotEnvFile()
        {
            for (var directory = new DirectoryInfo(Directory.GetCurrentDirectory());
                directory != null;
                directory = directory.Parent)
            {
                var candidate = Path.Combine(directory.FullName, ".env");
                if (!File.Exists(candidate))
                {
                    continue;
                }

                foreach (var line in File.ReadAllLines(candidate))
                {
                    var trimmed = line.Trim();
                    if (trimmed.Length == 0 || trimmed.StartsWith('#'))
                    {
                        continue;
                    }

                    var separator = trimmed.IndexOf('=');
                    if (separator <= 0)
                    {
                        continue;
                    }

                    var key = trimmed[..separator].Trim();
                    var value = trimmed[(separator + 1)..].Trim();

                    if (Environment.GetEnvironmentVariable(key) == null)
                    {
                        Environment.SetEnvironmentVariable(key, value);
                    }
                }

                return;
            }
        }

        /// <summary>
        /// appsettings.json carries the shape of the connection string but never the
        /// password - that comes from <c>.env</c> alone, via <see cref="LoadDotEnvFile"/>,
        /// so it is never hardcoded in source control.
        /// </summary>
        public static string BuildConnectionString(IConfiguration configuration)
        {
            var connectionString = configuration.GetConnectionString("PWMConnection")
                ?? throw new InvalidOperationException("Connection string 'PWMConnection' is not configured.");

            if (connectionString.Contains("Password=", StringComparison.OrdinalIgnoreCase))
            {
                return connectionString;
            }

            var password = Environment.GetEnvironmentVariable("DB_PASSWORD")
                ?? throw new InvalidOperationException(
                    "DB_PASSWORD is not set - add it to backend/.env.");

            return connectionString.TrimEnd(';') + $";Password={password}";
        }
    }
}
