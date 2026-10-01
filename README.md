# Project Work Manager (PWM)

Seminarski rad iz predmeta Razvoj softvera II - Nadir Hujdur, IB210050.

PWM tracks the hours a metal-industry firm's workers spend on each project and
type of work, together with the projects themselves and their truck loads.

- **Mobile app** (`frontend/pwm_mobile`, Android) - for workers. Clock in and
  out against a project and operation (with an optional note), follow the
  running session, review your own hours day by day, browse active projects,
  read notifications, manage your profile.
- **Desktop app** (`frontend/pwm_desktop`, Windows) - for the office.
  Dashboard, projects, work hours and their corrections, monthly hour reports,
  workers, companies and the other reference tables, transports and truck
  loads, PDF reports, notifications, the activity log, and the resource
  estimate (recommender).
- **Backend** (`backend/`) - an ASP.NET Core Web API on SQL Server, a separate
  worker service, and RabbitMQ between them, all run with Docker Compose.

## Pristupni podaci (test accounts)

Every seeded account has the password `test`. Sign in with the username or the
e-mail address.

| Kontekst | Korisničko ime | Lozinka |
| --- | --- | --- |
| Desktop verzija | `desktop` | `test` |
| Mobilna verzija | `mobile` | `test` |

One account per role, for testing what each role may see and do:

| Uloga (role) | Korisničko ime | E-mail | Lozinka |
| --- | --- | --- | --- |
| Admin | `desktop` | `desktop@pwm.ba` | `test` |
| Admin | `NadirHujdur` | `nadir.hujdur@pwm.ba` | `test` |
| Finances | `NadiraStupar` | `nadira.stupar@pwm.ba` | `test` |
| Project manager | `KenanFajic` | `kenan.fajic@pwm.ba` | `test` |
| Work preparation | `VedadKahrimanovic` | `vedad.kahrimanovic@pwm.ba` | `test` |
| Production worker | `mobile` | `mobile@pwm.ba` | `test` |

- A Production worker can only use the mobile app; the desktop app turns that
  role away at sign-in. Every role can use the mobile app.
- The seed also creates 30 more production workers (about one in ten
  deactivated, to show that path), so the reports and lists have real data.

## Pokretanje (running the application)

### 1. Configuration

All configuration is in `backend/.env`, which is not in the repository. Its
password-protected copy, `backend/.env-tajne.zip`, is. Extract it **into the
same folder** with the password **`fit`**, so the file ends up as
`backend/.env`. Windows Explorer, 7-Zip, or `unzip -P fit .env-tajne.zip` (run
from `backend/`) all work.

### 2. Backend

Requires Docker Desktop.

```
cd backend
docker compose up -d
```

This starts four containers:

| Service | Container | Port on the host |
| --- | --- | --- |
| Web API (`pwm.WebAPI`) | `pwm-api` | `http://localhost:7094` |
| Worker (`pwm.Worker`) | `pwm-worker` | - |
| RabbitMQ | `pwm-rabbitmq` | `5672`, management UI `http://localhost:15672` |
| SQL Server 2022 | `project-work-manager` | `1435` |

On its first start the API creates the database (`210050`), applies the
migrations and fills it with test data. That takes about half a minute; once
`docker compose logs api` shows `Now listening on`, the apps can sign in.
Nothing has to be run by hand. A database that already has data is left as it
is.

### 3. Desktop app (Windows)

From the GitHub release: extract `fit-build-<date>.zip` and run
`Release/pwm_desktop.exe`. It talks to the API at `http://localhost:7094`.

### 4. Mobile app (Android emulator)

From the GitHub release: drag `app-release.apk` onto a running Android
emulator (AVD) to install it, then open **pwm_mobile**. It talks to the API at
`http://10.0.2.2:7094` - `10.0.2.2` is the emulator's address for the host
machine.

The API is served over plain HTTP, as recommended, so no certificate has to be
trusted.

## Building from source

Requirements: Flutter (stable, 3.47 or newer), and for the backend outside
Docker the .NET 10 SDK.

### API address (`API_BASE_URL`)

Both apps read the API address with
`String.fromEnvironment('API_BASE_URL')` (`lib/providers/base_provider.dart`).
Without it they use:

| App | Default address |
| --- | --- |
| Desktop | `http://localhost:7094` |
| Mobile on the Android emulator | `http://10.0.2.2:7094` |

Another address is passed at run or build time:

```
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:7094
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:7094   # a physical phone, via the PC's LAN address
```

### Running

```
cd frontend/pwm_desktop        # or frontend/pwm_mobile
flutter pub get
flutter run                    # add -d windows for the desktop app
```

