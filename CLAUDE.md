# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Project Work Manager (PWM) — a work-tracking system for a metal fabrication shop. Office staff manage projects, transports and reports from a desktop app; shop-floor workers clock in/out and book hours against project operations from a mobile app. Both talk to one .NET Web API backed by SQL Server.

Monorepo layout:

- `backend/pwm/` — .NET 10 solution (`pwm.slnx`), four projects
- `frontend/pwm_desktop` — Flutter desktop app; the dashboard and work hours screens are built, the other modules are placeholders
- `frontend/pwm_mobile` — Flutter mobile app (scaffolding only, one `main.dart`)
- `docs/mockups/` — UI mockups that define the intended screens (gitignored)
- `docs/PWM - prijava seminarskog rada v3.md` - defines the projects scope and needed funcionality
- `docs/RSII_Upute_za_izradu_seminarskog_rada_2025_26.md` - defines the project requirements regarding implementation

## Working on this repo

`docs/progress.md` is the running checklist: which screens are built, what each remaining one needs, and
the open decisions. Read it at the start of a session, take the top unchecked item, and tick it off when
the work lands.

When a task is done, save your closing message to `docs/comments/<task>.md` — see
`docs/comments/work hours.md`. It is the handover: what was built, which judgement calls were made, and
what is still open.

## Commands

All backend commands run from `backend/pwm/`:

```bash
dotnet build                                     # whole solution
dotnet run --project pwm.WebAPI                  # API on http://localhost:5094
dotnet run --project pwm.WebAPI -- --seed        # migrate + fill test data, then exit
dotnet run --project pwm.WebAPI -- --seed --force  # wipe every table, reseed, reset identities
```

Database container, from `backend/` (needs `DB_PASSWORD` in `backend/.env`, gitignored):

```bash
docker compose up -d      # SQL Server 2022 on localhost,1435
```

Migrations — the context lives in `pwm.Services` but is built through the API's DI, so both projects are always passed:

```bash
dotnet ef migrations add <Name> --project pwm.Services --startup-project pwm.WebAPI --output-dir Database/Migrations
```

While the schema is still throwaway, prefer deleting `pwm.Services/Database/Migrations/*.cs` and re-adding `InitialCreate` over stacking migrations. A `PendingModelChangesWarning` at startup means the model and the newest snapshot disagree.

Flutter, from `frontend/pwm_desktop` or `frontend/pwm_mobile`:

```bash
flutter run -d windows                                        # desktop app
flutter run --dart-define=baseUrl=http://localhost:5094/       # point at a different API
flutter test
flutter test test/dashboard_test.dart --plain-name "<test name>"   # single test
```

There is no backend test project yet.

## Backend architecture

Four projects, referenced in a straight line — `pwm.WebAPI` → `pwm.Services` → (`pwm.Model`, `pwm.Common.Services`):

