import 'package:flutter/foundation.dart';
import 'cdata.dart';

/// Splits a medicine label like "Paracetamol 500mg" into (name, dosage).
/// "ORS Sachets" → ("ORS Sachets", ""). "T.Amlodipine 5mg" → ("T.Amlodipine", "5mg").
(String, String) splitMedicine(String s) {
  final t = s.trim();
  final m = RegExp(r'^(.*?)\s+(\d+\s*(?:mg|ml|mcg|g|iu)?)$', caseSensitive: false).firstMatch(t);
  if (m == null) return (t, '');
  final name = m.group(1)!.trim();
  var dose = m.group(2)!.trim();
  if (RegExp(r'^\d+$').hasMatch(dose)) dose = '$dose mg';
  return (name.isEmpty ? t : name, dose);
}

/// A prescribed medicine line.
class RxItem {
  /// Server's prescription_item_id. The dispense endpoint identifies each
  /// line by this — a medicine name won't do, since the same drug can be
  /// prescribed twice on one visit at different strengths. Null for locally
  /// created rows that haven't round-tripped through the backend yet.
  final int? itemId;
  final String name;
  String dosage; // strength e.g. "500 mg" — typed by the doctor
  String days;
  String interval; // OD/BD/TDS/QID/SOS
  int qty;
  int dispensedQty;
  bool dispensed;
  /// Reason the pharmacist wrote when dispensed qty ≠ prescribed qty.
  /// Server column: prescription_items.dispense_reason, payload key:
  /// qty_change_reason (user 2026-09-08: surface it on the Dispensed
  /// Patients detail sheet).
  String dispenseReason;
  /// Dosage form the doctor picked (Tab / Cap / Syp) — kept alongside
  /// the strength text (user 2026-09-08). Combined into the server's
  /// `dosage` field as "<form> · <strength>" so no PrescriptionItem
  /// schema change is needed; parsed back apart when loading (see
  /// RxItem.parseDosage in dcase.dart / pharmacist pshell.dart).
  String dosageForm;
  /// Zero, one, or many combination medicines paired with this row —
  /// Paracetamol + Vitamin A + Vitamin B style (user 2026-09-15
  /// "keep multiple combined medicine option"). Every partner shares
  /// the primary's frequency / duration / qty / dosage form; each
  /// carries its own strength text. Empty list = standalone row.
  List<ComboMed> combos;
  /// Shared id across two RxItems the doctor wrote as one combination
  /// strip (Paracetamol + Vitamin C). The pharmacist Deliver Medicine
  /// screen groups lines with the same key into a single card (user
  /// 2026-09-12). Empty for standalone lines.
  String comboKey;
  // No default duration (user rule 2026-08-16): the doctor must enter
  // the day count explicitly — pre-filling "5 Days" left rows silently
  // wrong and read as a required-field error.
  RxItem({required this.name, this.itemId, this.dosage = '', this.days = '', this.interval = 'TDS', this.qty = 0, int? dispensedQty, this.dispensed = false, this.dispenseReason = '', this.dosageForm = '', List<ComboMed>? combos, this.comboKey = ''})
      : dispensedQty = dispensedQty ?? qty,
        combos = combos ?? <ComboMed>[];
}

/// One combination partner attached to a primary [RxItem]. Its
/// frequency / duration / qty / dosage form all come from the primary
/// (single strip). Only the strength text is per-partner.
class ComboMed {
  String name;
  String dosage;
  ComboMed({required this.name, this.dosage = ''});
}

/// A historical prescription line (for the Previous Prescriptions section).
class PrevRx {
  final String medicine, dosage, frequency, duration, date;
  const PrevRx({required this.medicine, this.dosage = '', this.frequency = '', this.duration = '', required this.date});
}

/// A single file attached during counsellor registration — a prescription, a
/// lab report, or any other supporting document. Multiple attachments per
/// patient. Doctor sees them under "Prescription and Reports" in Case Details.
enum AttachmentKind { prescription, report, other }

extension AttachmentKindX on AttachmentKind {
  String get label => switch (this) {
        AttachmentKind.prescription => 'Prescription',
        AttachmentKind.report => 'Report',
        AttachmentKind.other => 'Other',
      };
  static AttachmentKind fromLabel(String s) => switch (s) {
        'Prescription' => AttachmentKind.prescription,
        'Report' => AttachmentKind.report,
        _ => AttachmentKind.other,
      };
}

class Attachment {
  final String path;         // local filesystem path (from ImagePicker)
  final AttachmentKind kind; // Prescription / Report / Other
  final String description;  // free-text description entered by counsellor
  /// Server-side name returned by POST /api/mobile/uploads
  /// ("patient_docs/<random>.jpg"). Null until the upload lands — the sync
  /// payload falls back to [path] so an offline registration still records
  /// that a photo existed, even if only the capturing phone can open it.
  final String? serverPath;
  const Attachment({
    required this.path,
    required this.kind,
    this.description = '',
    this.serverPath,
  });

  Attachment copyWith({AttachmentKind? kind, String? description, String? serverPath}) =>
      Attachment(
        path: path,
        kind: kind ?? this.kind,
        description: description ?? this.description,
        serverPath: serverPath ?? this.serverPath,
      );
}

class CPatient {
  final String id;
  String name;
  String gender;
  int age;
  String contact;
  String uniqueCode;
  String block;
  String village;
  String dob; // date of birth (display), if captured via calendar
  List<String> symptoms;
  String disease; // diagnosis (set by doctor); pre-fill = likely condition
  String observations;
  String doctorRemarks;
  String registeredOn;
  String regDate; // actual registration/appointment date (e.g. 19-Jun-2026)
  // Flow: registered -> with_doctor -> with_pharma -> completed
  String status;
  Map<String, String> vitals;
  bool pregnant;
  // Pregnancy dates from the server row (ISO yyyy-mm-dd, '' = none) — the
  // Re-Appointment prefill re-selects LMP/EDD from these (user 2026-08-21
  // "lmp or edd date is not showing selected").
  String lmpDate;
  String eddDate;
  String remarks; // counsellor remarks (English-first for DISPLAY)
  /// The remarks exactly as dictated (Hindi when spoken Hindi) — INPUT
  /// fields prefill from this, never from the English display copy
  /// (user 2026-08-22 "dont show english version in inputs").
  String remarksOriginal;
  String pastHistory; // chronic illness / surgeries / ongoing treatment
  String uploadedRx; // prescription file/image uploaded by counsellor (filename)
  List<Attachment> attachments; // multi-attachment (Prescription/Report/Other)
  List<RxItem> prescription;
  List<String> tests;
  List<PrevRx> previousRx;
  // Advance Details captured on the counsellor Register form (rule
  // 2026-07-31). Persisted so re-appointment can populate them without
  // asking the counsellor to retype.
  String aadhar;
  String heightCm;   // renamed to avoid clashing with widget helpers
  String weightKg;
  String? bloodGroup;
  String? category;
  String pwd;         // 'Yes' / 'No'
  String pin;
  String address;
  /// Backend appointment_id for the latest visit — populated by
  /// `mergeBackendPatients` from the queues list row. Detail screens
  /// use this to lazy-fetch full appointment data (symptoms,
  /// diagnoses, vitals) that the list endpoint doesn't return.
  int? backendAppointmentId;
  /// Backend patient_id — used by the Re-Appointment submit to tell
  /// `/mobile/sync/push` "attach a new appointment to THIS patient,
  /// don't insert a duplicate patient row" (user rule 2026-08-16).
  int? backendPatientId;
  /// medicine_count from the queue row. The queue payload carries no
  /// prescription lines, only their count, so lists can show "3 meds"
  /// without a per-patient fetch. `prescription` stays authoritative once
  /// the detail screen has loaded it.
  int medicineCount;
  /// Doctor the last visit was assigned to (staff_name) — filled by the
  /// detail hydrate; Re-Appointment prefill re-selects them.
  String? assignedDoctor;

