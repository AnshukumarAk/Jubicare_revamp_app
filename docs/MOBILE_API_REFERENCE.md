# JubiCare MMU — Mobile API Reference

Every backend endpoint the mobile app calls, with request bodies and query
params in the exact shape the Flutter client sends. Base URL:

```
https://revamp-back.indevconsultancy.in/api
```

**All authed calls (everything except `/auth/login`) require:**
```
Authorization: Bearer <access_token>
Content-Type:  application/json
```

Token flow is proactive + reactive: expired access tokens auto-refresh via
`/auth/refresh` (single-flight, serialised). Refresh past 30 days → login.

Path variables use `{id}`; the same client code writes them as `$id`.

Total: **40 unique endpoints across 12 modules · 48 client-side call sites.**

---

## Table of contents

1. [Auth](#1-auth)
2. [Bootstrap + Masters](#2-bootstrap--masters)
3. [Sync (offline queue)](#3-sync-offline-queue)
4. [Uploads (multipart)](#4-uploads-multipart)
5. [Attendance](#5-attendance)
6. [Camps](#6-camps)
7. [Patients](#7-patients)
8. [Appointments (clinical workflow)](#8-appointments-clinical-workflow)
9. [Queues (KPI tiles + drilldowns)](#9-queues-kpi-tiles--drilldowns)
10. [Devices (daily status)](#10-devices-daily-status)
11. [Requisitions (pharmacy stock)](#11-requisitions-pharmacy-stock)
12. [Staff (roster)](#12-staff-roster)

---

## 1. Auth
File: [`lib/api/auth_api.dart`](../lib/api/auth_api.dart)

### 1.1 POST `/auth/login`
Sign in, persists access + refresh tokens locally.
```json
{
  "username": "couns.mmu",
  "password": "…"
}
```
Response
```json
{
  "access_token":      "eyJ…",
  "refresh_token":     "eyJ…",
  "access_expires_at": "2026-08-20T18:30:00Z",
  "refresh_expires_at":"2026-09-19T18:30:00Z",
  "user": { "user_id": 30, "username": "couns.mmu", "role": "counsellor", … }
}
```

### 1.2 GET `/auth/me`
Current signed-in user's profile. No body.

### 1.3 POST `/auth/logout`
Ends session on server. No body.

### 1.4 POST `/auth/change-password`
```json
{ "old_password": "…", "new_password": "…" }
```

### 1.5 POST `/auth/refresh` *(client-internal, called by ApiClient)*
```json
{ "refresh_token": "eyJ…" }
```

---

## 2. Bootstrap + Masters
File: [`lib/api/bootstrap_api.dart`](../lib/api/bootstrap_api.dart)

### 2.1 GET `/mobile/bootstrap`
One call to hydrate Home: user + facility + today_camp + full masters
(symptoms, diseases, medicines, blood groups, camp types…). No body.

### 2.2 GET `/masters/blocks?district_id={id}`
### 2.3 GET `/masters/villages?block_id={id}`

Geography cascade for Register form. Returns `[{id, name}, …]`.

---

## 3. Sync (offline queue)
File: [`lib/api/sync_api.dart`](../lib/api/sync_api.dart)

### 3.1 GET `/mobile/sync/pull`
Delta pull for offline hydration.
```
?updated_since=2026-08-19T00:00:00Z&per_page=200
```
Response: `{patients, appointments, attendance, requisitions, cursor, has_more}`.

### 3.2 POST `/mobile/sync/push`
Drain offline write queue (batches of 200).
```json
{
  "client_batch_id": "…",
  "actions": [
    {
      "client_action_id": "uuid-1",
      "kind": "patient.register",
      "payload": { … full payload per action kind, see §7.1 for shape … }
    }
  ]
}
```
Response
```json
{
  "applied": 3, "rejected": 0, "failed": 0,
  "results": [
    { "client_action_id": "uuid-1", "status": "applied", "retry": false,
      "server_id": 42, "result": { … } }
  ]
}
```
Per-action `status`: `applied` (drop) · `rejected` (drop) · `failed` (retry).

### 3.3 GET `/mobile/sync/kinds`
Server tells the client which action kinds it accepts + role allow-list.

---

## 4. Uploads (multipart)
File: [`lib/api/uploads_api.dart`](../lib/api/uploads_api.dart)

### 4.1 POST `/mobile/uploads`
`multipart/form-data` with field `file` = a JPEG/PNG/WebP.  
Content-type inferred from extension.  
Response: `{file_name: "patient_docs/3f2a….jpg", url, size}`.

Used by:
- Prescription/report photos at register submit
- Offline sync's photo-lift pass (queued local `/data/user/…` paths uploaded before push).

---

## 5. Attendance
File: [`lib/api/attendance_api.dart`](../lib/api/attendance_api.dart)

### 5.1 GET `/attendance/today`
Returns `{attendance: {…}, checked_in: bool, checked_out: bool, server_time}`.

### 5.2 GET `/attendance/open`
Returns the current open shift row or `null`.

### 5.3 GET `/attendance`
```
?date_from=2026-08-01&date_to=2026-08-20&user_id=30&limit=50
```
List rows.

### 5.4 POST `/attendance/check-in`
```json
{
  "camp_anchor_id":   3,
  "location":         "MMU-Gajraula-01",
  "photo_key":        "attendance/…jpg",
  "latitude":         28.595819,
  "longitude":        77.374416,
  "start_km":         1280,
  "notes":            "…",
  "staff_present":    ["driver","doctor","pharmacist","other"],
  "staff_other_name": "Ramesh"
}
```

### 5.5 POST `/attendance/check-out`
```json
{
  "photo_key":  "attendance/…jpg",
  "latitude":   28.595820,
  "longitude":  77.374416,
  "end_km":     1290,
  "collection": 500,
  "notes":      "…",
  "staff_out":  ["driver","doctor"]
}
```

---

## 6. Camps
File: [`lib/api/camps_api.dart`](../lib/api/camps_api.dart)

### 6.1 GET `/camps`
```
?date_from=2026-08-01&date_to=2026-08-31&facility_id=25&limit=50
```

### 6.2 GET `/camps/anchors`
Facility's GPS camp anchors (for check-in snapping).

### 6.3 POST `/camps`
```json
{
  "camp_name":    "Kendriya vidyalaya",
  "camp_type":    "School",
  "camp_date":    "2026-08-19",
  "village_id":   12,
  "village_name": "Burablee",
  "block_name":   "Hasanpur",
  "venue":        "School",
  "attendees":    120,
  "services":     "…",
  "notes":        "…",
  "facility_id":  25,
  "photos":       ["camp_photos/abc.jpg", "camp_photos/def.jpg"]
}
```
Geography: pass `village_id` OR (`village_name` + `block_name`).

---

## 7. Patients
File: [`lib/api/patients_api.dart`](../lib/api/patients_api.dart)

### 7.1 GET `/patients`
```
?q=&facility_id=25&state_id=&district_id=&block_id=&village_id=
&gender=&facility_type=&visited_from=&visited_to=&limit=100&offset=0
```
Returns a plain array OR `{items, total, count, filters}`.

### 7.2 GET `/patients/summary/counts`
Same filters as list. Returns `{patients, male, female, other, visits}`.

### 7.3 GET `/patients/{id}`
Single patient + previous_prescriptions + light appointments list.

### 7.4 GET `/patients/{id}/history`
Full visit history (each visit carries diagnoses / lab_tests / prescription).

### 7.5 DELETE `/patients/{id}`
```json
{ "reason": "duplicate" }
```
Soft-delete; `reason` required by DB CHECK.

### 7.6 POST `/patients/{id}/re-appointment`
```json
{
  "parent_appointment_id": 24,
  "appointment_date":      "2026-08-26",
  "payment_type":          "Free",
  "paid_amount":           0,
  "counsellor_remarks":    "…",
  "counsellor_remarks_hindi": "…"
}
```

### 7.7 Offline: `patient.register` (via `/mobile/sync/push`)
Full first-visit payload (patient + appointment + symptom_ids + diagnoses + attachments):
```json
{
  "patient": {
    "name": "…", "gender": "Male", "age": 24,
    "dob": "2001-05-01", "contact": "9633258740",
    "unique_code": "…", "block_id": 3, "village_id": 12,
    "aadhar": "…", "height_cm": 170, "weight_kg": 65,
    "blood_group": "O+", "category": "General", "pwd": "No",
    "pin": "244235", "address": "…"
  },
  "appointment_date": "2026-08-20",
  "assigned_doctor_id": 31,
  "payment_type": "Free", "paid_amount": 0,
  "pregnant": false, "lmp_date": null, "edd_date": null,
  "taken_prescribed_medicine": false,
  "counsellor_remarks":        "…English translation…",
  "counsellor_remarks_hindi":  "…Hindi original…",
  "systolic_bp": 120, "diastolic_bp": 80, "blood_sugar": 110,
  "body_temp": 98.6, "oxygen": 98, "heart_rate": 78, "hemoglobin": 13,
  "height": 170, "weight": 65,
  "symptom_ids": [64, 65],
  "diagnoses": [
    { "diagnosis_text": "Dengue Fever", "disease_id": 97, "is_primary": true }
  ],
  "attachments": [
    { "file_path": "patient_docs/abc.jpg", "kind": "Prescription", "description": "…" }
  ]
}
```

---

## 8. Appointments (clinical workflow)
File: [`lib/api/appointments_api.dart`](../lib/api/appointments_api.dart)

### 8.1 GET `/appointments`
```
?status=registered,with_doctor&date_from=&date_to=&q=&limit=100
```

### 8.2 GET `/appointments/{id}`
Full detail (symptoms + diagnoses + lab_tests + prescription).

### 8.3 GET `/appointments/queues/summary`
Org-wide status counters (dashboard).

### 8.4 GET `/appointments/queues/payment?facility_id={id}`
Cases sitting at counsellor's desk for test-payment collection.

### 8.5 GET `/appointments/{id}/unpaid-tests`
Bill lines for "Collect Test Payment" dialog.

### 8.6 POST `/appointments`
Online-only fresh appointment for an existing patient.
```json
{
  "patient_id": 42, "facility_id": 25,
  "appointment_date": "2026-08-20",
  "pregnant": false, "lmp_date": null, "edd_date": null,
  "taken_prescribed_medicine": false,
  "counsellor_remarks": "…",
  "height": 170, "weight": 65,
  "systolic_bp": 120, "diastolic_bp": 80, "blood_sugar": 110,
  "body_temp": 98.6, "oxygen": 98, "hemoglobin": 13,
  "payment_type": "Free", "paid_amount": 0,
  "symptom_ids": [64, 65]
}
```

### 8.7 PATCH `/appointments/{id}/doctor`
Doctor submit.
```json
{
  "observation":            "…",
  "doctor_remarks":         "…",
  "follow_up_date":         "2026-08-27",
  "diagnoses": [
    { "diagnosis_text": "Dengue Fever", "disease_id": 97, "is_primary": true, "icd11_code": "1D2Y" }
  ],
  "lab_test_ids": [3, 7],
  "prescription": [
    { "medicine_id": 12, "medicine_name": "Paracetamol 500mg",
      "dosage": "1-0-1", "duration_days": "5", "frequency": "TDS",
      "qty_prescribed": 15 }
  ],
  "referred": false, "referral_destination_id": null,
  "counselled": true, "counselling_topic_id": 4
}
```

### 8.8 PATCH `/appointments/{id}/dispense`
Pharmacist dispenses.
```json
{
  "lines": [
    { "prescription_item_id": 8, "dispensed_qty": 15, "qty_change_reason": "" }
  ]
}
```

### 8.9 PATCH `/appointments/{id}/collect-test-payment`
No body. Server marks payment received → status flips to `with_lab`.

### 8.10 PATCH `/appointments/{id}/collect-consultation-fee`
No body. Stamps reg-time fee collection.

### 8.11 PATCH `/appointments/{id}/lab-sample`
```json
{
  "lines": [
    { "lab_test_order_id": 55, "sample_date": "2026-08-20", "handover_date": "2026-08-21" }
  ]
}
```

### 8.12 PATCH `/appointments/{id}/lab-report`
```json
{
  "lines": [
    { "lab_test_order_id": 55, "result_value": "…",
      "report_file_path": "lab_reports/abc.jpg", "reported_at": "2026-08-21T14:00:00Z" }
  ]
}
```
When every test has a report, status flips → `with_doctor`.

---

## 9. Queues (KPI tiles + drilldowns)
File: [`lib/api/queues_api.dart`](../lib/api/queues_api.dart)

### 9.1 GET `/queues/summary/tiles?facility_id=25`
One call fills every Home KPI tile.

All drilldown lists accept: `?facility_id=&updated_since=<iso>&limit=`.

### 9.2 GET `/queues/doctor`
### 9.3 GET `/queues/doctor/attended`
### 9.4 GET `/queues/doctor/past-7-days`
### 9.5 GET `/queues/lab`
### 9.6 GET `/queues/pharmacist`
### 9.7 GET `/queues/pharmacist/past-7-days`
### 9.8 GET `/queues/counsellor/past-7-days`
### 9.9 GET `/queues/counsellor/pending-payment`

All return `{items, total, count}`. `total` matches the tile; `count` is
what the current `limit` returned.

---

## 10. Devices (daily status)
File: [`lib/api/devices_api.dart`](../lib/api/devices_api.dart)

### 10.1 GET `/devices/status`
```
?date=2026-08-20&facility_id=25
```
Returns one row per device: `{device_id, device_name, status, reported_by, status_date}`.

### 10.2 POST `/devices/status`
```json
{
  "status_date": "2026-08-20",
  "facility_id": 25,
  "lines": [
    { "device_id": 1, "status": "Working" },
    { "device_id": 2, "status": "Not Working" },
    { "device_id": 3, "status": "Not Applicable" }
  ]
}
```

### 10.3 GET `/devices/history`
```
?date_from=&date_to=&device_id=&facility_id=&limit=
```

---

## 11. Requisitions (pharmacy stock)
File: [`lib/api/requisitions_api.dart`](../lib/api/requisitions_api.dart)

### 11.1 GET `/requisitions`
```
?status=pending&facility_id=&date_from=&date_to=&limit=
```

### 11.2 GET `/requisitions/summary/counts?facility_id=25`
Returns tile numbers `{pending, approved, partial, rejected, received}`.

### 11.3 GET `/requisitions/{id}`
Full detail + line items + audit trail.

### 11.4 POST `/requisitions`
Pharmacist raises a new indent.
```json
{
  "facility_id": 25,
  "remarks":     "monthly stock",
  "lines": [
    { "medicine_id": 12, "medicine_name": "Paracetamol 500mg",
      "dosage": "500 mg", "requested_qty": 100 }
  ]
}
```

### 11.5 PATCH `/requisitions/{id}/review`
CMO / Zonal Incharge decision.
```json
{
  "remarks": "approved partial",
  "decisions": [
    { "requisition_line_id": 55, "approved_qty": 80, "review_note": "" }
  ],
  "added_lines": [
    { "medicine_id": 33, "medicine_name": "ORS", "dosage": "packet", "approved_qty": 20 }
  ]
}
```

### 11.6 PATCH `/requisitions/{id}/receive`
Pharmacist confirms delivery.
```json
{
  "invoice_path": "invoices/inv-8734.jpg",
  "receipts": [
    { "requisition_line_id": 55, "received_qty": 80 }
  ]
}
```

---

## 12. Staff (roster)
File: [`lib/api/staff_api.dart`](../lib/api/staff_api.dart)

### 12.1 GET `/staff`
```
?role=doctor&facility_id=25&is_active=true&with_login=true&limit=
```
Counsellor Register calls this to fill the "Assigned Doctor" dropdown from
the real backend roster. `with_login=true` collapses duplicate seed rows
to only staff that have an active sign-in.

---

## Error envelope

Non-2xx responses follow this shape and are surfaced as `ApiException`:
```json
{
  "error": {
    "code":    "TOKEN_EXPIRED",
    "message": "Access token expired",
    "details": { … optional context … }
  }
}
```

Codes the client understands: `TOKEN_EXPIRED`, `SIGNED_OUT_REMOTELY`,
`INVALID_TOKEN`, `REFRESH_EXPIRED`, `NETWORK_UNREACHABLE`.

---

## Notes

- Every mutation the shipped screens make is enqueued into `SyncService`
  first (kind: `patient.register`, `appointment.check_in`, `camp.create`, …)
  and drained through `/mobile/sync/push`. `client_action_id` makes replays
  safe (server returns the original with `duplicate: true`).
- Non-mobile endpoints exist on the same backend (admin portal). Only the
  ones listed here are called by the Flutter client.
- Regenerate this file when new endpoints are added — the source of truth
  is `lib/api/*.dart` (public methods that call `client.get/post/patch/delete`).
