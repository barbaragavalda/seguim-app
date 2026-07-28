# Seguim!

A personal TV series/movie tracker (Catalan for "we follow!") — built after TV Time shut
down. Flutter client for [`tv-tracker`](https://seguim.cat/), a PHP/Freimguork backend
(separate repo, not included here).

## Features

- **Watchlist**: "Veient" (watching) and "No començat encara" (not started) sections, sticky
  headers, infinite scroll on the not-started list.
- **Search**: series and movies via TheTVDB.
- **Series detail**: episodes grouped by season, mark an episode watched/rewatched (with a
  watch-count indicator), archive or stop-watching a series (reversible, distinct from
  removing it entirely).
- **Les meves sèries** (My series): browse/search the full watchlist filtered by status (all/
  watching/not started/finished/archived/dropped).
- **Profile**: edit username, email (confirmed by code), password, and app language; import a
  TV Time GDPR data export (web only); delete account.
- Fully localized: Catalan, Spanish, English.

## Stack

- Flutter, [Riverpod](https://riverpod.dev/) (`Notifier`/`NotifierProvider`, no
  `StateNotifier`) for state management
- [go_router](https://pub.dev/packages/go_router), with a `StatefulShellRoute` for the
  bottom-tab shell (Watchlist/Cerca/Perfil) so each tab keeps its own state
- `flutter_secure_storage` for the session token, `http` for the API client
- `cached_network_image`, `google_fonts` (Fraunces + Manrope), `flutter_sticky_header`

## Project structure

```
lib/
  core/           # api client config, network helpers, locale provider
  features/       # one folder per feature (auth, watchlist, search, series_detail,
                   # my_series, profile, import), each split into data/providers/screens
  navigation/      # go_router config + bottom-tab shell
  theme/           # colors, spacing, radius, text theme
  widgets/         # small widgets shared across features
  l10n/            # app_{ca,es,en}.arb + generated/ (flutter gen-l10n output)
```

## Getting started

1. Have a `tv-tracker` backend running locally (see that repo's own README) and reachable at
   `http://tv-tracker.local` (or update the URL in step 2).
2. Copy `lib/core/config/api_config.example.dart` to `lib/core/config/api_config.dart`
   (gitignored) and fill in `defaultToken` with the value from the backend's own
   `config/api/dev/webservice.php` (also gitignored there).
3. `flutter pub get`
4. `flutter gen-l10n` (regenerates `lib/l10n/generated/` after editing any `.arb` file)
5. `flutter run` - for web specifically: `flutter run -d web-server --web-port=8765` (or
   `-d chrome`)

## Testing

```
flutter analyze
flutter test
```

`test/widget_test.dart` renders the app under each supported locale and checks the right
translation shows up - a good template to follow when adding more widget tests.
