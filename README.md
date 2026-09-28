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

   `DB_PASSWORD` is the SQL Server `sa` password; `JWT_SECRET` signs the
   access tokens the API issues. Both are read by `docker-compose.yml` and by
   `pwm.WebAPI/Program.cs` (`LoadDotEnvFile`) from the same file.

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

- The connection string in `appsettings.json` carries everything except the
  password, which always comes from `.env`/`DB_PASSWORD`.
- `pwm.WebAPI/DevSettings.BypassAuthenticationRequested` must stay `false`
  outside a local, throwaway debugging session — flipping it on turns off
  every `[Authorization]` check for the whole API. It only ever takes effect
  under `ASPNETCORE_ENVIRONMENT=Development`, so leaving it on by mistake
  cannot disable auth in a deployed environment.
- `pwm.WebAPI` and `pwm.Worker` are each built from their own Dockerfile with
  build context `backend/pwm` (both need their sibling projects visible to
  restore). After changing anything either depends on, rebuild it with
  `docker compose up -d --build api` / `--build worker`.
- Nothing about RabbitMQ - host, port, credentials, queue name - lives in
  `appsettings.json`; all five `RabbitMq:*` values come from `.env` (see
  `.env.example`). Host and port differ by how a process reaches the broker:
  a host-run `dotnet run --project pwm.WebAPI` uses `.env`'s `localhost:5672`
  (the container's port is published to the host); the `api`/`worker`
  containers instead get `rabbitmq:5672` directly from `docker-compose.yml`,
  since that is compose-network topology rather than something `.env` should
  own. The credentials and queue name are the same either way, so both read
  those from `.env`.

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
