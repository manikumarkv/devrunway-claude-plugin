# On-Device Storage Standards (Flutter)

Everything the app writes to the device. The rules below are mostly about two things:
putting each piece of data in a store whose threat model matches it, and making sure the
store can still be opened by build 40 on a phone that last updated at build 12.

**Scope boundaries.** This layer covers the **physical stores** — which store, how it is
encrypted, how it is opened, what a row looks like, how it is evicted, how it is migrated.
It does **not** cover offline *policy*: whether a resource reads cache-first or
network-first, the caching decorator over a service, and the `Cached<T>` envelope that
carries staleness to the UI all belong to `api-style/dio`. This layer supplies the store
that decorator writes into, and the `fetchedAt`/`expiresAt` it reads. It does **not** cover
**session teardown**: which stores are cleared on sign-out, in what order, and what happens
to an in-flight refresh belongs to `auth/flutter-session` — here a store only exposes
`clearForUser(userId)` and never decides when it is called. Provider lifetime and overrides
are `state/riverpod`. Row model shape, `fromJson`, freezed and enum decoding are
`language/dart-models`.

**Versions.** Written against `flutter_secure_storage` 9.x, `shared_preferences` 2.x,
`drift` 2.x with `sqlcipher_flutter_libs`, and `path_provider` 2.x. If a signature below
disagrees with the pubspec, the pubspec wins.

Sections are independent. Read the one you need.

| § | Concern |
|---|---|
| 1 | Pick the store by data class |
| 2 | `SharedPreferences` is world-readable |
| 3 | Secure storage — tokens and keys |
| 4 | Database encryption and the key that opens it |
| 5 | Backup exclusion is part of encryption |
| 6 | Stores are providers, not singletons |
| 7 | Cache entries: TTL, size cap, eviction, corruption |
| 8 | User scoping and `clearForUser` |
| 9 | Reads return staleness |
| 10 | Schema versioning and migrations |
| 11 | Large binaries |
| 12 | Choosing a database package |
| 13 | Testing a store |
| 14 | Never |

---

## 1. Pick the store by data class

**Rule: the store is chosen by what the data *is*, not by which API is nearest.**

This is the first decision and the expensive one to reverse — data written to the wrong
store is already on tens of thousands of devices by the time anyone notices, and moving it
needs a migration that runs before the first read.

| Data class | Store | Why |
|---|---|---|
| Access token, refresh token, PIN, biometric flag, the database key | `FlutterSecureStorage` | Keychain / Keystore-backed; survives neither backup nor extraction in plaintext |
| Non-personal UI preferences — theme mode, last tab, onboarding seen, feature-flag overrides | `SharedPreferences` | Cheap, synchronous-after-load, and **assume world-readable** (§2) |
| Personal or business records, cached API rows, drafts, anything with a user's name in it | Encrypted database (drift + SQLCipher) | Queryable, migratable, encrypted at rest (§4) |
| Large binaries — images, video, generated PDFs | `getApplicationCacheDirectory()` + a row pointing at the path | The OS can delete it; it must never be the only copy (§11) |

Two questions settle almost every case:

1. *If this string were printed in a bug report, would it matter?* Yes → secure storage or
   encrypted DB, never preferences.
2. *If the OS deleted this file tonight, would the user lose something they cannot
   re-fetch?* Yes → it does not belong in the cache directory.

```dart
// ✅ each piece in the store that matches it
await _secure.write(key: 'refresh_token', value: token);   // secret
await _prefs.setString('theme_mode', 'dark');              // non-personal preference
await _db.upsertEnrolment(enrolment);                      // personal record, encrypted
await _files.writeThumbnail(courseId, bytes);              // large binary, re-fetchable
```

---

## 2. `SharedPreferences` is world-readable

**Rule: treat everything in `SharedPreferences` as if it were printed on the app's about
screen.**

On Android it is an XML file in the app sandbox — readable on any rooted device, by any
backup extraction, and by `adb backup` on older API levels. On iOS it is `NSUserDefaults`,
a plist in the app container, included in unencrypted iTunes backups. Neither is encrypted.
The sandbox is a boundary against other apps, not against the device's owner or anyone
holding the device.

