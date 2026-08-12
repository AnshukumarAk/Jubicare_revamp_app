# JubiCare MMU — Backend Spec

**Version:** 1.0
**Date:** 2026-08-06
**Applies to mobile app version:** 0.20.0+35

Design document for the backend that powers the JubiCare MMU mobile app
(counsellor + doctor + pharmacist). Derived from the current in-memory
state and screens; no client-side change is assumed beyond replacing
`CounsellorState` reads/writes with HTTP calls.

Stack assumption (adjust to what your infra prefers):

- Database: PostgreSQL 15+
- App layer: FastAPI (Python 3.11+) — snake_case JSON, ISO-8601 dates
- Auth: JWT (access token + refresh) — 1 h access, 30 d refresh
- File storage: object storage (S3 / MinIO) with pre-signed URLs
- All IDs are UUID v7 unless stated otherwise; primary keys default
  `gen_random_uuid()`

---

## 1. Conventions

**JSON shape**

- All keys: `snake_case`.
- Timestamps: ISO-8601 with UTC offset, e.g. `2026-08-06T09:12:03Z`.
- Dates without time: `YYYY-MM-DD`.
- Booleans: `true` / `false`.
- Money in paise (int); measurements as decimal strings (`"98.6"`).

**Pagination** — `?page=1&per_page=25` → response:

```json
{ "items": [...], "page": 1, "per_page": 25, "total": 214 }
```

**Errors** — HTTP status + envelope:

```json
{ "error": { "code": "INVALID_TOKEN", "message": "…", "details": {...} } }
```

**Audit columns** on every table:

```sql
created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
created_by   UUID REFERENCES users(id),
updated_by   UUID REFERENCES users(id)
```

---

## 2. Auth + Users

### `users`

| Column         | Type            | Notes                                          |
|----------------|-----------------|------------------------------------------------|
| id             | UUID PK         |                                                |
| username       | TEXT UNIQUE     | login handle                                   |
| password_hash  | TEXT NOT NULL   | bcrypt / argon2id                              |
| full_name      | TEXT NOT NULL   | shown on Home headers                          |
| role           | user_role       | ENUM: counsellor / doctor / pharmacist / zonal / admin |
| phone          | TEXT            |                                                |
| email          | TEXT            |                                                |
| is_active      | BOOLEAN         | default true                                   |
| mmu_id         | UUID            | FK → mmus(id), nullable (only counsellor has one) |
| state_id       | UUID            | FK → states(id), for counsellor scoping        |
| district_id    | UUID            | FK → districts(id)                             |
| assigned_zone  | UUID            | FK → zones(id), for zonal-incharge scoping     |
| last_login_at  | TIMESTAMPTZ     |                                                |
| audit cols     |                 |                                                |

Indexes: `users(username)`, `users(role, is_active)`.

**Endpoints**

```
POST   /api/auth/login                     { username, password } → { access_token, refresh_token, user }
POST   /api/auth/refresh                   { refresh_token }      → { access_token }
POST   /api/auth/logout                    (bearer)               → 204
GET    /api/auth/me                        (bearer)               → user profile
POST   /api/auth/change-password           { old, new }           → 204
```

The `user` block returned on login lets the client persist the session
locally (matches `AuthPersistence` in the app):

```json
{
  "id": "…", "username": "con_test", "full_name": "Sanjeev Mahto",
  "role": "counsellor", "mmu_id": "MMU001",
  "state_id": "…", "district_id": "…"
}
```

---

## 3. Geography + Masters

Kept small; static rows loaded from Excel today. Backend just serves them.

### `states`, `districts`, `blocks`, `villages`

```sql
states     (id UUID PK, name TEXT, code TEXT UNIQUE)
districts  (id UUID PK, state_id FK, name TEXT, UNIQUE(state_id, name))
blocks     (id UUID PK, district_id FK, name TEXT, UNIQUE(district_id, name))
villages   (id UUID PK, block_id FK, name TEXT, UNIQUE(block_id, name))
```

### `mmus` — mobile medical units

```sql
mmus (
  id UUID PK,
  code TEXT UNIQUE,        -- 'MMU001'
  label TEXT,              -- 'MMU 1 · Gajraula route'
  state_id FK, district_id FK,
  active BOOLEAN,
  audit cols
)
```

### `mmu_camp_anchors` — the three GPS anchors used for nearest-camp auto-pick

```sql
mmu_camp_anchors (
  id UUID PK,
  mmu_id FK,
  name TEXT,               -- 'Gajraula Camp'
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION
)
```

