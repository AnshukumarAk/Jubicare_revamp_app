# JubiCare MMU — Mobile Local Storage

**No SQLite / Hive / Isar / Drift.** All persistent state lives in Android
`SharedPreferences` (a single XML at
`/data/data/com.jubicare.jubicare_mmu/shared_prefs/FlutterSharedPreferences.xml`).
Every value is a string (usually JSON) keyed under the `flutter.` prefix
Flutter adds automatically.

Photos / attachments captured before upload are **NOT** in SharedPreferences —
they sit as JPEGs in the app's `getTemporaryDirectory()`
(`/data/user/0/com.jubicare.jubicare_mmu/cache/wm_*.jpg`), and get uploaded
to the server at submit or via the offline sync photo-lift pass.

---

## Key inventory (pulled 2026-08-20 from CPH2119, counsellor + doctor logged in)

| Key | Owner class | Purpose |
|---|---|---|
| `flutter.jwt_access_token` | `TokenStore` | JWT access token (used in `Authorization: Bearer`) |
| `flutter.jwt_refresh_token` | `TokenStore` | JWT refresh token (30-day) |
| `flutter.jwt_access_expires_at` | `TokenStore` | ISO timestamp; proactive refresh keys off this |
| `flutter.jwt_refresh_expires_at` | `TokenStore` | ISO timestamp; past this = login screen |
| `flutter.logged_in` | `AuthPersistence` | bool flag — "is the user still signed in" |
| `flutter.username` | `AuthPersistence` | login username (shown in shell greeting) |
| `flutter.role` | `AuthPersistence` | `counsellor` / `doctor` / `pharmacist` / `driver` / `other` |
| `flutter.mmu_id` / `flutter.backend_user` | `AuthPersistence` | facility id + backend user id (drives per-user cache scoping) |
| `flutter.bootstrap_payload_v2` | `MastersStore` | Full `/mobile/bootstrap` JSON (user + facility + masters). ~500 KB — 90% of the app's local data lives here. |
| `flutter.bootstrap_masters_version` | `MastersStore` | masters version stamp for delta refresh |
| `flutter.bootstrap_fetched_at` | `MastersStore` | ISO of last successful bootstrap |
| `flutter.geo_blocks_v1` | `MastersStore` | Cached `/masters/blocks` for the caller's district |
| `flutter.geo_district_id` | `MastersStore` | District id the block cache was fetched for |
| `flutter.attend_cache_v1:{role}_{userId}:today` | `AttendanceStore` | Today's attendance row per user (JSON) |
| `flutter.attend_cache_v1:{role}_{userId}:history` | `AttendanceStore` | Facility-wide attendance history the user has seen (JSON array) |
| `flutter.attend_cache_v1:{role}_{userId}:anchors` | `AttendanceStore` | `/camps/anchors` cache for offline check-in snapping |
| `flutter.camps_cache_v1:{role}_{userId}` | `CampsStore` | Camps list for the user (JSON array) |
| `flutter.sync_push_queue` | `SyncService` | Offline write queue — array of `{client_action_id, kind, payload, enqueued_at}`. Drained through `/mobile/sync/push`. |
| `flutter.notif_history_v1:{userId}:items` | `NotificationsStore` | Bell dropdown history — last 50 in-app notifications |
| `flutter.notif_history_v1:{userId}:seen` | `NotificationsStore` | Read timestamp — controls the red badge count |

---

## Multi-user isolation

- Every per-user store keys by `{role}_{userId}` so a shared handset that
  logs out and back in as a different counsellor sees **their own** cache
  only. Logout wipes `AttendanceStore` for the outgoing user.
- FCM token registration is scoped to the currently-logged-in user via
  `NotificationsStore.currentUserKey` set right after login.

---

## Verify the XML yourself

Live from a connected DEBUG build (release APK is not debuggable):
```bash
adb -s <serial> shell "run-as com.jubicare.jubicare_mmu cat shared_prefs/FlutterSharedPreferences.xml"
```
Or pull the sample I checked in beside this doc:
[`mobile_local_storage.xml`](mobile_local_storage.xml) (26 lines, sanitize
tokens before sharing).

---

## Why no SQLite?

- The app is **online-first** — every entity has a server row of truth.
  Local storage is caches + offline-write queue, not a source of truth.
- SharedPreferences is a single-file XML — trivial to inspect, back up,
  and reason about. No migrations, no indexes to break.
- The biggest single value (`bootstrap_payload_v2`) is ~500 KB — well
  inside the ~2 MB SharedPreferences comfort zone. If any store starts
  approaching that alone, we'd move that specific store to Isar / SQLite
  — no bulk migration needed since the others stay put.
