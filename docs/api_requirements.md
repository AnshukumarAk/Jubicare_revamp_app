# JubiCare MMU — API Requirements (v2)

**Date:** 2026-08-11
**Author:** Mobile team
**Supersedes:** [backend_spec.v1-superseded.md](backend_spec.v1-superseded.md)
**Sources read:** DB overview from backend team (2026-08-11) + mobile
app v0.20.0+35 source

This document is written against the deployed database, not against
what v1 imagined. Where the two disagree, this v2 is authoritative for
the mobile side.

---

## 1. Why v2

v1 was drafted before we had the DB overview. Ten places it differed
from reality, in decreasing order of impact:

| # | v1 said                                       | Reality                                                                                     |
|---|-----------------------------------------------|---------------------------------------------------------------------------------------------|
| 1 | Table is called `visits`                      | Called **`appointment`** — one row per visit, vitals on the same row                        |
| 2 | Status ladder is straight-through             | Ladder loops **back to `with_counsellor`** for lab-test payment                              |
| 3 | UUID v7 primary keys                          | **BIGINT** sequences; human-facing codes (`GN-0123`, `MMU001`) alongside                    |
| 4 | Hard delete on DELETE                         | **Soft-delete everywhere**: `deleted_at / deleted_by / delete_reason` + `v_*_active` views  |
| 5 | Zonal Incharge approves stock                 | **DB is built for CMO per-line, Zonal read-only**. Mobile v0.19+ is built for Zonal. Open. |
| 6 | Per-role attendance tables                    | **Single `attendance` table** with a role column, `UNIQUE(user_id, attendance_date)`         |
| 7 | Attachments upload flow specified             | **Table exists, zero rows, no endpoint** — blocked on storage decision                       |
| 8 | Login only                                    | Login exists; **no refresh token** yet — staff get signed out mid-shift                      |
| 9 | Client sends `org_id` in some requests        | Never — **`org_id` comes from the signed-in account**                                        |
|10 | Chatty REST for Home                          | `/mobile/bootstrap` returns user + unit + camp + all masters in **one call** (built, not deployed) |

v2 aligns with the DB. Where a decision is still open, it is called
out in §14.

---

## 2. Ground rules the mobile app will follow

These are non-negotiable properties of the data. If the server enforces
them, the app respects them; if the server does not, the app respects
them anyway.

### 2.1 Read through views, write to base tables
Every list endpoint the mobile app reads must be backed by the
`v_*_active` view — otherwise soft-deleted rows leak into the UI. All
mutations target the base tables (server-side).

### 2.2 `org_id` comes from JWT
The client never sends `org_id`. Server derives it from the signed-in
account. Any query parameter attempting to override it is a **403**,
not a filter.

### 2.3 Send `id`, show `code`
Every screen displays the human code (`GN-0123`, `REQ-20260806-002`,
facility_code, org_code) but every request/response carries the
BIGINT id. Code is stable-enough for humans; id is stable for
software.

### 2.4 Enums are checked
Every enum value the mobile sends is one of the exact strings in §4 of
the DB overview. An unknown value is a **422**, not a silent coercion.
The client's dropdowns must be seeded from the enum, not hand-typed.

### 2.5 Names resolve inside their parent
Village is only valid within a block, block within a district. The
client always sends the parent id alongside the name-picker choice.

### 2.6 Aadhaar has no UI until it's encrypted
`patient.aadhar_number` is plaintext in the DB. Until the backend
decides on last-4-only / salted hash / at-rest encryption, the mobile
app will not capture or display Aadhaar on any screen. Advance-details
form will hide the field.

### 2.7 A sudden 401 means signed-out
`app_user.is_active` is re-read every request. If the app sees a 401
from a request that had a valid token yesterday, treat it as "you were
signed out remotely" — clear `AuthPersistence`, route to login. Do
not retry.

### 2.8 Soft-delete needs a reason
When the app calls a delete endpoint (e.g., cancel an attendance row),
it always sends `delete_reason`. The DB check-constraint requires it.

### 2.9 Prices are copied, not joined
When the doctor orders a lab test, the server copies
`lab_test_master.price` onto `appointment_lab_test.price` at that
moment. The mobile app displays the copied price on receipts. Rate
card can change — audit trail cannot.

---

## 3. Auth

### 3.1 Deployed

```
POST /api/auth/login        { username, password } → { access_token, user }
GET  /api/auth/me           → user profile (role, facility, org)
```