  CPatient({
    required this.id,
    required this.name,
    required this.gender,
    required this.age,
    required this.contact,
    this.uniqueCode = '',
    this.block = '',
    this.village = '',
    this.dob = '',
    List<String>? symptoms,
    this.disease = '',
    this.observations = '',
    this.doctorRemarks = '',
    this.registeredOn = 'Today',
    this.regDate = '',
    this.status = 'registered',
    Map<String, String>? vitals,
    this.pregnant = false,
    this.lmpDate = '',
    this.eddDate = '',
    this.remarks = '',
    this.remarksOriginal = '',
    this.pastHistory = '',
    this.uploadedRx = '',
    List<Attachment>? attachments,
    List<RxItem>? prescription,
    List<String>? tests,
    List<PrevRx>? previousRx,
    this.aadhar = '',
    this.heightCm = '',
    this.weightKg = '',
    this.bloodGroup,
    this.category,
    this.pwd = 'No',
    this.pin = '',
    this.address = '',
    this.backendAppointmentId,
    this.backendPatientId,
    this.medicineCount = 0,
  })  : symptoms = symptoms ?? [],
        vitals = vitals ?? {},
        attachments = attachments ?? [],
        prescription = prescription ?? [],
        tests = tests ?? [],
        previousRx = previousRx ?? [];

  String get initials => name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
}

class Camp {
  final String village, type, name, venue, date;
  const Camp({required this.village, required this.type, required this.name, required this.venue, required this.date});
}

/// A single device-status change. Stored per device in CounsellorState's
/// `deviceStatusHistory` map, sorted by date ascending. `date` is ISO format
/// (yyyy-mm-dd) so string comparison gives chronological order.
class DeviceStatusRecord {
  final String date;
  final String status;
  const DeviceStatusRecord(this.date, this.status);
}

class AttendanceRecord {
  final String date, checkIn, checkOut, location, status;
  final bool photo;
  // Counsellor attendance extras (CR25)
  final String collection, startKm, endKm, totalRun, notes;
  // Attendance geo-stamp + selfie proof (2026-07-04). photoPath is the local
  // filesystem path of the captured image; lat/lng are the GPS reading at the
  // moment the counsellor / doctor submitted the record. The *Out variants
  // (2026-07-29) are the check-out counterparts — same shape, filled when the
  // evening shift closes.
  final String photoPath;
  final double? lat;
  final double? lng;
  final String photoPathOut;
  final double? latOut;
  final double? lngOut;
  // Staff attendance the counsellor marks for the MMU crew (2026-07-29).
  // *In flags = present at morning check-in; *Out flags = present at evening
  // check-out. Defaults false so historical records remain intact.
  final bool driverIn, doctorIn, pharmacistIn;
  final bool driverOut, doctorOut, pharmacistOut;
  const AttendanceRecord({required this.date, required this.checkIn, required this.checkOut, required this.location,
      this.status = 'Present', this.photo = false,
      this.collection = '', this.startKm = '', this.endKm = '', this.totalRun = '', this.notes = '',
      this.photoPath = '', this.lat, this.lng,
      this.photoPathOut = '', this.latOut, this.lngOut,
      this.driverIn = false, this.doctorIn = false, this.pharmacistIn = false,
      this.driverOut = false, this.doctorOut = false, this.pharmacistOut = false});

  /// True while the record represents an in-flight shift: check-in was
  /// captured this morning but check-out isn't in yet.
  bool get isOpen => checkOut.trim().isEmpty;

  /// Return a new record with the given fields overridden. Used at check-out
  /// time to close an open shift without mutating the immutable record.
  AttendanceRecord copyWith({
    String? checkOut, String? endKm, String? collection, String? totalRun, String? notes,
    String? photoPathOut, double? latOut, double? lngOut,
    bool? driverOut, bool? doctorOut, bool? pharmacistOut,
  }) => AttendanceRecord(
        date: date, checkIn: checkIn,
        checkOut: checkOut ?? this.checkOut,
        location: location, status: status, photo: photo,
        collection: collection ?? this.collection,
        startKm: startKm,
        endKm: endKm ?? this.endKm,
        totalRun: totalRun ?? this.totalRun,
        notes: notes ?? this.notes,
        photoPath: photoPath, lat: lat, lng: lng,
        photoPathOut: photoPathOut ?? this.photoPathOut,
        latOut: latOut ?? this.latOut,
        lngOut: lngOut ?? this.lngOut,
        driverIn: driverIn, doctorIn: doctorIn, pharmacistIn: pharmacistIn,
        driverOut: driverOut ?? this.driverOut,
        doctorOut: doctorOut ?? this.doctorOut,
        pharmacistOut: pharmacistOut ?? this.pharmacistOut,
      );
}

/// A single line in a stock requisition. All non-final fields are mutable so
/// the Zonal Incharge can approve/reject/modify (via the future dashboard) and the
/// pharmacist can record what actually arrived (2026-07-29 stock rework).
class ReqLine {
  final String name;
  String dosage;
  String unit; // Strip / Tab / Vial / Bottle / Sachet / ml
  int requested;       // pharma's original ask (0 if isZonalAdded)
  int dispatched;      // legacy, kept for existing views
  int received;        // final verified quantity (pharma fills in)
  // Zonal Incharge decision on this line. `approvedQty` uses -1 = no decision yet,
  // 0 = rejected, >0 = approved (may differ from requested for partials).
  int approvedQty;
  String zonalRemark;
  // Set when Zonal Incharge adds a medicine that pharma didn't originally request.
  bool isZonalAdded;
  String status; // 'Pending' | 'Approved' | 'Rejected' | 'Received' | 'Partial'
  /// Server row id from GET /requisitions/{id} lines — what
  /// PATCH /requisitions/{id}/receive addresses its receipts to.
  final int? backendLineId;
  /// Lines the pharmacist ordered as ONE combination strip share this
  /// key, the same way [RxItem.comboKey] groups a doctor's combination
  /// prescription. Empty for standalone lines (user 2026-09-22).
  final String comboKey;
  ReqLine({
    required this.name, this.dosage = '', this.unit = 'Strip',
    required this.requested,
    this.dispatched = 0, this.received = 0,
    this.approvedQty = -1, this.zonalRemark = '',
    this.isZonalAdded = false,
    this.status = 'Pending',
    this.backendLineId,
    this.comboKey = '',
  });
}

/// A timestamped entry in a requisition's audit trail. Written on every
/// meaningful state change so the ledger tells the whole story.
class AuditEntry {
  final DateTime when;
  final String actor;   // 'Pharmacist' / 'Zonal Incharge' / 'System'
  final String action;  // short verb-phrase
  final String note;    // optional detail
  const AuditEntry({required this.when, required this.actor, required this.action, this.note = ''});
}

/// A stock indent raised by the pharmacist. Status flow:
///   pending_zi → approved (partial or full) → verified
/// or pending_zi → rejected (terminal).
class Requisition {
  final String id;      // Display id — either REQ-YYYYMMDD-NNN (legacy) or REQ-<serverId>
  final String date;    // display date (dd-MM-yyyy)
  String status;
  String zonalRemark;     // overall Zonal Incharge note (per-line notes live on ReqLine)
  String invoicePath;   // local path to invoice PDF/image (verification)
  final List<ReqLine> items; // both pharma-requested + Zonal Incharge-added rows
  final List<AuditEntry> audit;
  /// Server row id, present iff the row came from GET /requisitions.
  /// Used by lazy detail fetch, review, receive endpoints.
  final int? backendId;
  /// Line summary from the list endpoint — shown as "N medicines · X qty"
  /// until full lines are loaded via detail fetch.
  final int? backendLineCount;
  final int? backendRequestedTotal;
  Requisition({
    required this.id, required this.date, required this.status,
    required this.items,
    this.zonalRemark = '', this.invoicePath = '',
    List<AuditEntry>? audit,
    this.backendId,
    this.backendLineCount,
    this.backendRequestedTotal,
  }) : audit = audit ?? [];