| Belongs in prefs | Does not |
|---|---|
| `theme_mode`, `locale_override` | Any token or key |
| `onboarding_seen`, `last_tab_index` | Email, name, phone, address |
| `sort_order`, `list_density` | Entitlements the client enforces (`is_premium`) |
| A cache-busting `schema_stamp` | Anything a support ticket would redact |

The entitlement case is the one that gets missed: a `bool is_premium` in preferences is a
paywall an ordinary user can flip with a file editor. Entitlement is a server answer,
cached in the encrypted DB with a TTL, and re-verified.

```dart
// ❌ all three are wrong, for three different reasons
await prefs.setString('access_token', token);       // secret in cleartext
await prefs.setString('user_email', email);         // personal data in cleartext
await prefs.setBool('is_premium', true);            // client-enforced entitlement
```

---

## 3. Secure storage — tokens and keys

**Rule: every secret goes through one typed store class. No feature calls
`FlutterSecureStorage` directly.**

A single class is where the platform options live, so they cannot drift between call sites,
and it is the seam the session layer and the tests substitute.

```dart
// lib/core/storage/token_store.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Named RefreshTokenStore, not TokenStore: `auth/flutter-session` owns the
// canonical TokenStore contract (StoredTokens, access-token expiry, refresh
// coordination). This shows the STORAGE mechanics only. Two different
// contracts under one name would collide whenever both layers load.
abstract interface class RefreshTokenStore {
  Future<String?> readRefreshToken();
  Future<void> writeRefreshToken(String token);
  Future<void> clear();
}

final class SecureRefreshTokenStore implements RefreshTokenStore {
  const SecureRefreshTokenStore(this._storage);

  final FlutterSecureStorage _storage;

  static const _refreshTokenKey = 'auth.refresh_token';

  // The options are not optional. Every call passes them — a single call that
  // omits them writes that key with the plugin's defaults, which on iOS means
  // iCloud-syncing and restorable onto a different device.
  @override
  Future<String?> readRefreshToken() => _storage.read(
        key: _refreshTokenKey,
        iOptions: secureStorageIOSOptions,
        aOptions: secureStorageAndroidOptions,
      );

  @override
  Future<void> writeRefreshToken(String token) => _storage.write(
        key: _refreshTokenKey,
        value: token,
        iOptions: secureStorageIOSOptions,
        aOptions: secureStorageAndroidOptions,
      );

  @override
  Future<void> clear() => _storage.delete(
        key: _refreshTokenKey,
        iOptions: secureStorageIOSOptions,
        aOptions: secureStorageAndroidOptions,
      );
}
```

The options are defined just below. They are shown after the store only because the
constants read better once you have seen the call sites — not because the store works
without them.

**Rule: set the platform options explicitly. The defaults are wrong for a token.**

```dart
// lib/core/storage/secure_storage_options.dart
const secureStorageIOSOptions = IOSOptions(
  // Readable only after first unlock, and never restored onto a different device.
  accessibility: KeychainAccessibility.first_unlock_this_device,
);

const secureStorageAndroidOptions = AndroidOptions(
  encryptedSharedPreferences: true,
);
```

| Accessibility | Effect | Use |
|---|---|---|
| `first_unlock_this_device` | Available after first unlock; **excluded from backup and device transfer** | Default for every secret |
| `first_unlock` | Available after first unlock; migrates to a new device via backup | Only when the product requires transfer, and then never for the DB key |
| `unlocked` / `unlocked_this_device` | Locked while the screen is locked | Background refresh will fail; use only if background work is genuinely absent |
| `passcode` variants | Wiped when the passcode is removed | Deliberate, and the wipe must be handled |

The `_this_device` suffix is the backup-exclusion half of §5. A refresh token that rides an
iCloud backup onto a second device is a session the user never authorised, and a database
key restored onto another device turns "encrypted at rest" into a formality.

**Rule: a secure-storage read can fail, and failure is not the same as absent.** A Keystore
invalidated by a biometric enrolment change throws rather than returning null. Treat a
throw as "sign the user out", not as "no token".

