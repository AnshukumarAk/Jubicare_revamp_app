# JubiCare MMU — Project Handoff / Memory

> Self-contained context to resume work on another machine. Last updated after **CR29 / v0.13.0**.

## What this is
JubiCare is a **Mobile Medical Unit (MMU)** healthcare app for the **Jubilant Bhartia Foundation** (implemented by Indev Consultancy). This repo is a **Flutter prototype** of the MMU mobile app, built iteratively through change-request docs (CR22 → CR29).

Patient flow across three role logins (shared in-memory store):
**Counsellor** (register patient) → **Doctor** (diagnose + prescribe) → **Pharmacist** (dispense).
Status machine: `registered → with_doctor → with_pharma → completed` (plus `denied`).

## Project location & build
- App root: `/Users/keder/Myproject/jubicare/jubicare_mmu`
- Flutter 3.44.x / Dart 3.12.x. State via `provider` (ChangeNotifier).
- Current version: **0.13.0+15** (in `pubspec.yaml`).
- Build: `flutter build apk --release` → copy `build/app/outputs/flutter-apk/app-release.apk` to `JubiCare-MMU-prototype-vX.Y.Z.apk`. Release build ≈ 1 min warm, up to ~15 min cold.
- Release signing needs `JAVA_HOME=/Users/keder/jdk-17.0.12.jdk/Contents/Home` for keytool/apksigner. Keystore + Gradle signing already wired.
- Plugins: `provider`, `image_picker`, `speech_to_text`, `pdf`, `printing`. Inter font bundled at `assets/fonts/Inter.ttf`.
- Assets: `assets/jubicare_logo.png` (official logo), `assets/diseases.json` (111 ICD-11 diseases).

## HARD CONSTRAINTS (do not violate)
- **Do NOT change the login page layout or the logo.** Official logo = `assets/jubicare_logo.png` (from `https://jubicare.indevconsultancy.com/public/assets/images/jubi/logo.png`). CR29 changed login *auth logic + caption only*; visual design + logo stay as-is.
- After each CR: run `flutter analyze` (target 0 errors), then build only when the user says "Build".

## Login credentials (CR29)
Splash screen (1 s, logo + "JubiCare") → role landing → per-role login validating fixed creds:
| Role | Display name | Username | Password |
|---|---|---|---|
| Counsellor | Sanjeev Mahto | `con_test` | `con@123` |
| Doctor | Dr. Aakanksha Dua | `doc_test` | `doc@123` |
| Pharmacist | Kedar Dash | `pha_test` | `pha@123` |

## Code map (lib/)
- `main.dart` — MultiProvider (AppState + CounsellorState); home = `SplashScreen`; DEMO dart-define routes.
- `screens/splash.dart` — 1 s splash → LoginLanding (CR29).
- `screens/login_landing.dart` — role landing (logo + 3 role cards). **Don't restyle.**
- `screens/role_login.dart` — per-role username/password; validates `AppState.login`; routes to role shell with `role.fullName`.
- `models/models.dart` — `Role` enum + `fullName`/`credUser`/`credPass`/label/subtitle/icon.
- `state/app_state.dart` — `login()` validates fixed creds.
- `theme/app_theme.dart` — first-build `JC` palette (used by login/splash).
- **Counsellor** `counsellor/`:
  - `cw.dart` — JubiCare 2.0 UI kit + `C2` palette. `CCard, SecBar(title,trailing), GradGreeting, StatTile, CBadge, CField(label,child,required), cInput([hint]), CPrimaryButton, COutlineButton, ct(size,weight,color), DateField(hint,initial,first,last,onPicked), TimeField(hint,onPicked), fmtDate(DateTime), fmtTime12(TimeOfDay)`. DateField picker now uses `DateTime.now()` (real-time calendars, CR29).
  - `cstate.dart` — **shared store `CounsellorState`** + models. `CPatient` (fields incl. `regDate`, `uploadedRx`, `prescription`, `previousRx`, `disease`, `doctorRemarks`, `remarks`...). `RxItem`, `PrevRx`, `Camp`, `AttendanceRecord`(date,checkIn,checkOut,location,status,photo,collection,startKm,endKm,totalRun,notes), `ReqLine`(mutable received/status), `Requisition`(mutable status). Helpers: `splitMedicine(name)→(name,dosage)`. Getters: doctorQueue/doctorAttended/doctorCompleted/pharmaQueue/dispensedPatients/registeredToday/visitsCompleted/lastEndingKm. Methods: addPatient, doctorSubmit, pharmacistDispense, addRequisition, markLineReceived, updateRequisitions, denyDelivery, add*Attendance.
  - `cdata.dart` — masters (villages, symptoms, geo/disease scoring, states/districts/blocks, doctors, devices, etc.).
  - `shell.dart` — CounsellorShell: white header (logo + profile), 7-tab bottom nav: Home / **Status** / Register / Camps / Devices / Reports / Attend.
  - `screens_dashboard.dart` — CounDashboard (Registered Patients capped at 5), `CounPatientDetail` (**shared by doctor & pharma**; shows Registration, Vitals, **Patient Remarks** [renamed CR29], **Prescribed Medicines**, **Doctor Remarks**), `CounPatientsList`, `CounAppointmentStatus` (online/offline search), `apptStatus()`.
  - `screens_register.dart` — Fill Appointment: placeholders (EDD/LMP, State, District, DOB, Appointment Date, Doctor); collapsible Advanced/Vitals toggles; Symptoms its own section (free-text via SymptomField); validations (BP/sugar/HR 3 digits, Temp `_DecimalFormatter(3)`, O2 2, **Hb `_DecimalFormatter(2)`**, Height/Weight 3); Patient Remarks STT mic; Previous Prescription only when "currently on meds" (mandatory upload, stores `shot.path`). Saves `regDate` from Appointment Date.
  - `screens_misc.dart` — `CounAttendance` (Date=today, Location placeholder, Total Collection 5-digit, MMU start [from last end, non-editable]/end/total-run auto, photo, **Notes + mic**, 12h times), `CounCamps` (date placeholder), `CounDevices`, `CounReports` (From/To placeholders + revert after generate + **no future dates** + both required; **PDF landscape, no-wrap IntrinsicColumnWidth**; Patient PDF: Date col, Pending/Completed, separate Diagnosis & Symptoms; Device PDF: landscape per-day legend W/NW/NA/PR), `CounProfile`.
  - `symptom_field.dart` — chips + suggestions + free-text add (onSubmitted / "Add typed").