  // Convenience filters so the UI can render the four required sections
  // ("Requested / Approved / Zonal Incharge Added / Received") without duplicating rows.
  List<ReqLine> get requestedItems  => items.where((i) => !i.isZonalAdded).toList();
  List<ReqLine> get zonalAddedItems   => items.where((i) => i.isZonalAdded).toList();
  List<ReqLine> get approvedItems   => items.where((i) => i.approvedQty > 0).toList();
  List<ReqLine> get receivedItems   => items.where((i) => i.received > 0).toList();
}

class DeniedDelivery {
  final CPatient patient;
  final String reason, date;
  const DeniedDelivery({required this.patient, required this.reason, required this.date});
}

/// Shared MMU patient store + counsellor data. Provided at app root so the
/// Counsellor → Doctor → Pharmacist flow shares one set of patients.
class CounsellorState extends ChangeNotifier {
  /// Compile-time toggle for the demo seed. Off by default so real installs
  /// start blank and only render backend data. Turn on for screenshots or
  /// offline demos with `flutter run --dart-define=DEMO_SEED=true`.
  static const bool _useDemoSeed =
      bool.fromEnvironment('DEMO_SEED', defaultValue: false);

  // Patient list. Empty at first launch — populated by:
  //   1. `mergeBackendPatients()` after /api/queues/counsellor/past-7-days
  //      (and /api/queues/doctor, /api/queues/pharmacist) lands.
  //   2. `addPatient()` when the counsellor submits the Register form —
  //      which also enqueues the mutation for /api/mobile/sync/push so a
  //      backend row eventually replaces the local one.
  final List<CPatient> patients =
      _useDemoSeed ? _initialPatientSeed() : <CPatient>[];

  // Backend tile counts (from /api/queues/summary/tiles). Null until the
  // first refresh lands. The dashboard getters fall back to local counts
  // if this is still null, so offline first-open still shows something.
  int? backendRegisteredToday;
  int? backendVisitsCompleted;
  int? backendPast7DaysTotal;
  int? backendDoctorQueue;
  int? backendLabQueue;
  int? backendPharmaQueue;
  int? backendPendingPayment;

  /// True while a backend refresh is in flight; false when idle.
  bool refreshing = false;
  /// Last error surfaced by the backend refresh loop; null on success.
  String? lastRefreshError;
  /// Timestamp of the last successful backend refresh.
  DateTime? lastRefreshAt;

  /// Record the outcome of a backend refresh cycle. Emits a single notify
  /// so any watching widget rebuilds against the fresh flags / counts.
  void setRefreshState({required bool loading, String? error}) {
    refreshing = loading;
    lastRefreshError = error;
    if (!loading && error == null) lastRefreshAt = DateTime.now();
    notifyListeners();
  }

  /// Apply the /queues/summary/tiles response. Any missing key leaves that
  /// count untouched so a partial response can't zero-out a good number.
  void applyTiles(Map<String, dynamic> tiles) {
    int? asInt(dynamic v) => v is num ? v.toInt() : null;
    final t = asInt(tiles['today']);
    final c = asInt(tiles['completed']);
    final p = asInt(tiles['past_7_days']);
    final dq = asInt(tiles['doctor_queue']);
    final lq = asInt(tiles['lab_queue']);
    final pq = asInt(tiles['pharmacist_queue']);
    final pp = asInt(tiles['pending_payment']);
    if (t != null) backendRegisteredToday = t;
    if (c != null) backendVisitsCompleted = c;
    if (p != null) backendPast7DaysTotal = p;
    if (dq != null) backendDoctorQueue = dq;
    if (lq != null) backendLabQueue = lq;
    if (pq != null) backendPharmaQueue = pq;
    if (pp != null) backendPendingPayment = pp;
    notifyListeners();
  }

  // Re-Appointment flow (rule 2026-07-29): when the counsellor picks
  // "Re-Appointment" on a Status row, the source patient is stashed here and
  // the Register form pulls it in a post-frame callback so it can call
  // setState safely, then clears it so subsequent visits to Register start
  // blank again.
  CPatient? _prefillPatient;
  bool get hasPrefill => _prefillPatient != null;
  void setPrefill(CPatient p) { _prefillPatient = p; notifyListeners(); }
  CPatient? consumePrefill() {
    final p = _prefillPatient;
    _prefillPatient = null;
    return p;
  }

  // Abandoned re-appointment cleanup (user bug report 2026-08-13): the
  // counsellor opened Re-Appointment (form prefilled), backed out without
  // submitting, then came to Register for a NEW patient — and found the
  // old patient's data still in the form. The shell raises this flag on
  // every NORMAL entry into the Register tab (bottom nav / "Register New
  // Patient" button, i.e. no fresh prefill pending); the form consumes it
  // and resets itself ONLY if it is still holding re-appointment residue.
  // A half-typed normal registration is never wiped.
  bool _clearAbandonedReAppointment = false;
  void requestAbandonedReAppointmentClear() {
    _clearAbandonedReAppointment = true;
    notifyListeners();
  }
  bool consumeAbandonedReAppointmentClear() {
    final v = _clearAbandonedReAppointment;
    _clearAbandonedReAppointment = false;
    return v;
  }

  /// Full Register form reset flag (user rule 2026-08-16): fired when
  /// the counsellor navigates AWAY from the Register tab in-app (tab
  /// switch OR back button). Consumed on the next Register mount to
  /// blank every field. NOT fired on AppLifecycleState changes — a
  /// quick trip to WhatsApp / minimising the app must preserve
  /// half-typed values.
  bool _clearRegisterOnReturn = false;
  void requestRegisterFullReset() {
    _clearRegisterOnReturn = true;
    notifyListeners();
  }
  bool consumeRegisterFullReset() {
    final v = _clearRegisterOnReturn;
    _clearRegisterOnReturn = false;
    return v;
  }

  // "Re-Appointment" pending-switch flag (2026-07-31). Written when the
  // counsellor taps Re-Appointment from the Patient Detail screen; the shell
  // watches state, consumes the flag on its next build, and jumps to the
  // Register tab so the prefill flows in.
  bool _switchToRegister = false;
  bool get hasSwitchToRegister => _switchToRegister;
  void startReAppointmentFor(CPatient p) {
    setPrefill(p);
    _switchToRegister = true;
    // notifyListeners already called by setPrefill above.
  }
  bool consumeSwitchToRegister() {
    final v = _switchToRegister;
    _switchToRegister = false;
    return v;
  }


  static List<CPatient> _initialPatientSeed() {
    final base = <CPatient>[
      CPatient(id: '1', name: 'Rajwati', gender: 'Female', age: 69, contact: '9696767646', block: 'Gajraula', village: 'Allipur', symptoms: ['Weakness','Joint Pain','Body ache'], registeredOn: 'Today', regDate: _seedRegDate(0),
        pastHistory: 'Hypertension (5 yrs), Type 2 Diabetes; cataract surgery (2021); on Amlodipine.',
        previousRx: [
          PrevRx(medicine: 'T.Amlodipine 5mg', dosage: '5 mg', frequency: 'OD', duration: '30 Days', date: '12-Feb-2026'),
          PrevRx(medicine: 'T.Metformin 500', dosage: '500 mg', frequency: 'BD', duration: '30 Days', date: '12-Feb-2026'),
        ]),
      CPatient(id: '2', name: 'Kumkum', gender: 'Female', age: 17, contact: '7500846464', block: 'Gajraula', village: 'Bhanpur', symptoms: ['Fever','Headache'], registeredOn: 'Today', regDate: _seedRegDate(0), status: 'registered'),
      CPatient(id: '3', name: 'Rasid', gender: 'Male', age: 25, contact: '6797979797', block: 'Gajraula', village: 'Bhikanpur', symptoms: ['Fever','Cough','Runny nose'], disease: 'Viral Fever', registeredOn: 'Today', regDate: _seedRegDate(0), status: 'with_pharma',
        observations: 'Throat congested, chest clear.', doctorRemarks: 'Rest and fluids; review in 3 days.',
        prescription: [RxItem(name: 'T.Paracetamol 500', days: '3 Days', interval: 'TDS', qty: 9), RxItem(name: 'T.Cetirizine 10mg', days: '3 Days', interval: 'OD', qty: 3)],
        tests: ['CBC']),
      CPatient(id: '4', name: 'Achana', gender: 'Female', age: 33, contact: '9797949646', block: 'Gajraula', village: 'Choharpur', symptoms: ['Fever','Burning Micturition'], registeredOn: 'Yesterday', regDate: _seedRegDate(1)),
      CPatient(id: '5', name: 'Sanjay', gender: 'Male', age: 46, contact: '9494949464', block: 'Gajraula', village: 'Salempur', symptoms: ['Headache','Dizziness','Palpitations'], disease: 'Hypertension', registeredOn: 'Today', regDate: _seedRegDate(0), status: 'completed',
        prescription: [RxItem(name: 'T.Amlodipine 5mg', days: '30 Days', interval: 'OD', qty: 30, dispensed: true)]),
    ];
    base.addAll(_generatePast7DaysPatients(100, startId: 1000));
    return base;
  }

