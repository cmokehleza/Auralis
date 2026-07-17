# Auralis

Auralis is a premium, user-controlled Flutter music player prototype built from the default Flutter starter project. It intentionally contains no AI or machine-learning features.

## What is implemented

- Premium dark interface with Home, Library, Search, and Settings destinations
- Persistent mini player and immersive full-screen Now Playing view
- Play, pause, previous, next, seek, shuffle, repeat-one/all, playback speed, and volume state
- Editable/reorderable queue and Play Next actions
- Favorites, local-library search, albums, playlists, folders, and a scan interaction
- Synced-lyrics presentation, 10-band EQ interface, crossfade controls, and quality settings
- Responsive layout, semantic control labels, and system text scaling support
- Offline demo library with generated artwork (no network dependency)

## Architecture

```text
lib/
├── controllers/   Playback state and queue behavior
├── models/        Track and playlist domain models
├── screens/       Navigation destinations and Now Playing
├── services/      Library repository / future file index adapter
├── theme/         App-wide design tokens and Material theme
└── widgets/       Reusable artwork, player, and track components
```

`PlayerController` is the UI-facing playback contract. The prototype advances playback time locally so the starter remains dependency-light and runnable without platform setup. Production audio should replace that internal timing adapter with `just_audio` plus `audio_service` for decoding, gapless playback, background controls, and lock-screen integration; the screens do not need to change.

`LibraryRepository` is the current offline catalog. Production indexing should replace it with a database-backed scanner that parses device metadata off the UI isolate and exposes paged queries for large libraries.

## Run and verify

```bash
flutter run
flutter analyze
flutter test
```

## Production roadmap

1. Add native playback and media-session adapters (`just_audio`, `audio_service`) with integration tests for gapless playback, interruptions, and background state.
2. Add permission-aware device scanning, metadata parsing, artwork caching, M3U/PLS import, and an indexed local database.
3. Persist queue, favorites, playlists, ratings, EQ presets, and settings using open JSON/M3U exports.
4. Implement platform audio routing and capability detection for DACs, Bluetooth codecs, AirPlay, Chromecast, and DLNA.
5. Profile 50,000-track libraries, cold start, battery use, and large lossless-file playback on physical Android and iOS devices.

These production capabilities require native plugins, device permissions, hardware testing, and platform-specific configuration; their controls and integration boundaries are represented in the prototype but they are not falsely simulated as real audio or device I/O.
