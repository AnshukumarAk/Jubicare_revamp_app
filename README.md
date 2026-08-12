# JubiCare MMU — Mobile Prototype (Flutter)

Prototype of the **Mobile Medical Unit** app for the JubiCare upgrade, showcasing the three
"wish-list" improvements on top of the proven Counselor -> Doctor -> Pharmacist workflow:

1. **Modernized UI/UX** — brand identity derived from the JubiCare logo (navy/sky-blue + teal/yellow accents), rounded white cards, clearer forms and status.
2. **Voice capture** (simulated) — on the Doctor's Case Details screen: tap the mic -> realistic dictation transcript -> auto-fills Symptoms, Observations and Vitals.
3. **AI clinical decision-support** (simulated) — context-aware suggestions (patient history + pre-existing conditions + location/season + symptoms) for medicines and diagnostic tests. Decision-support only; the doctor decides.

Voice + AI are **gated on connectivity** — toggle the Online/Offline pill. Offline, both are disabled and the app keeps working in standard mode. Data is mock; offline-first is represented visually (per-record "synced" flags, pending-sync banner). No backend / SQLite yet.

## Run

    flutter pub get
    flutter run                 # pick a device (iOS Simulator, Android emulator, Chrome)

Deep-link a specific screen for demos:

    flutter run --dart-define=DEMO=doctor_case   # also: counselor_home | register | doctor_home | pharmacist_case

## Structure
- lib/theme/   — design system (JubiCare palette + Material theme)
- lib/models/  — Patient, Vitals, Prescription, AI result models
- lib/state/   — in-memory repository, mock data, simulated voice + AI logic
- lib/widgets/ — shared UI (gradient scaffold, cards, tiles, vector logo)
- lib/screens/{counselor,doctor,pharmacist}/ — role flows

Captured screens are in ../prototype_screens/.