  static const List<String> _seedFirstNames = [
    'Anjali','Priya','Sunita','Meera','Kiran','Reena','Pooja','Rekha','Deepa','Nisha',
    'Ravi','Sunil','Arjun','Amit','Vikas','Manoj','Rajesh','Ashok','Sandeep','Deepak',
    'Aarav','Vivaan','Aditya','Kabir','Rohan','Ishaan','Ansh','Krish','Yash','Om',
    'Saanvi','Ananya','Aadhya','Diya','Kavya','Isha','Mira','Aisha','Riya','Sara',
    'Suresh','Ramesh','Mahesh','Dinesh','Nitin','Vinod','Gaurav','Sachin','Prakash','Vijay',
  ];
  static const List<String> _seedSurnames = [
    'Sharma','Verma','Kumar','Singh','Devi','Yadav','Patel','Gupta','Chauhan','Rana',
    'Mishra','Tiwari','Pandey','Dubey','Saxena','Jain','Agarwal','Bhardwaj','Rathore','Malik',
  ];
  static const List<String> _seedVillages = [
    'Allipur','Bhanpur','Bhikanpur','Choharpur','Salempur','Joya','Mubarakpur','Aehrolla',
    'Burablee','Sutablee','Rukhalu','Sohrkaa','Roorkee Town','Laksar','Manglaur','Bhagwanpur',
  ];
  static const List<List<String>> _seedSymptomSets = [
    ['Fever','Headache'],
    ['Cough','Sore throat','Runny nose'],
    ['Body ache','Fatigue','Weakness'],
    ['Fever','Chills','Sweating'],
    ['Abdominal pain','Diarrhoea','Vomiting'],
    ['Burning micturition','Frequent urination'],
    ['Chest pain','Palpitations','Dizziness'],
    ['Joint pain','Rash','Fever'],
    ['Cough','Shortness of breath','Wheezing'],
    ['Weakness','Frequent urination','Weight loss'],
  ];
  static const List<String> _seedDiseases = [
    'Viral Fever','URTI','Gastroenteritis','UTI','Hypertension','Malaria',
    'Typhoid','Chikungunya','Diabetes Type 2','Dengue Fever',
  ];
  // Weighted so ~25 patients each land in queue, with-doctor, with-pharma
  // and completed — spread the leaderboard so all four columns feel alive.
  static const List<String> _seedStatuses = [
    'registered','registered','with_doctor','with_pharma','completed',
    'completed','with_pharma','registered','with_doctor','completed',
  ];

  static List<CPatient> _generatePast7DaysPatients(int count, {required int startId}) {
    return List.generate(count, (i) {
      // Deterministic pseudo-random: derive every field from i so reloads give
      // the same 100 patients (no jitter between hot reloads).
      final first = _seedFirstNames[(i * 3) % _seedFirstNames.length];
      final surname = _seedSurnames[(i * 7) % _seedSurnames.length];
      final village = _seedVillages[(i * 5) % _seedVillages.length];
      final symptoms = _seedSymptomSets[i % _seedSymptomSets.length];
      final status = _seedStatuses[i % _seedStatuses.length];
      // Distribute across the last 7 days (0 = today, 6 = 6 days ago). Skew
      // slightly toward today so the newest slice is visually populated.
      final daysAgo = i % 7;
      final regDate = _seedRegDate(daysAgo);
      final registeredOn = daysAgo == 0 ? 'Today' : (daysAgo == 1 ? 'Yesterday' : '$daysAgo days ago');
      final gender = i % 5 == 0 ? 'Male' : (i % 11 == 0 ? 'Other' : 'Female');
      final age = 12 + ((i * 17) % 68);
      // 10-digit contact starting 6/7/8/9 so the counsellor contact validator
      // is satisfied for the demo data.
      final contactPrefix = 6 + (i % 4);
      final contactTail = (100000000 + (i * 8641)) % 1000000000;
      final contact = '$contactPrefix${contactTail.toString().padLeft(9, '0')}';
      final disease = (status == 'with_pharma' || status == 'completed')
          ? _seedDiseases[i % _seedDiseases.length]
          : '';
      return CPatient(
        id: (startId + i).toString(),
        name: '$first $surname',
        gender: gender,
        age: age,
        contact: contact,
        uniqueCode: 'GN-${(startId + i).toString().padLeft(4, '0')}',
        block: 'Gajraula',
        village: village,
        symptoms: List.of(symptoms),
        disease: disease,
        status: status,
        registeredOn: registeredOn,
        regDate: regDate,
      );
    });
  }

  static const _seedMonths = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  static String _seedRegDate(int daysAgo) {
    final d = DateTime.now().subtract(Duration(days: daysAgo));
    return '${d.day.toString().padLeft(2, '0')}-${_seedMonths[d.month - 1]}-${d.year}';
  }

  int _seq = 100;
  final List<Camp> camps = [];
  // Per-date device status history. Each device has a list of (date, status)
  // records sorted by date ascending. Lookups for any date use
  // getDeviceStatusOn(); the current status is the latest record. Default
  // before any record is 'Working'.
  final Map<String, List<DeviceStatusRecord>> deviceStatusHistory = {};
  static const String defaultDeviceStatus = 'Working';

  /// Computed view: { device: current status }. Kept so screens_misc.dart's
  /// existing references (`s.deviceStatus[d]`, `s.deviceStatus.entries`,
  /// `s.deviceStatus.forEach(...)`) keep working unchanged.
  Map<String, String> get deviceStatus =>
      {for (final d in kDeviceNames) d: getDeviceStatus(d)};

  /// Current status (latest record) for a device.
  String getDeviceStatus(String name) {
    final h = deviceStatusHistory[name];
    return (h == null || h.isEmpty) ? defaultDeviceStatus : h.last.status;
  }

  /// Status that was active on a specific ISO date (yyyy-mm-dd).
  /// Returns the most recent record on or before that date, or
  /// [defaultDeviceStatus] if none.
  String getDeviceStatusOn(String name, String isoDate) {
    final h = deviceStatusHistory[name];
    if (h == null || h.isEmpty) return defaultDeviceStatus;
    String current = defaultDeviceStatus;
    for (final r in h) {
      if (r.date.compareTo(isoDate) <= 0) {
        current = r.status;
      } else {
        break;
      }
    }
    return current;
  }

  bool attendanceMarked = false;
  final List<AttendanceRecord> attendanceRecords = [];
  final List<AttendanceRecord> doctorAttendance = [];

  void addAttendance(AttendanceRecord r) {
    attendanceRecords.insert(0, r);
    attendanceMarked = true;
    notifyListeners();
  }

  /// Most recent open (check-in without matching check-out) shift, or null.
  /// The Attendance screen uses this to decide whether the next action is
  /// "Mark Check-in" or "Mark Check-out".
  AttendanceRecord? get openShift {
    for (final r in attendanceRecords) {
      if (r.isOpen) return r;
    }
    return null;
  }

  /// Start a new shift: stores the check-in half of the record. The counsellor
  /// completes it via [endShift] at end-of-day.
  void startShift(AttendanceRecord r) {
    attendanceRecords.insert(0, r);
    attendanceMarked = true;
    notifyListeners();
  }

