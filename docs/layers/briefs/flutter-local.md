# Brief — `storage/flutter-local`

**Kind:** layer · **Issue:** #2 · **Cookbook:** `#storage`

## Globs
```yaml
paths:
  - "**/core/storage/*.dart"
  - "**/core/cache/*.dart"
  - "**/*_store.dart"
  - "**/app_database.dart"
```

## Rules to encode
1. Pick the store by data class — tokens → secure storage; preferences → SharedPreferences
   (non-personal only, assume world-readable); personal or business records → encrypted DB;
   large binaries → cache dir, never the sole copy.
2. Personal data encrypted at rest, key generated once into the platform keystore, never
   derived from a compiled-in constant.
3. Backup exclusion is part of encryption: `allowBackup="false"`,
   `first_unlock_this_device` Keychain accessibility. An unencrypted cloud backup undoes
   on-device encryption.
4. Stores are providers, not singletons. `X.instance` cannot be faked and hides lazy init
   that silently no-ops (`_box?.put(...)`).
5. Every cache entry has a TTL; the store has a size cap and an eviction pass; a corrupt
   entry evicts itself rather than throwing forever.
6. Rows are user-scoped so sign-out can clear them completely.
7. `get` returns staleness rather than hiding it — the offline layer and the UI both need it.
8. Schema versioned from release one; upgrade path tested from the oldest version in the wild.
9. Choose a maintained database — check last release and issue trend before adopting.

## Eval cases
| id | Scenario | must_contain | must_not_contain |
|---|---|---|---|
| 01 | Persist an auth refresh token | `FlutterSecureStorage`, `accessibility` | `SharedPreferences` |
| 02 | Open an encrypted local database | `keystore`/`secure.read`, `encryptionKey` | hardcoded passphrase literal |
| 03 | A TTL cache with eviction | `expiresAt`, `deleteExpired`, `userId` | TTL with no cap |
| 04 | A schema migration from v2 to v3 | `schemaVersion`, `onUpgrade`, `from <` | unversioned schema |

## Boundaries
Offline *policy* is `api-style/dio`. Session teardown is `auth/flutter-session`.