### `zones` — for the Zonal Incharge routing on requisitions

```sql
zones (
  id UUID PK,
  name TEXT,
  incharge_user_id FK,     -- the Zonal Incharge user
  covers_state_ids UUID[]  -- list of states this zone covers
)
```

### `master_diseases`, `master_medicines`, `master_lab_tests`

```sql
master_diseases   (id UUID PK, term TEXT, icd_code TEXT, synonyms TEXT[])
master_medicines  (id UUID PK, name TEXT, default_dosage TEXT)
master_lab_tests  (id UUID PK, name TEXT)
```

Small lookup tables (blood groups, categories, gender, frequencies,
durations) can be served from a single endpoint or hard-coded on the
client — currently hard-coded, keep as-is.

**Endpoints**

```
GET /api/masters/states
GET /api/masters/districts?state_id=…
GET /api/masters/blocks?district_id=…
GET /api/masters/villages?block_id=…

GET /api/masters/mmus
GET /api/masters/mmus/{mmu_id}/camp-anchors

GET /api/masters/diseases?q=fever&limit=50
GET /api/masters/medicines?q=paraceta&limit=50
GET /api/masters/lab-tests
```

All GET endpoints are cacheable — respond with `ETag` + `Cache-Control: max-age=86400`.

---

## 4. Patients + Consultation Workflow

Core flow: **counsellor** registers → **doctor** consults → **pharmacist** dispenses.

### `patients`

```sql
patients (
  id                    UUID PK,
  mmu_id                UUID FK,
  registered_by_user_id UUID FK,           -- counsellor who filed the row
  unique_code           TEXT UNIQUE,       -- 'GN-1234' (auto)
  name                  TEXT NOT NULL,
  gender                TEXT NOT NULL,     -- 'Female' | 'Male' | 'Other'
  age                   INT,               -- either age or dob populated
  dob                   DATE,
  contact               TEXT NOT NULL,     -- 10-digit
  is_pregnant           BOOLEAN,
  lmp_date              DATE,              -- last menstrual period
  edd_date              DATE,              -- computed lmp + 280d
  state_id              UUID FK,
  district_id           UUID FK,
  block_id              UUID FK,
  village_id            UUID FK,

  -- Advance details
  aadhar                TEXT,
  height_cm             NUMERIC(4,1),
  weight_kg             NUMERIC(4,1),
  blood_group           TEXT,
  category              TEXT,              -- SC/ST/OBC/GEN
  pwd                   BOOLEAN,
  pin                   TEXT,
  address               TEXT,

  registered_on         DATE NOT NULL,     -- e.g. 2026-08-06 (appointment date)
  status                patient_status NOT NULL,
  audit cols
)
```

`patient_status` ENUM:
`registered → with_doctor → with_pharma → completed | lama | denied`.

Indexes:
- `patients(mmu_id, registered_on DESC)` — Home list
- `patients(contact)` — Status search
- `patients(status)` — Doctor / Pharma queues
- `patients(registered_by_user_id, registered_on DESC)` — counsellor's roll

### `patient_vitals`

```sql
patient_vitals (
  id UUID PK,
  patient_id FK,
  visit_id UUID NULL,      -- populated when captured on a specific visit
  systolic_bp    INT,
  diastolic_bp   INT,
  blood_sugar    INT,
  temp_f         NUMERIC(4,1),
  spo2           INT,
  heart_rate     INT,
  hemoglobin     NUMERIC(3,1),
  captured_by_user_id FK,
  captured_at    TIMESTAMPTZ,
  UNIQUE(patient_id, visit_id)
)
```

### `patient_symptoms`

```sql
patient_symptoms (
  patient_id UUID FK,
  visit_id   UUID FK,
  symptom    TEXT NOT NULL,      -- free-text tag
  PRIMARY KEY (patient_id, visit_id, symptom)
)
```

### `visits`

One row per appointment / re-appointment. Re-appointment carries
diagnosis + prescription forward (matches the code's `carryPast` /
`carryDisease` / `carryPrescription` in `screens_register.dart`).

```sql
visits (
  id UUID PK,
  patient_id FK,
  mmu_id FK,
  registered_by_user_id FK,      -- counsellor
  doctor_user_id FK NULL,
  pharmacist_user_id FK NULL,
  parent_visit_id FK NULL,       -- set on re-appointment → last visit
  appointment_date DATE,
  status patient_status,
  past_history TEXT,             -- doctor screen editable PMH
  observations TEXT,
  doctor_remarks TEXT,
  remarks TEXT,                   -- counsellor remarks
  payment_kind TEXT,              -- 'Free' | 'Paid'
  payment_amount NUMERIC(8,2),
  on_medication BOOLEAN,          -- 'Currently taking prescribed medication'
  audit cols
)
```