  /// Complete the most recent open shift with check-out fields. No-op if
  /// nothing is open (shouldn't happen — the UI hides the check-out form in
  /// that case).
  void endShift({
    required String checkOut,
    required String endKm,
    required String totalRun,
    String collection = '',
    String notes = '',
    String photoPathOut = '',
    double? latOut,
    double? lngOut,
    bool driverOut = false,
    bool doctorOut = false,
    bool pharmacistOut = false,
  }) {
    final idx = attendanceRecords.indexWhere((r) => r.isOpen);
    if (idx < 0) return;
    attendanceRecords[idx] = attendanceRecords[idx].copyWith(
      checkOut: checkOut,
      endKm: endKm,
      totalRun: totalRun,
      collection: collection,
      notes: notes,
      photoPathOut: photoPathOut,
      latOut: latOut,
      lngOut: lngOut,
      driverOut: driverOut,
      doctorOut: doctorOut,
      pharmacistOut: pharmacistOut,
    );
    notifyListeners();
  }

  /// Yesterday's MMU ending km — the most recent attendance with a recorded
  /// ending reading. Empty on first-ever login (counsellor types it then).
  String get lastEndingKm {
    for (final r in attendanceRecords) {
      if (r.endKm.trim().isNotEmpty) return r.endKm.trim();
    }
    return '';
  }

  void addDoctorAttendance(AttendanceRecord r) {
    doctorAttendance.insert(0, r);
    notifyListeners();
  }

  /// Drop the doctor's local row for [date] — used when a refresh finds
  /// the server no longer has an attendance record for today (admin
  /// deleted it), so the phone reflects the server truth instead of
  /// keeping a stale check-in on screen (user 2026-08-25).
  void removeDoctorAttendanceOn(String date) {
    final n = doctorAttendance.length;
    doctorAttendance.removeWhere((r) => r.date == date);
    if (doctorAttendance.length != n) notifyListeners();
  }

  /// Pharmacist counterpart of [removeDoctorAttendanceOn].
  void removePharmaAttendanceOn(String date) {
    final n = pharmaAttendance.length;
    pharmaAttendance.removeWhere((r) => r.date == date);
    if (pharmaAttendance.length != n) notifyListeners();
  }

  /// Close the doctor's open shift by replacing it with the given closed
  /// record. Used at Check-Out time (rule 2026-08-05) so the check-in +
  /// check-out land on a single row instead of two separate ones.
  void closeDoctorShift(AttendanceRecord open, AttendanceRecord closed) {
    final idx = doctorAttendance.indexOf(open);
    if (idx < 0) return;
    doctorAttendance[idx] = closed;
    notifyListeners();
  }

  /// Pharmacist counterpart of [closeDoctorShift].
  void closePharmaShift(AttendanceRecord open, AttendanceRecord closed) {
    final idx = pharmaAttendance.indexOf(open);
    if (idx < 0) return;
    pharmaAttendance[idx] = closed;
    notifyListeners();
  }

  // ----- Pharmacist: requisitions, denials, attendance -----
  // No seed — populated by GET /api/requisitions on the pharmacist
  // Stock tab (user rule 2026-08-16). Local Requisition rows persist
  // alongside backend ones for offline-submitted work not yet drained.
  final List<Requisition> requisitions = [];
  bool loadingRequisitions = false;
  String? requisitionsError;

  void setRequisitionsLoading(bool loading, {String? error}) {
    loadingRequisitions = loading;
    if (loading) requisitionsError = null;
    if (error != null) requisitionsError = error;
    notifyListeners();
  }

  /// Replace the requisitions list with rows fetched from
  /// GET /api/requisitions. Local-only requisitions (backendId == null)
  /// are preserved — they haven't landed on the server yet.
  void applyBackendRequisitions(List<Map<String, dynamic>> rows) {
    final localOnly = requisitions.where((r) => r.backendId == null).toList();
    requisitions
      ..clear()
      ..addAll(rows.map(_reqFromBackendRow))
      ..addAll(localOnly);
    // Newest first (dd-MM-yyyy tricky to sort → use backendId when present).
    requisitions.sort((a, b) {
      final ai = a.backendId ?? -1;
      final bi = b.backendId ?? -1;
      return bi.compareTo(ai);
    });
    requisitionsError = null;
    notifyListeners();
  }

  /// Wipe every user-scoped list on logout so the next signed-in user
  /// never sees the previous one's cached rows (user rule 2026-08-16 —
  /// "Anshu counsellor kaa data Divya ko nahi dikhna chahiye"). Called
  /// from every logout handler before AppState.logout().
  void resetForNewUser() {
    patients.clear();
    requisitions.clear();
    pharmaAttendance.clear();
    deniedDeliveries.clear();
    attendanceRecords.clear();
    doctorAttendance.clear();
    _reorderTemplate = null;
    refreshing = false;
    lastRefreshError = null;
    loadingRequisitions = false;
    requisitionsError = null;
    notifyListeners();
  }

  /// Update ONE requisition after GET /api/requisitions/{id} lands —
  /// swaps in the full line list without touching other rows.
  void replaceRequisitionLines(int backendId, List<ReqLine> lines) {
    final idx = requisitions.indexWhere((r) => r.backendId == backendId);
    if (idx < 0) return;
    final r = requisitions[idx];
    requisitions[idx] = Requisition(
      id: r.id, date: r.date, status: r.status,
      items: lines,
      zonalRemark: r.zonalRemark, invoicePath: r.invoicePath,
      audit: r.audit,
      backendId: r.backendId,
      backendLineCount: r.backendLineCount,
      backendRequestedTotal: r.backendRequestedTotal,
    );
    notifyListeners();
  }

  Requisition _reqFromBackendRow(Map<String, dynamic> r) {
    final rid = (r['requisition_id'] as num?)?.toInt() ?? 0;
    final iso = (r['requisition_date'] ?? '').toString();
    final dateStr = _fmtIsoDate(iso);
    final serverStatus = (r['status'] ?? 'Requested').toString();
    final audit = <AuditEntry>[];
    final createdRaw = r['created_at']?.toString();
    if (createdRaw != null) {
      final t = DateTime.tryParse(createdRaw);
      if (t != null) {
        audit.add(AuditEntry(
          when: t.toLocal(),
          actor: (r['raised_by_name'] ?? 'Pharmacist').toString(),
          action: 'Submitted requisition',
        ));
      }
    }
    final reviewedRaw = r['reviewed_at']?.toString();
    if (reviewedRaw != null) {
      final t = DateTime.tryParse(reviewedRaw);
      if (t != null) {
        audit.add(AuditEntry(
          when: t.toLocal(),
          actor: (r['reviewed_by_name'] ?? 'Zonal Incharge').toString(),
          action: 'Reviewed ($serverStatus)',
        ));
      }
    }
    return Requisition(
      id: 'REQ-$rid',
      date: dateStr,
      status: _mapServerReqStatus(serverStatus),
      zonalRemark: (r['remarks'] ?? '').toString(),
      // Server-side invoice file name — without it the detail page's invoice
      // button forgets the upload after every refresh and shows "Upload
      // Invoice" again on verified requisitions.
      invoicePath: (r['invoice_path'] ?? '').toString(),
      // The list endpoint sends full lines — parse them right away so the
      // Past cards can show medicine names without a detail round-trip
      // (user 2026-08-21).
      items: [
        for (final l in (r['lines'] as List? ?? const []))
          if (l is Map) reqLineFromBackend(l.cast<String, dynamic>()),
      ],
      audit: audit,
      backendId: rid,
      backendLineCount: (r['line_count'] as num?)?.toInt(),
      backendRequestedTotal: (r['requested_total'] as num?)?.toInt(),
    );
  }

  /// Map server enum → UI-friendly slug the existing chip renderer knows.
  /// Case-insensitive: after receipt the list endpoint sends the
  /// mobile_extra stage ("received", lowercase) instead of the
  /// Requisition.status enum ("Received") — both must land on 'verified',
  /// otherwise the chip falls through to its default "Pending" label.
  static String _mapServerReqStatus(String s) => switch (s.trim().toLowerCase()) {
        'requested' || 'pending'                 => 'pending_zi',
        'approved'                                => 'approved',
        'partial'                                 => 'partial',
        'rejected'                                => 'rejected',
        'received' || 'delivered' || 'verified'  => 'verified',
        _ => s.toLowerCase(),
      };