```dart
Future<String?> readRefreshToken() async {
  try {
    return await _storage.read(key: _refreshTokenKey);
  } on PlatformException catch (_) {
    // Keystore entry unreadable — the key is gone, not the value missing.
    await _storage.delete(key: _refreshTokenKey);
    return null;
  }
}
```

---

## 4. Database encryption and the key that opens it

**Rule: personal data is encrypted at rest, with a 32-byte key generated once from
`Random.secure()` on first open, stored in secure storage, and never derived from anything
that ships in the binary.**

A key that is a compiled-in constant, a `String.fromEnvironment` value, a bundled asset, or
a hash of the package name is the same key on every device and is recoverable from the APK
in minutes. It converts encryption-at-rest into obfuscation. A key derived from a device
identifier is barely better — the identifier is readable by the same attacker who has the
database file.

```dart
// lib/core/storage/database_key.dart
import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _databaseKeyName = 'db.encryption_key';

/// Generated once per install, then read back forever.
Future<String> readOrCreateDatabaseKey(FlutterSecureStorage storage) async {
  final existing = await storage.read(
    key: _databaseKeyName,
    iOptions: secureStorageIOSOptions,
    aOptions: secureStorageAndroidOptions,
  );
  if (existing != null) return existing;

  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  final key = base64UrlEncode(bytes);

  await storage.write(
    key: _databaseKeyName,
    value: key,
    iOptions: secureStorageIOSOptions,
    aOptions: secureStorageAndroidOptions,
  );
  return key;
}
```

The key is applied when the connection opens, before any other statement:

```dart
// lib/core/storage/app_database.dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';

LazyDatabase openEncryptedDatabase(String key, File file) {
  return LazyDatabase(() async {
    await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
    return NativeDatabase(
      file,
      setup: (db) {
        db.execute("PRAGMA key = '$key';");
        // Fails loudly if SQLCipher is not actually linked — plain sqlite3
        // silently ignores PRAGMA key and writes an unencrypted file.
        final result = db.select('PRAGMA cipher_version;');
        if (result.isEmpty) {
          throw StateError('SQLCipher not linked; refusing to open unencrypted.');
        }
      },
    );
  });
}
```

**Rule: verify `PRAGMA cipher_version` on open.** Plain `sqlite3` accepts `PRAGMA key` and
ignores it. Without the check, a dependency change that drops SQLCipher ships an
unencrypted database and nothing fails.

**Rule: losing the key is a recoverable state, not a crash.** If the keystore entry is gone
(OS restore onto a new device, backup restore, biometric reset) the database cannot be
opened. Delete it, recreate it empty, and let the app re-sync — the data was a cache of the
server. Anything in the local DB that is *not* recoverable from the server does not belong
there without an explicit export path.

---

## 5. Backup exclusion is part of encryption

**Rule: on-device encryption is only as good as the backup. Exclude the database and the
keystore entries from cloud backup, in the same change that adds encryption.**

Android's auto-backup uploads the app's data directory — including the SQLCipher file — to
Google Drive. If the key rides along, the pair is decryptable off-device. If the key does
not ride along, restore produces a database nothing can open. Both outcomes are worse than
excluding it.

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<application
    android:allowBackup="false"
    android:fullBackupContent="false"
    android:dataExtractionRules="@xml/data_extraction_rules">
```

```xml
<!-- android/app/src/main/res/xml/data_extraction_rules.xml (API 31+) -->
<data-extraction-rules>
  <cloud-backup>
    <exclude domain="database" />
    <exclude domain="sharedpref" path="FlutterSecureStorage" />
  </cloud-backup>
  <device-transfer>
    <exclude domain="database" />
  </device-transfer>