### `visit_diagnoses` — multi-select

```sql
visit_diagnoses (
  visit_id FK,
  disease_id FK NULL,      -- null when doctor typed free text
  free_text TEXT,          -- 'Term · ICD' or raw string
  ordering INT,
  PRIMARY KEY (visit_id, ordering)
)
```

### `visit_tests`

```sql
visit_tests (
  visit_id FK,
  test_id FK,               -- master_lab_tests
  status TEXT DEFAULT 'ordered'  -- ordered / done / not_done
)
```

### `visit_prescriptions` — one row per medicine line

```sql
visit_prescriptions (
  id UUID PK,
  visit_id FK,
  medicine_id FK NULL,      -- null on free-text meds
  medicine_name TEXT,
  dosage TEXT,              -- '500 mg'
  frequency TEXT,           -- OD/BD/TDS/QID/SOS/HS
  duration TEXT,            -- '5 Days' | 'SOS' | free string
  qty INT,                  -- auto-calculated on client, stored server-side
  dispensed_qty INT,
  dispensed BOOLEAN DEFAULT false,
  ordering INT
)
```

### `attachments`

```sql
attachments (
  id UUID PK,
  patient_id FK,
  visit_id FK,
  uploaded_by_user_id FK,
  kind attachment_kind,     -- prescription / report / other
  storage_key TEXT,         -- object-store path
  file_name TEXT,
  mime_type TEXT,
  size_bytes BIGINT,
  description TEXT,
  captured_lat DOUBLE PRECISION,
  captured_lng DOUBLE PRECISION,
  audit cols
)
```

**Endpoints**

```
POST   /api/patients                          → CPatient JSON
GET    /api/patients?mmu_id=…&q=…&status=…    (list + search + drill-down)
GET    /api/patients/{id}                     → detail incl. latest vitals + last-3 previous Rx
POST   /api/patients/{id}/re-appointment      → creates a new visit that carries prior visit forward

GET    /api/patients/{id}/visits              → all visits, newest first
POST   /api/visits                            → counsellor Submit
GET    /api/visits/{id}
PATCH  /api/visits/{id}                       → doctor Submit Case (diagnoses, tests, rx, observations, remarks)
POST   /api/visits/{id}/dispense              → pharmacist dispense

POST   /api/visits/{id}/vitals                → replace vitals block for the visit
GET    /api/visits/{id}/vitals

# Attachments
POST   /api/attachments/upload-url            → returns pre-signed PUT URL + storage_key
POST   /api/attachments                       → register the uploaded file with metadata
GET    /api/attachments/{id}/download-url     → pre-signed GET
DELETE /api/attachments/{id}
```

**Queue endpoints for Home KPI drilldowns**

```
GET  /api/queues/doctor?mmu_id=…              → status IN ('registered','with_doctor')
GET  /api/queues/doctor/past-7-days?mmu_id=…  → doctor's own drill-down list
GET  /api/queues/doctor/attended?mmu_id=…
GET  /api/queues/pharmacist?mmu_id=…
GET  /api/queues/pharmacist/past-7-days
GET  /api/queues/counsellor/past-7-days
```

Each returns paginated patient rows with `latest_visit_id` so the shell
can open the right detail view.

**Behaviour rules encoded in the client — enforce server-side too:**

- `patients.status` transitions must follow the enum ladder; reject
  `registered → completed` in one hop (require doctor step or explicit
  LAMA endpoint).
