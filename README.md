# Project Work Manager (PWM)

Seminarski rad iz predmeta Razvoj softvera II - Nadir Hujdur, IB210050.

Evidencija radnih sati po projektima i vrstama posla, sa transportom i
izvještajima, za firme u metalnom sektoru.

- **Mobilna aplikacija** (`frontend/pwm_mobile`) - radnici: clock-in/clock-out,
  moji sati, projekti, notifikacije, profil.
- **Desktop aplikacija** (`frontend/pwm_desktop`) - kancelarija: projekti, radni
  sati, mjesečni izvještaji, radnici, transport, PDF izvještaji, notifikacije,
  šifarnici, procjena resursa.
- **Backend** (`backend/`) - ASP.NET Core Web API, `pwm.Worker`, RabbitMQ i SQL
  Server, sve u Docker Compose.

## Pristupni podaci

| Kontekst | Korisničko ime | Lozinka |
| --- | --- | --- |
| Desktop verzija | `desktop` | `test` |
| Mobilna verzija | `mobile` | `test` |

Po jedan račun za svaku ulogu:

| Uloga | Korisničko ime | Lozinka |
| --- | --- | --- |
| Admin | `desktop` | `test` |
| Finances | `NadiraStupar` | `test` |
| Project manager | `KenanFajic` | `test` |
| Work preparation | `VedadKahrimanovic` | `test` |
| Production worker | `mobile` | `test` |

Production worker koristi samo mobilnu aplikaciju; ostale uloge mogu obje.

## Pokretanje

1. Raspakovati `backend/.env-tajne.zip` u isti folder, tako da
   nastane `backend/.env`.
2. Pokrenuti backend (potreban Docker Desktop):

   ```
   cd backend
   docker compose up -d
   ```

   Pri prvom pokretanju API sam kreira bazu `210050` i napuni je testnim
   podacima. API je na `http://localhost:7094`.
3. Desktop: iz GitHub release ZIP-a pokrenuti `Release/pwm_desktop.exe`.
4. Mobilna: `app-release.apk` iz istog ZIP-a prevući na Android emulator (AVD).

API radi preko HTTP-a, bez SSL-a.

## Adresa API-ja

Aplikacije čitaju adresu sa `String.fromEnvironment('API_BASE_URL')`. Bez nje
koriste `http://localhost:7094` (desktop) i `http://10.0.2.2:7094` (Android
emulator). Druga adresa se zadaje pri pokretanju:

```
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:7094
```

## Build

```
cd frontend/pwm_desktop
flutter clean
flutter build windows --release
```

→ `frontend/pwm_desktop/build/windows/x64/runner/Release/`

```
cd frontend/pwm_mobile
flutter clean
flutter build apk --release
```

→ `frontend/pwm_mobile/build/app/outputs/flutter-apk/app-release.apk`

Generisani `*.g.dart` fajlovi su u repozitoriju. Nakon izmjene modela:
`dart run build_runner build --delete-conflicting-outputs`.

## Konfiguracija

Sva podešavanja su u `backend/.env` (ključevi bez vrijednosti u
`backend/.env.example`): baza, JWT, RabbitMQ i rasporedi za `pwm.Worker`.
`appsettings.json` sadrži samo logovanje.

Nakon izmjene backend koda: `docker compose up -d --build api worker`.
Ponovno punjenje baze (iz `backend/pwm`):
`dotnet run --project pwm.WebAPI --seed --force`.

## Kako radi

- **PDF izvještaji:** API zapiše zahtjev i pošalje ga na RabbitMQ; `pwm.Worker`
  napravi PDF, a desktop ga preuzme kad je gotov.
- **pwm.Worker** još javlja adminima i projekt menadžerima zaboravljene
  clock-out-e i radnike koji ujutro nisu došli na posao.
- **Notifikacije** stižu odmah preko SignalR-a (`/hubs/notifications`), u obje
  aplikacije.
- **Sistem preporuke:** opisan u
  [`recommender-dokumentacija.md`](recommender-dokumentacija.md).