  /// Map a GET /requisitions/{id} `lines` entry into the local ReqLine
  /// shape used by the Past + Overall Status panels.
  static ReqLine reqLineFromBackend(Map<String, dynamic> l) => ReqLine(
        name: (l['medicine_name'] ?? '').toString(),
        dosage: (l['dosage'] ?? '').toString(),
        unit: 'Strip',
        requested: (l['requested_qty'] as num?)?.toInt() ?? 0,
        dispatched: (l['dispatched_qty'] as num?)?.toInt() ?? 0,
        received: (l['received_qty'] as num?)?.toInt() ?? 0,
        approvedQty: (l['approved_qty'] as num?)?.toInt() ?? -1,
        zonalRemark: (l['review_note'] ?? '').toString(),
        isZonalAdded: (l['added_by_cmo'] as bool?) ?? false,
        status: (l['status'] ?? 'Pending').toString(),
        backendLineId: (l['requisition_line_id'] as num?)?.toInt(),
        comboKey: (l['combo_key'] ?? '').toString(),
      );
  final List<DeniedDelivery> deniedDeliveries = [];
  final List<AttendanceRecord> pharmaAttendance = [];

  // Re-Order flow (2026-07-29): Past → "Re-Order" copies the medicine
  // list (name / dosage / unit) with qty blanked, stashes it here, and the
  // Requisition form consumes it on next render so the pharmacist just
  // types new quantities.
  Requisition? _reorderTemplate;
  bool get hasReorderTemplate => _reorderTemplate != null;
  void setReorderTemplate(Requisition r) { _reorderTemplate = r; notifyListeners(); }
  Requisition? consumeReorderTemplate() {
    final r = _reorderTemplate;
    _reorderTemplate = null;
    return r;
  }

  /// Auto-generate a unique requisition id in the form REQ-YYYYMMDD-NNN,
  /// where NNN is a per-day sequence based on existing requisitions.
  String nextRequisitionId([DateTime? now]) {
    final n = now ?? DateTime.now();
    final ymd = '${n.year.toString().padLeft(4, '0')}'
        '${n.month.toString().padLeft(2, '0')}'
        '${n.day.toString().padLeft(2, '0')}';
    final prefix = 'REQ-$ymd-';
    final used = requisitions
        .where((r) => r.id.startsWith(prefix))
        .map((r) => int.tryParse(r.id.substring(prefix.length)) ?? 0)
        .fold<int>(0, (m, v) => v > m ? v : m);
    return '$prefix${(used + 1).toString().padLeft(3, '0')}';
  }

  void addRequisition(Requisition r) {
    requisitions.insert(0, r);
    notifyListeners();
  }

  /// Simulate the future Zonal Incharge approval that will land from the dashboard
  /// (2026-07-29). Approves each pharma-requested line at its full quantity
  /// unless overridden in [overrides] {lineIndex → approvedQty}. Marks the
  /// requisition 'approved' (or 'partial' if any approvedQty < requested).
  void simulateZonalApproval(Requisition r,
      {Map<int, int>? overrides, String zonalRemark = '', String approverName = 'Zonal Incharge'}) {
    var anyPartial = false;
    for (var i = 0; i < r.items.length; i++) {
      final line = r.items[i];
      if (line.isZonalAdded) continue;
      final approved = overrides?[i] ?? line.requested;
      line.approvedQty = approved;
      line.status = approved == 0
          ? 'Rejected'
          : (approved < line.requested ? 'Partial' : 'Approved');
      if (approved > 0 && approved < line.requested) anyPartial = true;
    }
    r.zonalRemark = zonalRemark.isEmpty ? r.zonalRemark : zonalRemark;
    final anyApproved = r.items.any((i) => i.approvedQty > 0);
    r.status = !anyApproved ? 'rejected' : (anyPartial ? 'partial' : 'approved');
    r.audit.add(AuditEntry(
      when: DateTime.now(),
      actor: approverName,
      action: r.status == 'rejected'
          ? 'Rejected requisition'
          : (r.status == 'partial' ? 'Approved (partial)' : 'Approved (full)'),
      note: zonalRemark,
    ));
    notifyListeners();
  }

  /// Zonal Incharge adds a medicine that the pharmacist didn't originally request.
  /// The line goes in flagged so it renders in the "Zonal Incharge Added" section.
  void addZonalLine(Requisition r, ReqLine line) {
    line.isZonalAdded = true;
    line.status = 'Approved';
    if (line.approvedQty <= 0) line.approvedQty = line.requested;
    r.items.add(line);
    r.audit.add(AuditEntry(
      when: DateTime.now(), actor: 'Zonal Incharge',
      action: 'Added ${line.name} × ${line.approvedQty}',
    ));
    notifyListeners();
  }

  /// Persist edits to a requisition (e.g. typed received quantities).
  void updateRequisitions() => notifyListeners();

  /// Complete pharmacist verification: locks received quantities, attaches
  /// the invoice, and flips the requisition to 'verified'. Any extras the
  /// pharmacist added during receipt come in via [extras] (isZonalAdded=false
  /// so they render as pharma additions; we don't have a separate bucket).
  void completeVerification(Requisition r, {required String invoicePath, List<ReqLine> extras = const []}) {
    for (final e in extras) {
      e.status = 'Received';
      if (e.approvedQty <= 0) e.approvedQty = e.received;
      r.items.add(e);
    }
    for (final l in r.items) {
      if (l.received > 0 && l.status != 'Received') {
        l.status = l.received < (l.approvedQty > 0 ? l.approvedQty : l.requested)
            ? 'Partial'
            : 'Received';
      }
    }
    r.invoicePath = invoicePath;
    r.status = 'verified';
    r.audit.add(AuditEntry(
      when: DateTime.now(), actor: 'Pharmacist',
      action: 'Verified receipt',
      note: extras.isEmpty ? '' : 'Extras added: ${extras.map((e) => e.name).join(", ")}',
    ));
    notifyListeners();
  }

  /// Mark one requisition line as received (received = approved). Kept for
  /// backward compat with the older single-tap "Received" checkbox flow.
  void markLineReceived(Requisition r, ReqLine l) {
    if (l.received <= 0) l.received = l.approvedQty > 0 ? l.approvedQty : l.requested;
    l.status = 'Received';
    if (r.items.every((x) => x.status == 'Received')) r.status = 'verified';
    notifyListeners();
  }
  void denyDelivery(CPatient p, String reason) {
    p.status = 'denied';
    deniedDeliveries.insert(0, DeniedDelivery(patient: p, reason: reason, date: '11-Jun-2026'));
    notifyListeners();
  }
  void addPharmaAttendance(AttendanceRecord r) { pharmaAttendance.insert(0, r); notifyListeners(); }

  // ----- Derived views over `patients` -----
  //
  // Each of these was a fresh scan of the whole list on EVERY read, and the
  // Home screens read two or three of them per rebuild across eighteen
  // widgets. On a 2,000-row list that is fifty-odd full scans plus several
  // n-log-n sorts per frame — which is what made scrolling and typing
  // stutter (user 2026-09-26). They are computed once now and held until
  // the next notification.
  //
  // Invalidation lives in exactly one place, the notifyListeners() override
  // below, and NOT in the eight methods that mutate `patients`. That is the
  // whole safety argument: Provider rebuilds only on notifyListeners(), so a
  // value held between two notifications cannot be staler than what the
  // screen is already displaying. There is no invalidation to forget,
  // because nothing can change what the user sees without notifying.
  //
  // The one thing worth knowing: the past-7-day getters close over
  // DateTime.now(), so their window advances on the next notification rather
  // than the next read. With a 30-second queue poll that is not a window
  // anybody can observe.
  int? _registeredToday;
  int? _visitsCompleted;
  List<CPatient>? _doctorQueue;
  List<CPatient>? _doctorAttended;
  List<CPatient>? _doctorPast7Days;
  List<CPatient>? _pharmaQueue;
  List<CPatient>? _dispensedPatients;
  List<CPatient>? _counsellorPast7Days;
  List<CPatient>? _pharmaPast7Days;