- **pwm.Model** — DTOs only: `Requests/`, `Responses/`, `SearchObjects/`, plus `Exceptions/ClinetException`
  (the spelling is deliberate — the desktop client's error parser is written against it). No logic.
- **pwm.Services** — EF entities + `PWMDbContext` under `Database/`, the seeder under `Database/Seed/`, and the service layer.
- **pwm.Common.Services** — cross-cutting helpers. `CryptoService` (PBKDF2) is the **only** place passwords get hashed; both `UserService` and the seeder go through `ICryptoService`.
- **pwm.WebAPI** — controllers, `Program.cs`, exception filter. `ExceptionFilter` funnels every exception
  through `ModelState` and answers `{ "message": "...", "errors": { key: [messages] } }`: FluentValidation
  failures keyed by property, `ClinetException` under `clientError` (both 400), anything else under
  `serverError` as a 500 with the detail kept in the log.

### The generic service/controller pattern

Nearly every table follows the same five-file shape, so adding an entity means copying the pattern rather than writing new logic:

```
pwm.Model/Responses/XResponse.cs
pwm.Model/SearchObjects/XSearchObject.cs        : BaseSearchObject
pwm.Model/Requests/XInsertRequest.cs, XUpdateRequest.cs   (CRUD entities only)
pwm.Services/Interfaces/IXService.cs            : IBaseReadService<> or IBaseCRUDService<>
pwm.Services/Implementations/XService.cs        : BaseReadService<> or BaseCRUDService<>
pwm.WebAPI/Controllers/XController.cs           : BaseReadController<> or BaseCRUDController<>
```

`BaseReadService` gives `GetAllAsync` (paging, sorting, filtering) and `GetByIdAsync`; `BaseCRUDService` adds insert/update/delete. The only member a concrete service must implement is `ApplyFilters`. Concrete controllers are four-line classes that just inject the service interface — routes come from `[Route("[controller]")]` on the two base controllers, so `ProjectController` serves `/Project`.

Register new services in `pwm.Services/ServiceRegistration.cs` (`AddPwmServices`), which `Program.cs` calls once.

Mapping is Mapster by property name — a `Response`/`Request` property only maps if it matches the entity property. `UserService` overrides `MapInsertRequestToEntity`/`MapUpdateRequestToEntity` because the request carries a plain `Password` while the entity stores `PasswordHash`/`PasswordSalt`.

`BaseCRUDService` demands an `IValidator<TInsert>` and `IValidator<TUpdate>` in its constructor. `Validators/DefaultValidator<T>` is registered as the open-generic fallback so any request type resolves; register a concrete `AbstractValidator<T>` after it to take over for that type.

### Authentication and authorization

JWT, issued by `AccessController` (`/Access/Login`, `/Access/LoginWithRefreshToken`, `/Access/Logout`) over
`pwm.WebAPI/Services/AccessManager`. `UserService.AuthenticateAsync` is the only password check — it goes
through `ICryptoService.Verify` and answers an `AuthenticatedUser` (the `UserResponse` plus the role name,
which `UserResponse` itself does not carry). Tokens are signed from the `JwtToken` section of
`appsettings.json`; the claim types are the constants in `ClaimNames`, and `Roles` in `pwm.Model/Access`
holds the three seeded `UserTypes.Type` values.

Refresh tokens are rows in `RefreshTokens`, rotated on every use — one live token per user, deleted on
sign-out. That table has no controller and no DTOs; `IRefreshTokenService` is its only door.

`Program.cs` sets a **fallback policy of `RequireAuthenticatedUser`**, so a new endpoint is authenticated
unless it says `[AllowAnonymous]` (only sign-in, refresh and the API docs do). Roles are then checked per
action by `Filters/AuthorizationAttribute`, which reads the `Role` claim and answers 403:

- reading is open to every signed-in user;
- writing is `[Authorization(Roles.Administrator, Roles.Manager)]` on `BaseCRUDController`;
- `WorkLogController` and `WorkLogDetailController` override insert/update to admit `Roles.Worker` — that
  is the mobile clock-in path;
- `UserController` narrows all three writes to `Roles.Administrator`.

Changing an action's roles means overriding the base method purely to re-declare the attribute; MVC honours
the most derived one.

### CRUD vs read-only

Deliberate split — do not add write endpoints to the read-only set without asking:

- **CRUD**: Company, User, OperationType, UserOperation, Project, ProjectCategory, WorkLog, WorkLogDetail, TruckLoad, TruckLoadDetail
- **Read-only**: Country, City, UserType, CompanyType, ProjectStatusType, ActivityLogType, ActivityLog, Notification, MonthlyHourReport, MonthlyHourReportDetail

The rule: user-entered data gets CRUD; enum-like values the C# branches on (`ProjectStatusTypes.Name`, `UserTypes.Type`, `CompanyTypes.Name`) stay read-only so business logic can't be broken from Swagger; system-generated rows (activity logs, notifications, monthly reports) stay read-only and are written by services, not controllers.

### Entity and DbContext conventions

Entities mirror the ER diagram in `docs/`:

- Primary key is always `Id`; foreign keys keep descriptive names (`ActivityLogTypeId`, `Project.CustomerId`, `TruckLoad.TransportCompanyId`).
- Reference navigations exist (`ActivityLog.User`); **collection navigations deliberately do not**.
- Because of that, `OnModelCreating` declares every relationship explicitly with `HasOne(...).WithMany()` — the empty `WithMany()` is what says "no inverse navigation".
- `ToTable` pins every table name to the diagram; the DbSet name would otherwise decide it.
- Delete behavior is `Cascade` only where a row is meaningless without its parent and exactly one such path reaches it (detail tables, a user's own logs); everything else is `Restrict`. This is not cosmetic — SQL Server rejects the schema with error 1785 if multiple cascade paths reach a table such as `WorkLogDetails`.
- Fluent API beats data annotations, which is why `Project.DeliveryCompany` needs `.IsRequired(false)` to reconcile its `[Required]` attribute with the nullable `DeliveryCompanyId`.

### Seeding

`Database/Seed/DataSeeder` is one partial class split by area (Lookups, Organisation, Production, Logistics, Reporting). It runs in dependency order, saving after each stage so generated Ids are available to the next. Work logs are generated with a fixed `Random(20260826)` over the last 20 weekdays, and monthly reports are computed from those work logs rather than hardcoded, so a reseeded database always holds the same numbers. All seeded users share the password `test`.

`SeedAsync` is a no-op if any users exist; `--force` calls `ClearAsync`, which deletes children first and reseeds identity counters via `DBCC CHECKIDENT`.

## Desktop frontend architecture

`frontend/pwm_desktop/lib` is layered so a new module only adds files, never rewires the ones below it:

```
main.dart                     MultiProvider over every entity provider, MaterialApp + theme, opens LoginScreen
layouts/master_screen.dart    top bar + left navigation, the frame every screen renders into
models/                       one class per backend table, plus PageResult and the dashboard view model
providers/base_provider.dart  transport: get / getById / insert / update / remove, auth headers, baseUrl
providers/auth_provider.dart  sign in / refresh / sign out, and the token those headers carry
providers/<entity>_provider.dart  four-line subclass per controller: endpoint + row parser
providers/dashboard_provider.dart the dashboard's ChangeNotifier
screens/<name>_screen.dart    one screen per navigation entry
screens/widgets/              the pieces those screens are built from
utils/app_theme.dart          AppColors / AppSpacing / AppCard — the mockup's design tokens
utils/formatters.dart         hours, tonnes, dates, "3 d ago"
utils/api_client_exception.dart  ApiClientException + the parser that reads the API's error bodies
```

State management is `provider`; charts are `fl_chart`. A screen owns its own `ChangeNotifier` through a
`ChangeNotifierProvider` rather than a global store, and takes an optional factory parameter so tests can
inject a provider fed by fakes (see `test/dashboard_test.dart`).

The API base URL comes from `--dart-define=baseUrl` and **must end in a slash** — `BaseProvider` builds
routes as `{baseUrl}{endpoint}`, so endpoints are written without a leading one (`super('Project')`).
It defaults to `http://localhost:5094/`.

### Models and code generation

Every model mirrors one `pwm.Model.Responses.*Response` and is a `@JsonSerializable()` class whose mappers
are generated — `factory X.fromJson(...) => _$XFromJson(json)` and `Map<String, dynamic> toJson() => _$XToJson(this)`.
Dart field names match the API's camelCase keys one-for-one (the .NET naming policy lower-cases whole
acronyms, so `VAT`/`EORI` arrive as `vat`/`eori`); computed helpers such as `User.fullName` and
`TruckLoad.netWeight` carry `@JsonKey(includeFromJson: false, includeToJson: false)`.

After touching a model, regenerate:

```bash
dart run build_runner build      # add --watch while iterating
```

`PageResult<T>` is the exception: `BaseProvider.get` fills its two fields in directly, so it stays a
plain mutable class with no mapper at all.

`models/notification.dart` declares `Notification`, which collides with Flutter's own class of that name;
a file needing both should import `package:flutter/material.dart` with a `hide Notification` clause.

`BaseProvider<T>` is the only place HTTP happens: `get({filter})`, `getById`, `insert`, `update`, `remove`.
`filter` is a plain map flattened by `getQueryString`, which is what carries the search object's `page`,
`pageSize`, `includeTotalCount` and `sortBy` (it prefixes every pair with `&`, so URLs read `?&page=1` —
ASP.NET binds that fine). `createHeaders` attaches `Authorization: Bearer {AuthProvider.accesstoken}`,
which `LoginScreen` fills in through `AuthProvider.login`. Every call goes out through `BaseProvider.send`,
which on a 401 spends the refresh token once and repeats the request, so an expired access token is
invisible to the screens.

Errors: `validateResponse` throws `ApiClientException` carrying whatever `ApiErrorParser` finds in the
body — a root `message`, else `errors.clientError`, else the other `errors` entries. That is exactly the
shape `pwm.WebAPI/Filters/ExceptionFilter` now emits, so business-rule and validation messages reach the
user verbatim. All five calls run `validateResponse`, so `ApiClientException` is the only failure type a
screen has to handle — except a dead API, where `package:http` still throws its own `ClientException`.
One gap left: the filter has no `KeyNotFoundException` branch, so a missing id comes back 500 rather
than 404. `test/base_provider_test.dart` pins the mapping from each error body to its message.

### Sign-in

`main` opens `LoginScreen`, which pushes `MasterScreen` once `AuthProvider.login` returns; the account chip
in the top bar signs out and comes back. `AuthProvider` keeps the token, refresh token, user and role in
**static** fields because `BaseProvider.createHeaders` reads them with no `BuildContext` to hand — the app
builds exactly one instance, so the static and instance views never disagree. Its three calls
(`Access/Login`, `Access/LoginWithRefreshToken`, `Access/Logout`) are the only HTTP outside `BaseProvider`,
which is deliberate: they are what produces the token that provider's headers carry.

`LoginScreen` takes an optional `onSignedIn` callback for the same reason `DashboardScreen` takes a
provider factory — a test can sign in without the app then trying to load dashboards.

### Where the dashboard numbers come from

Responses carry raw foreign keys and there is no aggregate endpoint, so `DashboardProvider` fetches the
eleven tables it needs in one `Future.wait`, builds id→entity maps, and does every join and sum client-side.
Metrics and both charts cover a rolling 30-day window (`DashboardProvider.windowDays`); "active project"
means any status other than Delivered or Cancelled. This is the seam where a server-side `/Dashboard`
summary endpoint would replace the client-side aggregation if the data ever outgrows seed scale.

Every table it reads is injected as a `BaseProvider<T>`, so the test suite substitutes one generic fake
provider per table instead of stubbing HTTP.

New screens plug into `MasterScreen._destinations`; the entries with no screen yet render a
`PlaceholderBody`.

### Work Hours

A row is one `WorkLogDetail`, joined to its worker through `WorkLog.UserId` and to its project and
operation by id. Two columns the mockup asks for are not in the schema and are derived in
`WorkHoursProvider`: **regular vs overtime** splits each worker-day at
`WorkHoursProvider.regularHoursPerDay` (8 h) by walking that day's bookings in start order, and **status**
reads as "In progress" while either `FinishedAt` or the shift's `ClockedOut` is null. Search, project,
date range and the two funnel-menu toggles all filter client-side, and the four summary cards total
whatever is left after filtering.

"Add Work Hours" writes a `WorkLog` first and then a `WorkLogDetail` pointing at the new id — the API has
no endpoint that creates both. Because `ClockedOut` and `FinishedAt` are `NOT NULL`, the dialog always
sends a finished block; an open shift still cannot be recorded.

## Configuration

`appsettings.json` holds the `PWMConnection` string. If it has no `Password=`, `Program.cs` appends one from the `DB_PASSWORD` environment variable — matching how `backend/.env` already feeds docker-compose.

`JwtToken` holds the signing key, issuer, audience and both lifetimes. The committed `SecretKey` is a
development value; `JWT_SECRET` in the environment is used when the setting is missing, and startup fails
if neither is set.

Migrations are applied automatically on startup in Development only. Scalar API docs are served at `/scalar/v1` (Development only); the raw spec is at `/openapi/v1.json`. Both are mapped `AllowAnonymous`, or the fallback policy would lock them; the spec declares the `Bearer` scheme so Scalar can send a token from `/Access/Login`.

## Known rough edges

- `BaseReadService.GetAllAsync` assigns the DbSet to an `IEnumerable<TEntity>`, so filtering, sorting and paging all happen **in memory after loading the whole table**. Fine at seed scale, not beyond it. Fixing it means changing `ApplyFilters` to take and return `IQueryable<TEntity>` in all 20 services.
- `WorkLog.ClockedOut`, `WorkLogDetail.FinishedAt` and `Project.ProductionStartDate` are `DateTime?` in C# but carry `[Required]`, so EF made those columns `NOT NULL`. An open shift (clock in with no clock out) currently cannot be stored — this blocks the mobile clock-in flow.
- `CryptoService` builds with `SYSLIB0060`/`SYSLIB0023` obsolescence warnings and its `Verify` uses ordinary string comparison rather than a fixed-time compare.
- Killing a stray API process: `pkill` from Git Bash does not match native Windows processes. Use `Get-NetTCPConnection -LocalPort 5094 -State Listen` then `Stop-Process -Id <pid> -Force`.
