import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'cw.dart';
import 'cdata.dart';
import 'cstate.dart';
import 'symptom_field.dart';
import '../api/masters_store.dart';
import '../api/sync_service.dart';
import '../doctor/voice.dart';
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
int? _asInt(TextEditingController c) {
  final s = c.text.trim();
  if (s.isEmpty) return null;
  return int.tryParse(s);
}

/// Allows up to [intDigits] integer digits and 1 optional decimal place
/// (e.g. 100.1 with intDigits=3, or 14.5 with intDigits=2).
class _DecimalFormatter extends TextInputFormatter {
  final int intDigits;
  _DecimalFormatter(this.intDigits);
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final t = newValue.text;
    if (t.isEmpty) return newValue;
    return RegExp('^\\d{0,$intDigits}(\\.\\d?)?\$').hasMatch(t) ? newValue : oldValue;
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

  // basic
  final _name = TextEditingController();
  String gender = 'Female';
  bool pregnant = false;
  // For pregnant patients, the counsellor enters the LMP (last menstrual
  // period). EDD (estimated delivery date) is auto-calculated as LMP + 280 days
  // per Naegele's rule and shown as read-only below the LMP picker.
  DateTime? _lmp;
  bool knowAge = true;
  DateTime? _dob;
  final _age = TextEditingController();
  final _contact = TextEditingController();
  // Unique Code field removed 2026-07-29 per user rule. Contact is now
  // the sole patient identifier.
  String? block;
  String? village;
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

  void _submit(CounsellorState s) {
    // Drop focus BEFORE any validation or setState. If the symptoms field
    // still holds focus when _reset() rebuilds the form, the enclosing
    // SingleChildScrollView auto-scrolls to reveal that field — which the
    // user sees as "the form jumped back to the symptoms dropdown".
    FocusManager.instance.primaryFocus?.unfocus();
    void err(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: C2.danger));
    if (_name.text.trim().isEmpty) return err('Enter patient name');
    if (knowAge && _age.text.trim().isEmpty) return err('Enter age');
    if (!knowAge && _dob == null) return err('Select date of birth');
    final ce = _contactError(_contact.text.trim());
    // Contact is required now that Unique Code is removed (rule 2026-07-29).
    if (_contact.text.trim().isEmpty) return err('Enter contact number');
    if (ce != null) return err('Contact: $ce');
    // State + District are inherited from the counsellor's assigned
    // profile (rule 2026-07-29); only block + village are picked here.
    if (block == null) return err('Select block');
    if (village == null) return err('Select village');
    if (doctor == null) return err('Select doctor assignment');
    if (payment == 'Paid' && _amount.text.trim().isEmpty) return err('Enter paid amount');
    if (onMed && _attachments.isEmpty) return err('Attach at least one prescription or report');

    final vitals = <String, String>{};
    void v(String k, TextEditingController c) { if (c.text.trim().isNotEmpty) vitals[k] = c.text.trim(); }
    v('Systolic BP', _sys); v('Diastolic BP', _dia); v('Blood Sugar', _sugar);
    v('Body Temp (°F)', _temp); v('Oxygen Saturation', _spo2); v('Heart Rate', _hr); v('Hemoglobin', _hb);

    final scored = scoreDiseases(symptoms, block);
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
      // Re-Appointment: prefer the carried previous diagnosis over the
      // symptom-based ML score so the doctor sees the exact prior dx
      // pre-selected. Fresh registration falls back to the ML top pick.
      disease: carryDisease.isNotEmpty
          ? carryDisease
          : (scored.isNotEmpty ? scored.first.name : ''),
      // Re-Appointment: previous medicines pre-loaded on the doctor screen
      // (editable — doctor can add / remove / change dosage before Submit).
      prescription: carryPrescription,
      vitals: vitals,
      pregnant: pregnant,
      remarks: _remarks.text.trim(),
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

    // Diagnoses — the counsellor form's "Likely Condition" pre-fill goes
    // here as one appointment_diagnosis row so the doctor sees the
    // prediction on their case detail. `disease_id` is resolved from the
    // masters cache when possible; the backend stores diagnosis_text
    // regardless so free-text diagnoses (not in the master) still land.
    //
    // Match against both `term` (canonical name) and `synonyms` (e.g.
    // "Dengue Fever" → synonym of master "Dengue" id 97). Without the
    // synonym pass the mobile's ML picker sends "Dengue Fever" and the
    // backend link stays NULL because there's no exact-name row.
    final diseaseId = _lookupDiseaseId(
      masters.masterRows('diseases'), p.disease);
    final diagnoses = <Map<String, dynamic>>[
      if (p.disease.trim().isNotEmpty)
        {
          'diagnosis_text': p.disease,
          if (diseaseId != null) 'disease_id': diseaseId,
          'is_primary': true,
        },
    ];