The JSON code that `json_serializable` generates (`*.g.dart`) is committed.
After changing a model, regenerate it:

```
dart run build_runner build --delete-conflicting-outputs
```

### Release builds

Windows (the API at `localhost`):

```
cd frontend/pwm_desktop
flutter clean
flutter build windows --release
```

Output: `frontend/pwm_desktop/build/windows/x64/runner/Release/`

Android (the API at `10.0.2.2`):

```
cd frontend/pwm_mobile
flutter clean
flutter build apk --release
```

Output: `frontend/pwm_mobile/build/app/outputs/flutter-apk/app-release.apk`

No `--dart-define` is needed for either: their defaults are the addresses
above. The build files go into a GitHub release, not into the repository.

### Backend outside Docker

For working on the API, stop its container and run it on the host - it uses
the same SQL Server and RabbitMQ, whose ports are published:

```
cd backend
docker compose stop api
cd pwm
dotnet run --project pwm.WebAPI
```

It serves `http://localhost:7094`, the same port as the container, so don't
run both. In `Development` the Scalar API reference is at `/scalar`.

After changing backend code, rebuild the containers - a plain restart keeps the
old image:

```
cd backend
docker compose up -d --build api worker
```

To wipe the data and seed it again (from `backend/pwm`):

```
dotnet run --project pwm.WebAPI --seed --force
```

## Configuration

Every setting lives in `backend/.env`; `appsettings.json` holds only logging.
`backend/.env.example` lists every key without its value:

- **Database:** `DB_SERVER`, `DB_NAME`, `DB_USER`, `DB_PASSWORD` - the
  connection string is built from these
  (`EnvironmentConfig.BuildConnectionString`). `DB_PASSWORD` is also the SQL
  Server `sa` password Docker Compose sets.
- **JWT:** `JWT_SECRET` and `JwtToken__*` (issuer, audience, token lifetimes).
- **RabbitMQ:** `RabbitMq__HostName`, `RabbitMq__Port`, `RabbitMq__UserName`,
  `RabbitMq__Password`, and the two queue names.
- **Worker:** `MissedClockOut__ThresholdHours`,
  `MissedClockOut__PollIntervalMinutes`, `AbsenceCheck__TimeOfDay`.

`docker-compose.yml` loads the file into the `api` and `worker` containers
(`env_file`) and only overrides the database and RabbitMQ host names, which
differ inside the compose network. A host-run API or worker reads the same
file through `EnvironmentConfig.LoadDotEnvFile`.

## Architecture

```
backend/
  docker-compose.yml       SQL Server, RabbitMQ, pwm.WebAPI, pwm.Worker
  .env-tajne.zip           backend/.env, password "fit"
  .env.example             every key .env holds, without values
  pwm/
    pwm.Model/             requests, responses, search objects, exceptions
    pwm.Services/          EF Core, business rules, validators, seeding, RabbitMQ
    pwm.Common.Services/   password hashing, Sarajevo time, configuration
    pwm.WebAPI/            controllers, JWT auth, SignalR hub - its own container
    pwm.Worker/            background jobs off RabbitMQ - its own container
frontend/
  pwm_desktop/             Flutter Windows app (office)
  pwm_mobile/              Flutter Android app (workers)
recommender-dokumentacija.md
```

- **Reports.** Generating a PDF (`POST /Report/MonthlyWorkHours` or
  `/TransportLoads`) only queues it: the API saves a `GeneratedReport` row and
  publishes its id to RabbitMQ. `pwm.Worker` renders the PDF with QuestPDF and
  stores it on the row. The desktop app polls `GET /Report/{id}/Status`, then
  downloads it.
- **Worker jobs.** Besides rendering reports, `pwm.Worker` notifies admins and
  project managers about shifts left open too long (missed clock-out) and, on
  weekday mornings, about production workers who have not clocked in.
- **Live notifications.** Both apps keep a SignalR connection to
  `/hubs/notifications`. Every saved notification pushes a signal to its
  recipients' apps, which reload. The worker cannot reach SignalR itself, so it
  publishes the recipients on RabbitMQ and the API relays them.
- **Time.** The database stores UTC; both apps show Sarajevo time.

## Recommender (resource estimate)

The desktop app's Recommendations screen estimates the hours per type of work,
total hours and number of workers a new project needs. It takes the project's
category, its tonnage and the working days available, fits a linear regression
per type of work over delivered projects of the same category, and explains
each estimate. How it works is described in
[`recommender-dokumentacija.md`](recommender-dokumentacija.md).