  @override
  void notifyListeners() {
    _registeredToday      = null;
    _visitsCompleted      = null;
    _doctorQueue          = null;
    _doctorAttended       = null;
    _doctorPast7Days      = null;
    _pharmaQueue          = null;
    _dispensedPatients    = null;
    _counsellorPast7Days  = null;
    _pharmaPast7Days      = null;
    _cutoff               = null;
    super.notifyListeners();
  }

  // ----- Counsellor views -----
  int get registeredToday => _registeredToday ??=
      patients.where((p) => p.registeredOn == 'Today').length;
  int get visitsCompleted => _visitsCompleted ??=
      patients.where((p) => p.status == 'completed').length;

  // ----- Doctor views -----
  List<CPatient> get doctorQueue => _doctorQueue ??= patients
      .where((p) => p.status == 'registered' || p.status == 'with_doctor')
      .toList();
  /// Cases the doctor has finished consulting on.
  ///
  /// Deliberately wider than with_pharma/completed. The status ladder (§6.2)
  /// sends a case the doctor ordered tests for to `with_counsellor` (pay for
  /// the tests) and then `with_lab`, and only later back to the doctor. Those
  /// two states were in neither doctorQueue nor doctorAttended, so finishing a
  /// consultation with any lab test made the patient vanish from every tile —
  /// In Queue went down, Completed never went up.
  static const _doctorDoneStatuses = {
    'with_counsellor', 'with_lab', 'with_pharma', 'completed',
  };
  /// Latest action first (user 2026-08-22): newest appointment id leads;
  /// local rows still syncing (no id yet) sit on top.
  List<CPatient> get doctorAttended => _doctorAttended ??=
      patients.where((p) => _doctorDoneStatuses.contains(p.status)).toList()
        ..sort((a, b) => (b.backendAppointmentId ?? 1 << 30)
            .compareTo(a.backendAppointmentId ?? 1 << 30));
  // Free now that doctorAttended is held: the tile used to build and sort
  // the entire list just to read .length off it.
  int get doctorCompleted => doctorAttended.length;

  /// Every patient the doctor has interacted with in the last 7 days —
  /// queue + attended — sorted newest first. Filters by CPatient.regDate
  /// (format "dd-Mon-yyyy" per fmtDate).
  List<CPatient> get doctorPast7Days => _doctorPast7Days ??= _byRegDateDesc([
        ...doctorQueue.where((p) => _within7Days(p.regDate)),
        ...doctorAttended.where((p) => _within7Days(p.regDate)),
      ]);

  static const _months = {
    'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
    'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
  };
  DateTime? _parseFmtDate(String s) {
    // Expected shape: "19-Jun-2026". Empty strings/mismatches return null.
    final parts = s.split('-');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = _months[parts[1]];
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }

  // ----- Pharmacist views -----
  List<CPatient> get pharmaQueue => _pharmaQueue ??=
      patients.where((p) => p.status == 'with_pharma').toList();
  List<CPatient> get dispensedPatients => _dispensedPatients ??=
      patients.where((p) => p.status == 'completed').toList();
  int get pharmaDispensed => dispensedPatients.length;

  // ----- Past-7-day KPI feeds (rule 2026-07-31, parity with doctor) -----
  bool _within7Days(String regDate) {
    final d = _parseFmtDate(regDate);
    if (d == null) return false;
    return !d.isBefore(_sevenDaysAgo);
  }

  /// One cutoff per notification instead of one per element. This used to
  /// call DateTime.now() inside the filter, so a 2,000-row list built two
  /// thousand DateTimes and did two thousand subtractions to answer a
  /// question with a single answer.
  DateTime get _sevenDaysAgo =>
      _cutoff ??= DateTime.now().subtract(const Duration(days: 7));
  DateTime? _cutoff;

  /// Newest registration first, parsing each regDate ONCE.
  ///
  /// The comparator these getters shared called _parseFmtDate on both sides
  /// of every comparison — a split('-') and three int.tryParse calls, O(n log
  /// n) times over, for dates that cannot change while the sort runs. Same
  /// comparison result, so the ordering is unchanged.
  List<CPatient> _byRegDateDesc(Iterable<CPatient> src) {
    final keyed = [
      for (final p in src) (_parseFmtDate(p.regDate) ?? _epoch, p),
    ]..sort((a, b) => b.$1.compareTo(a.$1));
    return [for (final e in keyed) e.$2];
  }

  static final DateTime _epoch = DateTime(1970);

  /// Every patient the counsellor registered in the last 7 days, newest first.
  List<CPatient> get counsellorPast7Days => _counsellorPast7Days ??=
      _byRegDateDesc(patients.where((p) => _within7Days(p.regDate)));

  /// Every patient the pharmacist has seen (queue + dispensed) in the last
  /// 7 days, newest first.
  List<CPatient> get pharmaPast7Days => _pharmaPast7Days ??= _byRegDateDesc(
      patients
          .where((p) => p.status == 'with_pharma' || p.status == 'completed')
          .where((p) => _within7Days(p.regDate)));

  String nextId() => 'P${_seq++}';
  String nextUniqueCode() => 'GN-${(_seq).toString().padLeft(4, '0')}';

  String addPatient(CPatient p) {
    patients.insert(0, p);
    if (backendRegisteredToday != null) {
      backendRegisteredToday = backendRegisteredToday! + 1;
    }
    if (backendPast7DaysTotal != null) {
      backendPast7DaysTotal = backendPast7DaysTotal! + 1;
    }
    if (backendDoctorQueue != null) {
      backendDoctorQueue = backendDoctorQueue! + 1;
    }
    notifyListeners();
    return p.id;
  }