    // Attachments — Prescription / Report / Other photos the counsellor
    // picked up at registration. For now we send the local file path
    // (backend stores it as-is); a future upload endpoint will replace
    // that with a server-hosted URL so the doctor can see the file from
    // any device, not just the counsellor's phone.
    final attachments = <Map<String, dynamic>>[
      for (final a in _attachments)
        {
          'file_path': a.path,
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
    final lmpIso = (pregnant && _lmp != null) ? _isoDate(_lmp!) : null;
    final eddIso = (pregnant && _lmp != null)
        ? _isoDate(_lmp!.add(const Duration(days: 280)))
        : null;

    // Aadhaar / pin: send only when they look valid so the backend
    // regex CHECK doesn't 422 on partial numbers.
    final aadharDigits = _aadhar.text.trim();
    final aadharValue = RegExp(r'^\d{12}$').hasMatch(aadharDigits)
        ? aadharDigits : null;
    final pinDigits = _pin.text.trim();
    final pinValue = RegExp(r'^[1-9]\d{5}$').hasMatch(pinDigits)
        ? pinDigits : null;

    context.read<SyncService>().enqueue(kind: 'patient.register', payload: {
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
      if (bloodGroup != null)      'blood_group': bloodGroup,
      if (categoryId != null)      'category_id': categoryId,
      'disability':                pwd == 'Yes',
      if (p.pastHistory.trim().isNotEmpty) 'past_history': p.pastHistory,
      // Appointment leg
      // ISO date (yyyy-mm-dd) — backend Pydantic AppointmentIn expects
      // Python `date` format, NOT the dd-MM-yyyy display format that
      // CPatient.regDate uses.
      'appointment_date':  _isoDate(_apptDate ?? DateTime.now()),
      'payment_type':      payment,
      'paid_amount':       payment == 'Paid'
          ? (num.tryParse(_amount.text.trim()) ?? 0) : 0,
      'pregnant':          pregnant,
      if (lmpIso != null) 'lmp_date': lmpIso,
      if (eddIso != null) 'edd_date': eddIso,
      'taken_prescribed_medicine': onMed,
      if (_remarks.text.trim().isNotEmpty)
        'counsellor_remarks': _remarks.text.trim(),
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${p.name} added to Doctor Queue'),
      backgroundColor: C2.green,
    ));
    _reset();
    // Bounce back to the Home tab so the counsellor sees the newly-added
    // patient at the top of the "Registered Patients" list (addPatient
    // inserts at index 0). onSubmitted is provided by CounsellorShell.
    widget.onSubmitted?.call();
  }

  void _reset() {
    setState(() {
      for (final c in [_name,_age,_contact,_aadhar,_height,_weight,_pin,_address,_sys,_dia,_sugar,_temp,_spo2,_hr,_hb,_amount,_remarks]) {
        c.clear();
      }
      gender = 'Female'; pregnant = false; _lmp = null; knowAge = true; _dob = null; block = null; village = null;
      // state + district removed 2026-07-29 — inherited from AppState.
      showAdvanced = false; showVitals = false;
      bloodGroup = null; category = null; pwd = 'No'; onMed = false; payment = 'Free';
      doctor = null; _apptDate = DateTime.now(); symptoms.clear(); _attachments.clear();
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
      knowAge = true;
      _age.text = p.age > 0 ? p.age.toString() : '';
      _dob = null;
      _contact.text = p.contact;
      block = p.block.isEmpty ? null : p.block;
      village = p.village.isEmpty ? null : p.village;
      _remarks.text = p.remarks;
      // Carry the previous symptom picks over (rule 2026-07-31) so the
      // counsellor can just tweak them for today's visit instead of
      // re-selecting from scratch. Vitals still reset — per-visit reading.
      symptoms
        ..clear()
        ..addAll(p.symptoms);
      _attachments.clear();
      doctor = null;
      payment = 'Free';
      _amount.clear();
      _apptDate = DateTime.now();
      // Advance Details prefill (rule 2026-07-31) — Aadhaar, height, weight,
      // blood group, category, PwD flag, pincode, address. Section is
      // auto-expanded so the counsellor sees the values right away.
      _aadhar.text = p.aadhar;
      _height.text = p.heightCm;
      _weight.text = p.weightKg;
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
        CField('Gender', _radios(['Female','Male','Other'], gender, (v) => setState(() { gender = v; if (v != 'Female') pregnant = false; })), required: true),
        if (gender == 'Female') ...[
          Row(children: [
            Checkbox(value: pregnant, activeColor: C2.cyan, onChanged: (v) => setState(() => pregnant = v ?? false)),
            Text('Is Patient Pregnant?', style: ct(13, FontWeight.w500, C2.text)),
          ]),
          if (pregnant) ...[
            CField('LMP (last menstrual period)',
              DateField(hint: 'Pick LMP date', first: DateTime(2025), last: DateTime.now(),
                initial: _lmp, onPicked: (d) => setState(() => _lmp = d)),
              required: true),
            if (_lmp != null)
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
          CField('Age (in years)', TextField(controller: _age, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)], decoration: cInput('e.g. 28')), required: true)
        else
          CField('Date of Birth', DateField(hint: 'Pick date of birth', first: DateTime(1920), last: DateTime.now(), initial: _dob, onPicked: (d) => setState(() => _dob = d)), required: true),
        CField('Contact Number', TextField(controller: _contact, keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
          onChanged: (_) => setState(() {}),
          decoration: cInput('10-digit mobile').copyWith(errorText: _contactError(_contact.text.trim()))), required: true),
        // State + District are read-only badges — assigned to the
        // counsellor by the web admin (user rule 2026-07-29). Only Block
        // and Village pickers below.
        Builder(builder: (context) {
          final app = context.watch<AppState>();
          final assignedState    = app.currentMmuState;
          final assignedDistrict = app.currentMmuDistrict;
          final blocks = (kDistrictBlocks[assignedDistrict] ?? const <String>[]);
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
            CField('Village', SearchDropdown(items: block == null ? const <String>[] : (kBlockVillages[block!] ?? const ['Other']), value: village, hint: 'Select Village', onChanged: (v) => setState(() => village = v)), required: true),
          ]);
        }),
      ])),

      // SYMPTOMS (its own section, not part of Advance Details)
      CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SecBar('Symptoms of the Patient'),
        SymptomField(selected: symptoms, block: block, onChanged: (v) => setState(() { symptoms..clear()..addAll(v); })),
      ])),

      // ADVANCE (collapsible)
      CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SecBar('Advance Details', trailing: _toggle(showAdvanced, (v) => setState(() => showAdvanced = v))),
        if (showAdvanced) ...[
          CField('Aadhar Number', TextField(controller: _aadhar, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)], decoration: cInput())),
          Row(children: [
            Expanded(child: CField('Height (cm)', TextField(controller: _height, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)], decoration: cInput()))),
            const SizedBox(width: 8),
            Expanded(child: CField('Weight (kg)', TextField(controller: _weight, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)], decoration: cInput()))),
          ]),
          Row(children: [
            Expanded(child: CField('Blood Group', _dd(kBloodGroups, bloodGroup, (v) => setState(() => bloodGroup = v), hint: 'Select'))),
            const SizedBox(width: 8),
            Expanded(child: CField('Category', _dd(kCategories, category, (v) => setState(() => category = v), hint: 'Select'))),
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
          Row(children: [
            Expanded(child: CField('Systolic BP (mmHg)', TextField(controller: _sys, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)], decoration: cInput()))),
            const SizedBox(width: 8),
            Expanded(child: CField('Diastolic BP (mmHg)', TextField(controller: _dia, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)], decoration: cInput()))),
          ]),
          Row(children: [
            Expanded(child: CField('Blood Sugar (mg/dl)', TextField(controller: _sugar, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)], decoration: cInput()))),
            const SizedBox(width: 8),
            Expanded(child: CField('Body Temp (°F)', TextField(controller: _temp, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [_DecimalFormatter(3)], decoration: cInput('e.g. 100.1')))),
          ]),
          Row(children: [
            Expanded(child: CField('Oxygen Saturation (%)', TextField(controller: _spo2, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)], decoration: cInput()))),
            const SizedBox(width: 8),
            Expanded(child: CField('Heart Rate (BPM)', TextField(controller: _hr, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)], decoration: cInput()))),
          ]),
          CField('Hemoglobin (g/dl)', TextField(controller: _hb, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [_DecimalFormatter(2)], decoration: cInput('e.g. 12.5'))),
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
        CField('Payment', _radios(['Paid','Free'], payment, (v) => setState(() => payment = v)), required: true),
        if (payment == 'Paid')
          CField('Paid Amount (₹)', TextField(controller: _amount, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)], decoration: cInput()), required: true),
        CField('Doctor Assignment', _dd(kDoctors, doctor, (v) => setState(() => doctor = v), hint: 'Select Doctor'), required: true),
        CField('Patient Remarks', TextField(controller: _remarks, minLines: 2, maxLines: 4, decoration: cInput('Type or use the mic').copyWith(
          suffixIcon: VoiceMicButton(
            key: ValueKey('remarks-mic-$_voiceMicSeq'),
            controller: _remarks)))),
      ])),

      const SizedBox(height: 4),
      CPrimaryButton('Submit', icon: Icons.check_circle_outline, onTap: () => _submit(s)),
    ]),
    );
  }

  Widget _toggle(bool value, ValueChanged<bool> onCh) => Transform.scale(
        scale: 0.8,
        child: Switch(value: value, activeColor: Colors.white, activeTrackColor: C2.cyan,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, onChanged: onCh),
      );

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
}
