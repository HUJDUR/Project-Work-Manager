# Project Work Manager

A shop-floor management system: work logging, project/transport tracking, and
reporting. The backend is an ASP.NET Core Web API backed by SQL Server; the
frontend is two Flutter apps (`pwm_desktop` for office/admin use, `pwm_mobile`
for workers).

```
backend/
  docker-compose.yml     # SQL Server, RabbitMQ, pwm.WebAPI, pwm.Worker
  .env.example           # copy to .env and fill in
  pwm/
    pwm.Model/            # DTOs, enums, exceptions
    pwm.Services/         # EF Core, business logic, validators, RabbitMQ publisher
    pwm.Common.Services/  # crypto helper, shared Program.cs setup
    pwm.WebAPI/            # controllers, auth, startup - its own container too
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

   Every setting lives in this one file - the database, JWT, RabbitMQ and
   the worker's missed clock-out watchdog; `appsettings.json` holds only
   logging. `DB_PASSWORD` is the SQL Server `sa` password and `JWT_SECRET`
   signs the access tokens the API issues. `docker-compose.yml` loads the file
   into the `api` and `worker` containers, and a host-run process reads it via
   `EnvironmentConfig.LoadDotEnvFile`.

2. Start SQL Server, RabbitMQ, the API and the report-generation worker:

   ```
   cd backend
   docker compose up -d
   ```

   The API answers on `http://localhost:7094` (the port the Flutter apps
   default to), migrating itself on startup. RabbitMQ's management UI is at
   `http://localhost:15672` (`guest`/`guest`) - useful for watching the
   `report-generation` queue while reproducing a problem. `pwm.Worker`'s own
   logs (`docker compose logs -f worker`) are the other half of that: every
   report it picks up, and why one failed.

3. Seed sample data (from `backend/pwm`, against the SQL Server compose just
   started - its port is published to the host, so this runs outside Docker):

   ```
   dotnet run --project pwm.WebAPI --seed
   ```

   Add `--force` to wipe and reseed an existing database. Seeded accounts all
   share the password printed at the end of the seed run.

### Local iteration without rebuilding the API's container

`docker compose up -d --build api` picks up a code change, but rebuilding an
image for every edit is slow. For hot-reload-style iteration, stop just the
containerized API and run it on the host instead - it talks to the same
SQL Server and RabbitMQ, whose ports are published either way:

```
docker compose stop api
cd pwm
dotnet run --project pwm.WebAPI
```

By default this serves `https://localhost:7138` / `http://localhost:7094`
(see `pwm.WebAPI/Properties/launchSettings.json`) - the same `:7094` the
container publishes, so don't run both at once. In `Development`, the Scalar
API reference is available at `/scalar` and migrations are applied
automatically on startup, same as in the container.

### Test accounts

Sign in with either the account's e-mail or its username (first name + surname,
no space, e.g. `NadirHujdur` - the sign-in form takes either). Every seeded
account shares the same password.

| Context | Username | Password |
| --- | --- | --- |
| Desktop verzija | `desktop` | `test` |
| Mobilna verzija | `mobile` | `test` |

`desktop` is a fixed Admin account (`Name="Desktop"`, empty surname, so the
username is exactly `desktop`) and `mobile` is a fixed Production worker
account, both seeded by `DataSeeder.Organisation.DemoAccounts`; a production
worker's account is turned away from the desktop app, since no desktop screen
is theirs, so `mobile` only works from the mobile app.

Every other role also has a seeded account, for testing role-specific
behaviour:

| Role | E-mail | Username | Password |
| --- | --- | --- | --- |
| Admin | `nadir.hujdur@pwm.ba` | `NadirHujdur` | `test` |
| Finances | `nadira.stupar@pwm.ba` | `NadiraStupar` | `test` |
| Project manager | `kenan.fajic@pwm.ba` | `KenanFajic` | `test` |
| Work preparation | `vedad.kahrimanovic@pwm.ba` | `VedadKahrimanovic` | `test` |
| Production worker | `armin.karic@pwm.ba` | `ArminKaric` | `test` |

All five of those also work from the mobile app. 30 more `Production worker`
accounts are seeded with random Bosnian names on the
`firstname.surname@pwm.ba` pattern (about one in ten inactive, to exercise
the deactivated-account path) - see `DataSeeder.Organisation.cs` for the full
name pools, or query the `Users` table after seeding.

### Notes

- The connection string is built from `.env`'s `DB_SERVER`, `DB_NAME`,
  `DB_USER` and `DB_PASSWORD` (`EnvironmentConfig.BuildConnectionString`).
- `pwm.WebAPI` and `pwm.Worker` are each built from their own Dockerfile with
  build context `backend/pwm` (both need their sibling projects visible to
  restore). After changing anything either depends on, rebuild it with
  `docker compose up -d --build api` / `--build worker`.
- `.env` holds host-side addresses (`localhost` and the published ports),
  which a host-run `dotnet run` uses. Inside the compose network the
  containers reach SQL Server and RabbitMQ by service name instead, so
  `docker-compose.yml` overrides only `DB_SERVER`, `RabbitMq__HostName` and
  `RabbitMq__Port` (the `x-in-network` block) - everything else comes from
  `.env` unchanged.

## Frontend

Each app is a standalone Flutter project.

```
cd frontend/pwm_desktop   # or pwm_mobile
flutter pub get
flutter run
```

The API address is read from `API_BASE_URL` (`String.fromEnvironment` in
`lib/providers/base_provider.dart`). The desktop app defaults to
`http://localhost:7094`, and the mobile app to `http://10.0.2.2:7094` on the
Android emulator (its alias for the host machine). Override it at run time:

```
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:7094
```