Where `user` is the shape the mobile persists via `AuthPersistence` in
[`state/auth_persistence.dart`](../lib/state/auth_persistence.dart):

```json
{
  "id": 42,
  "username": "con_test",
  "full_name": "Sanjeev Mahto",
  "role": "counsellor",
  "facility_id": 7,
  "facility_code": "MMU001",
  "org_id": 3,
  "state_id": 5,
  "district_id": 21
}
```

### 3.2 Required, not yet built

**Refresh token.** JWT expires today mid-shift; staff are dropped into
login while a patient is on the seat. Required shape:

```
POST /api/auth/login    → { access_token, refresh_token, user, access_expires_at, refresh_expires_at }
POST /api/auth/refresh  { refresh_token } → { access_token, access_expires_at }
POST /api/auth/logout   (bearer) → 204, invalidates refresh_token
```

Access token lifetime: 1 h. Refresh token lifetime: 30 d, rotated on
use, revocable via `app_user.is_active = false`.

**Change password.**

```
POST /api/auth/change-password { old_password, new_password } → 204
```

---

## 4. Bootstrap — one call to paint Home

Already built, not deployed. Must ship — it eliminates the 8-12 REST
calls that Home would otherwise fire on one bar of signal.

```
GET /mobile/bootstrap        (bearer, org_id derived from JWT)
```

Response:

```json
{
  "user": { …§3 user shape… },
  "facility": {
    "id": 7, "code": "MMU001", "type": "mmu",
    "state_id": 5, "district_id": 21,
    "camp_anchors": [{ "id": 12, "name": "Gajraula Camp", "lat": 28.845, "lng": 78.240 }, …]
  },
  "today_camp": { … | null },
  "masters": {
    "diseases":            [{ id, term, icd_code, synonyms: [...] }, …],
    "medicines":           [{ id, name, default_dosage }, …],
    "lab_tests":           [{ id, name, price, category }, …],
    "symptoms":            [{ id, term }, …],
    "counselling_topics":  [{ id, name }, …],
    "categories":          [{ id, name }, …],
    "referral_destinations": [{ id, name }, …],
    "blood_groups":        ["A+", "A-", …],
    "frequencies":         ["OD", "BD", "TDS", "QID", "SOS", "HS"]
  },
  "server_time": "2026-08-11T04:12:03Z"
}
```

`ETag` on the response so a same-day reopen is a cheap 304.

The app calls `/mobile/bootstrap`:
- On login success
- On foreground after > 30 min in background
- On explicit "Refresh masters" action

---

## 5. Sync — offline capture

Field users spend hours offline. Two endpoints exist (built, not
deployed); a third gap is called out.

### 5.1 Pull — deltas since a timestamp

```
GET /mobile/sync/pull?updated_since=2026-08-10T09:00:00Z
```

Response, chunked and sorted `updated_at ASC` so the client can page
until `items.length < per_page`:

```json
{
  "patients":     [ …changed rows… ],
  "appointments": [ … ],
  "attendance":   [ … ],
  "requisitions": [ … ],
  "cursor":       "2026-08-11T04:11:59Z",
  "has_more":     false
}
```

Every list endpoint the app hits (patient list, doctor queue, past 7
days) must also accept `?updated_since=` so an incremental refresh
does not re-download the full list.

### 5.2 Push — batch of offline actions

```
POST /mobile/sync/push
{
  "client_batch_id": "batch-uuid-from-the-app",
  "actions": [
    { "kind": "patient.register", "client_action_id": "…", "payload": {…} },
    { "kind": "attendance.check_in", "client_action_id": "…", "payload": {…} },
    …
  ]
}
```

Response reports each action individually:

```json
{
  "results": [
    { "client_action_id": "…", "status": "applied", "server_id": 148 },
    { "client_action_id": "…", "status": "rejected", "code": "STATUS_CONFLICT", "message": "…" }
  ]
}
```

`client_action_id` is idempotent — retrying the same action is a
no-op on the server.

### 5.3 Push kinds — what the server accepts

```
GET /mobile/sync/kinds → [ "patient.register", "attendance.check_in", "attendance.check_out", "device.status", … ]
```

**Gap:** today, only registration + attendance + device status. Doctor
and pharmacist submissions must be added:

- `appointment.doctor_submit`  (diagnoses, tests, rx, observations, remarks)
- `appointment.lab_result`
- `appointment.dispense`
- `appointment.lama`
- `requisition.submit` (usually online — but sync-able for continuity)

The mobile app will not enable offline mode for those flows until the
kinds are live.

---

## 6. Patients + Appointments

