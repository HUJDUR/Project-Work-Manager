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
        /// Every part of the connection string comes from <c>.env</c> - nothing about the
        /// database lives in appsettings.json. <c>DB_SERVER</c> is the one part that
        /// differs by where the process runs: the host reaches SQL Server on its
        /// published port, the api/worker containers on the compose network, which is
        /// why docker-compose.yml overrides just that one.
        /// </summary>
        public static string BuildConnectionString() =>
            $"Server={Require("DB_SERVER")};Database={Require("DB_NAME")};" +
            $"User Id={Require("DB_USER")};Password={Require("DB_PASSWORD")};" +
            "TrustServerCertificate=True;MultipleActiveResultSets=True";

        /// <summary>A value <c>backend/.env</c> has to supply, failing at startup rather than on first use.</summary>
        public static string Require(string name) =>
            Environment.GetEnvironmentVariable(name) is { Length: > 0 } value
                ? value
                : throw new InvalidOperationException($"{name} is not set - add it to backend/.env.");
    }
}
