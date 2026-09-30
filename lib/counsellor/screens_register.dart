import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'cw.dart';
import 'cdata.dart';
import 'cstate.dart';
import 'symptom_field.dart';
import '../api/appointments_api.dart';
import '../api/masters_store.dart';
import '../api/staff_api.dart';
import '../api/sync_service.dart';
import '../api/uploads_api.dart';
import '../services/deepgram_stt.dart';
import '../services/staff_cache_store.dart';
import '../services/translation_service.dart';
import '../state/app_state.dart';
import '../widgets/attachments_field.dart';

/// yyyy-mm-dd (SQL date). Backend PatientIn / AppointmentIn expects this
/// format for `dob`, `lmp_date`, `edd_date`, `appointment_date`.
String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Best-effort id lookup for a value in a `masters` sublist. The bootstrap
/// payload returns each master row with `{id, name}` OR `{id, term}` OR
/// per-domain keys like `{symptom_id, symptom_name}` (depending on how
/// each master was aliased in the backend's SELECT). The fallback chain
/// covers all three shapes so callers don't have to worry which one
/// applies to which master. Case-insensitive so "Fever" and "fever" match.
int? _lookupIdByName(List<Map<String, dynamic>> rows, String? name,
    {String idKey = 'id', String nameKey = 'name'}) {
  if (name == null || name.trim().isEmpty) return null;
  final n = name.trim().toLowerCase();
  for (final r in rows) {
    final rn = (r[nameKey]
            ?? r['name']
            ?? r['term']          // symptoms + diseases are aliased to `term`
            ?? r['symptom_name']
            ?? r['category_name'])
        ?.toString().trim().toLowerCase();
    if (rn == n) {
      final id = r[idKey]
          ?? r['id']
          ?? r['symptom_id']
          ?? r['category_id']
          ?? r['disease_id'];
      if (id is num) return id.toInt();
      if (id is String) return int.tryParse(id);
    }
  }
  return null;
}

/// Disease-specific lookup that also matches against the `synonyms`
/// array each master row carries. Backend seeds Dengue with synonyms
/// ["dengue","dengue fever","DHF","dengue bukhar","haddi tod bukhar",
/// "break bone fever"] — without this pass, the mobile's "Dengue
/// Fever" pick from the ML scorer wouldn't link to id 97.
int? _lookupDiseaseId(List<Map<String, dynamic>> rows, String? name) {
  if (name == null || name.trim().isEmpty) return null;
  final n = name.trim().toLowerCase();
  for (final r in rows) {
    final rn = (r['term'] ?? r['name'] ?? r['disease_name'])?.toString().trim().toLowerCase();
    if (rn == n) return _asIntFromDynamic(r['id'] ?? r['disease_id']);
    final syns = r['synonyms'];
    if (syns is List) {
      for (final s in syns) {
        if (s != null && s.toString().trim().toLowerCase() == n) {
          return _asIntFromDynamic(r['id'] ?? r['disease_id']);
        }
      }
    }
  }
  return null;
}

int? _asIntFromDynamic(dynamic v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

/// Convert a numeric-in-a-controller to a nullable double. Empty or
/// unparseable → null (so the backend stores NULL instead of `0`, which
/// would look like a real reading).
double? _asDouble(TextEditingController c) {
  final s = c.text.trim();
  if (s.isEmpty) return null;
  return double.tryParse(s);
}

/// Same for ints. Backend vitals like systolic_bp / blood_sugar are int.
/// "100.0" -> "100"; "98.6" stays "98.6"; anything unparseable is returned
/// untouched.
///
/// Numeric columns come back from the server carrying their decimal part,
/// and Blood Sugar is the only one of them read back with int.tryParse --
/// which returns null for "100.0". So a re-appointment prefilled with last
/// visit's reading dropped that one field on submit while every other vital
/// carried over: BP, pulse and SpO2 are integer columns, and temperature and
/// haemoglobin are parsed as doubles. Confirmed on live 2026-09-28 --
/// appointment 1828880 recorded blood_sugar 100.0, its re-appointment
/// 1828894 recorded null, and nothing else differed.
///
/// It was visible as well as broken: the box is digits-only with a
/// three-character limit, and it was being handed five characters, two of
/// them ones it would refuse to accept if typed.
String _wholeNumber(String s) {
  final d = double.tryParse(s);
  if (d == null) return s;
  return d == d.roundToDouble() ? d.toInt().toString() : s;
}

int? _asInt(TextEditingController c) {
  final s = c.text.trim();
  if (s.isEmpty) return null;
  return int.tryParse(s);
}

/// Allows up to [intDigits] integer digits and up to [decimals] decimal
/// places (vitals rule 2026-08-14: max 3 digits, decimals max 2 — and
/// max 1 for height/weight).
class _DecimalFormatter extends TextInputFormatter {
  final int intDigits;
  final int decimals;
  _DecimalFormatter(this.intDigits, {this.decimals = 2});
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final t = newValue.text;
    if (t.isEmpty) return newValue;
    return RegExp('^\\d{0,$intDigits}(\\.\\d{0,$decimals})?\$').hasMatch(t) ? newValue : oldValue;
  }
}

class CounRegister extends StatefulWidget {
  /// Called after a patient is successfully saved. The shell uses this to
  /// jump back to the Home tab so the counsellor lands on the newly-registered
  /// patient at the top of the list.
  final VoidCallback? onSubmitted;
  const CounRegister({super.key, this.onSubmitted});
  @override
  State<CounRegister> createState() => _CounRegisterState();
}

class _CounRegisterState extends State<CounRegister> {
  /// Bumped on every _reset() so the VoiceMicButton (patient remarks) gets
  /// a fresh key. That forces Flutter to dispose the old widget State —
  /// killing any in-flight speech recognition, and dropping the internal
  /// `_base` transcript that would otherwise leak into the next patient's
  /// form. Root cause of "old value showing on user2's remarks field".
  int _voiceMicSeq = 0;

  /// True while _submit is uploading photos + enqueuing. Blocks double-tap
  /// and swaps the Submit button label so the counsellor sees why the form
  /// is holding for a moment on photo-heavy registrations.
  bool _submitting = false;

  // basic
  final _name = TextEditingController();
  String gender = 'Female';
  bool pregnant = false;
  // For pregnant patients the counsellor records whichever date they know
  // (user 2026-08-14): LMP (last menstrual period — PAST dates only) or
  // EDD (expected delivery date — FUTURE dates only). In LMP mode the EDD
  // is auto-derived as LMP + 280 days (Naegele's rule); in EDD mode only
  // edd_date is sent. `_lmp` holds the picked date for either mode.
  DateTime? _lmp;
  String _pregMode = 'LMP';
  bool knowAge = true;
  DateTime? _dob;
  final _age = TextEditingController();
  final _contact = TextEditingController();
  // Unique Code field removed 2026-07-29 per user rule. Contact is now
  // the sole patient identifier.
  String? block;
  String? village;
  static const _kLastBlock = 'coun_last_block';
  static const _kLastVillage = 'coun_last_village';
  // advance
  final _aadhar = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  String? bloodGroup;
  String? category;
  String pwd = 'No';
  final _pin = TextEditingController();
  // State + District are inherited from the counsellor's assigned MMU
  // profile (user rule 2026-07-29). No UI pickers — resolved via
  // AppState.currentMmu at submit time.
  final _address = TextEditingController();
  final List<String> symptoms = [];
  // Preview advisory (user 2026-08-27): counsellor's Register screen
  // now fetches the same village-boosted trending + related list the
  // doctor would see, so both surfaces stay in sync.
  Timer? _previewDebounce;
  List<Map<String, dynamic>>? _previewTrending;
  List<String>? _previewRelated;
  List<Map<String, dynamic>>? _previewLikely;
  bool _previewLoading = false;
  bool _previewError = false;
  String _lastPreviewKey = '';
  // collapsible sections (CR25)
  bool showAdvanced = false;
  bool showVitals = false;
  // vitals
  final _sys = TextEditingController();
  final _dia = TextEditingController();
  final _sugar = TextEditingController();
  final _temp = TextEditingController();
  final _spo2 = TextEditingController();
  final _hr = TextEditingController();
  final _hb = TextEditingController();
  // assignment
  bool onMed = false;
  String payment = 'Free';
  final _amount = TextEditingController();
  String? doctor;
  // Real doctors of this org from GET /staff?role=doctor (rule
  // 2026-08-13 — the dropdown was the hardcoded kDoctors demo list).
  // Rows: {staff_id, staff_name, ...}. Empty until the fetch lands;
  // the dropdown falls back to kDoctors so the form stays usable
  // offline / on first launch.
  List<Map<String, dynamic>> _doctors = const [];
  // Appointment Date defaults to today (rule 2026-07-29). The DateField
  // picks this up via `initial:` and displays it on first render; _reset()
  // reassigns to today so a fresh registration is always pre-filled.
  DateTime? _apptDate = DateTime.now();
  final _remarks = TextEditingController();
  // Multi-attachment upload: prescriptions + reports + other docs, each with
  // its own description. Attachments carry into the doctor's Case Details
  // under "Prescription and Reports".
  final List<Attachment> _attachments = [];