</data-extraction-rules>
```

On iOS the two halves are:

- Keychain: `KeychainAccessibility.first_unlock_this_device` — the `_this_device` suffix is
  what keeps the key out of iCloud Keychain and device transfer.
- The database file: mark it excluded from iCloud/iTunes backup, or place it under
  `getApplicationSupportDirectory()` with the exclusion attribute set.

| Surface | Setting | Without it |
|---|---|---|
| Android auto-backup | `allowBackup="false"` | Encrypted DB uploaded to Drive |
| Android D2D transfer | `<device-transfer><exclude domain="database"/>` | DB copied to a new phone |
| iOS Keychain | `first_unlock_this_device` | Key syncs to iCloud Keychain |
| iOS file backup | `isExcludedFromBackup` | DB in an unencrypted local iTunes backup |

---

## 6. Stores are providers, not singletons

**Rule: every store is constructed in a provider. No `AppDatabase.instance`, no
`static final` singleton, no top-level mutable holder.**

Two failures, both common:

1. **`X.instance` cannot be faked.** A widget test that touches a screen touching a store
   reaches the real Keystore and the real file. The only fix is to not have a singleton.
2. **A singleton hides lazy init that silently no-ops.** The classic shape is a nullable
   handle with a null-aware call:

```dart
// ❌ writes are dropped, silently, whenever init has not completed
class CacheStore {
  static final CacheStore instance = CacheStore._();
  CacheStore._();

  Box? _box;
  Future<void> init() async => _box = await Hive.openBox('cache');

  void put(String k, String v) => _box?.put(k, v);  // no-op before init
}
```

`_box?.put(...)` on a null `_box` does nothing and returns nothing. Every write before
`init()` completes vanishes, and it only reproduces on a cold start on a slow device.

```dart
// ✅ lib/core/storage/storage_providers.dart
@Riverpod(keepAlive: true)
FlutterSecureStorage secureStorage(Ref ref) => const FlutterSecureStorage(
      iOptions: secureStorageIOSOptions,
      aOptions: secureStorageAndroidOptions,
    );
// Constructor options are the floor, not a substitute for per-call options:
// any call that passes its own `iOptions`/`aOptions` overrides these entirely.

@Riverpod(keepAlive: true)
Future<AppDatabase> appDatabase(Ref ref) async {
  final key = await readOrCreateDatabaseKey(ref.watch(secureStorageProvider));
  final db = AppDatabase(openEncryptedDatabase(key, await _databaseFile()));
  ref.onDispose(db.close);
  return db;
}

@Riverpod(keepAlive: true)
RefreshTokenStore refreshTokenStore(Ref ref) =>
    SecureRefreshTokenStore(ref.watch(secureStorageProvider));
```

Three properties fall out: the async gap is in the provider, so a consumer awaits a
*constructed* store and there is no half-initialised state to no-op against;
`ref.onDispose(db.close)` releases the file handle; and the test overrides one provider.

```dart
// in a test — the whole point of the indirection
ProviderContainer(
  overrides: [
    appDatabaseProvider.overrideWith((ref) async => AppDatabase(NativeDatabase.memory())),
    refreshTokenStoreProvider.overrideWithValue(FakeRefreshTokenStore()),
  ],
);
```

If the app does not use Riverpod, the rule is unchanged in substance: the store is
constructed once at the composition root and injected. The prohibition is on global
reachability, not on a specific package.

---

## 7. Cache entries: TTL, size cap, eviction, corruption

**Rule: every cache entry carries `expiresAt`, and every cache store carries a
`maxEntries` cap with an `evict()` pass. TTL alone is not a bound.**

TTL bounds how *old* an entry is, not how *many* there are. A user who browses two hundred
courses in a session with a seven-day TTL has two hundred rows of JSON, none of them
expired, none of them ever read again. On a 32 GB device that is a support ticket. The cap
is what actually bounds the store; the TTL is what keeps it correct.

```dart
// lib/core/cache/cache_entries.dart  (drift table)
class CacheEntries extends Table {
  TextColumn get key => text()();
  TextColumn get userId => text()();
  TextColumn get payload => text()();
  DateTimeColumn get fetchedAt => dateTime()();
  DateTimeColumn get expiresAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key, userId};
}
```

```dart
// lib/core/cache/program_cache_store.dart
final class ProgramCacheStore {
  ProgramCacheStore(this._db);

  final AppDatabase _db;

  static const maxEntries = 300;
  static const defaultTtl = Duration(hours: 6);

  Future<void> write(String key, String userId, String payload) async {
    final now = DateTime.now();
    await _db.into(_db.cacheEntries).insertOnConflictUpdate(
          CacheEntriesCompanion.insert(
            key: key,
            userId: userId,
            payload: payload,
            fetchedAt: now,
            expiresAt: now.add(defaultTtl),
          ),
        );
    await evict();
  }

