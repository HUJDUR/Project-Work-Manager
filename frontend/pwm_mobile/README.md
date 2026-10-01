# pwm_mobile

The shop-floor side of Project Work Manager, a Flutter app for Android.
Workers use it to:

- clock in and out against a project and operation
- follow the running session
- review their own hours day by day
- browse active projects
- read notifications
- manage their profile

## Run

The backend has to be running first; see the root `README.md`.

```
flutter pub get
flutter run
```

The generated `*.g.dart` JSON code is committed. After changing a model,
regenerate it with `dart run build_runner build --delete-conflicting-outputs`.

The API address defaults to `http://10.0.2.2:7094` on Android, which is the
emulator's alias for the host machine. A physical phone needs the machine's
address on the local network:

```
flutter run --dart-define=API_BASE_URL=http://192.168.1.x:7094
```

Sign in as `mobile` / `test`. The other seeded accounts are listed in the root
`README.md`.

## Test

```
flutter test
```

## Release build

```
flutter clean
flutter build apk --release
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`.
