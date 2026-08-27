# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Project Work Manager (PWM) — a work-tracking system for a metal fabrication shop. Office staff manage projects, transports and reports from a desktop app; shop-floor workers clock in/out and book hours against project operations from a mobile app. Both talk to one .NET Web API backed by SQL Server.

Monorepo layout:

- `backend/pwm/` — .NET 10 solution (`pwm.slnx`), four projects
- `frontend/pwm_desktop`, `frontend/pwm_mobile` — two Flutter apps (currently scaffolding only, one `main.dart` each)
- `docs/mockups/` — UI mockups that define the intended screens (gitignored)
- `docs/PWM - prijava seminarskog rada v3.md` - defines the projects scope and needed funcionality
- `docs/RSII_Upute_za_izradu_seminarskog_rada_2025_26.md` - defines the project requirements regarding implementation

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
flutter run
flutter test
flutter test test/widget_test.dart --plain-name "<test name>"   # single test
```

There is no backend test project yet.

## Backend architecture

Four projects, referenced in a straight line — `pwm.WebAPI` → `pwm.Services` → (`pwm.Model`, `pwm.Common.Services`):

- **pwm.Model** — DTOs only: `Requests/`, `Responses/`, `SearchObjects/`. No logic.
- **pwm.Services** — EF entities + `PWMDbContext` under `Database/`, the seeder under `Database/Seed/`, and the service layer.
- **pwm.Common.Services** — cross-cutting helpers. `CryptoService` (PBKDF2) is the **only** place passwords get hashed; both `UserService` and the seeder go through `ICryptoService`.
- **pwm.WebAPI** — controllers, `Program.cs`, exception filter.

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

## Configuration

`appsettings.json` holds the `PWMConnection` string. If it has no `Password=`, `Program.cs` appends one from the `DB_PASSWORD` environment variable — matching how `backend/.env` already feeds docker-compose.

Migrations are applied automatically on startup in Development only. Scalar API docs are served at `/scalar/v1` (Development only); the raw spec is at `/openapi/v1.json`.

## Known rough edges

- `BaseReadService.GetAllAsync` assigns the DbSet to an `IEnumerable<TEntity>`, so filtering, sorting and paging all happen **in memory after loading the whole table**. Fine at seed scale, not beyond it. Fixing it means changing `ApplyFilters` to take and return `IQueryable<TEntity>` in all 20 services.
- `WorkLog.ClockedOut`, `WorkLogDetail.FinishedAt` and `Project.ProductionStartDate` are `DateTime?` in C# but carry `[Required]`, so EF made those columns `NOT NULL`. An open shift (clock in with no clock out) currently cannot be stored — this blocks the mobile clock-in flow.
- `CryptoService` builds with `SYSLIB0060`/`SYSLIB0023` obsolescence warnings and its `Verify` uses ordinary string comparison rather than a fixed-time compare.
- Killing a stray API process: `pkill` from Git Bash does not match native Windows processes. Use `Get-NetTCPConnection -LocalPort 5094 -State Listen` then `Stop-Process -Id <pid> -Force`.