  /// Expiry first, then the size cap, oldest-fetched first.
  Future<void> evict() async {
    await (_db.delete(_db.cacheEntries)
          ..where((t) => t.expiresAt.isSmallerThanValue(DateTime.now())))
        .go();

    final count = await _db.cacheEntries.count().getSingle();
    if (count <= maxEntries) return;

    final surplus = count - maxEntries;
    await _db.customStatement(
      'DELETE FROM cache_entries WHERE rowid IN ('
      'SELECT rowid FROM cache_entries ORDER BY fetched_at ASC LIMIT ?)',
      [surplus],
    );
  }
}
```

**Rule: `evict()` runs on database open and after each write.** Not on a timer, not on a
background isolate — an app that is opened once a month must not accumulate a month of
rows waiting for a maintenance window that never runs.

**Rule: an entry that fails to decode deletes itself and returns null.** A shape change
that lands mid-release leaves rows the current model cannot parse. If the read rethrows,
the screen is permanently broken until the app is reinstalled — a self-healing miss costs
one network request.

```dart
Future<Cached<List<Program>>?> read(String key, String userId) async {
  final row = await _select(key, userId);
  if (row == null) return null;

  try {
    final programs = (jsonDecode(row.payload) as List)
        .map((e) => Program.fromJson(e as Map<String, Object?>))
        .toList();
    return Cached(
      value: programs,
      fetchedAt: row.fetchedAt,
      isStale: row.expiresAt.isBefore(DateTime.now()),
    );
  } on FormatException catch (_) {
    await _deleteRow(key, userId);   // poison entry evicts itself
    return null;
  }
}
```

| Failure the rule prevents | Without it |
|---|---|
| Unbounded growth | Store grows to the size of everything the user ever viewed |
| Permanently stale reads | Data from six weeks ago shown as current |
| Poison entries | One unparseable row breaks a screen until reinstall |
| Cross-account leakage | See §8 |

---

## 8. User scoping and `clearForUser`

**Rule: every cached row carries the `userId` it was fetched for, and every read filters on
it.**

Shared devices are ordinary — a family tablet, a shift worker's handset, a demo device. An
unscoped cache shows the previous account's data to the next person, and it does so in the
window before the first network response, which is exactly the window a cache exists to
fill. The `userId` is in the primary key, not merely on the row, so a write for account B
cannot overwrite account A's entry for the same key.

```dart
Future<void> clearForUser(String userId) =>
    (_db.delete(_db.cacheEntries)..where((t) => t.userId.equals(userId))).go();
```

**The store exposes `clearForUser`; it does not decide when it runs.** Sign-out ordering —
which stores are cleared, whether an in-flight refresh is cancelled first, what survives a
"remember me" — is `auth/flutter-session`. The contract this layer owes it is that after
`clearForUser(id)` returns, no row for `id` remains and no secret for `id` remains.

**Rule: a "clear everything" path exists and is tested.** Sign-out clears the user's rows;
account deletion and "reset app" clear the store entirely, including preferences that
encode user choices. A partial clear that leaves one table behind is how the next account
inherits a stale entitlement.

---

## 9. Reads return staleness

**Rule: a read returns the entry *and* its freshness. It never presents an expired entry as
fresh, and never returns null when the caller could have used the stale copy.**

Two callers need the answer and they need different things from it. The dio caching
decorator needs to know whether it may skip the network (`cacheFirst` within TTL) or must
fall back (`networkFirst` offline). The UI needs to know whether to show "updated
yesterday". A store that returns `List<Program>?` and internally deletes expired rows has
destroyed the information both of them need.

```dart
// ✅ the store reports; it does not decide
Future<Cached<List<Program>>?> read(String key, String userId);

