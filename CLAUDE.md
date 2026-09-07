# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Project Work Manager (PWM) — a work-tracking system for a metal fabrication shop. Office staff manage projects, transports and reports from a desktop app; shop-floor workers clock in/out and book hours against project operations from a mobile app. Both talk to one .NET Web API backed by SQL Server.

Monorepo layout:

- `backend/pwm/` — .NET 10 solution (`pwm.slnx`), four projects
- `frontend/pwm_desktop` — Flutter desktop app; every screen in the navigation is built. The Recommendations screen is the one
  shell without a working body - the estimator behind it does not exist yet
- `frontend/pwm_mobile` — Flutter mobile app (scaffolding only, one `main.dart`)
- `docs/mockups/` — UI mockups that define the intended screens (gitignored)
- `docs/PWM - prijava seminarskog rada v3.md` - defines the projects scope and needed funcionality
- `docs/RSII_Upute_za_izradu_seminarskog_rada_2025_26.md` - defines the project requirements regarding implementation

## Working on this repo

`docs/progress.md` is the running checklist: which screens are built, what each remaining one needs, and
the open decisions. Read it at the start of a session, take the top unchecked item, and tick it off when
the work lands.

Do not write per-task handover files. A finished task is reported in the reply and, where it changes how
the repo works, in this file.

### The reference project

`~/Downloads/FIT-RS2-2026/eCommerce/UI/ecommerce_desktop` is the course's worked example, and it is the
**reference for how this project is laid out and written**. PWM does a different job — a fabrication
shop, not a shop front — so nothing is copied domain-wise; what is copied is the shape:

- one `providers/base_provider.dart` doing all the HTTP, with a four-line subclass per controller;
- `models/` of `@JsonSerializable` classes mirroring the API's responses one-for-one;
- **a list screen paired with a details screen per entity** — `x_list` / `x_details_screen` there,
  `<name>_screen.dart` / `<name>_details_screen.dart` here. The list pushes the details screen, the
  details screen pops `'reload'`, the list refetches. One details screen serves both New and Edit,
  told apart by whether it was handed a row;
- forms built with `flutter_form_builder` over a `GlobalKey<FormBuilderState>` and an initial-value
  map, validated with `form_builder_validators`;
- **filtering, sorting and paging sent to the API** as a search object in `get(filter: {...})`, rather
  than fetching a table and filtering it in Dart.

Where PWM deliberately differs from the reference, and should stay differing:

- `MasterScreen` is the shell, not a wrapper. The reference makes every screen wrap itself in
  `MasterScreen` and navigates by `Navigator.push` from a drawer, which stacks a fresh copy of the
  shell per hop. Here the shell owns a selected index and swaps its body.
- `BaseProvider.validateResponse` is used on every call, so the API's own message reaches the user;
  the reference's `isValidResponse` throws `Exception("Unknown error")` and loses it.
- `BaseProvider.send` retries once after a 401 with a refreshed token; the reference has no refresh.
- Screens keep a `ChangeNotifier` of their own (`ProjectsProvider`, `WorkersProvider`, …) that owns the
  filters, the counters and the joins, instead of holding that state in `setState` inside the widget.
- Tests exist and are expected to stay passing.

New work follows the reference's shape unless it collides with one of those five.

## Commands

All backend commands run from `backend/pwm/`:

```bash
dotnet build                                     # whole solution
dotnet run --project pwm.WebAPI                  # API on http://localhost:7094
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
flutter run --dart-define=baseUrl=http://localhost:7094/       # point at a different API
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

`BaseReadService` gives `GetAllAsync` (paging, sorting, filtering) and `GetByIdAsync`; `BaseCRUDService` adds insert/update/delete. Every list endpoint is capped: `GetAllAsync` clamps `PageSize` to `BaseSearchObject.MaxPageSize` (100) and `Page` to at least 1, so no request can pull a whole table. A client that wants a whole lookup table pages for it — see `BaseProvider.getAll` on the desktop. The only member a concrete service must implement is `ApplyFilters`. Concrete controllers are four-line classes that just inject the service interface — routes come from `[Route("[controller]")]` on the two base controllers, so `ProjectController` serves `/Project`.

`BaseReadController.GetAll` binds its search object from a parameter named **`searchObject`**, not `search`. A query key matching the name of a complex `[FromQuery]` parameter makes MVC try to bind the whole object from that single value, which silently swallowed `?search=` and returned unfiltered rows. Do not rename it back.

Register new services in `pwm.Services/ServiceRegistration.cs` (`AddPwmServices`), which `Program.cs` calls once.

`ProjectSearchObject`, `UserSearchObject` and `TruckLoadSearchObject` each carry a free-text `Search`
alongside their single-field filters — that is what the desktop's one search box sends. `Search` on a
project matches the project name **or** its customer's, which is why `ProjectService` overrides
`IncludeRelatedEntitiesAsync` to load `Customer`; on a user it matches name, surname, e-mail or job
title; on a truck load it matches the driver's name or surname, the vehicle registration **or** the
carrier's name, so `TruckLoadService` overrides the same method to load `TransportCompany`. Adding a
search box to a new screen means adding the same pair: a `Search` property and one `Where` over the
columns the box should reach.

Mapping is Mapster by property name — a `Response`/`Request` property only maps if it matches the entity property. `UserService` overrides `MapInsertRequestToEntity`/`MapUpdateRequestToEntity` because the request carries a plain `Password` while the entity stores `PasswordHash`/`PasswordSalt`.

`BaseCRUDService` demands an `IValidator<TInsert>` and `IValidator<TUpdate>` in its constructor. `Validators/DefaultValidator<T>` is registered as the open-generic fallback so any request type resolves; register a concrete `AbstractValidator<T>` after it to take over for that type — the project, truck-load, notification and user request validators are the ones that do.

**A `[Required]` string column is not a required field.** `NOT NULL` is satisfied by `""`, so anything the
UI marks as mandatory needs a `NotEmpty()` rule in a validator as well. `Project.Name` and `Project.Code`
are the worked example.

### Authentication and authorization

JWT, issued by `AccessController` (`/Access/Login`, `/Access/LoginWithRefreshToken`, `/Access/Logout`) over
`pwm.WebAPI/Services/AccessManager`. `UserService.AuthenticateAsync` is the only password check — it goes
through `ICryptoService.Verify` and answers an `AuthenticatedUser` (the `UserResponse` plus the role name,
which `UserResponse` itself does not carry). Tokens are signed from the `JwtToken` section of
`appsettings.json`; the claim types are the constants in `ClaimNames`, and `Roles` in `pwm.Model/Access`
holds the five seeded `UserTypes.Type` values — `Admin`, `Work preparation`, `Finances`,
`Project manager` and `Production worker`, with `Roles.Office` naming the four that are not the
shop floor. `AppRoles` on the desktop mirrors the same five and the screens each one may open.

Refresh tokens are rows in `RefreshTokens`, rotated on every use — one live token per user, deleted on
sign-out. That table has no controller and no DTOs; `IRefreshTokenService` is its only door.

`ICurrentUser` (`pwm.WebAPI/Services/CurrentUser`) is where "who is calling" comes from — the `Id` and
`Role` claims on the token, never the route or the body. `WorkLogController` and `WorkLogDetailController`
use it so a production worker writes only their own shifts: the controller overwrites `request.UserId` with the id
from the token, and checks ownership before an update or a delete. A block of work has no user of its
own, so its owner is the shift it hangs off. Violations throw `ForbiddenException`, which `ExceptionFilter`
answers as 403 under the `forbidden` key. While `DevSettings.BypassAuthentication` is true there is no
token to read, so `ICurrentUser.IsWorker` is false and nothing is narrowed — the same escape hatch
`AuthorizationFilter` takes.

`Program.cs` sets a **fallback policy of `RequireAuthenticatedUser`**, so a new endpoint is authenticated
unless it says `[AllowAnonymous]` (only sign-in, refresh and the API docs do). Roles are then checked per
action by `Filters/AuthorizationAttribute`, which reads the `Role` claim and answers 403:

- reading is open to every signed-in user;
- writing is the four office roles on `BaseCRUDController`;
- `WorkLogController` and `WorkLogDetailController` override insert/update to admit
  `Roles.ProductionWorker` — that is the mobile clock-in path — and drop `Roles.WorkPreparation`,
  which has no business with hours;
- `UserController` narrows all three writes to `Roles.Admin`;
- `ReportController` splits: monthly hours is `Admin` and `Finances`, transports adds
  `ProjectManager`, and `Download` re-checks the stored report's type so a project manager cannot
  pull a monthly hours PDF the attribute could not see.

Changing an action's roles means overriding the base method purely to re-declare the attribute; MVC honours
the most derived one.

### CRUD vs read-only

Deliberate split — do not add write endpoints to the read-only set without asking:

- **CRUD**: Company, User, OperationType, UserOperation, Project, ProjectCategory, WorkLog, WorkLogDetail, TruckLoad, TruckLoadDetail
- **Read-only**: Country, City, UserType, CompanyType, ProjectStatusType, TruckLoadStatusType, ActivityLogType, ActivityLog, ReportType, MonthlyHourReport, MonthlyHourReportDetail, GeneratedReport
- **Read plus one write**: Notification — reading is the generic list, and `POST /Notification/Send` is the only way in. See below.
- **CRUD plus one self-service write**: User — the three CRUD writes stay administrator-only, and `PUT /User/Me` lets anyone edit their own row. See below.

The rule: user-entered data gets CRUD; enum-like values the C# branches on (`ProjectStatusTypes.Name`, `TruckLoadStatusTypes.Name`, `UserTypes.Type`, `CompanyTypes.Name`) stay read-only so business logic can't be broken from Swagger; system-generated rows (activity logs, monthly reports) stay read-only and are written by services, not controllers.

`Notification` is the one deliberate exception, and it is a narrow one. The office has to be able to
write to the shop floor, so `NotificationController` adds **one** action — `POST /Notification/Send`,
`[Authorization]` over the four office roles, taking `{ title, message, userIds? }`. It fans
the message out into one `Notifications` row per recipient inside `NotificationService.SendAsync`;
an empty or missing `userIds` means every account with `IsActive`, resolved **on the server** so the
list cannot go stale between the screen loading and the message being sent. An id naming nobody is a
`ClinetException` rather than a silent drop. There is still no update or delete: a notification that
was sent stays sent.

**`Notifications` has no type column**, so the mockup's "Notification type" dropdown is not built.
Adding it means an enum plus a migration, which is a schema change rather than a screen change.

`PUT /User/Me` is the other exception, and it is narrow for a specific reason. `UserUpdateRequest`
carries `UserTypeId` and `IsActive`, so letting a worker put their own record would let them make
themselves an administrator — which is why the account settings screen does **not** use it.
`UserProfileUpdateRequest` cannot express a role or an active flag at all, the id it applies to comes
from `ICurrentUser` rather than the route or the body, and changing a password means proving the current
one through `ICryptoService.Verify` first. `UserService.UpdateProfileAsync` also refuses an e-mail
another account already holds. Adding a field to that request means asking whether a worker should be
able to set it on themselves.

A lookup table is for values the office might one day add to. Values fixed by the business get a C# enum
instead — `ProjectPriority` (Low/Medium/High/VeryHigh in `pwm.Model/Enums`) is the one of those, stored as
its int and mirrored by a Dart enum of the same name carrying the same ints. `Project.Priority` is the
only column of that kind; everything else that reads like an enum is a table.

### Entity and DbContext conventions

Entities mirror the ER diagram in `docs/`:

- Primary key is always `Id`; foreign keys keep descriptive names (`ActivityLogTypeId`, `Project.CustomerId`, `TruckLoad.TransportCompanyId`).
- Reference navigations exist (`ActivityLog.User`); **collection navigations deliberately do not**.
- Because of that, `OnModelCreating` declares every relationship explicitly with `HasOne(...).WithMany()` — the empty `WithMany()` is what says "no inverse navigation".
- `ToTable` pins every table name to the diagram; the DbSet name would otherwise decide it.
- Delete behavior is `Cascade` only where a row is meaningless without its parent and exactly one such path reaches it (detail tables, a user's own logs); everything else is `Restrict`. This is not cosmetic — SQL Server rejects the schema with error 1785 if multiple cascade paths reach a table such as `WorkLogDetails`.
- Fluent API beats data annotations, and `Project.DeliveryCompany` declares `.IsRequired(false)` so the optional carrier is explicit at both ends.
- `WorkLogDetail` carries its own `UserId` as well as its `WorkLogId`. A work log is one day of
  work and its details are the individual operations that worker did that day, so the owner is
  always the shift's owner — but having it on the row is what lets the hours screens group by
  worker without joining back through the shift. Its delete behaviour is `Restrict`: `WorkLogs`
  already cascades from `Users`, and a second cascade path into `WorkLogDetails` is SQL Server
  error 1785.
- A `DateTime?` that is genuinely optional must **not** carry `[Required]`: the attribute wins and EF makes the column `NOT NULL`. `WorkLog.ClockedOut`, `WorkLogDetail.FinishedAt` and `Project.ProductionStartDate` are the three that matter — they are nullable so an open shift (clocked in, not yet out) can be stored, which is what the mobile app writes.

### Seeding

`Database/Seed/DataSeeder` is one partial class split by area (Lookups, Organisation, Production, Logistics, Reporting). It runs in dependency order, saving after each stage so generated Ids are available to the next. Everything the seeder makes up draws on one `Random(20260826)` field, so a reseeded database always
holds the same numbers; monthly reports are computed from the work logs rather than hardcoded.

The roster is seven named office accounts — Nadir Hujdur (Admin), Nadira Stupar (Finances), Kenan
Fajic and Zuhdija Delic (Project manager), Vedad Kahrimanovic, Nevres Smajlovic and Ismail Brkic
(Work preparation) — plus thirty generated production workers, each qualified for two to five
operations. E-mails are `firstname.surname@pwm.ba` and all seeded users share the password `test`.
Nadir runs projects as well as the system, but an account holds exactly one `UserTypeId` and Admin
already reaches everything a project manager can, so he is seeded Admin.

`SeedAsync` is a no-op if any users exist; `--force` calls `ClearAsync`, which deletes children first and reseeds identity counters via `DBCC CHECKIDENT`.

## Desktop frontend architecture

`frontend/pwm_desktop/lib` is layered so a new module only adds files, never rewires the ones below it:

```
main.dart                     MultiProvider over every entity provider, MaterialApp + theme, opens LoginScreen
layouts/master_screen.dart    top bar + left navigation, the frame every screen renders into
layouts/window_chrome.dart    the app's own title bar: drag area + minimise/maximise/close
models/                       one class per backend table, plus PageResult and the dashboard view model
providers/base_provider.dart  transport: get / getById / insert / update / remove, auth headers, baseUrl
providers/auth_provider.dart  sign in / refresh / sign out, and the token those headers carry
providers/<entity>_provider.dart  four-line subclass per controller: endpoint + row parser
providers/dashboard_provider.dart the dashboard's ChangeNotifier
screens/<name>_screen.dart    one list screen per navigation entry
screens/<name>_details_screen.dart  its add/edit form, pushed from the list
screens/widgets/              the pieces those screens are built from
screens/widgets/details_scaffold.dart  back button + title + Save/Delete, the frame every form uses
screens/widgets/form_fields.dart  appInputDecoration + the form's spacing and date format
utils/app_theme.dart          AppPalette / AppColors / ThemeController / AppSpacing / AppCard
utils/app_roles.dart          the five roles and which screens each one may open
utils/password_rules.dart     what a password has to satisfy, mirrored on the API
utils/formatters.dart         hours, tonnes, dates, "3 d ago"
utils/dialogs.dart            confirmDialog / showErrorDialog / showSavedSnackBar
utils/api_client_exception.dart  ApiClientException + the parser that reads the API's error bodies
```

State management is `provider`; charts are `fl_chart`; PDFs are rendered, printed and saved with
`printing`; the window frame is `window_manager`; forms are `flutter_form_builder` +
`form_builder_validators`. A screen owns its own `ChangeNotifier` through a `ChangeNotifierProvider`
rather than a global store, and takes an optional factory parameter so tests can inject a provider fed
by fakes (see `test/dashboard_test.dart`).

### Theming

Two palettes, one set of names. `AppPalette` holds every colour a theme needs and has a `light` and a
`dark` instance; `AppColors.x` are **static getters** over `AppColors.palette`, which `ThemeController`
swaps *before* it notifies, so by the time the tree rebuilds every `AppColors.x` already answers the new
theme. `MaterialApp` takes `theme`, `darkTheme` and `themeMode` from the same controller. The toggle is
the icon next to the bell in the top bar. **The app opens dark** (`ThemeController.defaultMode`), and the
choice is not persisted — it lasts as long as the window does; storing it needs `shared_preferences` or
the like.

Two consequences follow from the palette being global mutable state, and both bite:

- **A colour is no longer a compile-time constant**, so a widget that uses one cannot be `const`. Adding
  `const` back in front of something that reads `AppColors` will not compile. `AppSpacing` is untouched
  and still const.
- **Nothing in this project may be `const`-constructed**, even a widget that holds no colour itself. A
  `const` instance is canonically identical across rebuilds, so Flutter skips its whole subtree — and the
  colours in that subtree come from the palette the toggle has just changed. Const-constructing one
  leaves part of the window in the old theme until something else forces a rebuild. Constructor
  *declarations* keep their `const`, which is what keeps `prefer_const_constructors_in_immutables`
  satisfied; only the call sites give it up. `test/theme_test.dart` scans `lib/` and fails on any
  `const <ProjectWidget>(`, so this cannot quietly come back.

A **tooltip is the one thing that cannot borrow the card's colours**, because it
floats over the card rather than sitting on it. `AppPalette` therefore carries
`tooltipSurface`/`tooltipText`: in light the bubble inverts to a dark slate with white
text, and in dark it lifts *above* the card instead of going near-white. It used to take
`AppColors.textPrimary` with hardcoded `Colors.white` text, which is 17.7:1 in light but
**1.2:1 in dark** — the bubble and its text were both near-white. Its border is a rim of
`tooltipText` at low alpha rather than `AppColors.border`, which in dark is darker than
the bubble and so would not separate it from the card.

Status chips do **not** store a colour pair. They store the one colour that names the state, and
`AppColors.chip(accent)` builds the (background, foreground) pair for whichever theme is on — tinting in
light, and lifting the accent towards white in dark so it stays legible on a dark card. In light this
lands within a shade of the pastels the mockups use. The four palettes are in `projects_table.dart`
(status and priority), `transports_table.dart` and `workers_table.dart`; each keeps a local `_neutral`
for a state with no colour of its own.

### The window frame

The OS title bar is **off**: `main` calls `windowManager.ensureInitialized()` and shows the window with
`titleBarStyle: TitleBarStyle.hidden`, so there is no second bar above the app's own. What replaces it
lives in `layouts/window_chrome.dart`:

- `AppDragArea` moves the window on a drag and maximises it on a double click, the way a native caption
  does. **Never wrap a bar's contents in it** — use `DraggableBar`, which lays the contents over a drag
  layer instead. An `AppDragArea` *around* the contents puts its `onDoubleTap` recogniser above every
  button in the bar, and the gesture arena then holds each tap until the double-click timeout expires,
  so Save, the bell and the account chip answer a beat late or not at all. Text and icons do not absorb
  pointers, so almost all of the bar still drags.
- `WindowControls` is minimise / maximise-restore / close at Windows' own 46x32, close going red on
  hover. It reads `isMaximized()` back through `WindowListener` rather than toggling a flag, because the
  window can be maximised by a snap or a double click without a button being pressed.

`WindowControls` takes the height of the bar hosting it and runs the full height at the right edge,
behind a hairline — the bar reads as one row rather than a strip with a hole punched in the corner. A row
holding it needs `crossAxisAlignment: CrossAxisAlignment.stretch`.

They are used in four places, and all four are needed: `MasterScreen`'s top bar, `LoginScreen` (which has
no top bar — without it the window could not be closed before signing in), and the two full-window
screens, `FullScreenReport` and `AccountSettingsScreen`, which cover the top bar and so carry the buttons
themselves. `AppWindowBar` is the shared bar those two wear.

**Every call into `window_manager` is wrapped in a try/catch** (`window_chrome.dart`'s `_window`), because
a widget test has no window behind the platform channel and `login_test.dart` builds `LoginScreen` for
real. Do not unwrap them.

### List and details

Every CRUD screen is a pair. The list screen holds the `ChangeNotifier`; the details screen is handed
that provider and, when editing, the row — it is **not** reachable through `context.read`, because it is
pushed as a route rather than nested under the list's `ChangeNotifierProvider`:

```dart
final result = await Navigator.of(context).push<String>(...);
if (result == 'reload') await provider.refresh();
```

The details screen writes through the provider, then pops `'reload'`. `row == null` means New: the title
changes and the Delete button is not built. `MasterScreen` gives each destination **its own nested
`Navigator`**, so a pushed details screen covers the content area while the top bar and sidebar stay put;
`DetailsScaffold` carries a `Scaffold` of its own because a pushed route cannot borrow the list's
Material.

`ChartSlice` carries a `shortLabel` beside its `label`, and `axisLabel` picks between
them: the bar chart's axis has room for a project's **code**, the tooltip shows the full
name. Before that the axis took the last word of the name — a heuristic from when seeded
names carried their code inline, which turned a project called "Purlin sets" into "sets".

Row models (`ProjectRow`, `WorkerRow`, `WorkHoursEntry`) carry the foreign-key **ids** as well as the
resolved names, so opening a row prefills its form without a second fetch.

The API base URL comes from `--dart-define=baseUrl` and **must end in a slash** — `BaseProvider` builds
routes as `{baseUrl}{endpoint}`, so endpoints are written without a leading one (`super('Project')`).
It defaults to `http://localhost:7094/`.

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

`BaseProvider.getAll()` walks a whole lookup table one 100-row page at a time, because the API clamps
`pageSize`. Use it for the small reference tables only; anything that can grow belongs behind a real
filter.

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

A **production worker is turned away at sign-in**: they work from the mobile app, no desktop screen
is theirs, and `AppRoles.usesDesktop` is what says so — `LoginScreen` signs the session straight back
out and says which app to use, rather than opening an empty shell.

`LoginScreen` takes an optional `onSignedIn` callback for the same reason `DashboardScreen` takes a
provider factory — a test can sign in without the app then trying to load dashboards.

### Where the dashboard numbers come from

Responses carry raw foreign keys and there is no aggregate endpoint, so `DashboardProvider` fetches the
eleven tables it needs in one `Future.wait`, builds id→entity maps, and does every join and sum client-side.
Metrics and both charts cover a rolling 30-day window (`DashboardProvider.windowDays`); "active project"
means any status other than Delivered or Rejected. This is the seam where a server-side `/Dashboard`
summary endpoint would replace the client-side aggregation if the data ever outgrows seed scale.

Every table it reads is injected as a `BaseProvider<T>`, so the test suite substitutes one generic fake
provider per table instead of stubbing HTTP.

### Who sees which screen

`utils/app_roles.dart` is the one place the access matrix lives on the desktop, and it is **mirrored
on the API** by `pwm.Model.Access.Roles` and the `[Authorization]` attributes over it — hiding a
screen only tidies the window, the endpoints refuse the call either way, so changing one means
changing the other. `AppRoles._blocked` names what each role may *not* open: work preparation loses
Work Hours, Workers and Reports; finances loses Workers and Recommendations; a project manager loses
Workers; an admin loses nothing. `MasterScreen` filters `_all` through it into `_destinations`, so a
selected index always points at a screen the signed-in user is allowed to see.

A project manager may run the transports report but not monthly work hours, which is one level
finer than a hidden screen: `AppRoles.reportsFor` builds `ReportsProvider.availableTypes`, the
picker offers only those cards, and `_type` starts on the first of them.

New screens plug into `MasterScreen._all`; the entries with no screen yet render a
`PlaceholderBody`.

### Projects

A row is one `Project` joined to its customer, category, status and author by id. Beyond those, a project
carries the fields the Project Details mockup asks for: `Code` (the shop's own reference, e.g. MU-2201),
`Description`, `Notes`, `Priority` and `CreatedByUserId`. Two of the mockup's labels are not columns and
must not become them — **Project Type** is the existing `ProjectCategory`, and **Location** is the delivery
company's city and country, resolved client-side through `Company.CityId` → `City` → `Country` and exposed
as `ProjectRow.location`. Seeded project names no longer carry their code inline; the code is its own
column, and `ProjectRow.displayName` puts them back together as "MU-2201 - Hall roof structure". **Search, status filter, sort
and paging are the API's job**: `ProjectsProvider.filter` builds the `ProjectSearchObject`
(`search`, `projectStatusId`, `page`, `pageSize`, `includeTotalCount`, `sortBy: 'CreationDate desc'`) and
one page of eight rows comes back. Only the small lookup tables — companies, company types, categories,
statuses — are read whole, to resolve the names and to offer only customers when raising a project.

The three header counters sit above the filter bar, so they count the whole book rather than the page:
`_loadCounters` asks the API four times with `pageSize: 0, includeTotalCount: true`, and *active* is
total minus delivered minus cancelled. They are refreshed by `load()` and `refresh()`, not by a filter
change. Because a search now costs a request, the box applies on Enter or its arrow button rather than
on every keystroke.

`ProjectDetailsScreen` serves both New and Edit, and a new project defaults its author to whoever is
signed in (`ProjectsProvider.signedInUserId`, read from `AuthProvider`). The carrier dropdown offers
companies that are *not* customers, and the location line under it is read from the one selected. It always sends `creationDate` and
`productionStartDate` — both are `NOT NULL`; on an edit the original `creationDate` is sent back
unchanged — while `deliveryDate` is left null until the project is scheduled. Statuses are coloured by
name in `ProjectStatusChip`, which falls back to neutral for a status it does not know.

### Workers

No mockup for this one; it follows the projects screen, down to the shared `TablePager` (which
`projects_table.dart` and `workers_table.dart` both use). A row is one `User` with its `UserType` name
resolved and, for the shop floor, the operations from `UserOperations` it is qualified for. Search,
role, the current-workers-only toggle and paging all go to the API as a `UserSearchObject`
(`search`, `userTypeId`, `isActive`, `sortBy: 'Surname, Name'`); the counters — *current*, *in
production* (role Production worker) and *administration* (the other four) — are more count-only
calls. Sorting is the API's, so the list is by surname; the office no longer floats above the shop floor.

`WorkerDetailsScreen` opens and edits accounts. Password is required when adding and left blank to keep
the current one when editing — `UserUpdateRequest.Password` is nullable and `UserService` only re-hashes
when it is set. Qualifications are rows in `UserOperations`, so saving **diffs** them: newly ticked
operations are inserted, unticked ones deleted. Deleting an account removes its qualifications first,
because they point at it. Deactivating is still the better move — the confirm dialog says so.

### Work Hours

A row is one `WorkLogDetail`, joined to its worker through `WorkLog.UserId` and to its project and
operation by id. Two columns the mockup asks for are not in the schema and are derived in
`WorkHoursProvider`: **regular vs overtime** splits each worker-day at
`WorkHoursProvider.regularHoursPerDay` (8 h) by walking that day's bookings in start order, and **status**
reads as "In progress" while either `FinishedAt` or the shift's `ClockedOut` is null.

This screen is the one that still reads its tables whole, and deliberately: the overtime split needs
every booking a worker made on a date, in start order, so a page of rows is not enough to compute it.
Search, project, date range and the two funnel-menu toggles therefore filter client-side, and the four
summary cards total whatever is left after filtering. Pushing this down would mean an API that returns
the split — the seam is `_buildEntries`.

`WorkHoursDetailsScreen` writes a `WorkLog` first and then a `WorkLogDetail` pointing at the new id — the
API has no endpoint that creates both — and on an edit puts both back. Deleting a block deletes its
shift too when nothing else was booked against it. Because `ClockedOut` and `FinishedAt` are `NOT NULL`,
the form always sends a finished block; an open shift still cannot be recorded.

### Transports

A row is one `TruckLoad` joined to its carrier and status by id. Two of the mockup's labels are not
columns and must not become them — **Transport No** is the load's `Id`, written out as `TR-0001` by
`TransportRow.transportNo`, and **net weight** is `FullWeight - EmptyWeight`. Search, status, the date
range and paging are the API's job: `TransportsProvider.filter` builds the `TruckLoadSearchObject`
(`search`, `truckLoadStatusId`, `dateFrom`, `dateTo`, `page`, `pageSize`, `includeTotalCount`,
`sortBy: 'LoadDate desc'`) and one page of eight rows comes back. `DateTo` is compared against a
`LoadDate` that carries a time of day, so the range closes on the last second of its final day rather
than at midnight. The mockup has no header counters, so this screen has none.

Cargo is rows in `TruckLoadDetails` and the table does not show it, so `TransportsProvider.linesOf`
fetches the lines for **one** load when its row is opened — a page of eight loads would otherwise cost
eight more requests. `TransportDetailsScreen` edits them as a list under the load and saving **diffs**
them: a line with `id == 0` has no row behind it and is inserted, a line that is gone is deleted, the
rest are put back. Deleting a load does not touch them — `TruckLoadDetails` cascades from `TruckLoads`
in the schema, so the database drops them itself. `UnloadColor` is free text; the colours the form
offers are the `unloadColors` map in `transport_details_screen.dart`, not something the database
enforces. Statuses are coloured by name in `TruckLoadStatusChip`, which falls back to neutral for a
status it does not know.

### Account settings and passwords

`account_settings_screen.dart` is reached from the account chip in the top bar and pushed on the **root**
navigator, because the top bar sits outside the per-destination navigator `MasterScreen` hands out. It
writes through `UserProvider.updateProfile` (`PUT /User/Me`) and then calls `AuthProvider.updateCurrentUser`,
so the chip shows the new name without signing in again. Role and whether the account is active are shown
but not editable — that is an administrator's job on the Workers screen, and the API agrees.

`utils/password_rules.dart` is the one place the rules live on the desktop: eight characters, an
upper-case letter, a lower-case letter and a number. `PasswordRules` is **mirrored on the API** by
`Validators/UserRequestValidators.cs`, so a password the form refuses is refused there too and a client
that skips the form gains nothing. Changing one means changing the other.

Both the worker form and account settings check their password fields **explicitly**, in `_save`, through
`PasswordRules.validateChange` — not through per-field `validator:` callbacks. Three fields that check
each other need one place that sees all three, and a sibling field's value read back out of
`FormBuilderState.fields` is not reliably current while the form is validating. The password inputs are
therefore plain `TextField`s over controllers the screen owns, with one complaint shown beneath them.

### Reports

Two PDFs, built on demand by `ReportService` with **QuestPDF** (Community licence, registered once in
`AddPwmServices`) and returned as `application/pdf`:

- `POST /Report/MonthlyWorkHours` — `{ year, month, userId?, projectId? }`. Hours per worker split into
  regular and overtime, with each worker's projects underneath.
- `POST /Report/TransportLoads` — `{ projectId?, dateFrom?, dateTo? }`. Every load with carrier, driver,
  vehicle, net weight and status.
- `GET /Report/{id}/Download` — rebuilds a past report from the parameters it was first run with.

**Nothing stores the PDF.** Each run writes a `GeneratedReport` row — `Parameters` (the request as
JSON) and `ReportTypeId` — and that table is the mockup's "Recent Reports"
list; its download button re-runs the endpoint. A report can therefore never disagree with the work logs
it was drawn from, and the database holds no blobs. `GeneratedReportController` is read-only: rows are
written by `ReportService`, never posted.

**Who ran a report and when is not on the report row.** `GeneratedReports` carries no `GeneratedAt`
or `GeneratedById`; `ReportService.RecordAsync` writes the row and then an `ActivityLog` entry whose
`GeneratedReportId` points back at it, under the activity type
`Generated report - <ReportTypes.Description>`. `ReportsProvider` on the desktop reads the recent
list by `Id desc` — Ids are handed out in run order — and joins those log entries back for the
author and the timestamp. `ReportTypes` is a two-row lookup (`Id`, `Description`) whose Ids are
declared `ValueGeneratedNever()` because they mirror `pwm.Model.Enums.ReportType`, which is what
`ReportService` still branches on; a file needing both names aliases the enum
(`using ReportKind = pwm.Model.Enums.ReportType;`).

The seeded `ActivityLogTypes` are Log In, Log out, Message sent, Marked messages as read and one
`Generated report - …` per report type. Only the report entries are written by the running app so
far — nothing yet logs a sent message or a read one, so those two arrive from the seeder alone.

The documents live in `pwm.Services/Reporting/` — `ReportTheme` holds the shared page frame and number
formats, and one `*Document` class per report.

**Overtime is everything past eight hours on a date**, per worker, walked in start order so a block that
straddles the boundary is split across both. The rule is `ReportService.RegularHoursPerDay`; the seeder
mirrors it, `MonthlyHourReportDetail` stores the result as `RegularHours`/`OvertimeHours`, and
`WorkHoursProvider.regularHoursPerDay` is the desktop's copy of the same number. All four have to agree.

The desktop half is `reports_screen.dart` over `ReportsProvider`. The two report types are picked as
cards, and the parameter row is built per type — Period/Worker/Project for the monthly one, Project plus
a date range for transports; the range closes on the last second of its final day, the same rule the
transports screen uses. Generating is one POST that answers PDF **bytes**, which is why `ReportProvider`
exists: it subclasses `BaseProvider` purely to borrow the auth header, the one-shot refresh after a 401
and `validateResponse`, and its type parameter is never used because these endpoints never answer JSON.
`printing`'s `PdfPreview` renders those same bytes in the preview pane, so what is on screen is what
prints and what saves. The expand button in the preview header opens `FullScreenReport` over the whole
window — pushed on the **root** navigator, not the per-destination one `MasterScreen` hands out, or it
would only cover the content area. Escape closes it, and `printReport`/`saveReport` are top-level so
the panel and the full-screen view act on the same bytes. Recent Reports reads `GeneratedReports` newest-first and its rows are described by
parsing the stored `Parameters` — `JsonSerializer.Serialize` writes property names as declared, so those
keys are **PascalCase** and `ReportsProvider._describe` reads them case-insensitively.

### Notifications

`notifications_screen.dart` is the mockup's Send Notification form over `NotificationsProvider`: the
message on the left, the recipients on the right. The two radios and the tick list are one control —
ticking somebody while "All workers" is set flips to picking by hand and pre-ticks everyone, so the
first untick means "everyone except them". Sending to everyone posts **no ids at all**, leaving the API
to resolve the list; only a hand-picked selection sends ids. The recipient list is active accounts only,
asked for with `isActive` and `sortBy: 'Surname, Name'` — a closed account cannot be written to.

### Recommendations

`recommendations_screen.dart` is the Project Resource Estimation layout — project type, expected tonnage
and deadline, the four metric cards and the work-type table — and **nothing behind it**. There is no
estimator: no endpoint, and nothing client-side that derives one. `RecommendationsProvider.hasEstimate`
is hardcoded false and every card reads an em dash; pressing Estimate says the estimator is not built
rather than showing invented numbers. The provider is the seam — `estimate()` is what will call the model,
and the only real work it does today is loading `ProjectCategory` for the dropdown and checking that all
three inputs are filled in.

## Configuration

`appsettings.json` holds the `PWMConnection` string. If it has no `Password=`, `Program.cs` appends one from the `DB_PASSWORD` environment variable — matching how `backend/.env` already feeds docker-compose.

`JwtToken` holds the signing key, issuer, audience and both lifetimes. The committed `SecretKey` is a
development value; `JWT_SECRET` in the environment is used when the setting is missing, and startup fails
if neither is set.

Migrations are applied automatically on startup in Development only. Scalar API docs are served at `/scalar/v1` (Development only); the raw spec is at `/openapi/v1.json`. Both are mapped `AllowAnonymous`, or the fallback policy would lock them; the spec declares the `Bearer` scheme so Scalar can send a token from `/Access/Login`.

## Known rough edges

- `BaseReadService.GetAllAsync` assigns the DbSet to an `IEnumerable<TEntity>`, so filtering, sorting and paging all happen **in memory after loading the whole table**. Fine at seed scale, not beyond it. Fixing it means changing `ApplyFilters` to take and return `IQueryable<TEntity>` in all 20 services. The desktop now sends its filters and paging down as search objects, so the *client* no longer holds whole tables — but the server still loads them, and that is where the remaining cost is.
- `intl` is pinned to `^0.20.2` rather than `^0.20.3`: `form_builder_validators` pulls in `flutter_localizations`, which the Flutter SDK pins to `intl 0.20.2`.
- `CryptoService` builds with `SYSLIB0060`/`SYSLIB0023` obsolescence warnings and its `Verify` uses ordinary string comparison rather than a fixed-time compare.
- Killing a stray API process: `pkill` from Git Bash does not match native Windows processes. Use `Get-NetTCPConnection -LocalPort 7094 -State Listen` then `Stop-Process -Id <pid> -Force`.
- **The API listens on 7094, not 5094**, and moving it back will break it on this machine. Windows
  reserves blocks of TCP ports for WinNAT/Hyper-V, and 5094 fell inside `5041-5140`; binding a port in
  a reserved block fails with `SocketException 10013` ("access permissions"), which reads like a
  permissions problem rather than a taken port — `Get-NetTCPConnection` shows nothing listening. The
  blocks are rebuilt at boot and can move, so if 7094 is ever swallowed too, check
  `netsh interface ipv4 show excludedportrange protocol=tcp` and pick a port outside every range
  (an elevated `net stop winnat` / `net start winnat` frees them until the next reboot). The port is
  written in three places: `pwm.WebAPI/Properties/launchSettings.json`, `BaseProvider.baseUrl` on the
  desktop, and this file.