The workflow. Every screen except Home hangs off this.

### 6.1 Model recap

- `patient` — org-scoped, per-org unique via `unique_code`
- `appointment` — one row per visit, vitals inline, status drives all queues
- `appointment_symptom / _diagnosis / _lab_test / _attachment` — child rows
- `prescription_item` — one row per prescribed medicine

Vitals live on `appointment`, not in a separate table. The mobile
Vitals card writes `systolic_bp / diastolic_bp / blood_sugar /
temp_f / spo2 / heart_rate / hemoglobin / height_cm / weight_kg`
directly to the appointment row.

### 6.2 The status ladder

```
registered
    → with_doctor
        → with_counsellor    (tests ordered → patient goes back to pay)
            → with_lab
                → with_doctor    (doctor reads the result, prescribes)
                    → with_pharma
                        → completed
```

Exits at any point: `lama` (auto after 24 h without progress) or
`denied` (pharmacist).

Short-circuits from `with_doctor`:
- No tests, no medicines → `completed`
- Medicines only → `with_pharma`
- Tests only → `with_counsellor` (payment) → `with_lab` → …

The mobile app already trusts this ladder — status transitions are
server-authoritative.

### 6.3 Endpoints

Counsellor:

```
POST  /api/patients                         { …demographics, advance, symptoms… } → patient + first appointment
POST  /api/patients/{id}/re-appointment     → new appointment carrying prior visit forward (see 6.5)

GET   /api/patients?facility_id=…&q=…&status=&updated_since=
GET   /api/patients/{id}                    → patient + last 3 appointments
GET   /api/patients/{id}/appointments       → all appointments, newest first

POST  /api/appointments/{id}/test-payment   → moves with_counsellor → with_lab (records amount_paid)
```

Doctor:

```
POST  /api/appointments/{id}/doctor-submit  {
  vitals:      { …7 vitals + height + weight… },
  past_history: "…",
  observations: "…",
  doctor_remarks: "…",
  symptoms:    [ …strings or symptom_ids… ],
  diagnoses:   [ { disease_id | free_text } ],
  tests:       [ { lab_test_id } ],
  prescriptions: [ { medicine_id | name, dosage, frequency, duration, qty } ]
}
  → server transitions status to with_counsellor / with_pharma / completed based on tests + rx
```

Lab (deployed):

```
POST  /api/appointments/{id}/lab-result     { results: [ { appointment_lab_test_id, value, status } ], report_attachment_id? }
  → transitions status back to with_doctor
```

Pharmacist:

```
POST  /api/appointments/{id}/dispense       { lines: [ { prescription_item_id, dispensed_qty } ] }
  → transitions status to completed
POST  /api/appointments/{id}/deny           { reason }
  → transitions status to denied
```

Home KPI drilldowns — one endpoint each so the tile counts and the
list come from the same query:

```
GET  /api/queues/doctor?facility_id=…                (status IN 'registered','with_doctor')
GET  /api/queues/doctor/attended?facility_id=…       (status IN 'with_pharma','completed')
GET  /api/queues/doctor/past-7-days?facility_id=…
GET  /api/queues/lab?facility_id=…                   (with_lab)
GET  /api/queues/pharmacist?facility_id=…            (with_pharma)
GET  /api/queues/pharmacist/past-7-days
GET  /api/queues/counsellor/past-7-days
GET  /api/queues/counsellor/pending-payment?facility_id=…  (with_counsellor after doctor ordered tests)
```

### 6.4 Vitals

Not a separate table — write directly to `appointment` in
doctor-submit. Blank values must be `NULL`, not zero.

### 6.5 Re-appointment carry-over (missing on server today)

This must be built server-side so the mobile app doesn't have to
re-implement it against the API. Server behaviour:

Given `POST /api/patients/{id}/re-appointment { parent_appointment_id: N }`,
create a new `appointment` row and:

1. Copy `past_history` from source
2. Copy `appointment_diagnosis` rows (unmodified — doctor can edit later)
3. Deep-copy `prescription_item` rows (new IDs — edits on the new
   appointment must not mutate the source)
4. Fold source's `disease` into the new `past_history` prefix:
   `"Previous Diagnosis (dd-Mon-yyyy): <disease>\n<existing past_history>"`
5. Attachments: reference-not-copy (both appointments point to the
   same `attachment` row; kind stays `Prescription/Report`)
6. Symptoms: copy for editability
7. Vitals: **do not carry** — per-visit reading

Status of the new appointment: `registered`. Set `parent_appointment_id`
so history is queryable.

