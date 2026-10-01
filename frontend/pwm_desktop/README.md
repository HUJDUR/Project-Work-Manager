# pwm_desktop

The office side of Project Work Manager, a Flutter app for Windows. It covers
the dashboard, projects, work hours, workers, transport, monthly reports, PDF
reports, resource estimates, notifications, activities and administration.
Admins, project managers, finances and work preparation sign in here. Each role
sees only its own screens (`lib/utils/app_roles.dart`). Production workers use
`pwm_mobile` instead.

## Run

The backend has to be running first; see the root `README.md`.

```
flutter pub get
flutter run -d windows
```

The generated `*.g.dart` JSON code is committed. After changing a model,
regenerate it with `dart run build_runner build --delete-conflicting-outputs`.

The API address defaults to `http://localhost:7094`. Override it with:

```
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:7094
```

Sign in as `desktop` / `test`. The other seeded accounts are listed in the root
`README.md`.

## Test

```
flutter test
```

## Release build

```
flutter clean
flutter build windows --release
```

The build is written to `build/windows/x64/runner/Release/`.