  // Source patient set when the counsellor opens Re-Appointment from a
  // Patient Detail page (rule 2026-07-31). Used in _submit to carry over
  // pastHistory / previousRx / attachments so the doctor sees the history
  // on the new appointment record.
  CPatient? _reAppointmentSource;

  @override
  void dispose() {
    _previewDebounce?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Pull the org's real doctor roster once the provider tree is up.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDoctors());
    // Restore the last block/village this counsellor picked (user
    // 2026-08-25) — logout clears the keys so a different user starts blank.
    () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final b = prefs.getString(_kLastBlock);
        final v = prefs.getString(_kLastVillage);
        if (!mounted || (b == null && v == null)) return;
        setState(() { block = b; village = v; });
        // Sticky village → warm the trending fetch so the symptom
        // dropdown opens with "Common in <village>" ready on first tap
        // (user 2026-09-08).
        if (v != null) {
          _previewDebounce?.cancel();
          _previewDebounce = Timer(const Duration(milliseconds: 300), _fetchPreview);
        }
      } catch (_) {}
    }();
    // Warm up the hi→en translation models in the background so the
    // first submit with remarks is instant (skipped entirely if the
    // remarks field is left blank).
    TranslationService.warmUp();
    // Load the counsellor's most-used fees so the quick-pick chips
    // reflect real prescribing habits (user 2026-09-11).
    _loadFrequentFees();
  }

  // ─── Frequently-used consultation fees ─────────────────────────────
  // Last 20 accepted amounts persisted in SharedPreferences; top-4 by
  // count feed the chips under Paid Amount. Static defaults show only
  // while the history is empty.
  static const _kFeeHistory = 'reg_fee_history_v1';
  List<int> _frequentFees = const [200, 300, 500, 1000];

  Future<void> _loadFrequentFees() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_kFeeHistory) ?? const [];
      if (raw.isEmpty) return;
      final count = <int, int>{};
      for (final s in raw) {
        final n = int.tryParse(s);
        if (n == null || n <= 0) continue;
        count[n] = (count[n] ?? 0) + 1;
      }
      final top = count.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final picks = top.take(4).map((e) => e.key).toList();
      if (mounted && picks.isNotEmpty) {
        setState(() => _frequentFees = picks);
      }
    } catch (_) {}
  }

  Future<void> _rememberFee(int amount) async {
    if (amount <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = (prefs.getStringList(_kFeeHistory) ?? const []).toList();
      list.add(amount.toString());
      // Keep the last 20 so the ranking follows recent habit, not
      // ancient one-offs.
      if (list.length > 20) list.removeRange(0, list.length - 20);
      await prefs.setStringList(_kFeeHistory, list);
    } catch (_) {}
  }

  /// Debounced call to /advisory/preview so the Register screen's
  /// Related + Likely panels match the Doctor's Case Details (user
  /// 2026-08-27). Fires 500 ms after the last chip/village change;
  /// no-op when the same (symptoms, village) has already been fetched.
  void _schedulePreview() {
    _previewDebounce?.cancel();
    // Immediately flip to loading so panels show "analyzing…" instead
    // of the stale reply from the previous chip set (user 2026-08-27).
    if (symptoms.isNotEmpty && !_previewLoading) {
      _previewLoading = true;
    }
    _previewDebounce = Timer(const Duration(milliseconds: 500), _fetchPreview);
  }

  Future<void> _fetchPreview() async {
    if (!mounted) return;
    final vid = context.read<MastersStore>().geoVillageId(block, village);
    // Symptoms may be empty on first tap — still fetch village trending
    // so the dropdown opens with "Common in <village>" ready to pick
    // (user 2026-09-08). Server returns trending-only when inputs are
    // empty; related/likely/advisory stay null and the panels hide.
    if (symptoms.isEmpty && vid == null) {
      if (_previewTrending != null || _previewRelated != null
          || _previewLikely != null || _previewLoading) {
        setState(() {
          _previewTrending = null;
          _previewRelated = null;
          _previewLikely = null;
          _previewLoading = false;
        });
      }
      return;
    }
    final key = '${symptoms.join("|")}|v=$vid';
    if (key == _lastPreviewKey) return;
    _lastPreviewKey = key;
    try {
      final body = await context.read<AppointmentsApi>()
          .advisoryPreview(symptoms: symptoms, villageId: vid);
      if (!mounted) return;
      final common = (body['common_in_village'] as Map?)?.cast<String, dynamic>();
      setState(() {
        _previewTrending = [
          for (final t in (common?['trending'] as List? ?? const []))
            if (t is Map) t.cast<String, dynamic>(),
        ];
        _previewRelated = [
          for (final r in (body['related_symptoms'] as List? ?? const []))
            if (r is Map && (r['symptom'] ?? '').toString().trim().isNotEmpty)
              (r['symptom'] as Object).toString(),
        ];
        _previewLikely = [
          for (final c in (body['likely_conditions'] as List? ?? const []))
            if (c is Map) c.cast<String, dynamic>(),
        ];
        _previewLoading = false;
        _previewError = false;
      });
    } catch (_) {
      // Offline / server unavailable — friendly error strip with Retry
      // (user 2026-08-28). Reset the key so Retry actually re-fetches.
      _lastPreviewKey = '';
      if (mounted) {
        setState(() { _previewLoading = false; _previewError = true; });
      }
    }
  }

  Future<void> _loadDoctors() async {
    if (!mounted) return;
    final facilityId = context.read<AppState>().backendFacilityId;
    // Hydrate from OFFLINE CACHE first (user bug 2026-08-20 "offline
    // doctor not downloading, empty dropdown blocks submit"). The
    // freshly-fetched list overwrites this later if online succeeds.
    if (facilityId != null) {
      try {
        final store = await StaffCacheStore.open();
        final cached = store.load('doctor', facilityId);
        if (cached.isNotEmpty && mounted) {
          _applyDoctors(cached);
        }
      } catch (_) {/* first launch — nothing cached */}
    }
    try {
      final rows = await context.read<StaffApi>()
          .list(role: 'doctor', facilityId: facilityId, withLogin: true);
      if (!mounted || rows.isEmpty) return;
      _applyDoctors(rows);
      // Persist for the next offline open.
      if (facilityId != null) {
        try {
          final store = await StaffCacheStore.open();
          await store.save('doctor', facilityId, rows);
        } catch (_) {/* best-effort */}
      }
    } catch (_) {
      // Offline / server hiccup — cache hydrate already ran, so the
      // dropdown has whatever the last successful fetch stored.
    }
  }

  void _applyDoctors(List<Map<String, dynamic>> rows) {
    // Safety on messy data: drop inactive rows, then collapse exact
    // duplicate names (first row wins → its staff_id is what submits).
    final seen = <String>{};
    final cleaned = <Map<String, dynamic>>[
      for (final r in rows)
        if ((r['is_active'] as bool? ?? true) &&
            seen.add((r['staff_name'] ?? '').toString().trim()))
          r,
    ];
    if (cleaned.isEmpty) return;
    setState(() {
      _doctors = cleaned;
      // One doctor per MMU is the normal case (user rule 2026-08-14):
      // pre-select them so the counsellor never has to touch the field.
      if (cleaned.length == 1) {
        doctor = (cleaned.first['staff_name'] ?? '').toString();
      }
    });
  }

  /// Dropdown labels — backend roster ONLY (user rule 2026-08-13: no
  /// hardcoded demo fallback). Until the fetch lands the dropdown is
  /// empty and disabled; SearchDropdown handles the empty list.
  List<String> get _doctorNames =>
      [for (final d in _doctors) (d['staff_name'] ?? '').toString()];

  /// staff_id of the selected doctor — null when the fallback demo list is
  /// in use or nothing selected.
  int? get _selectedDoctorId {
    for (final d in _doctors) {
      if ((d['staff_name'] ?? '').toString() == doctor) {
        return (d['staff_id'] as num?)?.toInt();
      }
    }
    return null;
  }

  String? _contactError(String v) {
    if (v.isEmpty) return null;
    if (v.length != 10) return 'Must be 10 digits';
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v)) return 'Must start 6-9';
    if (RegExp(r'^(\d)\1{9}$').hasMatch(v)) return 'Invalid number';
    return null;
  }

  int _ageFromDob(DateTime d) {
    final now = DateTime.now();
    var a = now.year - d.year;
    if (now.month < d.month || (now.month == d.month && now.day < d.day)) a--;
    return a < 0 ? 0 : a;
  }

  Future<void> _submit(CounsellorState s) async {
    if (_submitting) return; // double-tap guard while photos upload
    // Drop focus BEFORE any validation or setState. If the symptoms field
    // still holds focus when _reset() rebuilds the form, the enclosing
    // SingleChildScrollView auto-scrolls to reveal that field — which the
    // user sees as "the form jumped back to the symptoms dropdown".
    FocusManager.instance.primaryFocus?.unfocus();
    void err(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: C2.danger));
    if (_name.text.trim().isEmpty) return err('Enter patient name');
    if (knowAge && _age.text.trim().isEmpty) return err('Enter age');
    if (knowAge && _ageErr() != null) return err('Age must be between $_minAgeYears and $_maxAgeYears years');
    if (!knowAge && _dob == null) return err('Select date of birth');
    if (!knowAge && _dobErr() != null) {
      return err('Date of birth must give an age between '
          '$_minAgeYears and $_maxAgeYears years');
    }
    final ce = _contactError(_contact.text.trim());
    // Contact is required now that Unique Code is removed (rule 2026-07-29).
    if (_contact.text.trim().isEmpty) return err('Enter contact number');
    if (ce != null) return err('Contact: $ce');
    // State + District are inherited from the counsellor's assigned
    // profile (rule 2026-07-29); only block + village are picked here.
    if (block == null) return err('Select block');
    if (village == null) return err('Select village');
    // Symptoms are mandatory (user 2026-08-22) — a visit with no recorded
    // complaint gives the doctor and the advisory nothing to work from.
    if (symptoms.isEmpty) return err('Select at least one symptom');
    if (doctor == null) return err('Select doctor assignment');
    // Paid orgs must always collect a consultation fee (payment is
    // pinned to Paid by the render Builder). Free orgs skip this
    // entirely — no amount asked (user 2026-09-02).
    final _paidOrgReg = !context.read<AppState>().orgIsFree;
    if (_paidOrgReg && _amount.text.trim().isEmpty) return err('Enter paid amount');
    // Pin the payment variable to match the org gate so a race between
    // build's post-frame flip and submit can't send the wrong pair.
    payment = _paidOrgReg ? 'Paid' : 'Free';
    if (onMed && _attachments.isEmpty) return err('Attach at least one prescription or report');
    if (pregnant && _lmp == null) return err('Pick the $_pregMode date');
    // Vitals + height/weight are optional, but anything typed must
    // satisfy the 2–3 digit rule (user 2026-08-14) — the field already
    // shows the inline error.
    if ([_sys, _dia, _sugar, _temp, _spo2, _hr, _hb, _height, _weight]
        .any((c) => _vitalMinErr(c) != null)) {
      return err('Check the highlighted vital values — out of allowed range');
    }

    // ── Photo upload happens at SUBMIT, not at capture (user rule
    // 2026-08-13) — capturing then abandoning the form must not leave
    // orphan files on the server. Each photo that hasn't been uploaded
    // yet goes up now; on success the row gains its server name
    // ("patient_docs/<uuid>.jpg"). Offline / timeout → the local path
    // stays as fallback and the registration still goes through.
    //
    // _submitting stays TRUE through EVERY awaited step below — uploads,
    // translation, addPatient, sync enqueue, redirect — so a second
    // Submit tap during the 8-second translation window can never
    // create a duplicate patient (user 2026-09-02: registered Shyam,
    // waited for the "Submitting…" state, tapped again and got two
    // rows in the queue, one blank).
    setState(() => _submitting = true);
    try {
      final uploads = context.read<UploadsApi>();
      if (_attachments.isNotEmpty) {
        await Future.wait([
          for (var i = 0; i < _attachments.length; i++)
            if (_attachments[i].serverPath == null)
              (() async {
                try {
                  final res = await uploads
                      .uploadImage(_attachments[i].path)
                      .timeout(const Duration(seconds: 3));
                  final name = (res['file_name'] as String?) ?? '';
                  if (name.isNotEmpty) {
                    _attachments[i] = _attachments[i].copyWith(serverPath: name);
                  }
                } catch (_) {
                  // Offline, slow network, or timeout — keep the phone-local path.
                  // SyncService._liftPhotos will automatically lift it in the background when online.
                }
              })(),
        ]);
      }
      if (!mounted) return;
      await _submitAfterUploads(s);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitAfterUploads(CounsellorState s) async {
    void err(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: C2.danger));

    final vitals = <String, String>{};
    void v(String k, TextEditingController c) { if (c.text.trim().isNotEmpty) vitals[k] = c.text.trim(); }
    v('Systolic BP', _sys); v('Diastolic BP', _dia); v('Blood Sugar', _sugar);
    v('Body Temp (°F)', _temp); v('Oxygen Saturation', _spo2); v('Heart Rate', _hr); v('Hemoglobin', _hb);

    // Re-Appointment carry-over (rule 2026-07-31). If the counsellor
    // launched this from a Patient Detail, propagate history so the doctor
    // sees Past Medical History, previous Rx and prior diagnosis on the
    // new record. Falls back to empty defaults for a fresh registration.
    final src = _reAppointmentSource;
    final carryDisease  = src?.disease ?? '';
    // Fold the previous diagnosis into Past Medical History (rule 2026-08-05)
    // so the doctor sees it on the PMH card in Case Details. Existing PMH
    // text is preserved so nothing typed on the last visit gets lost.
    String carryPast    = src?.pastHistory ?? '';
    if (src != null && carryDisease.trim().isNotEmpty) {
      final tag = 'Previous Diagnosis (${src.regDate.isEmpty ? "—" : src.regDate}): $carryDisease';
      carryPast = carryPast.trim().isEmpty ? tag : '$tag\n$carryPast';
    }
    // previousRx = source's own previousRx history + last visit's
    // prescription (converted from RxItem → PrevRx).
    final carryPrevRx = <PrevRx>[
      if (src != null) ...src.previousRx,
      if (src != null)
        ...src.prescription.map((m) => PrevRx(
          medicine: m.name,
          dosage:   m.dosage,
          frequency: m.interval,
          duration:  m.days,
          date:      src.regDate.isEmpty ? '—' : src.regDate,
        )),
    ];
    // Attachments carry over so previous prescriptions and reports show up
    // on the doctor screen. New attachments captured this visit are
    // appended after the carry-overs.
    final carryAttachments = <Attachment>[
      if (src != null) ...src.attachments,
      ..._attachments,
    ];
    // Fix 2026-08-05: on Re-Appointment the doctor screen must show the
    // PREVIOUS diagnosis + medicines pre-selected (editable) so the doctor
    // can carry the treatment forward. Deep-copy the source's prescription
    // so edits made this visit don't mutate the source's stored Rx before
    // Submit. For a fresh (non re-appointment) registration `src` is null
    // and both fall back to their empty defaults.
    final carryPrescription = <RxItem>[
      if (src != null)
        ...src.prescription.map((m) => RxItem(
          name: m.name, dosage: m.dosage,
          days: m.days, interval: m.interval, qty: m.qty,
        )),
    ];

    // Remarks: OPTIONAL field. Translate ONLY when there is text
    // (user 2026-08-20 "if no remarks then no need to translate").
    // SILENT (user 2026-08-22 "dont show this message") — no modal; the
    // translation runs inline with a hard 8 s cap so Submit never feels
    // stuck. Worst case the original rides in both columns.
    final remarksHi = _remarks.text.trim();
    String remarksEn = remarksHi;
    if (remarksHi.isNotEmpty) {
      try {
        remarksEn = await TranslationService.hiToEn(remarksHi)
            .timeout(const Duration(seconds: 2));
      } catch (_) {/* capped — raw text in both columns */}
    }

    final p = CPatient(
      id: s.nextId(),
      name: _name.text.trim(),
      gender: gender,
      age: knowAge ? (int.tryParse(_age.text) ?? 0) : (_dob != null ? _ageFromDob(_dob!) : 0),
      dob: _dob != null ? fmtDate(_dob!) : '',
      contact: _contact.text.trim(),
      // Unique Code removed 2026-07-29 — auto-generate a fallback so any
      // downstream code still expecting one keeps working. The value is
      // no longer surfaced anywhere in the UI.
      uniqueCode: s.nextUniqueCode(),
      block: block!,
      village: village!,
      symptoms: List.from(symptoms),
      // Re-Appointment carries the PREVIOUS visit's real diagnosis for
      // display; a fresh registration has NO disease — the ML guess is
      // no longer stored anywhere (user 2026-08-22), it only lives in
      // the live Likely-Conditions panel.
      disease: carryDisease,
      // Re-Appointment: previous medicines pre-loaded on the doctor screen
      // (editable — doctor can add / remove / change dosage before Submit).
      prescription: carryPrescription,
      vitals: vitals,
      pregnant: pregnant,
      remarks: remarksEn,
      uploadedRx: carryAttachments.isNotEmpty ? carryAttachments.first.path : '',
      attachments: carryAttachments,
      regDate: _apptDate != null ? fmtDate(_apptDate!) : fmtDate(DateTime.now()),
      // Explicit — new appointment / re-appointment must land in the doctor
      // queue (rule 2026-07-31). doctorQueue filters on status 'registered'
      // | 'with_doctor', so this is what carries the patient across.
      status: 'registered',
      registeredOn: 'Today',
      pastHistory: carryPast,
      previousRx:  carryPrevRx,
      // Persist Advance Details so re-appointment can round-trip them.
      aadhar:      _aadhar.text.trim(),
      heightCm:    _height.text.trim(),
      weightKg:    _weight.text.trim(),
      bloodGroup:  bloodGroup,
      category:    category,
      pwd:         pwd,
      pin:         _pin.text.trim(),
      address:     _address.text.trim(),
    );
    s.addPatient(p);
    // Belt + braces: force a notify so any doctor screen already mounted
    // rebuilds against the fresh queue.
    s.updateRequisitions();
    // Enqueue the mutation for /mobile/sync/push (v2 §4). The action is
    // idempotent by client_action_id so a replay is safe; the local
    // insert above still gives the counsellor an instant Home tile.
    //
    // Payload carries the FULL patient + appointment shape so nothing the
    // counsellor typed is dropped on the way through the sync path. The
    // backend's `_register` handler in mobile.py maps these into the same
    // INSERT statements that `POST /patients` + `POST /appointments` use,
    // so an offline registration ends up equivalent to an online one.
    final masters = context.read<MastersStore>();
    final appState = context.read<AppState>();

    // Master-driven only. Resolve symptom name → id via the masters
    // cache and send `symptom_ids` alone. Names that don't resolve are
    // dropped here rather than sent as free-text — polluting the
    // symptom_master with client-typed variants ("Rash" vs "Skin rash")
    // is a data-quality problem the backend team should fix by seeding
    // the master properly, not by client auto-add. The mobile symptom
    // picker is already restricted to master-list entries, so a miss
    // here means the counsellor typed something outside that list.
    final symptomRows = masters.masterRows('symptoms');
    final symptomIds = <int>[
      for (final s in symptoms)
        if (_lookupIdByName(symptomRows, s, idKey: 'id', nameKey: 'term') is int)
          _lookupIdByName(symptomRows, s, idKey: 'id', nameKey: 'term')!,
    ];

    // Resolve category label → id via masters.categories. Bootstrap
    // returns rows as `{id, name}` so the plain 'id'/'name' keys work
    // (the fallback in _lookupIdByName also covers the aliased shape).
    final categoryId = _lookupIdByName(
      masters.masterRows('categories'), category,
      idKey: 'id', nameKey: 'name');

    // NO diagnoses at registration (user 2026-08-22 "Diagnosis showing
    // Viral which one I didn't choose"): the app used to save its ML
    // "likely condition" guess as a REAL appointment_diagnosis row, so
    // records carried a diagnosis nobody picked. Diagnoses are the
    // DOCTOR's to make — their Submit Case creates the rows.
    final diagnoses = const <Map<String, dynamic>>[];

    // Attachments — Prescription / Report / Other photos the counsellor
    // picked up at registration. Each photo was uploaded to
    // /api/mobile/uploads the moment it was captured; `serverPath` holds
    // the returned "patient_docs/<random>.jpg" name that any device can
    // fetch via GET /uploads/<name>. Falls back to the phone-local path
    // only when the upload never landed (offline capture) so the record
    // still notes a photo existed.
    final attachments = <Map<String, dynamic>>[
      for (final a in _attachments)
        {
          'file_path': a.serverPath ?? a.path,
          'kind': a.kind.label,
          if (a.description.isNotEmpty) 'description': a.description,
        },
    ];

    // Age/DOB: form enforces one-or-the-other, so send whichever is set.
    // DOB is preferred when the user picked the calendar option.
    final ageValue = knowAge
        ? (int.tryParse(_age.text.trim()))
        : (_dob != null ? _ageFromDob(_dob!) : null);
    final dobValue = (!knowAge && _dob != null) ? _isoDate(_dob!) : null;

    // Pregnancy dates — only meaningful when `pregnant` is true.
    // LMP mode: lmp_date + derived edd_date. EDD mode: edd_date only —
    // the counsellor picked the delivery date directly.
    final lmpIso = (pregnant && _pregMode == 'LMP' && _lmp != null)
        ? _isoDate(_lmp!) : null;
    final eddIso = (pregnant && _lmp != null)
        ? (_pregMode == 'LMP'
            ? _isoDate(_lmp!.add(const Duration(days: 280)))
            : _isoDate(_lmp!))
        : null;

    // Aadhaar / pin: send only when they look valid so the backend
    // regex CHECK doesn't 422 on partial numbers.
    final aadharDigits = _aadhar.text.trim();
    final aadharValue = RegExp(r'^\d{12}$').hasMatch(aadharDigits)
        ? aadharDigits : null;
    final pinDigits = _pin.text.trim();
    final pinValue = RegExp(r'^[1-9]\d{5}$').hasMatch(pinDigits)
        ? pinDigits : null;

    // Re-Appointment: hand the existing backend patient_id to the
    // server so `/mobile/sync/push` (mobile._register) attaches the new
    // appointment to the same patient row instead of inserting a
    // duplicate (user rule 2026-08-16).
    final reappointmentPatientId = _reAppointmentSource?.backendPatientId;
    final sync = context.read<SyncService>();
    await sync.enqueue(kind: 'patient.register', payload: {
      if (reappointmentPatientId != null) 'patient_id': reappointmentPatientId,
      // Basic identity
      'patient_name':      p.name,
      'gender':            p.gender,
      if (ageValue != null) 'age': ageValue,
      if (dobValue != null) 'dob': dobValue,
      'contact_number':    p.contact,
      // Address / geography — names carry the resolve chain the backend
      // uses to look up the ids inside _resolve_geography.
      'state_name':        appState.backendStateName ?? appState.currentMmuState,
      'district_name':     appState.backendDistrictName ?? appState.currentMmuDistrict,
      'block_name':        p.block,
      'village_name':      p.village,
      if (pinValue != null)   'pin_code': pinValue,
      if (_address.text.trim().isNotEmpty) 'address': _address.text.trim(),
      // Identity extras
      if (aadharValue != null)     'aadhar_number': aadharValue,
      // blood_group_id preferred — server skips the name-lookup when
      // the id is present (user 2026-09-10 id-first). Name still sent
      // as fallback so an older server build reads it unchanged.
      if (bloodGroup != null)      'blood_group': bloodGroup,
      if (bloodGroup != null &&
          masters.masterIdOf('blood_groups', bloodGroup) != null)
                                   'blood_group_id': masters.masterIdOf('blood_groups', bloodGroup),
      if (categoryId != null)      'category_id': categoryId,
      // Village id — resolved from the geo cascade already. Extra
      // `_id` keys let the server skip the get_or_create name path.
      if (masters.geoVillageId(block, village) != null)
                                   'village_id': masters.geoVillageId(block, village),
      'disability':                pwd == 'Yes',
      if (p.pastHistory.trim().isNotEmpty) 'past_history': p.pastHistory,
      // Appointment leg
      // ISO date (yyyy-mm-dd) — backend Pydantic AppointmentIn expects
      // Python `date` format, NOT the dd-MM-yyyy display format that
      // CPatient.regDate uses.
      'appointment_date':  _isoDate(_apptDate ?? DateTime.now()),
      // staff_id of the assigned doctor (backend roster). Null when the
      // offline fallback list was used — server stores NULL, same as a
      // legacy handset.
      if (_selectedDoctorId != null) 'assigned_doctor_id': _selectedDoctorId,
      'payment_type':      payment,
      'paid_amount':       payment == 'Paid'
          ? (num.tryParse(_amount.text.trim()) ?? 0) : 0,
      'pregnant':          pregnant,
      if (lmpIso != null) 'lmp_date': lmpIso,
      if (eddIso != null) 'edd_date': eddIso,
      'taken_prescribed_medicine': onMed,
      // Final design 2026-08-22 (DB owner): ORIGINAL as dictated →
      // patients.remarks via counsellor_remarks; the app-side translation →
      // patients.remarks_english. Blank field → neither key is sent, the
      // server stores ''.
      if (remarksHi.isNotEmpty)
        'counsellor_remarks': remarksHi,
      if (remarksEn.isNotEmpty)
        'counsellor_remarks_english': remarksEn,
      // Vitals — send only fields the counsellor actually typed so a
      // NULL doesn't get stored as a real reading.
      if (_asInt(_sys)      != null) 'systolic_bp':  _asInt(_sys),
      if (_asInt(_dia)      != null) 'diastolic_bp': _asInt(_dia),
      if (_asInt(_sugar)    != null) 'blood_sugar':  _asInt(_sugar),
      if (_asDouble(_temp)  != null) 'body_temp':    _asDouble(_temp),
      if (_asDouble(_spo2)  != null) 'oxygen':       _asDouble(_spo2),
      if (_asInt(_hr)       != null) 'heart_rate':   _asInt(_hr),
      if (_asDouble(_hb)    != null) 'hemoglobin':   _asDouble(_hb),
      if (_asDouble(_height) != null) 'height':      _asDouble(_height),
      if (_asDouble(_weight) != null) 'weight':      _asDouble(_weight),
      // Clinical arrays — child tables the backend will insert:
      //   appointment_symptom  ← symptom_ids (master-driven, no free-text)
      //   appointment_diagnosis ← diagnoses (text-primary; disease_id optional)
      //   appointment_attachment ← attachments
      if (symptomIds.isNotEmpty)  'symptom_ids': symptomIds,
      if (diagnoses.isNotEmpty)   'diagnoses':   diagnoses,
      if (attachments.isNotEmpty) 'attachments': attachments,
    });
    // Action is safely persisted in the offline sync queue and drain() runs
    // in the background. Redirect immediately without blocking the UI.
    // Redirect FIRST, then show the snackbar. Any unexpected throw between
    // enqueue and this line was leaving the counsellor stranded on the
    // register form with the patient already saved (user 2026-08-20:
    // "data is saving but not redirecting anywhere"). Doing the redirect
    // immediately after the local addPatient makes the tab switch
    // unconditional; snackbar + reset run on the way out.
    try {
      // Remember today's location for the next patient — clears on logout.
      () async {
        try {
          final prefs = await SharedPreferences.getInstance();
          if (block != null && block!.isNotEmpty) {
            await prefs.setString(_kLastBlock, block!);
          }
          if (village != null && village!.isNotEmpty) {
            await prefs.setString(_kLastVillage, village!);
          }
        } catch (_) {}
      }();
      widget.onSubmitted?.call();
    } catch (_) {/* redirect must never block the toast/reset below */}
    // Remember this fee so the Paid Amount chips rank by real usage
    // (user 2026-09-11). Only paid orgs write; free orgs stay at ₹0.
    if (payment == 'Paid') {
      final feeVal = int.tryParse(_amount.text.trim());
      if (feeVal != null && feeVal > 0) {
        await _rememberFee(feeVal);
        await _loadFrequentFees();
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${p.name} added to Doctor Queue'),
      backgroundColor: C2.green,
    ));
    _reset();
  }

  void _reset() {
    setState(() {
      for (final c in [_name,_age,_contact,_aadhar,_height,_weight,_pin,_address,_sys,_dia,_sugar,_temp,_spo2,_hr,_hb,_amount,_remarks]) {
        c.clear();
      }
      gender = 'Female'; pregnant = false; _lmp = null; _pregMode = 'LMP'; knowAge = true; _dob = null;
      // Location sticks across submits (user 2026-08-25) — MMU camps one
      // village at a time; logout wipes the prefs so a different user
      // starts blank. block + village intentionally NOT cleared here.
      // state + district removed 2026-07-29 — inherited from AppState.
      showAdvanced = false; showVitals = false;
      bloodGroup = null; category = null; pwd = 'No'; onMed = false; payment = 'Free';
      // Single-doctor MMU: keep them selected across resets — the field
      // is locked, there is nothing else to pick (user rule 2026-08-14).
      doctor = _doctors.length == 1
          ? (_doctors.first['staff_name'] ?? '').toString()
          : null;
      _apptDate = DateTime.now(); symptoms.clear(); _attachments.clear();
      // Drop the re-appointment source so the next fresh registration
      // doesn't accidentally inherit history from the previous submit.
      _reAppointmentSource = null;
      // Bump the mic key so the VoiceMicButton on Patient Remarks is
      // fully torn down + rebuilt — otherwise its in-flight speech
      // recogniser (with the previous patient's transcript in `_base`)
      // keeps writing to the freshly-cleared controller as new words
      // arrive, resurrecting the old text.
      _voiceMicSeq++;
    });
  }

  /// Apply demographic + Advance Details from an existing patient. Called
  /// on the frame after the counsellor taps "Re-Appointment" in the Status
  /// list. Source patient is stashed so _submit can carry pastHistory /
  /// previousRx / attachments over to the fresh appointment record.
  void _applyPrefill(CPatient p) {
    setState(() {
      _reAppointmentSource = p;
      _name.text = p.name;
      if (const ['Female','Male','Other'].contains(p.gender)) gender = p.gender;
      pregnant = p.pregnant;
      // Re-select the pregnancy date (user 2026-08-21): an LMP on record
      // wins (the EDD next to it is just LMP+280); an EDD-only record
      // re-opens in EDD mode. Nothing on record → picker stays blank.
      final prevLmp = DateTime.tryParse(p.lmpDate);
      final prevEdd = DateTime.tryParse(p.eddDate);
      final today = DateTime.now();
      if (pregnant && prevLmp != null) {
        _pregMode = 'LMP'; _lmp = prevLmp;
      } else if (pregnant && prevEdd != null &&
          !prevEdd.isBefore(DateTime(today.year, today.month, today.day))) {
        // EDD mode only allows future dates — an already-passed EDD
        // (delivered) would break the picker, so it stays blank instead.
        _pregMode = 'EDD'; _lmp = prevEdd;
      } else {
        _pregMode = 'LMP'; _lmp = null;
      }
      knowAge = true;
      _age.text = p.age > 0 ? p.age.toString() : '';
      _dob = null;
      _contact.text = p.contact;
      block = p.block.isEmpty ? null : p.block;
      village = p.village.isEmpty ? null : p.village;
      // INPUT gets the ORIGINAL as dictated, never the English display
      // copy (user 2026-08-22 "dont show english version in inputs").
      _remarks.text =
          p.remarksOriginal.isNotEmpty ? p.remarksOriginal : p.remarks;
      // Carry the previous symptom picks over (rule 2026-07-31) so the
      // counsellor can just tweak them for today's visit instead of
      // re-selecting from scratch.
      symptoms
        ..clear()
        ..addAll(p.symptoms);
      // Vitals prefill (user rule 2026-08-13): show the LAST visit's
      // readings so the counsellor sees them selected and just updates
      // what changed. Keys cover both spellings the app has written —
      // 'Oxygen' (backend hydrate) and 'Oxygen Saturation' (local form).
      String vital(List<String> keys) {
        for (final k in keys) {
          final v = p.vitals[k];
          if (v != null && v.trim().isNotEmpty) return _wholeNumber(v.trim());
        }
        return '';
      }
      _sys.text   = vital(['Systolic BP']);
      _dia.text   = vital(['Diastolic BP']);
      _sugar.text = vital(['Blood Sugar']);
      _temp.text  = vital(['Body Temp (°F)']);
      _spo2.text  = vital(['Oxygen', 'Oxygen Saturation']);
      _hr.text    = vital(['Heart Rate']);
      _hb.text    = vital(['Hemoglobin']);
      // Auto-expand the vitals section when anything came through, so the
      // prefill is visible instead of hiding behind the collapsed toggle.
      showVitals = [_sys, _dia, _sugar, _temp, _spo2, _hr, _hb]
          .any((c) => c.text.isNotEmpty);
      _attachments.clear();
      // Previous visit's doctor pre-selected (rule 2026-08-13) — the
      // hydrate stored their staff_name; keep it only when it exists in
      // the loaded roster so the dropdown never shows a stale name.
      doctor = (p.assignedDoctor != null &&
              _doctorNames.contains(p.assignedDoctor))
          ? p.assignedDoctor
          : null;
      payment = 'Free';
      _amount.clear();
      _apptDate = DateTime.now();
      // Advance Details prefill (rule 2026-07-31) — Aadhaar, height, weight,
      // blood group, category, PwD flag, pincode, address. Section is
      // auto-expanded so the counsellor sees the values right away.
      _aadhar.text = p.aadhar;
      _height.text = _wholeNumber(p.heightCm);
      _weight.text = _wholeNumber(p.weightKg);
      bloodGroup   = p.bloodGroup;
      category     = p.category;
      pwd          = p.pwd.isEmpty ? 'No' : p.pwd;
      _pin.text    = p.pin;
      _address.text = p.address;
      showAdvanced = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<CounsellorState>();
    // Abandoned re-appointment residue: the shell raised this flag because
    // the counsellor entered Register normally. Reset ONLY when the form is
    // actually still in re-appointment mode — a half-typed fresh
    // registration is left untouched.
    if (s.consumeAbandonedReAppointmentClear() &&
        _reAppointmentSource != null && !s.hasPrefill) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reset();
      });
    }
    // Full tab-leave reset (user rule 2026-08-16): the shell raised
    // this flag when the counsellor navigated AWAY from Register in-app
    // (tab switch or back button). Blank everything so the next entry
    // is a fresh form. Skipped if a Re-Appointment is being staged
    // (hasPrefill) — that flow wants the prefill preserved.
    if (s.consumeRegisterFullReset() && !s.hasPrefill) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reset();
      });
    }
    // If Status handed us a patient to re-appoint, consume it after the frame
    // so setState is safe and the notifier doesn't trigger a rebuild loop.
    if (s.hasPrefill) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final p = s.consumePrefill();
        if (p != null) _applyPrefill(p);
      });
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.only(left: 4, bottom: 4), child: SecBar('Fill Appointment')),
      Text('Note: Fields marked * are mandatory.', style: ct(11.5, FontWeight.w400, C2.text2)),
      const SizedBox(height: 10),

      // BASIC
      CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SecBar('Basic Details'),
        CField('Name', TextField(controller: _name, decoration: cInput('Patient name')), required: true),
        // Switching gender resets the WHOLE pregnancy block — flag, mode
        // AND picked date. Before, only the flag cleared, so Female → Male
        // → Female resurrected the stale LMP/EDD date (user 2026-08-21).
        CField('Gender', _radios(['Female','Male','Other'], gender, (v) => setState(() {
          if (v != gender) { pregnant = false; _lmp = null; _pregMode = 'LMP'; }
          gender = v;
        })), required: true),
        if (gender == 'Female') ...[
          Row(children: [
            Checkbox(value: pregnant, activeColor: C2.cyan, onChanged: (v) => setState(() => pregnant = v ?? false)),
            Text('Is Patient Pregnant?', style: ct(13, FontWeight.w500, C2.text)),
          ]),
          if (pregnant) ...[
            // EDD / LMP selector (user 2026-08-14): LMP is a past date,
            // EDD a future one — the picker's range enforces it.
            CField('EDD / LMP Date',
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 96, child: DropdownButtonFormField<String>(
                  value: _pregMode,
                  isDense: true,
                  decoration: cInput().copyWith(contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
                  style: ct(13.5, FontWeight.w600, C2.text),
                  items: const [
                    DropdownMenuItem(value: 'LMP', child: Text('LMP')),
                    DropdownMenuItem(value: 'EDD', child: Text('EDD')),
                  ],
                  onChanged: (v) => setState(() {
                    if (v != null && v != _pregMode) { _pregMode = v; _lmp = null; }
                  }),
                )),
                const SizedBox(width: 8),
                Expanded(child: DateField(
                  hint: _pregMode == 'LMP' ? 'Pick LMP date' : 'Pick EDD date',
                  first: _pregMode == 'LMP' ? DateTime(2025) : DateTime.now(),
                  last: _pregMode == 'LMP'
                      ? DateTime.now()
                      : DateTime.now().add(const Duration(days: 300)),
                  initial: _lmp,
                  onPicked: (d) => setState(() => _lmp = d),
                )),
              ]),
              required: true),
            if (_pregMode == 'LMP' && _lmp != null)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Row(children: [
                  const Icon(Icons.event_available, size: 14, color: C2.cyan),
                  const SizedBox(width: 6),
                  Text('EDD: ${fmtDate(_lmp!.add(const Duration(days: 280)))}',
                      style: ct(12.5, FontWeight.w700, C2.navy)),
                  const SizedBox(width: 6),
                  Text('(LMP + 280 days)',
                      style: ct(11, FontWeight.w400, C2.text2)),
                ]),
              ),
          ],
        ],
        CField('Know', _radios(['Age','Date of Birth'], knowAge ? 'Age' : 'Date of Birth', (v) => setState(() => knowAge = v == 'Age')), required: true),
        if (knowAge)
          CField('Age (Years)', TextField(controller: _age, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)], onChanged: (_) => setState(() {}), decoration: cInput('e.g. 28').copyWith(errorText: _ageErr())), required: true)
        else
          CField('Date of Birth', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            DateField(hint: 'Pick date of birth',
                first: _earliestDob, last: _latestDob,
                initial: _dob, onPicked: (d) => setState(() => _dob = d)),
            if (_dobErr() case final e?)
              Padding(padding: const EdgeInsets.only(top: 6, left: 2),
                  child: Text(e, style: ct(11.5, FontWeight.w400, C2.danger))),
          ]), required: true),
        CField('Contact Number', TextField(controller: _contact, keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
          onChanged: (_) => setState(() {}),
          decoration: cInput('10-digit mobile').copyWith(errorText: _contactError(_contact.text.trim()))), required: true),
        // State + District are read-only badges — assigned to the
        // counsellor by the web admin (user rule 2026-07-29). Only Block
        // and Village pickers below.
        Builder(builder: (context) {
          final app = context.watch<AppState>();
          final geo = context.watch<MastersStore>();
          final assignedState    = app.currentMmuState;
          final assignedDistrict = app.currentMmuDistrict;
          // Blocks + villages come from the backend geography cascade
          // (downloaded right after login using the facility's
          // district_id — user rule 2026-08-13). The hardcoded
          // kDistrictBlocks / kBlockVillages maps only kick in as a
          // fallback while the very first download hasn't landed yet.
          final blocks = geo.hasGeo
              ? geo.geoBlockNames
              : (kDistrictBlocks[assignedDistrict] ?? const <String>[]);
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // State + District as the compact read-only line (user
            // 2026-08-14: back to the old way — locked input fields out).
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Icon(Icons.location_on_outlined, size: 14, color: C2.text2),
                const SizedBox(width: 4),
                Expanded(child: Text(
                  '${assignedState.isEmpty ? '—' : assignedState} · ${assignedDistrict.isEmpty ? '—' : assignedDistrict}',
                  style: ct(12, FontWeight.w500, C2.text2),
                )),
              ]),
            ),
            CField('Block', SearchDropdown(items: blocks, value: block, hint: 'Select Block', onChanged: (v) => setState(() { block = v; village = null; })), required: true),
            CField('Village', SearchDropdown(
              items: block == null
                  ? const <String>[]
                  : (geo.hasGeo
                      ? geo.geoVillagesOf(block!)
                      : (kBlockVillages[block!] ?? const ['Other'])),
              value: village, hint: 'Select Village',
              onChanged: (v) {
                setState(() => village = v);
                // Trending is village-scoped, so a fresh village
                // triggers a preview fetch even before the first
                // symptom is chipped (user 2026-09-08).
                _lastPreviewKey = '';
                _previewDebounce?.cancel();
                _previewDebounce = Timer(const Duration(milliseconds: 300), _fetchPreview);
              }), required: true),
          ]);
        }),
      ])),

      // SYMPTOMS (its own section, not part of Advance Details)
      CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Section header carries the required marker — submit blocks when
        // symptoms is empty (user 2026-09-02 asterisk audit).
        const SecBar('Symptoms of the Patient', required: true),
        SymptomField(
          selected: symptoms,
          block: block,
          // Village panel deliberately HIDDEN on Register (user
          // 2026-08-27) — trending still fetched below so the Likely
          // Conditions card keeps its village-share bonus; only the
          // visible "Common in <village>" chip strip is suppressed.
          hideVillagePanel: true,
          // Counsellor Register no longer surfaces Likely Conditions
          // (user 2026-09-10). Doctor Case Details keeps it — that
          // instance leaves the flag unset (default false).
          hideLikelyPanel: true,
          placeName: village ?? block,
          trending: _previewTrending,
          serverRelated: _previewRelated,
          serverLikely: _previewLikely,
          loading: _previewLoading,
          error: _previewError,
          onRetry: () {
            setState(() { _previewError = false; _previewLoading = true; });
            _lastPreviewKey = '';
            _fetchPreview();
          },
          onChanged: (v) => setState(() {
            symptoms..clear()..addAll(v);
            _schedulePreview();
          }),
        ),
      ])),

      // ADVANCE (collapsible)
      CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SecBar('Advance Details', trailing: _toggle(showAdvanced, (v) => setState(() => showAdvanced = v))),
        if (showAdvanced) ...[
          CField('Aadhar Number', TextField(controller: _aadhar, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)], decoration: cInput())),
          Row(children: [
            // 2–3 digits, at most 1 decimal place (user 2026-08-14).
            Expanded(child: CField('Height (cm)', TextField(controller: _height, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [_DecimalFormatter(3, decimals: 1)], onChanged: (_) => setState(() {}), decoration: cInput('e.g. 160.5').copyWith(errorText: _vitalMinErr(_height))))),
            const SizedBox(width: 8),
            Expanded(child: CField('Weight (kg)', TextField(controller: _weight, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [_DecimalFormatter(3, decimals: 1)], onChanged: (_) => setState(() {}), decoration: cInput('e.g. 55.2').copyWith(errorText: _vitalMinErr(_weight))))),
          ]),
          Row(children: [
            // Blood Group + Category — dynamic from server masters
            // (bootstrap `blood_groups` / `categories`). Hardcoded consts
            // stay as offline fallback; when the server list already
            // covers a fallback value, dedupe keeps a single row (user
            // 2026-09-10 dynamic masters, same pattern as Camp Type).
            Expanded(child: CField('Blood Group',
                _dd(_masterOr(context, 'blood_groups', kBloodGroups),
                    bloodGroup, (v) => setState(() => bloodGroup = v),
                    hint: 'Select'))),
            const SizedBox(width: 8),
            Expanded(child: CField('Category',
                _dd(_masterOr(context, 'categories', kCategories),
                    category, (v) => setState(() => category = v),
                    hint: 'Select'))),
          ]),
          CField('Person with Disability (PWD)', _radios(['Yes','No'], pwd, (v) => setState(() => pwd = v))),
          CField('Pin Code', TextField(controller: _pin, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)], decoration: cInput())),
          CField('Address', TextField(controller: _address, minLines: 1, maxLines: 2, decoration: cInput('House / street / landmark'))),
        ] else
          Text('Turn on to add height, weight, blood group and more.', style: ct(11.5, FontWeight.w400, C2.text2)),
      ])),

      // VITALS (collapsible)
      CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SecBar('Vitals', trailing: _toggle(showVitals, (v) => setState(() => showVitals = v))),
        if (showVitals) ...[
          // Every field: placeholder + 2–3 digit rule (decimals where the
          // measurement has them; max 2 decimal places) — user 2026-08-14.
          Row(children: [
            Expanded(child: CField('Systolic BP (mmHg)', TextField(controller: _sys, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)], onChanged: (_) => setState(() {}), decoration: cInput('e.g. 120').copyWith(errorText: _vitalMinErr(_sys))))),
            const SizedBox(width: 8),
            Expanded(child: CField('Diastolic BP (mmHg)', TextField(controller: _dia, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)], onChanged: (_) => setState(() {}), decoration: cInput('e.g. 80').copyWith(errorText: _vitalMinErr(_dia))))),
          ]),
          Row(children: [
            Expanded(child: CField('Blood Sugar (mg/dl)', TextField(controller: _sugar, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)], onChanged: (_) => setState(() {}), decoration: cInput('e.g. 110').copyWith(errorText: _vitalMinErr(_sugar))))),
            const SizedBox(width: 8),
            Expanded(child: CField('Body Temp (°F)', TextField(controller: _temp, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [_DecimalFormatter(3)], onChanged: (_) => setState(() {}), decoration: cInput('e.g. 98.6').copyWith(errorText: _vitalMinErr(_temp))))),
          ]),
          Row(children: [
            Expanded(child: CField('Oxygen Saturation (%)', TextField(controller: _spo2, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [_DecimalFormatter(3)], onChanged: (_) => setState(() {}), decoration: cInput('e.g. 98.5').copyWith(errorText: _vitalMinErr(_spo2))))),
            const SizedBox(width: 8),
            Expanded(child: CField('Heart Rate (BPM)', TextField(controller: _hr, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)], onChanged: (_) => setState(() {}), decoration: cInput('e.g. 72').copyWith(errorText: _vitalMinErr(_hr))))),
          ]),
          CField('Hemoglobin (g/dl)', TextField(controller: _hb, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [_DecimalFormatter(3)], onChanged: (_) => setState(() {}), decoration: cInput('e.g. 12.5').copyWith(errorText: _vitalMinErr(_hb)))),
        ] else
          Text('Turn on to record BP, sugar, temperature and more.', style: ct(11.5, FontWeight.w400, C2.text2)),
      ])),

      // ASSIGNMENT
      CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SecBar('Assignment & Prescription'),
        CField('Appointment Date', DateField(hint: 'Select date', first: DateTime(2025), last: DateTime(2027), initial: _apptDate, onPicked: (d) => _apptDate = d), required: true),
        Row(children: [
          Checkbox(value: onMed, activeColor: C2.cyan, onChanged: (v) => setState(() {
            onMed = v ?? false;
            // Un-ticking hides (and drops) any attachments the counsellor
            // already captured — otherwise they'd silently ride along on
            // submit even though the "on medication" answer is now No.
            if (!onMed) _attachments.clear();
          })),
          Expanded(child: Text('Currently taking prescribed medication', style: ct(13, FontWeight.w500, C2.text))),
        ]),
        // Multi-attachment upload — prescriptions, lab reports, or other docs.
        // Only surfaced when "Currently taking prescribed medication" is ticked;
        // otherwise the counsellor has nothing to photograph and the extra
        // control just clutters the form.
        if (onMed)
          CField('Prescription and Reports',
            AttachmentsField(
              value: _attachments,
              onChanged: (list) => setState(() { _attachments..clear()..addAll(list); }),
            ),
            required: true),
        // Payment section — final rule (user 2026-09-02):
        //   Free org  → NOTHING shown (payment auto-Free, amount zero)
        //   Paid org  → ONLY the Paid Amount field (radio hidden,
        //               payment is always "Paid" by definition of a
        //               paid organisation).
        // The `payment` variable is pinned to "Paid" for paid orgs so
        // the submit path's `payment == 'Paid'` amount check fires,
        // and to "Free" for free orgs so the same check is skipped.
        Builder(builder: (context) {
          final free = context.watch<AppState>().orgIsFree;
          if (free) {
            if (payment != 'Free') {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && payment != 'Free') setState(() => payment = 'Free');
              });
            }
            return const SizedBox.shrink();
          }
          if (payment != 'Paid') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && payment != 'Paid') setState(() => payment = 'Paid');
            });
          }
          return CField('Consultation Fees (₹)',
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(controller: _amount, keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(5)],
                  decoration: cInput('Enter consultation fee')),
                const SizedBox(height: 8),
                // Quick-pick amount chips — cream card, medium radius,
                // frequently used fees (user 2026-09-11). Tap fills the
                // field above; still fully editable.
                Wrap(spacing: 8, runSpacing: 6, children: [
                  for (final v in _frequentFees)
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() {
                        _amount.text = v.toString();
                        _amount.selection = TextSelection.fromPosition(
                            TextPosition(offset: _amount.text.length));
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: C2.border),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('₹ $v', style: ct(12.5, FontWeight.w700, C2.text)),
                      ),
                    ),
                ]),
              ]),
              required: true);
        }),
        // Single-doctor MMU (the normal case): show them locked — no
        // dropdown to mis-tap. Multiple rows (e.g. until the backend
        // with_login deploy lands) keep the picker so nothing breaks.
        CField('Doctor Assignment',
            _doctorNames.length == 1
                ? _lockedField(doctor ?? _doctorNames.first, showLock: false)
                : _dd(_doctorNames, doctor, (v) => setState(() => doctor = v), hint: 'Select Doctor'),
            required: true),
        // Patient Remarks — Deepgram STT (nova-2 + language=hi, locked
        // 2026-08-19 after 10/10 scripted test; nova-3 multi rejected for
        // English-word injection) with OFFLINE FALLBACK to the Google
        // SpeechRecognizer (RemarksMicButton decides per connectivity).
        // Every OTHER mic field keeps Google STT (verdict 2026-08-18).
        // Box grows with the text.
        CField('Patient Remarks', TextField(controller: _remarks, minLines: 2, maxLines: null,
          keyboardType: TextInputType.multiline,
          decoration: cInput('Type or use the mic').copyWith(
          suffixIcon: RemarksMicButton(
            key: ValueKey('remarks-mic-$_voiceMicSeq'),
            controller: _remarks)))),
      ])),

      const SizedBox(height: 4),
      CPrimaryButton(
        _submitting ? 'Submitting…' : 'Submit',
        icon: Icons.check_circle_outline,
        // Disabled + "Submitting…" while the submit (incl. photo upload)
        // is in flight — double-tap can't enqueue the registration twice.
        onTap: _submitting ? null : () => _submit(s),
      ),
    ]),
    );
  }

  Widget _toggle(bool value, ValueChanged<bool> onCh) => Transform.scale(
        scale: 0.8,
        child: Switch(value: value, activeColor: Colors.white, activeTrackColor: C2.cyan,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, onChanged: onCh),
      );

  /// Merge server master values with a hardcoded fallback list.
  ///
  /// * `key` is the bootstrap `masters` key — bootstrap accepts two shapes:
  ///   plain `List<String>` (blood_groups, camp_types, frequencies,
  ///   device_states, genders, payment_types) OR
  ///   `List<{id, name}>` rows (categories, symptoms, diseases, medicines,
  ///   devices, referral_destinations, lab_tests). Both are supported —
  ///   the row shape has its `name` field pulled out.
  /// * Fallback const is appended (deduped) so an old saved value
  ///   still validates and offline sessions render a working picker
  ///   (user 2026-09-10 dynamic masters).
  List<String> _masterOr(BuildContext ctx, String key, List<String> fallback) {
    final store = ctx.read<MastersStore>();
    var server = store.masterStrings(key);
    if (server.isEmpty) {
      // Rows-shape? Extract the `name` field.
      final rows = store.masterRows(key);
      server = [
        for (final r in rows)
          if ((r['name'] ?? r['term'] ?? r['label']) != null)
            (r['name'] ?? r['term'] ?? r['label']).toString(),
      ];
    }
    if (server.isEmpty) return fallback;
    final seen = <String>{};
    final out = <String>[];
    for (final s in [...server, ...fallback]) {
      if (s.trim().isEmpty) continue;
      if (seen.add(s)) out.add(s);
    }
    return out;
  }

  Widget _radios(List<String> opts, String val, ValueChanged<String> onCh) => Wrap(spacing: 14, children: opts.map((o) => InkWell(
        onTap: () => onCh(o),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(val == o ? Icons.radio_button_checked : Icons.radio_button_off, size: 18, color: val == o ? C2.cyan : C2.text3),
          const SizedBox(width: 4),
          Text(o, style: ct(13, FontWeight.w500, C2.text)),
        ]),
      )).toList());

  Widget _dd(List<String> items, String? val, ValueChanged<String?> onCh, {String? hint}) =>
      SearchDropdown(items: items, value: val, hint: hint ?? 'Select', onChanged: onCh);

  /// Vitals rule (user 2026-08-14): whatever is typed must have 2–3
  /// digits before the decimal (the max is enforced by the input
  /// formatters). Empty is fine — vitals are optional.
  /// Clinical plausibility ranges (user 2026-08-22) — replace the old
  /// "min 2 digits" rule for the seven vitals. Blank stays allowed
  /// (vitals are optional); height/weight keep the digit floor.
  late final Map<TextEditingController, (double, double, String)>
      _vitalRanges = {
    _sys:   (60, 280, 'Allowed 60–280'),
    _dia:   (40, 150, 'Allowed 40–150'),
    _sugar: (20, 600, 'Allowed 20–600'),
    _temp:  (86, 113, 'Allowed 86–113 °F'),
    _spo2:  (50, 100, 'Allowed 50–100%'),
    _hr:    (30, 220, 'Allowed 30–220'),
    _hb:    (3, 25, 'Allowed 3–25'),
    // Weight had only the shared "Min 2 digits" floor, so 999.9 kg went
    // through. 300 is well past any patient an MMU will weigh; the floor is
    // kept where it already was, at 10, so nothing that used to be accepted
    // stops being accepted (user 2026-09-28).
    _weight: (10, 300, 'Allowed 10–300 kg'),
    // Height had no ceiling at all — only the shared "Min 2 digits" floor —
    // so 999.9 cm went through. 50-260 is the range the user set on
    // 2026-09-29; the tallest recorded human reached 272 cm, so 260 is
    // generous for anyone an MMU will measure.
    _height: (50, 260, 'Allowed 50–260 cm'),
  };

  /// Age is typed from memory, not measured, so it gets its own bound rather
  /// than a _vitalRanges entry — that map feeds the vitals section.
  ///
  /// 1-120 (user 2026-09-29). The ceiling is because the field accepts three
  /// digits and nothing else, so a slipped keystroke could register a
  /// 999-year-old.
  ///
  /// The floor means an infant cannot be entered HERE, since an age in whole
  /// years rounds to 0 below their first birthday. They are registered by
  /// Date of Birth instead — the radio above this field — and that path
  /// works out the age itself, so nothing is locked out.
  static const int _minAgeYears = 1;
  static const int _maxAgeYears = 120;

  String? _ageErr() {
    final t = _age.text.trim();
    if (t.isEmpty) return null;
    final v = int.tryParse(t);
    if (v == null || v < _minAgeYears || v > _maxAgeYears) {
      return 'Allowed $_minAgeYears–$_maxAgeYears years';
    }
    return null;
  }

  /// The window a date of birth may fall in — the same 1–120 years the Age
  /// field allows (user 2026-09-30), expressed as dates so the picker can
  /// refuse the rest rather than let one be chosen and then rejected.
  ///
  /// The picker used to open on 1920–today, which accepted a 106-year-old
  /// and a date typed a decade out by a slipped year.
  DateTime get _earliestDob {
    final n = DateTime.now();
    return DateTime(n.year - _maxAgeYears, n.month, n.day);
  }

  DateTime get _latestDob {
    final n = DateTime.now();
    return DateTime(n.year - _minAgeYears, n.month, n.day);
  }

  /// Guards a date that got past the picker — a value held from before the
  /// bounds existed, or one restored by a re-appointment prefill.
  String? _dobErr() {
    final d = _dob;
    if (d == null) return null;
    final years = _ageFromDob(d);
    if (years < _minAgeYears || years > _maxAgeYears) {
      return 'Allowed $_minAgeYears–$_maxAgeYears years (this is $years)';
    }
    return null;
  }

  String? _vitalMinErr(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    final r = _vitalRanges[c];
    if (r == null) {
      // Every field this is called with now carries a range, so nothing
      // reaches here. Kept as the safe default for a controller added later
      // before somebody remembers to give it one.
      if (t.split('.').first.length < 2) return 'Min 2 digits';
      return null;
    }
    final v = double.tryParse(t);
    if (v == null || v < r.$1 || v > r.$2) return r.$3;
    return null;
  }

  /// Read-only input look-alike for values assigned by the web admin
  /// (State / District). Renders with the same border/padding as every
  /// other field, a lock suffix instead of a dropdown arrow, and no tap
  /// handler — visibly a field, visibly not editable.
  /// [showLock] false drops the padlock while keeping the read-only look.
  /// State and District are assigned by the web admin and the padlock says
  /// so usefully. A single-doctor MMU is not the same thing — there is
  /// simply nobody else to pick, and a padlock made it read as a permission
  /// the counsellor lacks (user 2026-09-28).
  Widget _lockedField(String v, {bool showLock = true}) => InputDecorator(
        decoration: cInput().copyWith(
          suffixIcon: showLock
              ? const Icon(Icons.lock_outline, size: 16, color: C2.text3)
              : null,
        ),
        child: Text(
          v.isEmpty ? '—' : v,
          overflow: TextOverflow.ellipsis,
          style: ct(13.5, FontWeight.w600, v.isEmpty ? C2.text3 : C2.text),
        ),
      );
}


/// Modal shown while remarks are being translated hi→en at submit
/// (user 2026-08-20 "loader progress bar aisa kuch use kar sakte ho"),
/// so the counsellor sees why submit takes a moment.
class _TranslatingDialog extends StatelessWidget {
  const _TranslatingDialog();
  @override
  Widget build(BuildContext context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: C2.cyan)),
            const SizedBox(width: 14),
            Flexible(child: Text("Translating remarks\u2026",
                style: ct(13.5, FontWeight.w600, C2.text))),
          ]),
        ),
      );
}
