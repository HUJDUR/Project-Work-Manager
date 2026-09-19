# Project Work Manager

A shop-floor management system: work logging, project/transport tracking, and
reporting. The backend is an ASP.NET Core Web API backed by SQL Server; the
frontend is two Flutter apps (`pwm_desktop` for office/admin use, `pwm_mobile`
for workers).

```
backend/
  docker-compose.yml     # SQL Server, RabbitMQ, pwm.Worker
  .env.example           # copy to .env and fill in
  pwm/
    pwm.Model/            # DTOs, enums, exceptions
    pwm.Services/         # EF Core, business logic, validators, RabbitMQ publisher
    pwm.Common.Services/  # crypto helper, shared Program.cs setup
    pwm.WebAPI/            # controllers, auth, startup
    pwm.Worker/            # renders report PDFs, off RabbitMQ - its own container
frontend/
  pwm_desktop/            # Flutter desktop app (office/admin)
  pwm_mobile/             # Flutter mobile app (workers)
```

Generating a report (`POST /Report/MonthlyWorkHours` or `/TransportLoads`) only
queues it - `pwm.WebAPI` writes a `GeneratedReport` row and publishes its id to
RabbitMQ, then answers immediately. `pwm.Worker`, a separate process consuming
that queue, is what actually renders the PDF with QuestPDF and stores it back
on the row. The desktop app polls `GET /Report/{id}/Status` until it reads
"Completed" (or "Failed", with a reason), then downloads it.

## Backend

### Prerequisites

- .NET 10 SDK
- Docker (for SQL Server), or your own SQL Server instance

### Setup

1. Copy the env template and fill in real values:

   ```
   cp backend/.env.example backend/.env
   ```

   `DB_PASSWORD` is the SQL Server `sa` password; `JWT_SECRET` signs the
   access tokens the API issues. Both are read by `docker-compose.yml` and by
   `pwm.WebAPI/Program.cs` (`LoadDotEnvFile`) from the same file.

2. Start SQL Server, RabbitMQ and the report-generation worker:

   ```
   cd backend
   docker compose up -d
   ```

   RabbitMQ's management UI is at `http://localhost:15672` (`guest`/`guest`) -
   useful for watching the `report-generation` queue while reproducing a
   problem. `pwm.Worker`'s own logs (`docker compose logs -f worker`) are the
   other half of that: every report it picks up, and why one failed.

3. Apply migrations and seed sample data (from `backend/pwm`):

   ```
   dotnet run --project pwm.WebAPI --seed
   ```

   Add `--force` to wipe and reseed an existing database. Seeded accounts all
   share the password printed at the end of the seed run.

4. Run the API:

   ```
   dotnet run --project pwm.WebAPI
   ```

   By default this serves `https://localhost:7138` / `http://localhost:7094`
   (see `pwm.WebAPI/Properties/launchSettings.json`). In `Development`, the
   Scalar API reference is available at `/scalar` and migrations are applied
   automatically on startup.

### Notes

- The connection string in `appsettings.json` carries everything except the
  password, which always comes from `.env`/`DB_PASSWORD`.
- `pwm.WebAPI/DevSettings.BypassAuthentication` must stay `false` outside a
  local, throwaway debugging session — flipping it on turns off every
  `[Authorization]` check for the whole API.
- `pwm.Worker` runs only in Docker, built from `pwm.Worker/Dockerfile` with
  build context `backend/pwm` (it needs its sibling projects visible to
  restore). After changing anything it or `pwm.Services/Reporting` depends
  on, rebuild it with `docker compose up -d --build worker`.
- The API connects to RabbitMQ over `localhost:5672` (the container's port is
  published to the host); `pwm.Worker` connects to it as `rabbitmq:5672`
  instead, since it runs inside the same compose network. Both default to the
  `guest`/`guest` credentials RabbitMQ itself defaults to - see the `RabbitMq`
  section of each project's `appsettings.json` to change that.

## Frontend

Each app is a standalone Flutter project.

```
cd frontend/pwm_desktop   # or pwm_mobile
flutter pub get
flutter run
```

Both apps default to `http://localhost:7094/` for the API (see
`lib/providers/base_provider.dart`). Override it at run time if needed:

```
flutter run --dart-define=baseUrl=http://localhost:7094/
```