- After 24 h in `registered` or `with_doctor` without a visit update,
  auto-mark `lama` (matches the portal's auto-LAMA rule).
- On re-appointment, server carries: `past_history`, latest visit's
  `diagnoses`, latest visit's `prescriptions` (deep-copied so edits on
  the new visit don't mutate the old one), and all `attachments`.

---

## 5. Attendance

Three tables, one per role — mobile screens differ per role. Same
shape kept so downstream reporting can UNION them cleanly.

### `attendance_counsellor`, `attendance_doctor`, `attendance_pharma`

```sql
attendance_<role> (
  id UUID PK,
  user_id FK,
  mmu_id FK,
  date DATE NOT NULL,
  status TEXT DEFAULT 'Present',
  location_camp TEXT,           -- 'Gajraula Camp' — from mmu_camp_anchors.name
  camp_anchor_id FK,

  -- Check-In half
  check_in_time TIME,
  check_in_photo_key TEXT,      -- object-store key of selfie
  check_in_lat DOUBLE PRECISION,
  check_in_lng DOUBLE PRECISION,

  -- Check-Out half (nullable until end-of-shift)
  check_out_time TIME,
  check_out_photo_key TEXT,
  check_out_lat DOUBLE PRECISION,
  check_out_lng DOUBLE PRECISION,

  notes TEXT,

  -- Counsellor extras (only on attendance_counsellor)
  start_km INT,
  end_km INT,
  total_run INT,
  collection NUMERIC(8,2),
  driver_in BOOLEAN, doctor_in BOOLEAN, pharma_in BOOLEAN,
  driver_out BOOLEAN, doctor_out BOOLEAN, pharma_out BOOLEAN,

  audit cols,
  UNIQUE(user_id, date)         -- one row per user per day (open then closed)
)
```

Indexes: `attendance_<role>(user_id, date DESC)`.

**Business rules (server-enforced)**

- Reject a check-out submission when no row exists for `(user_id, date)`
  or when the existing row already has `check_out_time`. Matches the
  mobile guard "Please complete Check-In before Check-Out".
- On check-out, the row's `location_camp` is not updated — the
  audit trail keeps the morning's camp.
- `check_in_time` / `check_out_time` should be filled server-side using
  `NOW()` regardless of what the client sends (mobile shows them
  read-only anyway — server is the authority).

**Endpoints**

```
POST /api/attendance/{role}/check-in         { camp_anchor_id, photo_key, lat, lng, notes?, staff?, start_km? }
POST /api/attendance/{role}/check-out        { photo_key, lat, lng, notes?, staff?, end_km?, collection? }
GET  /api/attendance/{role}?user_id=…&from=&to=
GET  /api/attendance/{role}/{id}
GET  /api/attendance/{role}/today?user_id=…  → returns the open row or null (feeds the mode gate)
```

`role ∈ { counsellor, doctor, pharma }`.

---

## 6. Camps + Devices (Counsellor tabs)

### `camps`

```sql
camps (
  id UUID PK,
  mmu_id FK,
  village_id FK,
  type TEXT,               -- 'Health Awareness' | 'NCD' | 'ANC' | …
  name TEXT,
  venue TEXT,
  camp_date DATE,
  submitted_by_user_id FK,
  audit cols
)
```

Endpoints:

```
POST /api/camps
GET  /api/camps?mmu_id=…&from=&to=
```

### `devices` + `device_status_history`

```sql
devices (
  id UUID PK,
  mmu_id FK,
  name TEXT,               -- 'ECG Machine', 'BP Monitor', …
  active BOOLEAN
)

device_status_history (
  id UUID PK,
  device_id FK,
  status_date DATE,
  status TEXT,             -- 'Working' | 'Not Working' | 'Under Repair'
  submitted_by_user_id FK,
  UNIQUE (device_id, status_date)
)
```

Endpoints:

```
GET  /api/devices?mmu_id=…
POST /api/devices/status                 { status_date, statuses: [{ device_id, status }] }
GET  /api/devices/status?mmu_id=…&month=YYYY-MM
GET  /api/devices/status/on?date=…&mmu_id=…    → snapshot for that date
```

---

## 7. Requisitions (Stock — Pharmacist ↔ Zonal Incharge)

Matches the current in-memory `Requisition` + `ReqLine` + `AuditEntry`
model, with the CMO role removed per today's rule.

### `requisitions`

```sql
requisitions (
  id UUID PK,
  code TEXT UNIQUE,               -- REQ-YYYYMMDD-NNN, generated server-side
  mmu_id FK,
  submitted_by_user_id FK,        -- pharmacist
  zone_id FK,                     -- routes it to a Zonal Incharge
  submitted_at TIMESTAMPTZ,
  status req_status NOT NULL,     -- pending | approved | partial | rejected | verified
  zonal_remark TEXT,
  invoice_storage_key TEXT,       -- upload from pharma on verification
  audit cols
)
```

### `requisition_lines`

```sql
requisition_lines (
  id UUID PK,
  requisition_id FK,
  medicine_id FK NULL,
  medicine_name TEXT,
  dosage TEXT,
  unit TEXT,                      -- Tab / Strip / Vial / ml / Bottle / Sachet
  requested_qty INT,
  approved_qty INT DEFAULT -1,    -- -1 no decision, 0 rejected, >0 approved
  received_qty INT DEFAULT 0,
  is_zonal_added BOOLEAN,         -- Zonal Incharge added on top of pharma ask
  zonal_remark TEXT,
  status TEXT,                    -- Pending / Approved / Rejected / Received / Partial
  ordering INT
)
```

### `requisition_audit`

```sql
requisition_audit (
  id UUID PK,
  requisition_id FK,
  actor TEXT,                     -- 'Pharmacist' | 'Zonal Incharge' | 'System'
  actor_user_id FK NULL,
  action TEXT,                    -- 'Submitted requisition', 'Approved (partial)', …
  note TEXT,
  when_ts TIMESTAMPTZ DEFAULT now()
)
```

**Endpoints**

Pharmacist side (mobile):

```
POST  /api/requisitions                           → { lines: [{ medicine, dosage, unit, qty }] }
GET   /api/requisitions?mmu_id=…&status=          (list — Past tab)
GET   /api/requisitions/{id}                      → header + lines + audit
POST  /api/requisitions/{id}/verify               → { invoice_storage_key, lines: [{ id, received_qty }], extras?: [...] }
POST  /api/requisitions/{id}/re-order             → creates a fresh requisition copying medicine/dosage/unit with qty=0
```

Zonal Incharge side (web portal — spec here for completeness):

```
GET   /api/requisitions/pending?zone_id=…
POST  /api/requisitions/{id}/decision             → { lines: [{ id, approved_qty, remark? }], remark? }
POST  /api/requisitions/{id}/add-line             → Zonal-added medicine
```

**Business rules**

- Server generates `code` (REQ-YYYYMMDD-NNN) — do not trust client.
- Only `zonal` role can hit the `decision` / `add-line` endpoints; the
  auth guard rejects otherwise.
- `re-order` allowed only when source requisition `status = 'verified'`.
- Every state change writes exactly one `requisition_audit` row.

---

## 8. Denials (Pharmacist)

Small table for pharmacist-side denials.

```sql
denied_deliveries (
  id UUID PK,
  patient_id FK,
  visit_id FK,
  reason TEXT,
  denied_on DATE,
  denied_by_user_id FK,
  audit cols
)
```

Endpoints:

```
POST /api/denials     { visit_id, reason }     → flips patient.status to 'denied'
GET  /api/denials?mmu_id=…
```

---

## 9. Cross-cutting

### File upload flow

Mobile keeps files light — the client always requests a pre-signed URL,
uploads directly to object storage, then registers metadata:

```
1. POST /api/attachments/upload-url → { url, storage_key, expires_at }
2. PUT <url> with the file bytes (no auth needed inside pre-signed URL)
3. POST /api/attachments             { storage_key, kind, description, patient_id, visit_id }
```

Same pattern for attendance selfies (`/api/attendance/upload-url`)
and requisition invoices.

### Sync-friendly reads

Mobile field users spend hours offline. Provide list endpoints with
`?updated_since=<ISO ts>` so the app can incrementally refresh from
what it has cached. Return items in `updated_at ASC` order; page until
`items.length < per_page`.

### Rate limits + audit

- Login: 5 failed attempts / 15 min per IP + username.
- Auth failures + role-guard rejections written to `security_audit`.
- All mutating endpoints logged in `api_audit(request_id, user_id, path, body_hash)`.

---

## 10. Delivery checklist for the backend team

- [ ] Postgres migrations for §2–§8 tables + ENUMs
- [ ] Seed script for `states / districts / blocks / villages / mmus /
      camp_anchors / master_diseases / master_medicines`
- [ ] Auth module (login / refresh / me / logout / change-password)
- [ ] Patients + Visits + Vitals + Symptoms + Diagnoses + Prescriptions
- [ ] Re-appointment carry-over logic
- [ ] Attachments (upload-url + metadata + download-url)
- [ ] Attendance for all three roles with check-in-first guard
- [ ] Camps + Devices
- [ ] Requisitions + lines + audit + Zonal decision + Re-order
- [ ] Denials
- [ ] KPI queue endpoints (Home tiles + drilldowns + past 7 days)
- [ ] Postman / OpenAPI collection published at `/openapi.json`
- [ ] Integration tests covering the counsellor → doctor → pharma flow

Once these ship, the mobile app can migrate off `CounsellorState`
in-memory storage screen-by-screen without changing any UI.
