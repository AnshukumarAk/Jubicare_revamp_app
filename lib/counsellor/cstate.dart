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
  final String name;
  String dosage; // strength e.g. "500 mg" — typed by the doctor
  String days;
  String interval; // OD/BD/TDS/QID/SOS
  int qty;
  int dispensedQty;
  bool dispensed;
  RxItem({required this.name, this.dosage = '', this.days = '5 Days', this.interval = 'TDS', this.qty = 10, int? dispensedQty, this.dispensed = false})
      : dispensedQty = dispensedQty ?? qty;
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
  String remarks; // counsellor remarks
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
    this.remarks = '',
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
  ReqLine({
    required this.name, this.dosage = '', this.unit = 'Strip',
    required this.requested,
    this.dispatched = 0, this.received = 0,
    this.approvedQty = -1, this.zonalRemark = '',
    this.isZonalAdded = false,
    this.status = 'Pending',
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
  final String id;      // REQ-YYYYMMDD-NNN, unique per submission
  final String date;    // display date (dd-MM-yyyy)
  String status;
  String zonalRemark;     // overall Zonal Incharge note (per-line notes live on ReqLine)
  String invoicePath;   // local path to invoice PDF/image (verification)
  final List<ReqLine> items; // both pharma-requested + Zonal Incharge-added rows
  final List<AuditEntry> audit;
  Requisition({
    required this.id, required this.date, required this.status,
    required this.items,
    this.zonalRemark = '', this.invoicePath = '',
    List<AuditEntry>? audit,
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

  // "Re-Appointment" pending-switch flag (2026-07-31). Written when the
  // counsellor taps Re-Appointment from the Patient Detail screen; the shell
  // watches state, consumes the flag on its next build, and jumps to the
  // Register tab so the prefill flows in.
  bool _switchToRegister = false;
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
  final List<Requisition> requisitions = [
    Requisition(
      id: 'REQ-20260606-001',
      date: '06-06-2026', status: 'verified',
      zonalRemark: 'Approved as requested. Please verify batches on receipt.',
      items: [
        ReqLine(name: 'Paracetamol', dosage: '500', unit: 'Tab', requested: 200, dispatched: 200, received: 200, approvedQty: 200, status: 'Received'),
        ReqLine(name: 'ORS Sachets', dosage: '', unit: 'Sachet', requested: 100, dispatched: 100, received: 60, approvedQty: 100, status: 'Partial'),
      ],
      audit: [
        AuditEntry(when: DateTime(2026, 6, 6, 9, 30),  actor: 'Pharmacist', action: 'Submitted requisition'),
        AuditEntry(when: DateTime(2026, 6, 6, 11, 15), actor: 'Zonal Incharge', action: 'Approved (full)'),
        AuditEntry(when: DateTime(2026, 6, 7, 15, 20), actor: 'Pharmacist', action: 'Verified receipt', note: 'ORS partial: 60/100'),
      ]),
    Requisition(
      id: 'REQ-20260609-001',
      date: '09-06-2026', status: 'pending_zi',
      items: [
        ReqLine(name: 'Cetirizine',   dosage: '10',  unit: 'Tab', requested: 50, status: 'Pending'),
        ReqLine(name: 'Azithromycin', dosage: '500', unit: 'Tab', requested: 30, status: 'Pending'),
      ],
      audit: [
        AuditEntry(when: DateTime(2026, 6, 9, 10, 0), actor: 'Pharmacist', action: 'Submitted requisition'),
        AuditEntry(when: DateTime(2026, 6, 9, 10, 0), actor: 'System',     action: 'Email sent to Zonal Incharge'),
      ]),
  ];
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

  // ----- Counsellor views -----
  int get registeredToday => patients.where((p) => p.registeredOn == 'Today').length;
  int get visitsCompleted => patients.where((p) => p.status == 'completed').length;

  // ----- Doctor views -----
  List<CPatient> get doctorQueue => patients.where((p) => p.status == 'registered' || p.status == 'with_doctor').toList();
  List<CPatient> get doctorAttended => patients.where((p) => p.status == 'with_pharma' || p.status == 'completed').toList();
  int get doctorCompleted => doctorAttended.length;

  /// Every patient the doctor has interacted with in the last 7 days —
  /// queue + attended — sorted newest first. Filters by CPatient.regDate
  /// (format "dd-Mon-yyyy" per fmtDate).
  List<CPatient> get doctorPast7Days {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    bool within(String s) {
      final d = _parseFmtDate(s);
      return d != null && !d.isBefore(cutoff);
    }
    final list = [
      ...doctorQueue.where((p) => within(p.regDate)),
      ...doctorAttended.where((p) => within(p.regDate)),
    ]..sort((a, b) {
        final da = _parseFmtDate(a.regDate) ?? DateTime(1970);
        final db = _parseFmtDate(b.regDate) ?? DateTime(1970);
        return db.compareTo(da);
      });
    return list;
  }

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
  List<CPatient> get pharmaQueue => patients.where((p) => p.status == 'with_pharma').toList();
  List<CPatient> get dispensedPatients => patients.where((p) => p.status == 'completed').toList();
  int get pharmaDispensed => dispensedPatients.length;

  // ----- Past-7-day KPI feeds (rule 2026-07-31, parity with doctor) -----
  bool _within7Days(String regDate) {
    final d = _parseFmtDate(regDate);
    if (d == null) return false;
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return !d.isBefore(cutoff);
  }

  /// Every patient the counsellor registered in the last 7 days, newest first.
  List<CPatient> get counsellorPast7Days {
    final list = patients.where((p) => _within7Days(p.regDate)).toList()
      ..sort((a, b) {
        final da = _parseFmtDate(a.regDate) ?? DateTime(1970);
        final db = _parseFmtDate(b.regDate) ?? DateTime(1970);
        return db.compareTo(da);
      });
    return list;
  }

  /// Every patient the pharmacist has seen (queue + dispensed) in the last
  /// 7 days, newest first.
  List<CPatient> get pharmaPast7Days {
    final list = patients
        .where((p) => p.status == 'with_pharma' || p.status == 'completed')
        .where((p) => _within7Days(p.regDate))
        .toList()
      ..sort((a, b) {
        final da = _parseFmtDate(a.regDate) ?? DateTime(1970);
        final db = _parseFmtDate(b.regDate) ?? DateTime(1970);
        return db.compareTo(da);
      });
    return list;
  }

  String nextId() => 'P${_seq++}';
  String nextUniqueCode() => 'GN-${(_seq).toString().padLeft(4, '0')}';

  String addPatient(CPatient p) { patients.insert(0, p); notifyListeners(); return p.id; }

  /// Merge a batch of patients from an /api/queues/* endpoint into the
  /// local patient list. Backend rows are tagged with an id prefix of
  /// `B` (e.g. B53) so we can find and replace them on the next refresh
  /// without touching the demo seed rows. Existing seed rows keep their
  /// numeric ids (`1`, `2`, `1000`...) and are untouched.
  void mergeBackendPatients(List<Map<String, dynamic>> queueRows, {String? statusOverride}) {
    // Drop the previous backend snapshot — replace, don't accumulate.
    patients.removeWhere((p) => p.id.startsWith('B'));
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
        // with the list already).
        backendAppointmentId: (row['appointment_id'] as num?)?.toInt(),
      );
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

  void doctorSubmit(CPatient p, {required String disease, required List<RxItem> rx, required List<String> tests, String observations = '', String remarks = ''}) {
    p.disease = disease;
    p.prescription = rx;
    p.tests = tests;
    p.observations = observations;
    p.doctorRemarks = remarks;
    p.status = rx.isNotEmpty ? 'with_pharma' : 'completed';
    notifyListeners();
  }

  void pharmacistDispense(CPatient p) {
    p.status = 'completed';
    for (final m in p.prescription) {
      m.dispensed = true;
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