### 6.6 Attachments — blocked on storage decision (§14.2)

Table + kind enum exist. Zero rows. No endpoint. When the storage
decision lands, the flow is:

```
POST /api/attachments/upload-url       { kind, mime_type, size_bytes } → { url, storage_key, expires_at }
PUT  <url> with the file bytes
POST /api/attachments                  { storage_key, kind, description, appointment_id }
GET  /api/attachments/{id}/download-url → pre-signed GET
DELETE /api/attachments/{id}           { delete_reason }
```

Until then, mobile hides the "Prescription and Reports" upload
control on the register form and shows attachments purely as text
descriptions where they exist.

---

## 7. Attendance

Single table with a role column. `UNIQUE(user_id, attendance_date)`
— one row per user per day, opened at check-in and closed at
check-out. This exactly matches what the mobile app enforces.

Endpoints:

```
GET  /api/attendance/today                → open row for today, or null
POST /api/attendance/check-in             { camp_anchor_id, photo_key, lat, lng, staff?, start_km? }
POST /api/attendance/check-out            { photo_key, lat, lng, staff?, end_km?, collection? }

GET  /api/attendance?user_id=…&from=&to=
GET  /api/attendance/{id}
```

Server enforcement (must — the mobile app already assumes this):

- Reject check-out when no row exists for `(user_id, today)` or when
  the row already has `check_out_time`. Error code:
  `CHECK_IN_REQUIRED`.
- Fill `check_in_time` / `check_out_time` server-side using `NOW()`.
  Ignore the client's clock — the mobile shows them as read-only.
- Do not update `location_camp` on check-out — it stays the
  check-in camp.

Selfie upload: same flow as §6.6. Photo key is required.

---

## 8. Requisitions (stock)

### 8.1 Model

- `requisition` — header, `code` = `REQ-YYYYMMDD-NNN`, server-generated
- `requisition_line` — per-medicine line
- Approval semantics on the line: `approved_qty` — **NULL = undecided,
  0 = rejected, >0 = approved (may differ from requested)**. These
  three states must not be collapsed by the API.

### 8.2 OPEN — CMO vs Zonal Incharge (see §14.1)

The DB is built for CMO per-line approval with Zonal Incharge
read-only. The mobile app (v0.19+) is built for Zonal Incharge
approval with CMO removed. **These are incompatible.** Do not build
requisition endpoints until this is resolved. The mobile side
recommends going with Zonal Incharge for consistency with the
already-shipped UI, but this is a policy call, not a technical one.

### 8.3 Endpoints — pharmacist side (mobile)

```
POST  /api/requisitions                   { lines: [ { medicine_id, dosage, unit, requested_qty } ] }
  → server generates code, sets status = 'Requested'
GET   /api/requisitions?facility_id=…&status=&updated_since=
GET   /api/requisitions/{id}              → header + lines + audit
POST  /api/requisitions/{id}/verify       {
  invoice_storage_key,
  lines: [ { line_id, received_qty } ],
  extras: [ { medicine_id, dosage, unit, received_qty } ]?
}
POST  /api/requisitions/{id}/re-order     → new requisition copying medicine/dosage/unit, requested_qty = 0
```