- **Doctor** `doctor/`:
  - `dshell.dart` — DoctorShell (Home/Case/Report/Attend), `DocHeader`/`DocBottomNav` (shared), DoctorDashboard (In Queue/Completed tiles → `DoctorPatientList` searchable; lists capped at 5), `DoctorPatientList`, DoctorCaseList, `DoctorAttendance` (today date, location placeholder, 12h, **Notes + mic**), `DoctorReport` (placeholders, no future dates, both required, **PDF landscape no-wrap**, Date col, "with pharmacist" label), `SimpleProfile`, `showAttendedCase`.
  - `dcase.dart` — DoctorCaseDetails: registration, Observation (VoiceTranscriptBox), Past History, **Previous Prescriptions (counsellor-uploaded tappable image view + previous MMU meds)**, Symptoms (free-text + dismiss-on-outside-tap), **Diagnosis (multi-select chips + free-text via `_DiseasePickerSheet`)**, Tests (free-text `_PickerSheet`), Prescription (name + Dosage, auto qty), Doctor Remarks (mic). AI advisory **Apply** uses `splitMedicine` so name→name field, strength→Dosage. Pickers call `FocusScope.unfocus()` to fix focus jumping to Symptoms.
  - `ddata.dart` — kDoctorDb (DPlan: symptoms/tests/rx/redFlags/firstLine), kLabTests, kMedicines, kMedicineNames, kFrequencies, kDurations, scoreDoctor.
  - `disease_master.dart` — `Disease` + `DiseaseMaster.load/search/resolve`. **`resolve()` fixed (CR28 follow-up):** ignores blank synonyms + word-safe matching → returns null instead of false-positive (was placing "Rheumatoid Arthritis" for "Viral Fever").
  - `voice.dart` — `VoiceTranscriptBox`, `VoiceMicButton` (speech_to_text).
- **Pharmacist** `pharmacist/pshell.dart` — PharmacistShell 4-tab: Home / Stock / Report / Attend (**Dispense tab removed CR27**). PharmaDashboard (In Queue tile → `PharmaQueueList` searchable → `CounPatientDetail`; Dispensed tile → `PharmaDispensedList` search + tap shows dispensed meds; Pending Prescriptions → `PharmaDispense` with **mandatory reason on qty change**). PharmaStock: tabs Requisition (blank med, name-only dropdown, **Dosage mandatory**, qty) / Past (indents, real-time date; detail = editable Received + **green checkbox ACTION**; all checked → "Delivered") / **Overall Status** (live aggregate Requested/Dispatched/Received). PharmaReport (placeholders, no future, both required; **PDF landscape no-wrap**: Date, Patient, **Diagnosis**, Medicine, **Dosage non-nil** [derived via splitMedicine], Frequency, Qty). PharmaAttendance (today, location placeholder, 12h, **Notes + mic**).

## Change-request history (all done)
- CR22 Counsellor, CR23 Doctor, CR24 Pharmacist, CR25 + CR25(1) Counsellor, CR26 Doctor, CR27 Pharmacist, CR28 (all roles + bug), CR29 (splash/creds/PDF/calendars/Patient-Remarks/stock). Plus the Viral-Fever `resolve()` bug fix.
- APK versions: v0.9.0 (CR24), v0.10.0 (CR25), v0.11.0 (CR26+27), v0.12.0 (CR28 + resolve fix), **v0.13.0 (CR29 — current)**.

## Known minor items
- Report PDFs use plain hyphen in titles ("JubiCare - X Report") to avoid an em-dash tofu glyph in the default PDF font.
- `_Req` helper in pshell has 3 harmless "unused optional param" lint warnings (pre-existing).
- Device report shows current device condition repeated per day (no per-day history stored — prototype).

## Emulator notes (verification)
- AVD name: `jubicare`. Launch: `$ANDROID_HOME/emulator/emulator -avd jubicare -gpu host -no-snapshot-load -partition-size 4096` (hardware GPU avoids dropped-input issues).
- adb: `$HOME/Library/Android/sdk/platform-tools/adb`. Package: `com.jubicare.jubicare_mmu`, activity `.MainActivity`.
- Screenshot helper: `adb shell screencap -p /sdcard/s.png && adb pull ...` then `sips -Z 600`. Tap coords = screenshot×4 (device is 1080×2400, screenshot scaled to 270×600). Use `uiautomator dump` for exact bounds; Flutter text appears in `content-desc`, not `text`.

## To resume on the new machine
1. `cd jubicare_mmu && flutter pub get`
2. `flutter analyze` (expect 0 errors)
3. New CR doc → read with `pandoc CRxx.docx -o out.md`; implement per the code map above; analyze; build on request; bump version.