// ❌ the caller cannot tell "no cache" from "cache expired", and offline shows nothing
Future<List<Program>?> readIfFresh(String key, String userId);
```

`Cached<T>` — `value`, `fetchedAt`, `isStale` — is defined by `api-style/dio`; this layer
populates it. The division: **the store reports freshness, the decorator decides what to do
about it, the widget renders it.** A store that returns null for expired data quietly
converts every `networkFirst` resource into `networkOnly` the moment the TTL passes, and
the app stops working on a plane.

---

## 10. Schema versioning and migrations

**Rule: `schemaVersion` starts at 1 in the first release and is bumped on every shape
change — a new table, a new column, a changed type, a new index.**

An unversioned schema has no place to hang the first migration, so the first one is written
under time pressure against installs whose shape nobody recorded.

**Rule: `onUpgrade` is a sequence of `if (from < N)` steps, never a switch on the exact
previous version.**

Users skip releases. A migration written as `if (from == 2)` runs for the fraction of
users who happened to be on v2 and silently does nothing for everyone on v1 — who then hit
a missing column on the first query. Sequential `from <` guards compose: a v1 install runs
every step in order, a v3 install runs none.

```dart
// lib/core/storage/app_database.dart
@DriftDatabase(tables: [CacheEntries, Enrolments, Programs])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // v1 → v2: enrolments gained a completion timestamp.
          if (from < 2) {
            await m.addColumn(enrolments, enrolments.completedAt);
          }
          // v2 → v3: cache rows became user-scoped. Old rows have no owner,
          // so they are dropped rather than guessed at.
          if (from < 3) {
            await m.addColumn(cacheEntries, cacheEntries.userId);
            await customStatement('DELETE FROM cache_entries');
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          if (details.wasCreated || details.hadUpgrade) {
            await _evictAll();
          }
        },
      );
}
```

**Rule: a migration that cannot preserve a row deletes it explicitly.** Adding a
`NOT NULL` column to a table with existing rows needs a default or a backfill; inventing a
plausible value silently is worse than dropping a cache row, because the invented value
looks real. Cache rows are droppable by definition — they are re-fetchable. User-authored
content is not, and a migration that would drop it needs a backfill, not a `DELETE`.

**Rule: the migration test starts from the oldest version still installed, not from the
previous one.**

This is the rule that gets skipped, because testing `v2 → v3` is easy and passes. The
install base is not on v2. Check the store's version-adoption report for the oldest release
above a floor (commonly 1% of installs) and test every path from there.

```dart
// test/storage/migration_test.dart
import 'package:drift_dev/api/migrations.dart';