`re-order` is only allowed when source `status = 'Received'` (matches
the mobile app's rule).

### 8.4 Endpoints — approver side (web portal, out of mobile scope)

Listed for completeness so the API team can plan them:

```
GET  /api/requisitions/pending
POST /api/requisitions/{id}/decision      { lines: [ { line_id, approved_qty, remark? } ], remark? }
POST /api/requisitions/{id}/add-line      { medicine_id, dosage, unit, qty }
```

Role gate on both: whoever §8.2 lands on.

---

## 9. Camps + Devices

### 9.1 Camps

```
POST /api/camps                { village_id, type, name, venue, camp_date }
GET  /api/camps?facility_id=…&from=&to=&updated_since=
```

`type` is the `camp_type_t` enum (`Community | School | Workplace |
Health Awareness`).

### 9.2 Devices + status history

```
GET  /api/devices?facility_id=…
POST /api/devices/status               { status_date, statuses: [ { device_id, status } ] }
GET  /api/devices/status?facility_id=…&month=YYYY-MM
GET  /api/devices/status/on?date=…&facility_id=…
```

`status` is the `device_state_t` enum.

---

## 10. GPS — blocked on decision (§14.3)

Three tables ready and empty: `mmu_current_position`, `mmu_location_track`,
`mmu_route_stop`. When the decision lands:

```
POST /api/mmu/position                 { lat, lng, speed_mps, heading_deg, recorded_at }
     (rate-limited: 1 request per 30 s per user)
GET  /api/mmu/position?facility_id=…   → most recent
GET  /api/mmu/track?facility_id=…&date=…
```

Runs on its own low-frequency loop in the app — does not ride on the
sync queue.

---

## 11. Deletes

Every write endpoint that supports removal takes `delete_reason`:

```
DELETE /api/{resource}/{id}       { delete_reason }
```

Server sets `deleted_at`, `deleted_by`, `delete_reason`. Missing
reason is a **422** (DB check-constraint would reject anyway).

The mobile app currently does not expose deletes. When it does, the
UI will collect a reason before the request goes out.

---

## 12. Error format

All errors:

```json
{
  "error": {
    "code":    "STATUS_CONFLICT",
    "message": "Cannot dispense — appointment is not with pharmacist",
    "details": { "current_status": "with_lab" }
  }
}
```

Well-known codes the mobile handles specifically:

| Code                  | HTTP | Mobile behaviour                                  |
|-----------------------|------|---------------------------------------------------|
| `INVALID_CREDENTIALS` | 401  | Show inline error on login                        |
| `TOKEN_EXPIRED`       | 401  | Silent refresh via refresh_token; retry once      |
| `SIGNED_OUT_REMOTELY` | 401  | Clear AuthPersistence, route to login             |
| `CHECK_IN_REQUIRED`   | 409  | Show "Please complete Check-In before Check-Out"   |
| `STATUS_CONFLICT`     | 409  | Show server message + refresh the record          |
| `ENUM_INVALID`        | 422  | Log + surface generic "Please retry"              |
| `RATE_LIMITED`        | 429  | Back off with `Retry-After`                        |

---

## 13. Mobile-side changes required

- Replace `CounsellorState` in-memory writes with API calls
  (screen-by-screen, no UI change)
- Wire `/mobile/bootstrap` on login + foreground
- Wire `/mobile/sync/pull` on foreground (with cursor persisted)
- Queue offline mutations, drain via `/mobile/sync/push`
- Handle 401 as "signed out" (clear `AuthPersistence`, route to login)
- Store refresh_token in `AuthPersistence`; use on 401
- Hide the "Aadhaar" input on the counsellor Register form until §2.6
  is settled

---

## 14. Open decisions blocking this spec

### 14.1 Who approves a medicine requisition?

DB built for **CMO per-line, Zonal Incharge read-only**.
Mobile app v0.19+ built for **Zonal Incharge approval, CMO removed**.
These cannot both be true.

**Recommendation:** go with Zonal Incharge (matches the shipped
mobile). If we pick CMO, the mobile UI has to be undone and
re-shipped. Policy call from ops needed.

### 14.2 Where do files live?

Attachments table exists, zero rows, no endpoint. Options:

- **S3 or MinIO** — signed URLs, cheap to scale, backup-friendly
- **Disk path on the app server** — simple but needs to be in the
  backup and behind auth

Until this is chosen, `appointment_attachment` stays empty and lab
reports have a filename with no file behind it. Blocks Prescription
and Reports on the counsellor Register + Doctor screen.

### 14.3 Should the phone report GPS?

Three tables ready and empty. If yes, low-frequency endpoint per
§10. If no, table lives on and we do not spec anything.

### 14.4 Does the app do consultations offline?

`/mobile/sync/push` today accepts registration + attendance + device
status only. Doctor and pharmacist actions need to be added to the
handler. Small server change, big win for field usability.

---

## 15. Recommended delivery order

1. **Ship what's built.** Deploy `/mobile/bootstrap` and
   `/mobile/sync/{pull,push,kinds}` to the same server the app hits.
2. **Refresh token.** Staff getting signed out mid-shift is the
   loudest complaint after "the tab won't load" — fix first.
3. **`?updated_since=` on every list endpoint.** Cheap change,
   unblocks incremental refresh.
4. **Resolve §14.1** (CMO vs Zonal). Build the requisition
   approval endpoints against that decision.
5. **Resolve §14.2** (storage). Build the attachment endpoints.
6. **Add doctor + pharmacist mutations to `/mobile/sync/push`
   kinds.**
7. **Ship `re-appointment` carry-over** on the server (§6.5).
8. **GPS** if §14.3 is a yes.

Once (1)–(3) land, the mobile team can migrate the app off in-memory
state screen-by-screen without breaking the shipped UI.