  /// Merge a batch of patients from an /api/queues/* endpoint into the
  /// local patient list. Backend rows are tagged with an id prefix of
  /// `B` (e.g. B53) so we can find and replace them on the next refresh
  /// without touching the demo seed rows. Existing seed rows keep their
  /// numeric ids (`1`, `2`, `1000`...) and are untouched.
  ///
  /// [additive] preserves already-merged 'B' rows and only inserts new ones,
  /// so a companion fetch (e.g. doctor-attended alongside counsellor-past-7)
  /// won't wipe the primary list's rows (user 2026-09-02: the second
  /// mergeBackendPatients was wiping just-registered patients because
  /// they weren't in the second endpoint's response).
  void mergeBackendPatients(List<Map<String, dynamic>> queueRows,
      {String? statusOverride, bool additive = false}) {
    if (!additive) {
      // Drop the previous backend snapshot — replace, don't accumulate.
      patients.removeWhere((p) => p.id.startsWith('B'));
    }
    // Also drop locally-added rows ('P…') whose registration has landed on
    // the server — the incoming backend row is the authoritative copy.
    // Without this the counsellor sees the same patient twice after a
    // successful sync: the optimistic local "Waiting" row AND the server
    // "With Doctor" row (user bug report 2026-08-13). Contact number is
    // the match key — the form requires it and the server dedups on it.
    final backendContacts = {
      for (final row in queueRows)
        if ((row['contact_number'] as String?)?.isNotEmpty == true)
          row['contact_number'] as String,
    };
    patients.removeWhere(
        (p) => p.id.startsWith('P') && backendContacts.contains(p.contact));
    for (final row in queueRows.reversed) {
      final patientId = row['patient_id'];
      if (patientId == null) continue;
      final apptDateIso = (row['appointment_date'] as String?) ?? '';
      final regDateFmt = _fmtIsoDate(apptDateIso);
      final registeredOn = _relRegisteredOn(apptDateIso);
      // Symptoms come back as a Postgres text[] which the JSON encoder
      // renders as a Dart List. Missing / empty rows land as null.
      // Always produce a MUTABLE list — CounPatientDetail's hydrate
      // does `p.symptoms.clear()..addAll(...)`, and a const empty list
      // fallback throws UnmodifiableListMixin.clear on the empty case
      // (backend deploy of the queue-symptoms commit still pending).
      final rawSyms = row['symptoms'];
      final syms = rawSyms is List
          ? <String>[ for (final s in rawSyms) if (s != null) s.toString() ]
          : <String>[];
      final adapted = CPatient(
        id:          'B$patientId',
        name:        (row['patient_name'] as String?)?.trim().isNotEmpty == true
                        ? row['patient_name'] as String
                        : '(no name)',
        gender:      (row['gender']       as String?) ?? 'Female',
        age:         (row['age']          as num?)?.toInt() ?? 0,
        contact:     (row['contact_number'] as String?) ?? '',
        uniqueCode:  (row['unique_code']  as String?) ?? '',
        block:       (row['block_name']   as String?) ?? '',
        village:     (row['village_name'] as String?) ?? '',
        symptoms:    syms,
        // primary diagnosis text if the doctor / counsellor has set one
        // — used as "Likely" label on Home + detail screen without a
        // separate /appointments/{id} fetch.
        disease:     (row['primary_diagnosis'] as String?) ?? '',
        status:      statusOverride ?? (row['status'] as String?) ?? 'registered',
        registeredOn: registeredOn,
        regDate:     regDateFmt,
        // Carry the appointment_id from the queue row so the detail
        // screen can lazy-fetch vitals + remarks + Rx via
        // /api/appointments/{id} (symptoms + primary diagnosis now come
        // with the list already). patient_id also rides along so the
        // Re-Appointment submit can tell the backend "attach to this
        // patient, don't insert a duplicate" (user rule 2026-08-16).
        backendAppointmentId: (row['appointment_id'] as num?)?.toInt(),
        backendPatientId: (row['patient_id'] as num?)?.toInt(),
        medicineCount: (row['medicine_count'] as num?)?.toInt() ?? 0,
        // Pregnancy block, when the list row carries it — otherwise the
        // detail hydrate fills these in before Re-Appointment prefill.
        pregnant: (row['pregnant'] as bool?) ?? false,
        lmpDate: (row['lmp_date'] as String?) ?? '',
        eddDate: (row['edd_date'] as String?) ?? '',
      );
      // Optimistic shield: a local submit already moved this case forward;
      // a stale server snapshot must not drag it back into the queue.
      final apptId = adapted.backendAppointmentId;
      final optimistic = apptId != null ? _optimisticStatus[apptId] : null;
      if (optimistic != null) {
        final serverRank = _statusRank[adapted.status] ?? 0;
        final localRank = _statusRank[optimistic] ?? 0;
        if (serverRank >= localRank) {
          _optimisticStatus.remove(apptId); // server caught up
        } else {
          adapted.status = optimistic;
        }
      }
      // In additive mode the primary list already inserted this patient,
      // so replace the earlier copy in place instead of double-inserting
      // (user 2026-09-02).
      if (additive) {
        final existing = patients.indexWhere((p) => p.id == adapted.id);
        if (existing >= 0) {
          patients[existing] = adapted;
          continue;
        }
      }
      patients.insert(0, adapted);
    }
    notifyListeners();
  }

  static String _fmtIsoDate(String iso) {
    if (iso.length < 10) return '';
    final parts = iso.substring(0, 10).split('-');
    if (parts.length != 3) return '';
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final m = int.tryParse(parts[1]);
    if (m == null || m < 1 || m > 12) return '';
    return '${parts[2]}-${months[m-1]}-${parts[0]}';
  }

  static String _relRegisteredOn(String iso) {
    if (iso.length < 10) return '';
    final d = DateTime.tryParse('${iso.substring(0, 10)}T00:00:00');
    if (d == null) return '';
    final today = DateTime.now();
    final base = DateTime(today.year, today.month, today.day);
    final delta = base.difference(DateTime(d.year, d.month, d.day)).inDays;
    if (delta == 0) return 'Today';
    if (delta == 1) return 'Yesterday';
    if (delta > 1 && delta < 7) return '$delta days ago';
    return _fmtIsoDate(iso);
  }

  /// Optimistic status shield (user bug 2026-08-22 "submitted but not
  /// removing from the queue until refresh"): a background refresh that
  /// races the sync push can pull a snapshot where the case is still
  /// with_doctor and resurrect the row. Local actions record their status
  /// here; mergeBackendPatients keeps it until the SERVER status catches
  /// up (equal or further along the ladder), then forgets it.
  final Map<int, String> _optimisticStatus = {};
  static const Map<String, int> _statusRank = {
    'registered': 0, 'with_doctor': 1, 'payment_pending': 2,
    'with_counsellor': 2, 'with_lab': 3, 'with_pharma': 4, 'completed': 5,
  };

  /// The row currently IN the list for this patient. A background refresh
  /// while a detail/case screen is open REPLACES list rows with fresh
  /// objects — mutating only the (now stale) object the screen holds left
  /// the visible row unchanged, so the queue "didn't shift until refresh"
  /// (user bug 2026-08-22).
  CPatient _liveRow(CPatient p) => patients.firstWhere(
        (x) =>
            identical(x, p) ||
            (p.backendAppointmentId != null &&
                x.backendAppointmentId == p.backendAppointmentId) ||
            x.id == p.id,
        orElse: () => p,
      );

  void doctorSubmit(CPatient p, {required String disease, required List<RxItem> rx, required List<String> tests, String observations = '', String remarks = ''}) {
    final status = rx.isNotEmpty ? 'with_pharma' : 'completed';
    for (final t in {p, _liveRow(p)}) {
      t.disease = disease;
      t.prescription = rx;
      t.tests = tests;
      t.observations = observations;
      t.doctorRemarks = remarks;
      t.status = status;
    }
    if (p.backendAppointmentId != null) {
      _optimisticStatus[p.backendAppointmentId!] = status;
    }
    notifyListeners();
  }

  void pharmacistDispense(CPatient p) {
    for (final t in {p, _liveRow(p)}) {
      t.status = 'completed';
      for (final m in t.prescription) {
        m.dispensed = true;
      }
    }
    if (p.backendAppointmentId != null) {
      _optimisticStatus[p.backendAppointmentId!] = 'completed';
    }
    notifyListeners();
  }

  void addCamp(Camp c) { camps.insert(0, c); notifyListeners(); }
  /// Record a device status change with today's date. If a record already
  /// exists for today it's updated in place (idempotent within the same day).
  /// Kept for legacy callers; the Devices screen now uses
  /// [submitDeviceStatusReport] which lets the user pick the date.
  void setDevice(String name, String status) {
    submitDeviceStatusReport(_todayIso(), {name: status});
  }

  /// Append a snapshot of all-device statuses for a chosen date. Each entry in
  /// [statusMap] becomes a history record; existing records for that date are
  /// overwritten so the same submission can be re-saved.
  void submitDeviceStatusReport(String isoDate, Map<String, String> statusMap) {
    statusMap.forEach((name, status) {
      final history = deviceStatusHistory.putIfAbsent(name, () => <DeviceStatusRecord>[]);
      final idx = history.indexWhere((r) => r.date == isoDate);
      if (idx >= 0) {
        history[idx] = DeviceStatusRecord(isoDate, status);
      } else {
        history.add(DeviceStatusRecord(isoDate, status));
        history.sort((a, b) => a.date.compareTo(b.date));
      }
    });
    notifyListeners();
  }

  /// Past submissions, one entry per date. Each entry contains the statuses of
  /// every device that was recorded on that date. Sorted newest first.
  List<({String date, Map<String, String> statuses})> getDeviceSubmissions() {
    final byDate = <String, Map<String, String>>{};
    deviceStatusHistory.forEach((dev, records) {
      for (final r in records) {
        byDate.putIfAbsent(r.date, () => <String, String>{})[dev] = r.status;
      }
    });
    final dates = byDate.keys.toList()..sort((a, b) => b.compareTo(a));
    return dates.map((d) => (date: d, statuses: byDate[d]!)).toList();
  }

  String _todayIso() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }
  void markAttendance() { attendanceMarked = true; notifyListeners(); }
}