void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  // One case per version still in the wild — not just the previous one.
  for (final from in [1, 2]) {
    test('migrates v$from to v3 with data intact', () async {
      final connection = await verifier.startAt(from);
      final db = AppDatabase(connection);

      await verifier.migrateAndValidate(db, 3);

      // Shape is verified above; assert the data survived.
      final enrolments = await db.select(db.enrolments).get();
      expect(enrolments, isNotEmpty);
      await db.close();
    });
  }
}
```

**Rule: never `deleteDatabase` as a migration strategy.** "Drop and recreate on version
mismatch" is a data-loss bug wearing a migration's clothes. It is acceptable only for a
store whose every row is a re-fetchable cache, and then it is written as an explicit
`DELETE FROM` in the numbered step so the decision is visible in the diff.

**Rule: schema files are committed.** `drift`'s exported schema JSON (or the equivalent for
the chosen package) is checked in per version, because the migration test needs the old
shape and the old shape no longer exists in the code.

---

## 11. Large binaries

**Rule: binaries live on the filesystem; the database holds the path and the metadata.**

A 4 MB image as a BLOB is read into memory in full on every query that touches the row, and
it makes the encrypted database file — and any per-write re-encryption — proportional to
media volume rather than record count.

```dart
final dir = await getApplicationCacheDirectory();   // OS may reclaim this
final file = File('${dir.path}/thumbnails/$courseId.jpg');
await file.writeAsBytes(bytes);
await _db.upsertThumbnail(courseId: courseId, path: file.path, bytes: bytes.length);
```

| Directory | Backed up | OS may delete | Use for |
|---|---|---|---|
| `getApplicationCacheDirectory()` | No | **Yes** | Re-downloadable media, thumbnails |
| `getApplicationSupportDirectory()` | Yes (exclude explicitly) | No | The database, user-authored content |
| `getTemporaryDirectory()` | No | Yes, aggressively | In-flight downloads, scratch |

**Rule: the cache directory is never the sole copy.** iOS reclaims it under storage
pressure without notifying the app. Every read of a cached file handles "not there" as a
normal path — re-download — never as an error state.

**Rule: files are user-scoped and evicted too.** A per-user subdirectory, a total-bytes cap,
and a delete pass that runs alongside `evict()`. Orphaned files — a row deleted, the file
left behind — are the most common way a "bounded" cache grows without bound.

---

## 12. Choosing a database package

**Rule: check maintenance before adopting. Last release date, open-issue trend, and whether
the maintainer has stated the project's status.**

The local database is the hardest dependency in the app to replace: the data is on user
devices, so replacing it means writing a migration out of a package that no longer builds.
Adopting an unmaintained one is a decision with a multi-year tail.

| Check | Threshold |
|---|---|
| Last release | Within ~6 months, and compatible with the current stable Flutter |
| Issue trend | Closing roughly as fast as opening; no year-old build-breaking issue |
| Maintainer signal | No archived repo, no "looking for maintainers" notice |
| Encryption story | First-party or a well-used companion package, not a fork |
| Migration story | A documented, testable path — not "delete and recreate" |
| Null safety / current SDK | Builds against the SDK constraint in `pubspec.yaml` |

Current defaults, subject to the checks above rather than to this table:

| Need | Reach for |
|---|---|
| Relational, migratable, encryptable | `drift` + `sqlcipher_flutter_libs` |
| Raw SQL, minimal layer | `sqflite_sqlcipher` |
| Key–value secrets | `flutter_secure_storage` |
| Non-personal preferences | `shared_preferences` |

Record the decision and the evidence in an ADR. "We picked it because a blog post from 2021
said it was fastest" is how apps end up on an archived package.

---

## 13. Testing a store

**Rule: store tests run against a real in-memory database, not a mock of the store.**

Mocking the store tests the mock. The behaviours worth testing — eviction, expiry, user
scoping, migration, self-healing on corrupt rows — are all behaviours of the storage engine.

```dart
test('evict drops the oldest rows once the cap is exceeded', () async {
  final db = AppDatabase(NativeDatabase.memory());
  final store = ProgramCacheStore(db);

  for (var i = 0; i < ProgramCacheStore.maxEntries + 10; i++) {
    await store.write('key-$i', 'user-1', '[]');
  }

  final count = await db.cacheEntries.count().getSingle();
  expect(count, ProgramCacheStore.maxEntries);
  await db.close();
});

test('a read for one user never returns another user rows', () async { /* … */ });
test('an unparseable payload deletes itself and returns null', () async { /* … */ });
```

Secure storage is the exception: the platform channel is not available in a unit test.
Test against a fake implementing `RefreshTokenStore` (§3) — which is why the contract exists —
and cover the real Keystore path in an integration test on a device.

---

## 14. Never

| Never | Because |
|---|---|
| A token, key, email, or entitlement in `SharedPreferences` | It is cleartext and world-readable (§2) |
| A database key that is a constant, a `String.fromEnvironment`, an asset, or a device-id hash | The same key on every device, recoverable from the binary (§4) |
| `allowBackup` left at its default alongside an encrypted DB | The cloud backup undoes the encryption (§5) |
| `AppDatabase.instance` or any `static` store handle | Cannot be overridden in a test; hides `_box?.put(...)` no-ops (§6) |
| A cache with a TTL but no size cap | Bounded in age, unbounded in bytes (§7) |
| A cache row without a `userId` | The next account on the device sees the previous one's data (§8) |
| A read that returns `null` for an expired entry | Turns every offline-capable screen into an online-only one (§9) |
| `if (from == previousVersion)` in `onUpgrade` | Users skip releases; most installs get no migration (§10) |
| `deleteDatabase` on version mismatch | Data loss labelled as a migration (§10) |
| A binary BLOB in the database | Whole rows read into memory; encrypted file grows with media (§11) |
| Adopting an unmaintained database package | The data is on user devices; you cannot leave cheaply (§12) |
| Mocking the store in a store test | Tests the mock, not the eviction, scoping, or migration (§13) |
