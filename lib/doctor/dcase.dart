import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/appointments_api.dart';
import '../api/api_client.dart';
import '../api/masters_store.dart';
import '../api/sync_service.dart';
import '../counsellor/cw.dart';
import '../counsellor/cstate.dart';
import '../counsellor/symptom_field.dart';
import '../services/appointment_detail_store.dart';
import '../services/connectivity_service.dart';
import '../services/terminology_store.dart';
import '../services/translation_service.dart';
import '../services/symptom_catalog.dart';
import '../state/app_state.dart';
import 'ddata.dart';
import '../counsellor/cdata.dart' show ScoredDisease;
import 'disease_master.dart';
import 'doctor_db_loader.dart';
import '../services/deepgram_stt.dart';

class DoctorCaseDetails extends StatefulWidget {
  final CPatient patient;
  const DoctorCaseDetails({super.key, required this.patient});
  @override
  State<DoctorCaseDetails> createState() => _DoctorCaseDetailsState();
}

// The vitals keys the counsellor Register form writes into CPatient.vitals.
// Doctor's editable Vitals card mirrors the same set + order so the update
// overwrites the same map keys and the values flow onward unchanged.
const List<({String key, String label, String hint})> _kVitalSpecs = [
  (key: 'Systolic BP',       label: 'Systolic BP',        hint: 'e.g. 120'),
  (key: 'Diastolic BP',      label: 'Diastolic BP',       hint: 'e.g. 80'),
  (key: 'Blood Sugar',       label: 'Blood Sugar',        hint: 'e.g. 110'),
  (key: 'Body Temp (°F)',    label: 'Body Temp (°F)',     hint: 'e.g. 98.6'),
  (key: 'Oxygen Saturation', label: 'Oxygen Saturation',  hint: '%'),
  (key: 'Heart Rate',        label: 'Heart Rate',         hint: 'bpm'),
  (key: 'Hemoglobin',        label: 'Hemoglobin',         hint: 'g/dL'),
];

// _kVitalSpecs label -> the column GET /api/appointments/{id} returns it as.
// Heart Rate was mapped 2026-08-20 — appointment.heart_rate exists in the
// backend (migration 2026-08-16); without this the counsellor-typed BPM
// was landing in DB but not pre-filling on the doctor screen.
const Map<String, String> _kVitalColumns = {
  'Systolic BP':       'systolic_bp',
  'Diastolic BP':      'diastolic_bp',
  'Blood Sugar':       'blood_sugar',
  'Body Temp (°F)':    'body_temp',
  'Oxygen Saturation': 'oxygen',
  'Heart Rate':        'heart_rate',
  'Hemoglobin':        'hemoglobin',
};

/// Readings come back as int, double or numeric string depending on column.
/// Render 120.0 as '120' so the field reads the way it was typed, and treat
/// 0 as "not recorded" rather than a real measurement.
String _fmtVital(Object? v) {
  if (v == null) return '';
  if (v is num) {
    if (v == 0) return '';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }
  final s = v.toString().trim();
  if (s.isEmpty || s == 'null') return '';
  final n = num.tryParse(s);
  return n != null ? _fmtVital(n) : s;
}

/// A diagnosis chip carries the term and the ICD code glued into one label —
/// "Fever · MG26" from the picker (Disease.display), "Fever | MG26" from the
/// advisory card's Apply. The server stores them in two separate columns
/// (appointment_diagnosis.diagnosis_text / .icd11_code), so the label is split
/// back apart here rather than shipped whole. Before this the whole label went
/// into diagnosis_text, which is why the web's case page read
/// "Previous Diagnosis: Fever · MG26" (user 2026-09-30).
({String text, String icd}) _splitDx(String label) {
  for (final sep in const [' · ', ' | ']) {
    final i = label.lastIndexOf(sep);
    if (i <= 0) continue;
    final code = label.substring(i + sep.length).trim();
    // An ICD-11 stem is short and alphanumeric. Anything else belongs to the
    // term — a doctor may well type "Fever | origin unknown" by hand.
    if (code.isNotEmpty && code.length <= 12 &&
        RegExp(r'^[A-Za-z0-9.]+$').hasMatch(code)) {
      return (text: label.substring(0, i).trim(), icd: code);
    }
  }
  return (text: label.trim(), icd: '');
}

class _DoctorCaseDetailsState extends State<DoctorCaseDetails> {
  late List<String> symptoms;
  final List<String> diagnoses = []; // multi-select; master "Term · ICD" or typed free text
  final List<String> tests = [];
  final List<RxItem> rx = [];
  final _obs = TextEditingController();
  final _remarks = TextEditingController();
  final _pastHistory = TextEditingController();
  // Per-vital editable controllers (rule 2026-07-29). Seeded from the
  // patient's counsellor-captured values in initState. Fields sit inside a
  // collapsible section mirroring the Counsellor Register form — the
  // switch in the header shows / hides them. Values commit to p.vitals
  // when the page-level Submit Case button fires.
  late final Map<String, TextEditingController> _vitals;
  bool _showVitals = false;
  bool _advisoryDismissed = false;
  // Red "Required" boxes on prescription rows appear only after a Submit
  // attempt, not while the doctor is still filling the card in (user
  // 2026-08-21 "dont show required red box, show on submitting").
  bool _showRxErrors = false;
  // Blocks a second Submit tap while the first submit is still working
  // (uploads, translation, enqueue, redirect). Without this, tapping
  // twice during the ~12 s translation window created duplicate
  // appointment.doctor_submit pushes (user 2026-09-02: parity with the
  // counsellor register double-submit guard).
  bool _submittingCase = false;
  // Village advisory (GET /appointments/{id}/advisory) — real village name
  // + trending terms for the SymptomField panels. Null until loaded.
  String? _advPlaceName;
  List<Map<String, dynamic>>? _advTrending;
  // Server-computed related symptoms (co-occurrence over real village
  // data — user 2026-08-26: client-side terminology.relatedTerms was
  // surfacing terms like "bleeding" that server's algorithm never
  // returned). We prefer this when the API delivered it; the client
  // fallback still runs offline.
  List<String>? _advRelated;
  // Server-ranked Likely Conditions (same reason as _advRelated —
  // client compute was diverging from server on village bonus).
  List<Map<String, dynamic>>? _advLikely;
  // Next Follow-Up question (user 2026-08-21): null = not answered yet;
  // Yes requires a date, which submits as follow_up_date.
  bool? _nextFollowUp;
  DateTime? _followUpDate;
  /// How far ahead a follow-up may be booked — one month (user 2026-09-30).
  static const int _followUpMaxDays = 31;
  // True while GET /api/appointments/{id} is in flight — see
  // _loadRegistrationDetail. Without it the Registration Details card shows
  // a bare '—' during the round-trip, which reads as "none recorded".
  bool _loadingRegDetail = false;
  // Page-level focus sink. Picker buttons (Add Diagnosis / Add Test / Add
  // Medicine) move focus to this BEFORE opening the bottom-sheet AND right
  // after it closes, so Flutter's focus restoration can't land back on the
  // Symptoms TextField and trigger Scrollable.ensureVisible — which was the
  // root cause of the page jumping to Symptoms after picking.
  final FocusNode _focusSink = FocusNode(skipTraversal: true, debugLabel: 'doctor-case-focus-sink');

  CPatient get p => widget.patient;

  @override
  void initState() {
    super.initState();
    // The advisory reads keywords out of the Observation text (user spec
    // 2026-08-14) — rescore as the doctor dictates/types.
    _obs.addListener(_onObsChanged);
    symptoms = List.from(p.symptoms);
    _pastHistory.text = p.pastHistory;
    _vitals = {
      for (final v in _kVitalSpecs)
        v.key: TextEditingController(text: p.vitals[v.key] ?? ''),
    };
    // Diagnosis prefill HIDDEN (user 2026-08-14): the counsellor's
    // provisional diagnosis (p.disease) used to land here pre-selected,
    // which read as a hardcoded value. The doctor now starts with an
    // empty Diagnosis list and picks their own — the provisional one
    // still shows via the AI advisory "Likely" and the village trend.
    // Uncomment to restore the old re-appointment shortcut:
    // if (p.disease.isNotEmpty) {
    //   for (final d in p.disease.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty)) {
    //     if (!diagnoses.contains(d)) diagnoses.add(d);
    //   }
    // }
    if (p.prescription.isNotEmpty) {
      // Copy each RxItem so edits don't mutate the source until Submit.
      // Split stored dosage back into (form, strength) so the two
      // dropdowns hydrate correctly — old rows without a form prefix
      // keep the whole string as strength (user 2026-09-08).
      // Combo pairs / triples (N lines sharing combo_key) are
      // re-assembled into ONE RxItem — otherwise re-opening a case
      // shows the group as N duplicate rows (user 2026-09-14).
      // Multiple partners are supported (user 2026-09-15).
      final seenComboKeys = <String>{};
      for (var i = 0; i < p.prescription.length; i++) {
        final m = p.prescription[i];
        final key = m.comboKey.trim();
        if (key.isNotEmpty && seenComboKeys.contains(key)) continue;
        final parsed = parseDosage(m.dosage);
        final partners = <ComboMed>[];
        if (key.isNotEmpty) {
          seenComboKeys.add(key);
          for (var j = i + 1; j < p.prescription.length; j++) {
            if (p.prescription[j].comboKey == key) {
              final pp = parseDosage(p.prescription[j].dosage);
              partners.add(ComboMed(
                  name: p.prescription[j].name,
                  dosage: bareStrength(pp.strength)));
            }
          }
        }
        rx.add(RxItem(
          name: m.name,
          // Rows written before the unit became automatic carry it in the
          // text ("100 mg"); the box below is captioned with the unit
          // already (user 2026-09-26).
          dosage: bareStrength(parsed.strength),
          dosageForm: m.dosageForm.isNotEmpty ? m.dosageForm : parsed.form,
          days: m.days, interval: m.interval, qty: m.qty,
          comboKey: key,
          combos: partners,
        ));
      }
    }
    DiseaseMaster.load().then((_) { if (mounted) setState(() {}); });
    // Full 158-condition clinical DB from assets (user 2026-08-22).
    DoctorDbLoader.load().then((_) { if (mounted) setState(() {}); });
    // Warm the hi/en models so the Submit-time translation is instant.
    TranslationService.warmUp();
    _loadRegistrationDetail();
    _loadAdvisory();
    _loadStock();
  }

  /// Pharmacy on-hand quantities for this unit (GET /medicines/stock) —
  /// shown under each prescribed medicine so the doctor knows what the
  /// pharmacist can actually dispense (user 2026-08-21). Cache-first so
  /// the numbers survive offline; a live fetch then refreshes them.
  Map<String, int> _stock = {};
  bool _stockLoaded = false;

  static String _stockKey(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  Future<void> _loadStock() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('med_stock_v1');
      if (raw != null && mounted) {
        final m = (jsonDecode(raw) as Map).cast<String, dynamic>();
        setState(() {
          _stock = {for (final e in m.entries) e.key: (e.value as num).toInt()};
          _stockLoaded = true;
        });
      }
    } catch (_) {/* no cache yet */}
    try {
      final res = await context.read<ApiClient>().get('/medicines/stock');
      if (!mounted || res is! List) return;
      final next = <String, int>{
        for (final r in res)
          if (r is Map && (r['medicine_name'] ?? '').toString().isNotEmpty)
            _stockKey(r['medicine_name'].toString()):
                (r['quantity'] as num?)?.toInt() ?? 0,
      };
      setState(() { _stock = next; _stockLoaded = true; });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('med_stock_v1', jsonEncode(next));
    } catch (_) {
      // Offline / old backend without the endpoint — the line stays hidden.
    }
  }

  /// Village name + village trending from GET /appointments/{id}/advisory.
  /// Cache-first (per appointment) so the "Common in <village>" panel still
  /// renders offline with the last good pull; a live fetch then refreshes.
  /// Passes the CURRENT chip list so the server's relevance filter tracks
  /// what the doctor has on screen (user 2026-08-27: "Common in Baknaur"
  /// was still showing Fever-relevant conditions for a case whose chips
  /// were switched to Abdominal cramps + Abdominal discomfort).
  bool _advisoryLoading = false;
  bool _advisoryError = false;

  Future<void> _loadAdvisory() async {
    final apptId = p.backendAppointmentId;
    if (apptId == null) return;
    final csv = symptoms.join(',');
    // Show "analyzing…" placeholder immediately so the panels don't
    // flash stale data from the previous chip set (user 2026-08-27).
    if (mounted && !_advisoryLoading) {
      setState(() => _advisoryLoading = true);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('advisory_v1:$apptId');
      if (raw != null && mounted) {
        _applyAdvisoryData(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {/* no cache yet */}
    try {
      final body = await context.read<AppointmentsApi>()
          .advisory(apptId, symptoms: csv.isEmpty ? null : csv);
      if (!mounted) return;
      _advisoryError = false;
      _applyAdvisoryData(body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('advisory_v1:$apptId', jsonEncode(body));
    } catch (_) {
      // Offline / server error — friendly Retry strip on the panels
      // (user 2026-08-28); a cached copy (if any) still rendered above.
      if (mounted) setState(() => _advisoryError = true);
    } finally {
      if (mounted && _advisoryLoading) {
        setState(() => _advisoryLoading = false);
      }
    }
  }

  // Debounced re-fetch of the advisory when the chip list changes at
  // runtime (2026-08-27). Debounce keeps the API quiet during rapid
  // edits (tap-tap-tap on chips) and coalesces to one round trip.
  Timer? _advisoryRefetch;
  String _advisorySymsSig = '';
  void _maybeRefetchAdvisory() {
    final sig = symptoms.join('|');
    if (sig == _advisorySymsSig) return;
    _advisorySymsSig = sig;
    _advisoryRefetch?.cancel();
    _advisoryRefetch = Timer(const Duration(milliseconds: 500), () {
      if (mounted) _loadAdvisory();
    });
  }

  void _applyAdvisoryData(Map<String, dynamic> body) {
    final common = (body['common_in_village'] as Map?)?.cast<String, dynamic>();
    setState(() {
      _advPlaceName = (body['case'] as Map?)?['village_name']?.toString();
      _advTrending = [
        for (final t in (common?['trending'] as List? ?? const []))
          if (t is Map) t.cast<String, dynamic>(),
      ];
      // Server rows look like {"symptom": "anorexia", "association": 6,
      // "rank": 1}. We just need the term string for the chip label.
      _advRelated = [
        for (final r in (body['related_symptoms'] as List? ?? const []))
          if (r is Map && (r['symptom'] ?? '').toString().trim().isNotEmpty)
            (r['symptom'] as Object).toString(),
      ];
      _advLikely = [
        for (final c in (body['likely_conditions'] as List? ?? const []))
          if (c is Map) c.cast<String, dynamic>(),
      ];
    });
  }

  /// Pull what the counsellor recorded at registration for a backend patient.
  ///
  /// /api/queues/doctor returns one flat appointment row — no symptoms, no
  /// vitals — so a CPatient built by mergeBackendPatients always arrives with
  /// an empty `symptoms` list and an empty `vitals` map however much the
  /// counsellor entered. GET /api/appointments/{id} is the only endpoint that
  /// joins `appointment_symptom` and returns the vitals columns. Demo-seed
  /// rows already carry their own values and are skipped.
  Future<void> _loadRegistrationDetail() async {
    final apptId = p.backendAppointmentId;
    if (apptId == null) return;
    // Assigned directly, not via setState — initState runs before first build.
    _loadingRegDetail = true;
    final app = context.read<AppState>();
    final userKey = 'doctor_${app.backendUserId ?? app.currentUser}';
    // Hydrate from OFFLINE CACHE first so the doctor sees symptoms +
    // vitals immediately (user rule 2026-08-20 "case details also offline").
    try {
      final store = await AppointmentDetailStore.open();
      final cached = store.load(userKey, apptId);
      if (cached != null && mounted) {
        _applyRegistrationDetail(cached);
      }
    } catch (_) {/* first-time — nothing cached */}
    try {
      final d = await context.read<AppointmentsApi>().detail(apptId);
      if (!mounted) return;
      // Persist the fresh copy for the next offline open (2026-08-20).
      unawaited(AppointmentDetailStore.open()
          .then((s) => s.save(userKey, apptId, d))
          .catchError((_) {}));
      _applyRegistrationDetail(d);
    } catch (_) {
      // Offline / API error — the cache hydrate above already ran, so
      // symptoms/vitals are showing whatever the last successful pull
      // left. No banner: the user shouldn't see network noise.
    } finally {
      if (mounted) setState(() => _loadingRegDetail = false);
    }
  }

  /// Apply an appointment detail JSON to the local editable state.
  /// Extracted so cache-hydrate and live-fetch share the same mapping.
  void _applyRegistrationDetail(Map<String, dynamic> d) {
    final freshSymptoms = <String>[
      for (final s in (d['symptoms'] as List? ?? const []))
        if (s is Map)
          (s['symptom_name'] ?? s['name'] ?? '').toString().trim()
    ]..removeWhere((s) => s.isEmpty);
    final freshVitals = <String, String>{};
    for (final spec in _kVitalSpecs) {
      final raw = d[_kVitalColumns[spec.key]];
      final val = _fmtVital(raw);
      if (val.isNotEmpty) freshVitals[spec.key] = val;
    }
    setState(() {
      if (freshSymptoms.isNotEmpty) {
        p.symptoms = freshSymptoms;
        symptoms = List.from(freshSymptoms);
      }
      // Previously saved observation must show when the case reopens
      // (user 2026-08-21 "Observation value not showing") — but never
      // clobber text the doctor is typing right now.
      final obs = (d['observation'] ?? '').toString().trim();
      if (obs.isNotEmpty && _obs.text.trim().isEmpty) _obs.text = obs;
      // English version leads (user 2026-08-22); original is the fallback.
      final cRemarksEn = (d['counsellor_remarks_english'] ?? '').toString().trim();
      final cRemarks = cRemarksEn.isNotEmpty
          ? cRemarksEn
          : (d['counsellor_remarks'] ?? '').toString().trim();
      if (cRemarks.isNotEmpty) p.remarks = cRemarks;
      // As dictated. Kept so the card below can offer it back — a
      // translation of a complaint is worth reading against the words the
      // patient actually used (user 2026-09-28).
      p.remarksOriginal = (d['counsellor_remarks'] ?? '').toString();
      if (freshVitals.isNotEmpty) {
        p.vitals = {...p.vitals, ...freshVitals};
        for (final e in freshVitals.entries) {
          final c = _vitals[e.key];
          if (c != null && c.text.trim().isEmpty) c.text = e.value;
        }
        _showVitals = true;
      }
    });
  }

  @override
  void dispose() {
    _obsDebounce?.cancel();
    _obs.removeListener(_onObsChanged);
    for (final c in _vitals.values) { c.dispose(); }
    _focusSink.dispose();
    super.dispose();
  }

  final Set<String> _autoAdded = {};

  /// Every problem the doctor dictates in the Observation — Hindi,
  /// Hinglish or English, several in one sentence — becomes a selected
  /// symptom chip automatically (user 2026-08-22 "बुखार हो रहा है" →
  /// Fever). Two passes:
  ///   1. SymptomCatalog — the explicit spoken-word → chip mapping
  ///      ("bukhar"/"बुखार"/"fever" → Fever), spelling-tolerant.
  ///   2. Clinical sheet synonyms, but a chip is only added when the
  ///      match lines up with a name from the server's SYMPTOM MASTER —
  ///      the same names the counsellor's picker uses, so no long
  ///      clinical phrases or condition names sneak into the chips.
  // Cache the last text auto-add ran on, so a debounce fire that reflects
  // no new speech (e.g. cursor moved, whitespace-only edit) skips the
  // heavy master + terminology scan entirely.
  String _lastAutoText = '';
  void _autoAddFromTranscript() {
    final text = _obs.text.trim();
    if (text.isEmpty) return;
    if (text == _lastAutoText) return;
    _lastAutoText = text;
    final found = <String>{...SymptomCatalog.match(text)};
    final textWords = SymptomCatalog.wordsOf(text);
    final store = context.read<TerminologyStore>();
    if (store.isLoaded) {
      final masterByKey = <String, String>{};
      for (final r in context.read<MastersStore>().masterRows('symptoms')) {
        final name = (r['term'] ?? r['name'] ?? r['symptom_name'])?.toString();
        if (name == null || name.trim().isEmpty) continue;
        masterByKey[TerminologyStore.loose(TerminologyStore.normalize(name))] =
            name;
      }
      // Words that are too generic to carry a diagnosis on their own —
      // "दर्द" (dard) matches every Xxx-dard synonym, "pain" matches
      // every English pain phrase; plus vocative honorifics ("sar,
      // hamne..." starts many dictations, and 'sar' ALSO means "head",
      // which was mis-adding Headache — user 2026-08-26).
      const ambiguous = {'dard', 'pain', 'ache', 'problem', 'ho', 'hota',
        'takleef', 'taklif', 'dikkat', 'issue',
        'sir', 'sar', 'madam', 'sahab', 'sahib', 'doctor', 'sirji'};
      for (final m in store.matchInputs([text])) {
        // A single shared word ("dard") is not evidence — the WHOLE
        // matched synonym must be present in the dictation (user
        // 2026-08-22: "हाथ में जलन" was adding Headache + Abdominal pain).
        if (!SymptomCatalog.phraseHit(textWords, m.matchedSynonym)) continue;
        // Reject synonyms whose only meaningful words are ≤3 chars —
        // 3-char words are usually filler / grammar / honorifics in
        // Hindi and produce false positives when combined with a
        // generic pain word (user 2026-08-26).
        final synWords = SymptomCatalog.wordsOf(m.matchedSynonym);
        final meaningful = synWords.where(
            (w) => w.length >= 4 && !ambiguous.contains(w)).toList();
        if (meaningful.isEmpty) continue;
        var mapped = false;
        for (final cand in [m.matchedSynonym, m.entry.standardTerm]) {
          final master = masterByKey[
              TerminologyStore.loose(TerminologyStore.normalize(cand))];
          if (master != null) {
            found.add(master);
            mapped = true;
            break;
          }
        }
        // Sheet fallback (user 2026-08-22 "your mapping word + Synonyms
        // word"): the Excel's Symptoms column rides in the synonym table
        // too — when the dictation matched one of those SHORT symptom
        // names and the server master doesn't carry it, the sheet term
        // itself becomes the chip. Disease names stay out: only terms
        // listed in the entry's own Symptoms column qualify.
        if (!mapped) {
          final syn = m.matchedSynonym.trim();
          final synKey = TerminologyStore.loose(TerminologyStore.normalize(syn));
          final fromSymptomsColumn = m.entry.symptoms.any((s) =>
              TerminologyStore.loose(TerminologyStore.normalize(s)) == synKey);
          if (fromSymptomsColumn && syn.length <= 30) found.add(syn);
        }
      }
    }
    var addedAny = false;
    for (final canonical in found) {
      final key = canonical.toLowerCase();
      if (_autoAdded.contains(key)) continue;
      if (symptoms.any((s) => s.toLowerCase() == key)) continue;
      _autoAdded.add(key);
      symptoms.add(canonical);
      addedAny = true;
    }
    _autoAddedThisRun = addedAny;
  }
  bool _autoAddedThisRun = false;

  Timer? _obsDebounce;

  /// Debounced (user 2026-08-25 "lagging while taking observation and
  /// after apply"). Deepgram streams partial transcripts every ~200 ms,
  /// so a short debounce fires the heavy work over and over WHILE the
  /// doctor is still speaking. 1200 ms (raised 2026-08-28 from 800 ms —
  /// long dictation was still causing setState storms on the advisory
  /// panels) lands the work AFTER the user pauses. Also skips the
  /// setState when nothing new was auto-added — no visual change to
  /// render, so the frame stays free.
  void _onObsChanged() {
    if (!mounted) return;
    _obsDebounce?.cancel();
    _obsDebounce = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      _autoAddFromTranscript();
      if (_autoAddedThisRun) setState(() {});
    });
  }

  /// Commit the current controller values into p.vitals. Called from the
  /// page-level Submit Case handler so the updated readings ship along with
  /// the diagnosis / Rx / observations. Blanks are dropped so a cleared
  /// field removes that vital rather than storing '' for it.
  void _commitVitalsToPatient() {
    p.vitals.clear();
    for (final v in _kVitalSpecs) {
      final t = _vitals[v.key]!.text.trim();
      if (t.isNotEmpty) p.vitals[v.key] = t;
    }
  }

  void _parkFocus() {
    if (_focusSink.canRequestFocus) _focusSink.requestFocus();
  }

  /// Doctor's remarks with any advised tests appended.
  ///
  /// Tests are advice here, not lab orders (see the submit payload), and
  /// DoctorSubmitIn has no free-text field for them — so without this they
  /// would be recorded nowhere and the patient would leave with no written
  /// note of what to get done. Remarks is the right home: the field is
  /// labelled "Advice / follow-up" on this screen.
  String _remarksWithTests() {
    final base = _remarks.text.trim();
    if (tests.isEmpty) return base;
    final line = 'Tests advised: ${tests.join(', ')}';
    return base.isEmpty ? line : '$base\n$line';
  }

  /// '5 Days' -> 5. The server requires a positive int and defaults to 5,
  /// so an unparseable label falls back to the same value rather than
  /// failing the whole push.
  static int _daysToInt(String days) {
    final n = int.tryParse(RegExp(r'\d+').firstMatch(days)?.group(0) ?? '');
    return (n == null || n <= 0) ? 5 : n;
  }

  // HS mapping kept — legacy rows might still carry it (dropdown option
  // itself is removed per user rule 2026-08-16, see kFrequencies).
  static const _perDay = {'OD': 1, 'BD': 2, 'TDS': 3, 'QID': 4, 'SOS': 1, 'HS': 1};
  void _recalcQty(RxItem m) {
    // Non-solid forms have no piece count — set qty to 0 so the
    // backend gets a truthful "dispense by volume/tube" value
    // (user 2026-09-14).
    if (!dosageFormNeedsQty(m.dosageForm)) { m.qty = 0; return; }
    final perDay = _perDay[m.interval] ?? 1;
    final days = int.tryParse(RegExp(r'\d+').firstMatch(m.days)?.group(0) ?? '') ?? 0;
    m.qty = perDay * days;
  }

  // Trackers for the LAST auto-applied advisory items (user 2026-08-26:
  // re-Apply was accumulating stale diagnoses/tests/medicines instead of
  // replacing them). Only these get removed on the next Apply — anything
  // the doctor added by hand stays put.
  String? _lastAppliedDx;
  List<String> _lastAppliedTests = const [];
  List<String> _lastAppliedRxNames = const [];

  void _applyAdvisory(String name, DPlan plan) {
    final resolved = DiseaseMaster.resolve(name);
    final dxStr = resolved?.display ?? name;
    // The other half of the adoption record. This path applies from the
    // bundled clinical sheet, which carries no entry id, so the condition is
    // resolved back to the terminology master to find one. No match means no
    // row -- a statistic is not worth guessing at (user 2026-09-30).
    final term = context.read<TerminologyStore>().entryByTerm(name);
    if (term != null) {
      _recordAdvisoryApplied(
        entryId: term.entryId,
        condition: term.standardTerm,
        icd11Code: term.icd11Code,
        tests: plan.tests.where((t) => t.masterName.isNotEmpty).length,
        medicines: plan.rx.length,
      );
    }
    // masterName goes into Investigations; skip tests with no masterName.
    final newTests = plan.tests
        .where((t) => t.masterName.isNotEmpty)
        .map((t) => t.masterName)
        .toList();
    final newRxItems = plan.rx.map((r) {
      final (mn, md) = splitMedicine(r.name);
      // splitMedicine returns the strength WITH its unit — right for the
      // dispense report that also calls it, wrong for an input box that
      // already says MG above it (user 2026-09-26).
      return RxItem(name: mn, dosage: bareStrength(md),
          days: r.days, interval: r.interval, qty: r.qty);
    }).toList();
    setState(() {
      // 1. Drop the PREVIOUS auto-applied items (only if they are still
      //    present — doctor may have deleted them manually).
      if (_lastAppliedDx != null) {
        diagnoses.remove(_lastAppliedDx);
      }
      for (final t in _lastAppliedTests) {
        tests.remove(t);
      }
      for (final rxName in _lastAppliedRxNames) {
        rx.removeWhere((m) => m.name == rxName);
      }
      // 2. Add the new advisory items (dedup against what's already there).
      if (!diagnoses.contains(dxStr)) diagnoses.add(dxStr);
      for (final t in newTests) {
        if (!tests.contains(t)) tests.add(t);
      }
      for (final m in newRxItems) {
        if (!rx.any((x) => x.name == m.name)) rx.add(m);
      }
      // 3. Remember what we just applied for the NEXT re-Apply.
      _lastAppliedDx = dxStr;
      _lastAppliedTests = newTests;
      _lastAppliedRxNames = newRxItems.map((m) => m.name).toList();
      _appliedAdvSig = _advSig;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Applied $name protocol'), backgroundColor: C2.green));
  }

  // Memoized advisory computation (user 2026-08-25: lag after each
  // diagnosis/test/medicine tap). build() ran the whole sheet scan +
  // village aggregation + scoreDoctor on EVERY setState — even when just
  // toggling a chip that has nothing to do with them. Now they only
  // recompute when the inputs they depend on actually change.
  String? _advSig;
  // Signature of the advisory at the moment Apply was tapped. Apply is
  // disabled while `_appliedAdvSig == _advSig` — i.e. nothing about the
  // case has changed since the last apply, so tapping again would just
  // repeat the same protocol (user 2026-08-26). Any input change
  // (symptoms/observation/village/…) rebuilds `_advSig`, which flips
  // the button back to active and the next Apply refreshes tests/rx.
  String? _appliedAdvSig;
  Map<String, int>? _cachedVillageDx;
  ScoredCondition? _cachedSheetTop;
  TermEntry? _cachedSheetEntry;
  List<String> _cachedSheetFlagHits = const [];
  List<ScoredDisease> _cachedScored = const [];
  DPlan? _cachedPlan;
  bool _cachedTermLoaded = false;

  @override
  Widget build(BuildContext context) {
    final s = context.read<CounsellorState>();
    // Watch connectivity — the AI advisory panel is only shown when the doctor
    // is online (user rule: no AI/ML surfaces when offline).
    final online = context.watch<ConnectivityService>().isOnline;
    final terminology = context.watch<TerminologyStore>();
    final obsText = _obs.text;
    final sig = [
      symptoms.join('|'),
      // obsText EXCLUDED (user 2026-08-28 "clicking on observation
      // freezes"): every dictated keystroke was mutating obsText and
      // invalidating this cache, re-running the full terminology scan.
      // The fallback path below still reads obsText — freshness arrives
      // via the observation debounce, not on every scroll/tap.
      p.village,
      p.block ?? '',
      terminology.isLoaded ? 't' : 'f',
      (_advTrending ?? const []).length.toString(),
      s.patients.length.toString(),
    ].join('');
    if (sig != _advSig) {
      _advSig = sig;
      final vill = p.village.trim().toLowerCase();
      final villageDx = <String, int>{};
      if (vill.isNotEmpty) {
        for (final q in s.patients) {
          final d = q.disease.trim();
          if (q.id != p.id && d.isNotEmpty &&
              q.village.trim().toLowerCase() == vill) {
            villageDx[d] = (villageDx[d] ?? 0) + 1;
          }
        }
      }
      _cachedVillageDx = villageDx;
      _cachedTermLoaded = terminology.isLoaded;
      _cachedSheetTop = null;
      _cachedSheetEntry = null;
      _cachedSheetFlagHits = const [];
      if (terminology.isLoaded) {
        final consolidated = [
          ...symptoms,
          if (obsText.trim().isNotEmpty) obsText.trim(),
        ];
        final conds = terminology.likelyConditions(consolidated,
            trending: _advTrending ?? const []);
        if (conds.isNotEmpty) {
          _cachedSheetTop = conds.first;
          _cachedSheetEntry = terminology.entryByTerm(_cachedSheetTop!.name);
          if (_cachedSheetEntry != null) {
            _cachedSheetFlagHits =
                terminology.redFlagHits(consolidated, _cachedSheetEntry!);
          }
        }
      }
      _cachedScored = scoreDoctor(symptoms, p.block,
          observation: obsText, villageDx: villageDx);
      _cachedPlan = _cachedScored.isNotEmpty
          ? doctorDb[_cachedScored.first.name]
          : null;
    }
    final villageDx = _cachedVillageDx ?? const <String, int>{};
    // Avoid unused-variable warnings on the reused caches.
    // ignore: unused_local_variable
    final termLoaded = _cachedTermLoaded;
    // ignore: unused_local_variable
    final _villageDxRef = villageDx;
    final sheetTop = _cachedSheetTop;
    final sheetEntry = _cachedSheetEntry;
    final sheetFlagHits = _cachedSheetFlagHits;
    final scored = _cachedScored;
    final top = scored.isNotEmpty ? scored.first : null;
    final plan = _cachedPlan;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
      child: Scaffold(
        backgroundColor: C2.bg,
        appBar: AppBar(backgroundColor: C2.white, foregroundColor: C2.navy, elevation: 0,
          shape: const Border(bottom: BorderSide(color: C2.cyan, width: 3)), title: Text('Case Details', style: ct(16, FontWeight.w700, C2.navy))),
        body: Focus(
          focusNode: _focusSink,
          // Attached but invisible — never participates in tab traversal and
          // doesn't trigger Scrollable.ensureVisible like a TextField would.
          child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // patient header
          CCard(child: Row(children: [
            Container(width: 46, height: 46, alignment: Alignment.center, decoration: const BoxDecoration(color: C2.cyanLight, shape: BoxShape.circle), child: Text(p.initials, style: ct(18, FontWeight.w700, C2.navy))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, style: ct(16, FontWeight.w700, C2.text)),
              Text('${p.gender}, ${p.age}y · ${p.contact}', style: ct(12, FontWeight.w400, C2.text2)),
              // unique_code stays internal (user rule 2026-08-14).
              Text(p.village.isEmpty ? '—' : p.village, style: ct(11.5, FontWeight.w400, C2.text2)),
            ])),
          ])),
          // registration details (read-only, filled by counsellor)
          CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Expanded(child: SecBar('Registration Details')), CBadge('By Receptionist', bg: C2.cyanLight, fg: C2.cyan)]),
            _kv('Symptoms', p.symptoms.isNotEmpty
                ? p.symptoms.join(', ')
                : (_loadingRegDetail ? 'Loading…' : '—')),
            // Label matches patient_history.dart (user 2026-08-22 rename).
            // p.remarks is set by _applyRegistrationDetail with the English
            // version preferred (counsellor_remarks_english), falling back
            // to the original counsellor_remarks only when English is empty.
            if (p.remarks.isNotEmpty)
              _kv('Patient Remarks', p.remarks,
                  value: CTranslatedText(p.remarks,
                      original: p.remarksOriginal,
                      style: ct(13, FontWeight.w500, C2.text))),
          ])),
          // Editable Vitals card (rule 2026-07-31). Collapsible — same
          // switch pattern as the Counsellor Register form's Vitals section.
          // Values commit to p.vitals via the page-level Submit Case handler.
          CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SecBar('Vitals', trailing: _vitalsToggle()),
            if (_showVitals) ...[
              const SizedBox(height: 4),
              Text('Edit any reading — updated values save when you tap Submit Case.',
                  style: ct(11, FontWeight.w400, C2.text2)),
              const SizedBox(height: 8),
              for (var i = 0; i < _kVitalSpecs.length; i += 2) Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Expanded(child: _vitalField(_kVitalSpecs[i])),
                  const SizedBox(width: 8),
                  Expanded(child: i + 1 < _kVitalSpecs.length
                      ? _vitalField(_kVitalSpecs[i + 1])
                      : const SizedBox()),
                ]),
              ),
            ] else
              Text('Turn on to view or update BP, sugar, temperature and more.',
                  style: ct(11.5, FontWeight.w400, C2.text2)),
          ])),
          // observation box (voice transcript) — between Registration & Symptoms
          CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SecBar('Observation'),
            SmartTranscriptBox(controller: _obs, hint: 'Tap to record, or type observations'),
          ])),
          // Past Medical History input HIDDEN on this page (user
          // 2026-08-14: "dont remove just comment out"). The controller
          // stays seeded from p.pastHistory, so the submit path still
          // carries the counsellor's value forward unchanged and the Dx
          // history dialog still shows it. Uncomment to bring it back:
          // CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          //   const SecBar('Past Medical History'),
          //   Text('Chronic illness, past surgeries, ongoing treatment.', style: ct(11, FontWeight.w400, C2.text2)),
          //   const SizedBox(height: 6),
          //   TextField(controller: _pastHistory, minLines: 2, maxLines: 5, decoration: cInput('e.g. Hypertension, diabetes, prior surgery, current meds')),
          // ])),
          // Prescription and Reports — two chip-buttons (Px + Rx) that open
          // a tabular history dialog (rule 2026-08-05). Doctor sees a
          // structured view of past consultations and past prescriptions
          // instead of two long stacked lists inline.
          CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SecBar('Past Medical History and Prescription'),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(child: _historyChip(
                label: 'Dx',
                icon: Icons.history_edu_outlined,
                count: _pxCount(),
                onTap: () => _openPxHistory(),
              )),
              const SizedBox(width: 8),
              Expanded(child: _historyChip(
                label: 'Rx',
                icon: Icons.medication_outlined,
                count: p.previousRx.length,
                onTap: () => _openRxHistory(),
              )),
            ]),
            if (_pxCount() == 0 && p.previousRx.isEmpty)
              Padding(padding: const EdgeInsets.only(top: 8),
                child: Text('No prescriptions or reports on record.',
                    style: ct(12, FontWeight.w400, C2.text2))),
          ])),
          // symptoms & diagnosis
          CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SecBar('Symptoms & Diagnosis'),
            CField('Symptoms', required: true, SymptomField(
              selected: symptoms,
              block: p.block,
              // Real village name + trends from the advisory API; the
              // village on the patient row is the offline fallback label.
              placeName: _advPlaceName ??
                  (p.village.isNotEmpty ? p.village : p.block),
              trending: _advTrending,
              // Server-computed related symptoms (from the same
              // advisory API). SymptomField will prefer this over its
              // local co-occurrence guess; the client-side compute stays
              // as the offline fallback.
              serverRelated: _advRelated,
              serverLikely: _advLikely,
              loading: _advisoryLoading,
              error: _advisoryError,
              onRetry: () {
                setState(() {
                  _advisoryError = false;
                  _advisoryLoading = true;
                });
                _loadAdvisory();
              },
              // The dictated Observation feeds symptom hints too — the
              // obs listener already rebuilds on every keystroke.
              freeText: _obs.text,
              onChanged: (v) {
                setState(() { symptoms..clear()..addAll(v); _advisoryDismissed = false; });
                // Re-pull advisory so "Common in <village>" tracks the
                // current chip list (2026-08-27).
                _maybeRefetchAdvisory();
              })),
            // Advisory shows the SAME top condition + % as the Likely
            // Conditions card (user 2026-08-22 "percentage showing wrong")
            // — sheet scoring leads; plan looked up by STANDARD TERM in
            // the clinical JSON; ICD rides on the Likely line.
            // AI Advisory only when there's a case to advise on — when
            // the doctor clears all chips there's nothing to interpret
            // (user 2026-08-27: card was lingering after all symptoms
            // were removed).
            if (online && !_advisoryDismissed && symptoms.isNotEmpty
                && _advisoryLoading)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [C2.navy, Color(0xFF005A8D)]),
                    borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                  const SizedBox(width: 10),
                  Text('AI Clinical Advisory — analyzing…',
                      style: ct(12.5, FontWeight.w700, Colors.white)),
                ]),
              ),
            if (online && !_advisoryDismissed && symptoms.isNotEmpty
                && !_advisoryLoading)
              Builder(builder: (_) {
                // Prefer the SERVER's top ranked condition — same list
                // the Likely Conditions card shows (user 2026-08-27:
                // Likely showed Fever top 81% while the Advisory below
                // still read Gout 85% from the client's diverging
                // compute). Fall back to the sheet/client compute only
                // when the server list is empty (offline / cache miss).
                final serverTop = (_advLikely != null && _advLikely!.isNotEmpty)
                    ? _advLikely!.first : null;
                final srvName = serverTop == null ? null
                    : (serverTop['condition'] ?? serverTop['name'] ?? '')
                        .toString();
                final srvPct = serverTop == null ? 0
                    : ((serverTop['score'] ?? serverTop['pct'] ?? 0) as num)
                        .toInt();
                final srvIcd = serverTop == null ? null
                    : (serverTop['icd11_code'] ?? serverTop['icd11'] ?? '')
                        .toString();
                final advName = srvName?.isNotEmpty == true
                    ? srvName : (sheetTop?.name ?? top?.name);
                final advPct = (srvName?.isNotEmpty == true) ? srvPct
                    : (sheetTop?.pct ?? top?.pct ?? 0);
                final advIcd = (srvIcd?.isNotEmpty == true)
                    ? srvIcd! : (sheetEntry?.icd11Code ?? '');
                // Case-insensitive multi-key lookup (loader indexes
                // standardTerm / condition / icd + lowercased variants).
                // NO longer falls back to `plan` — that was silently
                // showing Viral Fever's Tests/Rx/Red Flags under an
                // "Acute sinusitis" header (user 2026-08-26). If
                // doctorDb has no match, we render the terminology
                // sheet's own tests/red-flags/reference instead.
                DPlan? _lookup(String? name) {
                  if (name == null || name.trim().isEmpty) return null;
                  final n = name.trim();
                  return doctorDb[n] ?? doctorDb[n.toLowerCase()];
                }
                final advPlan = _lookup(advName)
                    ?? (sheetEntry != null
                        ? (_lookup(sheetEntry.standardTerm)
                            ?? _lookup(sheetEntry.subCategory)
                            ?? _lookup(sheetEntry.icd11Code))
                        : null);
                if (advName != null && advPlan != null) {
                  return _advisory(advName, advPct, advPlan, icd: advIcd);
                }
                if (sheetEntry != null && sheetTop != null) {
                  return _advisoryFromSheet(sheetTop, sheetEntry, sheetFlagHits);
                }
                return const SizedBox.shrink();
              }),
            CField('Diagnosis (ICD-11)', required: true, _diagnosisField()),
            CField('Investigations', _testsField()),
          ])),
          // prescription
          CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Section header carries the required marker so the Prescription
            // card matches Symptoms / Diagnosis (user 2026-09-02: add red
            // asterisk on required fields, don't touch working functionality).
            const SecBar('Prescription', required: true),
            if (rx.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(_showRxErrors ? 'Add at least one medicine' : 'No medicines added',
                    style: ct(12, FontWeight.w400,
                        _showRxErrors ? C2.danger : C2.text2))),
            ...rx.map(_medCard),
            const SizedBox(height: 6),
            // Frequently prescribed medicines — chip strip above the
            // "Add Medicine" button. Each chip carries the name AND the
            // most-common strength (e.g. "Paracetamol · 500 mg"), so a
            // tap adds a fully-prefilled Rx row. Cream card, medium
            // radius (user 2026-09-11).
            Builder(builder: (_) {
              final freq = _frequentMedicines();
              if (freq.isEmpty) return const SizedBox.shrink();
              return Padding(padding: const EdgeInsets.only(bottom: 6),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('FREQUENTLY PRESCRIBED', style: ct(10, FontWeight.w700, C2.text2)),
                  const SizedBox(height: 4),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    for (final f in freq)
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() {
                          if (rx.any((x) => x.name == f.name)) return;
                          // The chip SHOWS "Paracetamol · 100 mg" because
                          // that reads well on a chip. The Dosage box is
                          // captioned (MG) and filters to digits, so only
                          // the number goes in (user 2026-09-26).
                          rx.add(RxItem(name: f.name, dosage: bareStrength(f.dosage)));
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: C2.border),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.add, size: 13, color: C2.text),
                            const SizedBox(width: 4),
                            Text(f.dosage.isEmpty ? f.name : '${f.name} · ${f.dosage}',
                                style: ct(12, FontWeight.w700, C2.text)),
                          ]),
                        ),
                      ),
                  ]),
                ]),
              );
            }),
            COutlineButton('Add Medicine', icon: Icons.add_circle_outline, onTap: _addMed),
          ])),
          // doctor remarks (with speech-to-text)
          CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SecBar('Doctor Remarks'),
            TextField(controller: _remarks, minLines: 2, maxLines: null, decoration: cInput('Advice / follow-up').copyWith(
              suffixIcon: RemarksMicButton(controller: _remarks))),
          ])),
          // Next follow-up: Yes -> pick the date (user 2026-08-21). Rides
          // to the server as follow_up_date, which doctor_submit already
          // stores on the prescription.
          CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SecBar('Next Follow-Up', required: true),
            Row(children: [
              for (final yes in [true, false]) ...[
                InkWell(
                  onTap: () => setState(() {
                    _nextFollowUp = yes;
                    if (!yes) _followUpDate = null;
                  }),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      _nextFollowUp == yes
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      size: 18,
                      color: _nextFollowUp == yes ? C2.cyan : C2.text3,
                    ),
                    const SizedBox(width: 5),
                    Text(yes ? 'Yes' : 'No', style: ct(13, FontWeight.w600, C2.text)),
                  ]),
                ),
                const SizedBox(width: 24),
              ],
            ]),
            if (_nextFollowUp == true) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final now = DateTime.now();
                  // A month out at most. The picker opened on a full year,
                  // so a stray tap on the forward arrow landed the doctor
                  // in September 2027 and a review that far ahead is not a
                  // follow-up (user 2026-09-30). Tomorrow is still the
                  // earliest — a follow-up dated today is this visit.
                  final last = now.add(const Duration(days: _followUpMaxDays));
                  final current = _followUpDate;
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: (current != null && !current.isAfter(last))
                        ? current
                        : now.add(const Duration(days: 7)),
                    firstDate: now.add(const Duration(days: 1)),
                    lastDate: last,
                  );
                  if (picked != null) setState(() => _followUpDate = picked);
                },
                child: InputDecorator(
                  decoration: cInput('Select follow-up date').copyWith(
                    suffixIcon: const Icon(Icons.calendar_month, size: 18)),
                  child: Text(
                    _followUpDate == null
                        ? 'Select follow-up date'
                        : fmtDate(_followUpDate!),
                    style: ct(13, FontWeight.w500,
                        _followUpDate == null ? C2.text3 : C2.text),
                  ),
                ),
              ),
            ],
          ])),
          const SizedBox(height: 4),
          CPrimaryButton(
              _submittingCase ? 'Submitting…' : 'Submit Case',
              icon: _submittingCase ? Icons.hourglass_top : Icons.check_circle_outline,
              onTap: _submittingCase ? null : () async {
            // [JC] debug trail (user 2026-08-21) — visible in logcat.
            print('[JC] submit tapped: dx=${diagnoses.length} rx=${rx.length} '
                'followUp=$_nextFollowUp date=$_followUpDate '
                'apptId=${p.backendAppointmentId}');
            void err(String m) {
              print('[JC] submit BLOCKED: ' + m);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: C2.danger));
            }
            if (symptoms.isEmpty) { return err('Add at least one symptom'); }
            if (diagnoses.isEmpty) { return err('Add at least one diagnosis'); }
            // Prescription is now a hard requirement — a doctor's submit
            // without any medicine used to slip through and land at the
            // pharmacist with nothing to dispense (user 2026-09-02).
            if (rx.isEmpty) {
              setState(() => _showRxErrors = true);
              return err('Add at least one medicine');
            }
            if (_nextFollowUp == null) { return err('Answer "Next Follow-Up" (Yes/No)'); }
            if (_nextFollowUp == true && _followUpDate == null) { return err('Select the follow-up date'); }
            // Catches a date the picker could not have produced — one held
            // from before the limit existed, or a re-appointment prefill.
            if (_nextFollowUp == true && _followUpDate != null &&
                _followUpDate!.isAfter(DateTime.now()
                    .add(const Duration(days: _followUpMaxDays)))) {
              return err('Follow-up must be within $_followUpMaxDays days');
            }
            // Vitals must be clinically plausible (user 2026-08-22).
            for (final v in _kVitalSpecs) {
              final rangeErr = _vitalRangeErr(v.key);
              if (rangeErr != null) return err('${v.label}: $rangeErr');
            }
            // Prescription validation: any row added must be complete.
            // Doctor's prescription is the audit trail — half-filled rows
            // block dispense downstream (user rule 2026-08-16).
            // Validation reads the SAME options the dropdown showed —
            // server list first, static fallback next (user 2026-09-07
            // dynamic frequencies). Never reject a value that the row
            // itself just offered.
            final _allowedFreqs = _frequencyOptions(context).toSet();
            for (final m in rx) {
              final missingCombo = m.combos.firstWhere(
                  (c) => c.dosage.trim().isEmpty,
                  orElse: () => ComboMed(name: ''));
              final bad = m.dosage.trim().isEmpty ||
                  !_allowedFreqs.contains(m.interval) ||
                  _durationError(m.days) != null ||
                  missingCombo.name.isNotEmpty;
              // Light up the inline "Required" boxes from here on — they
              // stay hidden until the first failed Submit (user 2026-08-21).
              if (bad) setState(() => _showRxErrors = true);
              if (m.dosage.trim().isEmpty) return err('${m.name}: enter dosage');
              if (!_allowedFreqs.contains(m.interval)) return err('${m.name}: pick frequency');
              if (_durationError(m.days) != null) return err('${m.name}: ${_durationError(m.days)!.toLowerCase()} in duration');
              if (missingCombo.name.isNotEmpty) return err('${missingCombo.name}: enter dosage');
            }
            // Bilingual columns (user 2026-08-21): the original goes to
            // `observation` / `doctor_remarks` exactly as dictated; the
            // *_english twin is translated the same way the counsellor's
            // remarks are (Google web → ML Kit offline → raw). Hard cap so
            // Submit never hangs on a slow translator.
            final obsOriginal = _obs.text.trim();
            final remOriginal = _remarksWithTests();
            final devanagari = RegExp(r'[ऀ-ॿ]');
            Future<String> toEnglish(String t) async {
              if (t.isEmpty || !devanagari.hasMatch(t)) return t;
              try {
                return await TranslationService.hiToEn(t)
                    .timeout(const Duration(seconds: 12));
              } catch (_) {
                return t; // worst case: original rides in both columns
              }
            }
            // Lock the button for the WHOLE remaining flow (translation,
            // enqueue, snackbar, pop). A second tap during the up-to-12 s
            // translation was creating a duplicate doctor_submit push
            // (user 2026-09-02 parity fix with counsellor register).
            setState(() => _submittingCase = true);
            try {
            final obsEnglish = await toEnglish(obsOriginal);
            final remEnglish = await toEnglish(remOriginal);
            if (!mounted) return;
            p.pastHistory = _pastHistory.text.trim();
            // Commit any edited vitals so the update rides along with the
            // rest of the case submission.
            _commitVitalsToPatient();
            // Split each chip's "Term · ICD" label into the two columns the
            // server keeps them in. Blank-text chips can't happen (the picker
            // never returns one) but are dropped rather than trusted.
            final dxPayload = <Map<String, Object?>>[];
            for (var i = 0; i < diagnoses.length; i++) {
              final d = _splitDx(diagnoses[i]);
              if (d.text.isEmpty) continue;
              dxPayload.add({'diagnosis_text': d.text,
                             'icd11_code':     d.icd,
                             'is_primary':     i == 0});
            }
            s.doctorSubmit(p, disease: diagnoses.join(', '), rx: rx, tests: tests, observations: _obs.text.trim(), remarks: _remarks.text.trim());
            // Enqueue appointment.doctor_submit (v2 §4). Server decides
            // the next status based on tests vs medicines.
            print('[JC] submit validations passed — enqueueing doctor_submit');
            try {
            context.read<SyncService>().enqueue(kind: 'appointment.doctor_submit', payload: {
              // The server resolves the case by appointment_id and rejects the
              // push outright without it ("appointment_id is required", 422 —
              // mobile.py `_doctor_submit`). p.id is the local row key ('B71'),
              // never an appointment id, so sending only client_appointment_ref
              // meant every consultation was rejected: the phone showed the
              // case as done while the server kept it at 'with_doctor', and the
              // next queue refresh pulled that stale status back as In Progress.
              if (p.backendAppointmentId != null)
                'appointment_id': p.backendAppointmentId,
              'client_appointment_ref': p.id,
              'observation':            obsOriginal,
              'doctor_remarks':         remOriginal,
              // English twins → appointments.observation_english /
              // doctor_remarks_english (real columns, user 2026-08-21).
              'observation_english':    obsEnglish,
              'doctor_remarks_english': remEnglish,
              // Next Follow-Up (user 2026-08-21). ISO date; the server's
              // doctor_submit stores it on the prescription row.
              if (_nextFollowUp == true && _followUpDate != null)
                'follow_up_date': _followUpDate!.toIso8601String().substring(0, 10),
              'past_history':           _pastHistory.text.trim(),
              // Doctor-side symptom chips (auto-added from the dictation
              // or hand-picked) ride to the server too — before this only
              // the counsellor's picks showed on the record (user
              // 2026-08-22 "details page only showing Sore throat").
              'symptom_names': [for (final s in symptoms) s],
              // DoctorSubmitIn reads `diagnosis_text`; a bare `text` key was
              // dropped on the floor, losing the diagnosis on every case.
              // `icd11_code` rides separately so the server can link the visit
              // to the diseases master the web portal reads — without it the
              // web's Diagnosis column stayed "—" on every MMU case.
              'diagnoses': dxPayload,
              // Tests are recorded as ADVISED (not billed) — the patient
              // goes straight to the pharmacist. lab_test_ids carries the
              // master ids so the server creates structured LabTestOrder
              // rows; lab_test_names is the text fallback.
              'lab_test_ids': [
                for (final t in tests)
                  if (context.read<MastersStore>().labTestIdOf(t) case final id?) id,
              ],
              'lab_test_names': [ for (final t in tests) t ],
              'prescription': () {
                // Resolve master ids on the mobile side so the server
                // skips the case-insensitive name/code scan (user
                // 2026-09-10 id-first). Name/code still ride as fallback
                // for older server builds. Combination medicines split
                // into TWO prescription lines that share frequency,
                // duration, and qty (user 2026-09-11).
                final masters = context.read<MastersStore>();
                Map<String, dynamic> line(String name, String dosage,
                    String dosageForm, RxItem m, {String comboKey = ''}) {
                  final medId = masters.masterIdOf('medicines', name);
                  final freqId = masters.masterIdOf('frequencies', m.interval);
                  return {
                    'medicine_name': name,
                    if (medId != null) 'medicine_id': medId,
                    'dosage': dosageForm.isEmpty
                        ? dosage
                        : '$dosageForm$kDosageFormSep$dosage',
                    if (dosageForm.isNotEmpty) 'dosage_form': dosageForm,
                    'frequency': m.interval,
                    if (freqId != null) 'frequency_id': freqId,
                    'duration_days': _daysToInt(m.days),
                    'qty': m.qty,
                    if (comboKey.isNotEmpty) 'combo_key': comboKey,
                  };
                }
                final out = <Map<String, dynamic>>[];
                var comboSeq = 0;
                for (final m in rx) {
                  // Every line in a combination strip shares one
                  // combo_key so the pharmacist card groups them
                  // together. Single medicines stay untouched (user
                  // 2026-09-12, multi-combo 2026-09-15).
                  final comboKey = m.combos.isEmpty
                      ? ''
                      : 'c${DateTime.now().millisecondsSinceEpoch}_${comboSeq++}';
                  out.add(line(m.name, m.dosage, m.dosageForm, m, comboKey: comboKey));
                  for (final c in m.combos) {
                    // Every combo partner shares the primary's dosage
                    // form (one physical strip carrying all).
                    out.add(line(c.name, c.dosage, m.dosageForm, m, comboKey: comboKey));
                  }
                }
                return out;
              }(),
              'vitals': {
                for (final e in p.vitals.entries) e.key: e.value,
              },
            });
            } catch (e, st) {
              print('[JC] enqueue THREW: ' + e.toString());
              print(st.toString().split('\n').take(6).join(' | '));
            }
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(rx.isEmpty ? 'Case completed' : 'Case submitted → Pharmacist'), backgroundColor: C2.green));
            print('[JC] submit done — popping case screen, canPop='
                '${Navigator.of(context).canPop()}');
            try {
              Navigator.of(context).pop();
              print('[JC] pop OK');
            } catch (e) {
              print('[JC] pop FAILED: ' + e.toString());
            }
            } finally {
              // Release the button — no-op if pop already disposed us.
              if (mounted) setState(() => _submittingCase = false);
            }
          }),
          const SizedBox(height: 8),
        ])))),
      ),
    );
  }

  /// AI Clinical Advisory from the master sheet (spec 2026-08-21):
  /// highest-probability condition + ICD, its symptom profile, red flags
  /// (the ones present in THIS case highlighted first), tests/treatment/Rx
  /// only when the approved local clinical DB carries them, and the
  /// literature reference. Percentages are AI-estimated confidence, never
  /// a diagnosis - the doctor reviews and decides.
  Widget _advisoryFromSheet(
      ScoredCondition c, TermEntry e, List<String> flagHits) {
    Widget line(IconData ic, String label, String val,
            {Color? valueColor}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(ic, size: 14, color: C2.cyanLight), const SizedBox(width: 8),
            Expanded(child: RichText(text: TextSpan(children: [
              TextSpan(text: '$label  ', style: ct(12, FontWeight.w700, C2.cyanLight)),
              TextSpan(text: val,
                  style: ct(12.5, FontWeight.w400, valueColor ?? Colors.white)),
            ]))),
          ]),
        );
    // Approved local clinical content (tests/treatment/Rx) - shown only
    // when it exists for this condition; never invented. Multi-key +
    // lowercase lookup matches the loader's index (user 2026-08-26:
    // Fever's kdoctordb tests/red-flags weren't appearing because the
    // sheet name missed the map key).
    final plan = doctorDb[e.standardTerm] ??
        doctorDb[e.standardTerm.toLowerCase()] ??
        doctorDb[e.subCategory] ??
        doctorDb[e.subCategory.toLowerCase()] ??
        (e.icd11Code != null ? doctorDb[e.icd11Code!] : null);
    // The terminology sheet's Symptoms/Red-Flags columns mix short
    // names with full clinical paragraphs — only the short ones belong
    // on this compact card (user 2026-08-26 "card change kar diya").
    final shortSymptoms =
        e.symptoms.where((s) => s.trim().length <= 40).take(6).toList();
    final shortFlags =
        e.redFlags.where((s) => s.trim().length <= 60).take(3).toList();
    final icd = (e.icd11Code ?? '').isEmpty ? '' : ' | ICD ${e.icd11Code}';
    final flagWord = flagHits.length == 1 ? 'RED FLAG' : 'RED FLAGS';
    return RepaintBoundary(child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [C2.navy, Color(0xFF005A8D)]), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.memory, size: 15, color: Colors.white), const SizedBox(width: 6),
          Text('AI Clinical Advisory', style: ct(12.5, FontWeight.w700, Colors.white)),
        ]),
        const SizedBox(height: 10),
        // Red flags present in THIS case - the most important line (spec).
        if (flagHits.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: C2.danger.withValues(alpha: 0.25),
                border: Border.all(color: C2.danger),
                borderRadius: BorderRadius.circular(8)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Expanded(child: Text(
                  '$flagWord PRESENT: ${flagHits.join('; ')}',
                  style: ct(11.5, FontWeight.w700, Colors.white))),
            ]),
          ),
        line(Icons.coronavirus_outlined, 'Likely:',
            '${e.standardTerm} (${c.pct}%)$icd'),
        if (shortSymptoms.isNotEmpty)
          line(Icons.sick_outlined, 'Symptoms:', shortSymptoms.join('; ')),
        if (plan != null) ...[
          if (plan.tests.isNotEmpty)
            line(Icons.science_outlined, 'Tests:',
                plan.tests.map((t) => t.sourceText).where((t) => t.trim().length <= 60).join(', ')),
          if (plan.firstLine.trim().isNotEmpty)
            line(Icons.healing_outlined, 'Treatment:', plan.firstLine),
          if (plan.rx.isNotEmpty)
            line(Icons.medication_outlined, 'Rx:',
                plan.rx.map((r) => '${r.name} (${r.interval} x ${r.days})').join(', ')),
          if (plan.redFlags.isNotEmpty)
            line(Icons.warning_amber_rounded, 'Red Flags:',
                plan.redFlags.where((f) => f.trim().length <= 60)
                    .take(3).join('; ')),
        ],
        if (plan == null && flagHits.isEmpty && shortFlags.isNotEmpty)
          line(Icons.warning_amber_rounded, 'Red Flags:',
              shortFlags.join('; ')),
        if (e.reference.isNotEmpty)
          line(Icons.menu_book_outlined, 'Ref:', e.reference),
        const SizedBox(height: 6),
        Row(children: [
          _aiBtn(_appliedAdvSig == null ? 'Apply' : 'Re-apply',
              C2.green, () {
            final label = (e.icd11Code ?? '').isEmpty
                ? e.standardTerm
                : '${e.standardTerm} | ${e.icd11Code}';
            setState(() {
              if (!diagnoses.contains(label)) diagnoses.add(label);
              if (plan != null) {
                for (final t in plan.tests) {
                  if (t.masterName.isEmpty) continue;
                  if (!tests.contains(t.masterName)) tests.add(t.masterName);
                }
                for (final r in plan.rx) {
                  if (!rx.any((x) => x.name == r.name)) {
                    rx.add(RxItem(name: r.name,
                        days: r.days, interval: r.interval, qty: r.qty));
                  }
                }
              }
              // Track applied signature so the button switches to
              // Re-apply and Dismiss hides after the first tap
              // (user 2026-08-27).
              _appliedAdvSig = _advSig;
            });
            // Tell the server the advisory was taken. Until this existed the
            // adoption panel counted the web portal only, and every MMU
            // consultation was missing from it (user 2026-09-30). Fired and
            // forgotten -- a statistic never delays the doctor.
            _recordAdvisoryApplied(
              entryId: e.entryId,
              condition: e.standardTerm,
              icd11Code: e.icd11Code,
              tests: plan?.rx == null
                  ? 0
                  : plan!.tests.where((t) => t.masterName.isNotEmpty).length,
              medicines: plan?.rx.length ?? 0,
            );
          }, disabled: _appliedAdvSig != null && _appliedAdvSig == _advSig),
          // Dismiss hides after the first Apply — once the plan is on
          // record, dismissing the card no longer makes sense
          // (user 2026-08-27).
          if (_appliedAdvSig == null) ...[
            const SizedBox(width: 6),
            _aiBtn('Dismiss', Colors.white.withValues(alpha: 0.15),
                () => setState(() => _advisoryDismissed = true)),
          ],
        ]),
      ]),
    ));
  }

  Widget _advisory(String name, int pct, DPlan plan, {String? icd}) {
    Widget line(IconData ic, String label, String val) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(ic, size: 14, color: C2.cyanLight), const SizedBox(width: 8),
            Expanded(child: RichText(text: TextSpan(children: [
              TextSpan(text: '$label  ', style: ct(12, FontWeight.w700, C2.cyanLight)),
              TextSpan(text: val, style: ct(12.5, FontWeight.w400, Colors.white)),
            ]))),
          ]),
        );
    final rxStr = plan.rx.map((r) => '${r.name} (${r.interval} × ${r.days})').join(', ');
    return RepaintBoundary(child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [C2.navy, Color(0xFF005A8D)]), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.memory, size: 15, color: Colors.white), const SizedBox(width: 6),
          Text('AI Clinical Advisory', style: ct(12.5, FontWeight.w700, Colors.white)),
        ]),
        const SizedBox(height: 10),
        // "Typhoid fever - 1A09 (46%)" (user 2026-08-22).
        line(Icons.coronavirus_outlined, 'Likely:',
            '$name${(icd ?? '').isNotEmpty ? ' - $icd' : ''} ($pct%)'),
        line(Icons.science_outlined, 'Tests:', plan.tests.map((t) => t.sourceText).join(', ')),
        line(Icons.healing_outlined, 'Treatment:', plan.firstLine),
        line(Icons.medication_outlined, 'Rx:', rxStr),
        line(Icons.warning_amber_rounded, 'Red Flags:', plan.redFlags.join(', ')),
        // Disclaimer strip removed (user 2026-08-22).
        const SizedBox(height: 6),
        Row(children: [
          _aiBtn(_appliedAdvSig == null ? 'Apply' : 'Re-apply',
              C2.green, () => _applyAdvisory(name, plan),
              disabled: _appliedAdvSig != null && _appliedAdvSig == _advSig),
          // Dismiss hides after the first Apply (user 2026-08-27).
          if (_appliedAdvSig == null) ...[
            const SizedBox(width: 6),
            _aiBtn('Dismiss', Colors.white.withValues(alpha: 0.15),
                () => setState(() => _advisoryDismissed = true)),
          ],
        ]),
      ]),
    ));
  }

  /// Record that the doctor took the advisory. Never awaited and never
  /// allowed to throw: this is a dashboard number, and a dashboard number is
  /// not worth a snackbar on a clinical screen.
  void _recordAdvisoryApplied({
    required int entryId,
    required String condition,
    String? icd11Code,
    int tests = 0,
    int medicines = 0,
  }) {
    final apptId = p.backendAppointmentId;
    if (apptId == null || entryId <= 0) return;
    unawaited(context.read<AppointmentsApi>().advisoryApplied(
          apptId,
          entryId: entryId,
          condition: condition,
          icd11Code: icd11Code,
          diagnosis: true,
          tests: tests,
          medicines: medicines,
        ));
  }

  Widget _aiBtn(String t, Color bg, VoidCallback onTap, {bool disabled = false}) => InkWell(
        onTap: disabled ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
              color: disabled ? bg.withValues(alpha: 0.35) : bg,
              borderRadius: BorderRadius.circular(6)),
          child: Text(t,
              style: ct(12, FontWeight.w600,
                  disabled ? Colors.white.withValues(alpha: 0.55) : Colors.white)),
        ),
      );

  Widget _diagnosisField() {
    final loaded = DiseaseMaster.isLoaded;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (diagnoses.isNotEmpty)
        Padding(padding: const EdgeInsets.only(bottom: 6), child: Wrap(spacing: 6, runSpacing: 6, children: diagnoses.map((d) => Chip(
          label: Text(d, style: ct(11.5, FontWeight.w600, C2.navy)), backgroundColor: C2.cyanLight, side: BorderSide.none,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, visualDensity: VisualDensity.compact,
          deleteIcon: const Icon(Icons.close, size: 13), deleteIconColor: C2.text2, onDeleted: () => setState(() => diagnoses.remove(d)),
        )).toList())),
      COutlineButton(loaded ? 'Add Diagnosis' : 'Loading disease list…', icon: Icons.add, onTap: !loaded ? null : () async {
        print('[JC] Add Diagnosis TAPPED at ${DateTime.now().toIso8601String().substring(11,23)}');
        // Park focus on the page-level sink so the modal route's focus
        // restoration can't bring focus back to the Symptoms TextField
        // (which would call Scrollable.ensureVisible and jump the page).
        _parkFocus();
        final picked = await showModalBottomSheet<String>(
          context: context, isScrollControlled: true, backgroundColor: C2.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          builder: (_) => const _DiseasePickerSheet());
        if (!mounted) return;
        _parkFocus();
        if (picked != null && picked.trim().isNotEmpty && !diagnoses.contains(picked)) setState(() => diagnoses.add(picked));
      }),
    ]);
  }

  Widget _testsField() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Not a Chip: a Chip keeps its label on one line, and the master's
      // standard names run long — "Spirometry / Pulmonary Function Test
      // (with bronchodilator reversibility)" lost its tail the moment the
      // advisory started applying them (user 2026-09-29). This wraps to as
      // many lines as the name needs, bounded by the field's own width.
      if (tests.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: LayoutBuilder(builder: (context, box) => Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in tests)
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: box.maxWidth),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
                    decoration: BoxDecoration(
                        color: C2.cyanLight,
                        borderRadius: BorderRadius.circular(14)),
                    child: Row(mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                      Flexible(child: Text(t,
                          style: ct(11.5, FontWeight.w600, C2.navy))),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => setState(() => tests.remove(t)),
                        borderRadius: BorderRadius.circular(10),
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(Icons.close, size: 13, color: C2.text2),
                        ),
                      ),
                    ]),
                  ),
                ),
            ],
          )),
        ),
      COutlineButton('Add Test', icon: Icons.add, onTap: () async {
        print('[JC] Add Test TAPPED at ${DateTime.now().toIso8601String().substring(11,23)}');
        _parkFocus();
        // Lab tests DYNAMIC — server master `lab_tests` first, static
        // fallback (user 2026-09-10 dynamic masters, additive only —
        // send-side payload unchanged, no breakage risk).
        // Server master only. The hardcoded kLabTests used to be merged in
        // on top of it, so "ESR", "Blood Group" and "ANC Profile" were
        // offered whether or not this organisation's catalogue had them —
        // and a test it does not have resolves to no id, so the order was
        // dropped without a word (user 2026-09-30).
        final labTests = <String>[
          for (final r in context.read<MastersStore>().masterRows('lab_tests'))
            if ((r['name'] ?? r['term']) != null)
              (r['name'] ?? r['term']).toString(),
        ];
        final picked = await _pick(context, 'Add Test', labTests.where((t) => !tests.contains(t)).toList());
        if (!mounted) return;
        _parkFocus();
        if (picked != null) setState(() => tests.add(picked));
      }),
    ]);
  }

  Widget _medCard(RxItem m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: C2.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: C2.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // Combined name — "Paracetamol + Vitamin A + Vitamin B" when
          // combo partners are attached (a single tablet strip that
          // carries all, user 2026-09-15 multi-combo). Single-medicine
          // rows show name alone.
          Expanded(child: Text(
              m.combos.isEmpty
                  ? m.name
                  : '${m.name}${m.combos.map((c) => ' + ${c.name}').join()}',
              style: ct(13, FontWeight.w600, C2.text))),
          // Edit combo — bare pencil icon (user 2026-09-18 "remove
          // rounded circle from pencil icon"). Opens the manage sheet
          // where the doctor can tick / untick partners in one place.
          //
          // The icon LOOKS 20px but its tap target is 42x42 (user
          // 2026-09-22 "pencil edit icon ... nothing happening"):
          // Icon(20) + EdgeInsets.all(4) gave a 28x28 hit box, so any
          // tap more than ~14px off centre landed on the dead gap
          // between the pencil and the X and did nothing. Measured on
          // device — 38px off still fired, 53px off did not. 42 clears
          // Material's 48-dp guidance far enough for a finger without
          // pushing the two icons apart visually.
          InkWell(
            onTap: () => _editCombos(m),
            borderRadius: BorderRadius.circular(6),
            child: const SizedBox(
              width: 42, height: 42,
              child: Icon(Icons.edit, size: 20, color: C2.navy),
            ),
          ),
          // Remove medicine — same enlarged target. This one is
          // destructive, so an accidental near-miss mattered even more
          // than the pencil's: the bare Icon(20) was a 20x20 hit box.
          InkWell(
            onTap: () => setState(() => rx.remove(m)),
            borderRadius: BorderRadius.circular(6),
            child: const SizedBox(
              width: 42, height: 42,
              child: Icon(Icons.close, size: 20, color: C2.text2),
            ),
          ),
        ]),
        // Pharmacy on-hand for this unit (user 2026-08-21). Only rendered
        // once /medicines/stock has answered — unknown medicines show 0.
        if (_stockLoaded)
          Padding(padding: const EdgeInsets.only(top: 2), child: Builder(builder: (_) {
            final qty = _stock[_stockKey(m.name)] ?? 0;
            return Text('Stock: $qty',
                style: ct(10.5, FontWeight.w600, qty > 0 ? C2.green : C2.danger));
          })),
        const SizedBox(height: 8),
        // Dosage Form FIRST, then Dosage — same reading order the
        // pharmacist requisition form has used since 2026-09-14, now
        // asked for here too (user 2026-09-22). The form is not a
        // detail hanging off the strength; it decides what the
        // strength MEANS, so it has to be answered first: Tab / Cap
        // are counted in mg, Syp / Gel / Cream are measured in ml, and
        // the label, placeholder, keyboard and input rules of the
        // Dosage box all follow from it.
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('DOSAGE FORM', style: ct(9.5, FontWeight.w600, C2.text2)),
            const SizedBox(height: 3),
            SizedBox(height: 38, child: SearchDropdown(
              items: kDosageForms,
              value: kDosageForms.contains(m.dosageForm) ? m.dosageForm : null,
              onChanged: (v) => setState(() { m.dosageForm = v ?? ''; _recalcQty(m); }))),
          ])),
          const SizedBox(width: 6),
          Expanded(flex: 3, child: Builder(builder: (_) {
            final needsQty = dosageFormNeedsQty(m.dosageForm);
            final unit = needsQty ? 'MG' : 'ML';
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.combos.isEmpty
                      ? 'DOSAGE ($unit)'
                      : '${m.name.toUpperCase()} DOSAGE ($unit)',
                  style: ct(9.5, FontWeight.w600, C2.text2)),
              const SizedBox(height: 3),
              TextFormField(
                key: ValueKey('dose-${identityHashCode(m)}-$needsQty'),
                initialValue: m.dosage, style: ct(12.5, FontWeight.w500, C2.text),
                keyboardType: needsQty
                    ? TextInputType.number
                    : const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: needsQty
                    ? [FilteringTextInputFormatter.digitsOnly,
                       LengthLimitingTextInputFormatter(4)]
                    : [LengthLimitingTextInputFormatter(12)],
                decoration: cInput(needsQty ? 'e.g. 500' : 'e.g. 100 ml').copyWith(
                  errorText: (_showRxErrors && m.dosage.trim().isEmpty) ? 'Required' : null,
                  errorStyle: const TextStyle(fontSize: 11),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => m.dosage = v)),
            ]);
          })),
        ]),
        // Combination partner dosages — one stacked row per attached
        // ComboMed. No inline X; the pencil edit icon in the header
        // handles remove. Partners share the primary's dosage form, so
        // their unit follows it too.
        for (final c in m.combos) ...[
          const SizedBox(height: 8),
          Builder(builder: (_) {
            final needsQty = dosageFormNeedsQty(m.dosageForm);
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${c.name.toUpperCase()} DOSAGE (${needsQty ? 'MG' : 'ML'})',
                  style: ct(9.5, FontWeight.w600, C2.text2)),
              const SizedBox(height: 3),
              TextFormField(
                key: ValueKey('combo-${identityHashCode(c)}-$needsQty'),
                initialValue: c.dosage, style: ct(12.5, FontWeight.w500, C2.text),
                keyboardType: needsQty
                    ? TextInputType.number
                    : const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: needsQty
                    ? [FilteringTextInputFormatter.digitsOnly,
                       LengthLimitingTextInputFormatter(4)]
                    : [LengthLimitingTextInputFormatter(12)],
                decoration: cInput(needsQty ? 'e.g. 500' : 'e.g. 100 ml').copyWith(
                  errorText: (_showRxErrors && c.dosage.trim().isEmpty) ? 'Required' : null,
                  errorStyle: const TextStyle(fontSize: 11),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => c.dosage = v)),
            ]);
          }),
        ],
        const SizedBox(height: 8),
        // Top-align — a "Required" error under Duration makes that
        // column ~20px taller than Frequency / QTY, and the default
        // center-alignment was dropping the neighbours by half that
        // gap, breaking the row (user 2026-09-15).
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Frequency options are DYNAMIC — pulled from the server's
          // `masters.frequencies` (bootstrap). Static `kFrequencies` stays
          // as the offline fallback so a fresh install / cache-miss still
          // renders a working dropdown, and validation always accepts
          // either source (user 2026-09-07: "do dynamic frequencies").
          Expanded(child: _mini('Frequency', m.interval, _frequencyOptions(context),
              (v) => setState(() { m.interval = v; _recalcQty(m); }))),
          const SizedBox(width: 6),
          // Open-ended duration: 1-2 digit days OR a 3-letter code (SOS, PRN).
          // Dropdown can't cover all values the AI advisory suggests.
          Expanded(child: _miniDuration(m)),
          // QTY only makes sense for solid forms (Tab / Cap). For
          // syrup / jell / cream the pharmacist dispenses by volume
          // or a whole tube, so hide the auto-count box (user
          // 2026-09-14).
          if (dosageFormNeedsQty(m.dosageForm)) ...[
            const SizedBox(width: 6),
            SizedBox(width: 64, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('QTY (auto)', style: ct(9.5, FontWeight.w600, C2.text2)), const SizedBox(height: 3),
              Container(height: 38, alignment: Alignment.center,
                decoration: BoxDecoration(color: C2.cyanLight, borderRadius: BorderRadius.circular(8), border: Border.all(color: C2.border)),
                child: Text('${m.qty}', style: ct(14, FontWeight.w700, C2.navy))),
            ])),
          ],
        ]),
      ]),
    );
  }

  Widget _mini(String label, String val, List<String> opts, ValueChanged<String> onCh) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: ct(10, FontWeight.w600, C2.text2)), const SizedBox(height: 3),
        SizedBox(height: 38, child: SearchDropdown(
          items: opts, value: opts.contains(val) ? val : null,
          onChanged: (v) => onCh(v ?? val))),
      ]);

  /// Frequency options — server master (bootstrap `masters.frequencies`)
  /// leads; the const `kFrequencies` list is the offline fallback. Result
  /// is deduplicated so a server list that already covers the fallback
  /// codes does not repeat them (user 2026-09-07 dynamic frequencies).
  List<String> _frequencyOptions(BuildContext ctx) {
    final server = ctx.read<MastersStore>().masterStrings('frequencies');
    if (server.isNotEmpty) {
      // Preserve server order but ensure every static fallback code is
      // reachable — an old build's saved value must still validate.
      final seen = <String>{};
      final out = <String>[];
      for (final s in [...server, ...kFrequencies]) {
        if (s.trim().isEmpty) continue;
        if (seen.add(s)) out.add(s);
      }
      return out;
    }
    return kFrequencies;
  }

  /// Duration input — days only, 1-99 (user rule 2026-08-16: no
  /// letter codes, plain number). Label spells out the unit so the
  /// doctor never has to type "Days" as part of the value.
  Widget _miniDuration(RxItem m) {
    final err = _showRxErrors ? _durationError(m.days) : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('DURATION (DAYS)', style: ct(10, FontWeight.w600, C2.text2)),
      const SizedBox(height: 3),
      TextFormField(
        initialValue: m.days,
        style: ct(12.5, FontWeight.w500, C2.text),
        keyboardType: TextInputType.number,
        decoration: cInput('e.g. 5').copyWith(
          errorText: err,
          errorStyle: const TextStyle(fontSize: 11),
          isDense: true,
        ),
        inputFormatters: [
          LengthLimitingTextInputFormatter(2),
          FilteringTextInputFormatter.digitsOnly,
        ],
        onChanged: (v) => setState(() {
          m.days = v;
          _recalcQty(m);
        }),
      ),
    ]);
  }

  /// Returns null if the value is a valid duration, else the error to
  /// block Submit on. Empty is invalid (a med with no duration can't be
  /// dispensed). Digits only, 1-99.
  String? _durationError(String v) {
    final s = v.trim();
    if (s.isEmpty) return 'Required';
    if (!RegExp(r'^\d{1,2}$').hasMatch(s)) return 'Digits only';
    final n = int.parse(s);
    if (n < 1) return 'Min 1 day';
    if (n > 99) return 'Max 99';
    return null;
  }

  /// Top-5 (name + strength) pairs this doctor prescribes most often,
  /// counted across every patient in local state (`prescription` +
  /// `previousRx`). Chip label = "Paracetamol · 500 mg" so a tap adds
  /// a fully-prefilled Rx row. Names already in the current Rx are
  /// filtered out (user 2026-09-11).
  List<({String name, String dosage})> _frequentMedicines() {
    final s = context.read<CounsellorState>();
    // Key by "name||dosage" so the same drug at different strengths
    // shows twice (e.g. Paracetamol 500 vs 650). Strip the dosage-form
    // prefix ("Tab · 500 mg" → "500 mg") — the chip only re-fills the
    // strength box; form is picked separately.
    String stripForm(String d) {
      final ix = d.indexOf(kDosageFormSep);
      return ix < 0 ? d.trim() : d.substring(ix + kDosageFormSep.length).trim();
    }
    final count = <String, int>{};
    final key = (String n, String d) => '${n.trim().toLowerCase()}||${d.trim().toLowerCase()}';
    final labels = <String, ({String name, String dosage})>{};
    void bump(String n, String d) {
      final nn = n.trim();
      if (nn.isEmpty) return;
      final dd = stripForm(d);
      final k = key(nn, dd);
      count[k] = (count[k] ?? 0) + 1;
      labels.putIfAbsent(k, () => (name: nn, dosage: dd));
    }
    for (final pat in s.patients) {
      for (final m in pat.prescription) {
        bump(m.name, m.dosage);
      }
      for (final pr in pat.previousRx) {
        bump(pr.medicine, pr.dosage);
      }
    }
    final entries = count.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final taken = {for (final x in rx) x.name.toLowerCase()};
    final out = <({String name, String dosage})>[];
    for (final e in entries) {
      if (out.length >= 5) break;
      final rec = labels[e.key]!;
      if (taken.contains(rec.name.toLowerCase())) continue;
      out.add(rec);
      taken.add(rec.name.toLowerCase());
    }
    if (out.length >= 5) return out;
    // Fresh install / thin history — top up from the medicine master
    // so the strip is never empty (user 2026-09-11). Master carries
    // names only, so pair each with a common OPD default strength
    // for the chip label (user 2026-09-15 "show also mg with the
    // medicine name"). Doctor can still edit the strength on the
    // added row.
    const defaults = <String, String>{
      'paracetamol': '500 mg',
      'ibuprofen': '400 mg',
      'diclofenac': '50 mg',
      'aceclofenac': '100 mg',
      'acebrophylline': '100 mg',
      'acyclovir': '400 mg',
      'allopurinol': '100 mg',
      'alprazolam': '0.25 mg',
      'cetirizine': '10 mg',
      'levocetirizine': '5 mg',
      'chlorpheniramine': '4 mg',
      'montelukast': '10 mg',
      'amoxicillin': '500 mg',
      'amoxicillin-clavulanate': '625 mg',
      'azithromycin': '500 mg',
      'cefixime': '200 mg',
      'ciprofloxacin': '500 mg',
      'ofloxacin': '200 mg',
      'doxycycline': '100 mg',
      'metronidazole': '400 mg',
      'albendazole': '400 mg',
      'ors sachets': '21 g',
      'zinc': '20 mg',
      'pantoprazole': '40 mg',
      'omeprazole': '20 mg',
      'domperidone': '10 mg',
      'ondansetron': '4 mg',
      'ambroxol': '30 mg',
      'dextromethorphan syrup': '10 ml',
      'salbutamol inhaler': '100 mcg',
      'amlodipine': '5 mg',
      'telmisartan': '40 mg',
      'metformin': '500 mg',
      'glimepiride': '1 mg',
      'ferrous sulphate + folic acid': '60 mg',
      'vitamin c': '500 mg',
      'vitamin d3': '60000 IU',
      'multivitamin': '1 tab',
      'calcium': '500 mg',
      'nitrofurantoin': '100 mg',
      'b-complex': '1 tab',
      'betadine gargle': '10 ml',
    };
    final serverMeds = context.read<MastersStore>().medicineNames();
    final pool = serverMeds;
    for (final n in pool) {
      if (out.length >= 5) break;
      if (taken.contains(n.toLowerCase())) continue;
      out.add((name: n, dosage: defaults[n.toLowerCase()] ?? ''));
      taken.add(n.toLowerCase());
    }
    return out;
  }

  /// Open the medicine picker to attach a COMBINATION medicine to [m].
  /// Already-selected medicines (either primary or combo partners) are
  /// filtered out so the same drug isn't picked twice on one visit
  /// (user 2026-09-11).
  Future<void> _pickComboMed(RxItem m) async {
    _parkFocus();
    final serverMeds = context.read<MastersStore>().medicineNames();
    final medOptions = serverMeds;
    final taken = <String>{
      for (final x in rx) x.name.toLowerCase(),
      for (final x in rx)
        for (final c in x.combos) c.name.toLowerCase(),
    };
    // Same case-insensitive de-dup as the main picker so a server
    // master with duplicated names doesn't repeat rows here either
    // (user 2026-09-15).
    final seen = <String>{};
    final opts = <String>[];
    for (final n in medOptions) {
      final t = n.trim();
      if (t.isEmpty) continue;
      final k = t.toLowerCase();
      if (taken.contains(k) || !seen.add(k)) continue;
      opts.add(t);
    }
    // Multi-select — parity with the main Add Medicine picker so the
    // doctor can tick several partners at once (Vitamin A + Vitamin B
    // + Vitamin C ...) and Add them together (user 2026-09-15
    // "combined medicine dropdown same as add medicine — checkbox").
    final picked = await _pickMulti(context, 'Add Combination Medicine', opts);
    if (!mounted || picked == null || picked.isEmpty) return;
    _parkFocus();
    setState(() {
      for (final name in picked) {
        // Guard against a double-tap adding the same drug twice in
        // this same batch.
        if (m.combos.any((c) => c.name.toLowerCase() == name.toLowerCase())) continue;
        m.combos.add(ComboMed(name: name));
      }
    });
  }

  /// Manage sheet — currently-attached partners pre-ticked, unticking
  /// removes; ticking a fresh option adds it. Save applies the diff
  /// in one setState (user 2026-09-18 "edit icon ... user can remove
  /// from the list and combine").
  Future<void> _editCombos(RxItem m) async {
    _parkFocus();
    final serverMeds = context.read<MastersStore>().medicineNames();
    final medOptions = serverMeds;
    // Options = every medicine in the master EXCEPT this primary and
    // any drug already sitting on another rx row (primary or combo).
    final otherRxNames = <String>{
      for (final x in rx) if (!identical(x, m)) x.name.toLowerCase(),
      for (final x in rx) if (!identical(x, m))
        for (final c in x.combos) c.name.toLowerCase(),
    };
    otherRxNames.add(m.name.toLowerCase());
    final seen = <String>{};
    final opts = <String>[];
    for (final n in medOptions) {
      final t = n.trim();
      if (t.isEmpty) continue;
      final k = t.toLowerCase();
      if (otherRxNames.contains(k) || !seen.add(k)) continue;
      opts.add(t);
    }
    final attached = {for (final c in m.combos) c.name};
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C2.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _MultiComboEditSheet(
        title: 'Combination medicines',
        primaryName: m.name,
        options: opts,
        preSelected: attached,
      ),
    );
    if (!mounted || result == null) return;
    _parkFocus();
    setState(() {
      final keepSet = result.toSet();
      // Keep any existing ComboMed still ticked (preserving its
      // dosage), drop the rest, and append newly ticked names.
      final existing = <String, ComboMed>{
        for (final c in m.combos) c.name: c,
      };
      final next = <ComboMed>[
        for (final name in result)
          existing[name] ?? ComboMed(name: name),
      ];
      m.combos
        ..clear()
        ..addAll(next);
      // Silence a lint about keepSet being unused when the loop above
      // reads directly from result.
      keepSet.length;
    });
  }

  Future<void> _addMed() async {
    print('[JC] Add Medicine TAPPED at ${DateTime.now().toIso8601String().substring(11,23)}');
    final _tMed0 = DateTime.now().microsecondsSinceEpoch;
    _parkFocus();
    // Server medicine master first — a hardcoded name the master lacks is
    // silently dropped by the server's prescription mirror (same root as
    // the requisition "No line matched" bug, 2026-08-21).
    final serverMeds = context.read<MastersStore>().medicineNames();
    final medOptions = serverMeds;
    // Case-insensitive de-dup — the server master occasionally lists a
    // medicine twice (name variants under different ids), and the
    // multi-select checkbox picker was rendering both, letting the
    // doctor tick the same drug twice (user 2026-09-15 "still showing
    // duplicate on medicine dropdown"). Also drops names already on
    // the current Rx.
    final rxNames = {for (final x in rx) x.name.toLowerCase()};
    final seen = <String>{};
    final _opts = <String>[];
    for (final m in medOptions) {
      final n = m.trim();
      if (n.isEmpty) continue;
      final k = n.toLowerCase();
      if (rxNames.contains(k) || !seen.add(k)) continue;
      _opts.add(n);
    }
    print('[JC] Add Medicine prep took '
        '${DateTime.now().microsecondsSinceEpoch - _tMed0} µs '
        '(options=${_opts.length})');
    // Multi-select — doctor ticks any number of medicines and one tap
    // on Add adds them all (parity with the previous app, user
    // 2026-09-14). Combination picker + test picker stay single-pick
    // since each of those adds one row.
    final picked = await _pickMulti(context, 'Add Medicine', _opts);
    if (!mounted) return;
    _parkFocus();
    if (picked != null && picked.isNotEmpty) {
      setState(() {
        for (final name in picked) {
          if (rx.any((x) => x.name == name)) continue;
          rx.add(RxItem(name: name));
        }
      });
    }
  }

  Future<List<String>?> _pickMulti(BuildContext context, String title, List<String> options) {
    return showModalBottomSheet<List<String>>(context: context, isScrollControlled: true, backgroundColor: C2.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _MultiPickerSheet(title: title, options: options));
  }

  Future<String?> _pick(BuildContext context, String title, List<String> options) {
    return showModalBottomSheet<String>(context: context, isScrollControlled: true, backgroundColor: C2.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _PickerSheet(title: title, options: options));
  }

  void _viewUploadedRx(String path) {
    final file = File(path);
    showDialog(context: context, builder: (_) => Dialog(
      backgroundColor: C2.white,
      child: Padding(padding: const EdgeInsets.all(12), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Uploaded Prescription', style: ct(14.5, FontWeight.w700, C2.navy)),
        const SizedBox(height: 4),
        Text(path.split('/').last, style: ct(11, FontWeight.w400, C2.text2)),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 420),
          child: file.existsSync()
            ? InteractiveViewer(child: Image.file(file, fit: BoxFit.contain))
            : Container(padding: const EdgeInsets.all(24), alignment: Alignment.center,
                decoration: BoxDecoration(color: C2.bg, borderRadius: BorderRadius.circular(8)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.image_not_supported_outlined, size: 36, color: C2.text3),
                  const SizedBox(height: 8),
                  Text('Image preview not available on this device.', textAlign: TextAlign.center, style: ct(12, FontWeight.w400, C2.text2)),
                ])),
        ),
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Navigator.pop(context), child: Text('Close', style: ct(13, FontWeight.w700, C2.cyan)))),
      ])),
    ));
  }

  /// Label above value, each taking the full width.
  ///
  /// It was a 90px label column with the value beside it, which left a
  /// dictated remark running twenty lines down 65% of the screen while the
  /// column beside it sat empty — and wrapped a five-symptom list onto two
  /// lines for no reason (user 2026-09-28, screenshot). Only two rows use
  /// this and both are long, so both stack.
  ///
  /// [value] replaces the plain Text for rows that need more than one — the
  /// remarks carry a "Show original" toggle.
  Widget _kv(String k, String v, {Widget? value}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: ct(12, FontWeight.w400, C2.text2)),
          const SizedBox(height: 3),
          SizedBox(
            width: double.infinity,
            child: value ?? Text(v, style: ct(13, FontWeight.w500, C2.text)),
          ),
        ]),
      );

  // ═════════════ Px + Rx history (rule 2026-08-05) ═════════════
  // Prescription & Reports section renders two chip buttons; tapping each
  // opens a modal dialog with a table of historical rows.

  /// Total count for the Dx chip badge: past-history + attached
  /// reports/prescriptions. The CURRENT visit's provisional diagnosis
  /// (p.disease) is deliberately NOT counted — it isn't history, and it
  /// made the dialog show "past" data the counsellor never entered
  /// (user bug report 2026-08-14). A genuine previous diagnosis reaches
  /// here via the re-appointment carry-forward tag inside pastHistory.
  int _pxCount() {
    var c = 0;
    if (p.pastHistory.trim().isNotEmpty) c++;
    c += p.attachments.length;
    return c;
  }

  Widget _historyChip({
    required String label,
    required IconData icon,
    required int count,
    required VoidCallback onTap,
  }) {
    // Outline style (user 2026-08-18): white face, navy border, black
    // label. Icon sits in a soft tinted square and the count is a solid
    // navy pill so the tap target reads as a proper control, not a bare
    // box.
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: C2.white,
          border: Border.all(color: C2.navy, width: 1.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: C2.cyanLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 17, color: C2.navy),
          ),
          const SizedBox(width: 8),
          Expanded(child: Row(children: [
            Text(label, style: ct(15, FontWeight.w800, Colors.black)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: C2.navy,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count', style: ct(10.5, FontWeight.w700, Colors.white)),
            ),
          ])),
          const Icon(Icons.chevron_right, size: 18, color: C2.navy),
        ]),
      ),
    );
  }

  void _openPxHistory() {
    // Rows for Dx = past consultations table. Sourced from:
    //  - Past Medical History text (one row, no date) — includes the
    //    re-appointment carry-forward "Previous Diagnosis (date): X" tag
    //  - Each counsellor-uploaded attachment (Report / Other) with its
    //    kind + description. Attachment rows are tappable → the previously
    //    captured image opens in an interactive viewer.
    // The current visit's provisional diagnosis is NOT listed here — the
    // doctor already sees it in Symptoms & Diagnosis, and presenting it
    // as a past consultation fabricated history (user bug 2026-08-14).
    final rows = <_HistoryRow>[];
    if (p.pastHistory.trim().isNotEmpty) {
      rows.add(_HistoryRow(cells: ['—', 'Past History', p.pastHistory.trim()]));
    }
    for (final a in p.attachments) {
      rows.add(_HistoryRow(
        cells: [
          p.regDate.isEmpty ? '—' : p.regDate,
          a.kind.label,
          a.description.isEmpty ? a.path.split(RegExp(r'[\\/]+')).last : a.description,
        ],
        onTap: () => _viewUploadedRx(a.path),
      ));
    }
    _openHistoryDialog(
      title: 'Dx',
      icon: Icons.history_edu_outlined,
      headers: const ['Date', 'Type', 'Details'],
      rows: rows,
      empty: 'No past consultation records on file.',
    );
  }

  void _openRxHistory() {
    // Rows for Rx = past prescriptions table. One row per PrevRx entry.
    final rows = p.previousRx.map((r) => _HistoryRow(cells: [
      r.date,
      r.medicine,
      r.dosage.isEmpty ? '—' : displayDosage(r.dosage),
      r.frequency.isEmpty ? '—' : r.frequency,
      r.duration.isEmpty ? '—' : r.duration,
    ])).toList();
    _openHistoryDialog(
      title: 'Rx',
      icon: Icons.medication_outlined,
      headers: const ['Date', 'Medicine', 'Dosage', 'Frequency', 'Duration'],
      rows: rows,
      empty: 'No prescriptions on file yet.',
    );
  }

  /// Shared Px/Rx dialog. Header + scrollable structured table + Close.
  void _openHistoryDialog({
    required String title,
    required IconData icon,
    required List<String> headers,
    required List<_HistoryRow> rows,
    required String empty,
  }) {
    showDialog(context: context, builder: (_) => Dialog(
      backgroundColor: C2.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 520),
        child: Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 18, color: C2.navy),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: ct(15, FontWeight.w700, C2.navy))),
              InkWell(onTap: () => Navigator.pop(context),
                child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.close, size: 18, color: C2.text2))),
            ]),
            const SizedBox(height: 6),
            Container(height: 1, color: C2.border),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              Padding(padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text(empty, style: ct(12.5, FontWeight.w400, C2.text2))))
            else
              Flexible(child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowColor: WidgetStatePropertyAll(C2.cyanLight),
                    headingTextStyle: ct(11.5, FontWeight.w800, C2.navy),
                    dataTextStyle: ct(12, FontWeight.w500, C2.text),
                    columnSpacing: 16,
                    horizontalMargin: 8,
                    columns: [for (final h in headers) DataColumn(label: Text(h))],
                    rows: [for (final r in rows) DataRow(
                      onSelectChanged: r.onTap == null ? null : (_) { Navigator.pop(context); r.onTap!(); },
                      cells: [for (final c in r.cells) DataCell(Text(c, style: ct(12, FontWeight.w500, C2.text)))],
                    )],
                  ),
                ),
              )),
            const SizedBox(height: 6),
            Align(alignment: Alignment.centerRight,
              child: TextButton(onPressed: () => Navigator.pop(context),
                child: Text('Close', style: ct(13, FontWeight.w700, C2.cyan)))),
          ]),
        ),
      ),
    ));
  }

  // Mirrors the counsellor Register form's _toggle helper so the two
  // Vitals sections look identical.
  Widget _vitalsToggle() => Transform.scale(
        scale: 0.8,
        child: Switch(
          value: _showVitals,
          activeColor: Colors.white,
          activeTrackColor: C2.cyan,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onChanged: (v) => setState(() => _showVitals = v),
        ),
      );

  /// Clinical plausibility ranges (user 2026-08-22) — same limits as the
  /// counsellor register form. Blank stays allowed.
  static const Map<String, (double, double, String)> _kVitalRanges = {
    'Systolic BP':       (60, 280, 'Allowed 60–280'),
    'Diastolic BP':      (40, 150, 'Allowed 40–150'),
    'Blood Sugar':       (20, 600, 'Allowed 20–600'),
    'Body Temp (°F)':    (86, 113, 'Allowed 86–113 °F'),
    'Oxygen Saturation': (50, 100, 'Allowed 50–100%'),
    'Heart Rate':        (30, 220, 'Allowed 30–220'),
    'Hemoglobin':        (3, 25, 'Allowed 3–25'),
  };

  String? _vitalRangeErr(String key) {
    final t = _vitals[key]?.text.trim() ?? '';
    if (t.isEmpty) return null;
    final r = _kVitalRanges[key];
    if (r == null) return null;
    final v = double.tryParse(t);
    if (v == null || v < r.$1 || v > r.$2) return r.$3;
    return null;
  }

  Widget _vitalField(({String key, String label, String hint}) v) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(v.label.toUpperCase(), style: ct(9.5, FontWeight.w700, C2.text2)),
      const SizedBox(height: 3),
      TextField(
        controller: _vitals[v.key],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          LengthLimitingTextInputFormatter(6),
        ],
        onChanged: (_) => setState(() {}),
        style: ct(12.5, FontWeight.w600, C2.text),
        decoration: cInput(v.hint).copyWith(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          isDense: true,
          errorText: _vitalRangeErr(v.key),
          errorStyle: const TextStyle(fontSize: 10),
        ),
      ),
    ]);
  }
}

class _PickerSheet extends StatefulWidget {
  final String title;
  final List<String> options;
  const _PickerSheet({required this.title, required this.options});
  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final _tB = DateTime.now().microsecondsSinceEpoch;
    final query = q.trim();
    // Lowercase the query ONCE per keystroke, not once per option
    // (user 2026-08-26: picker lag was O(N × keystroke) since every
    // option ran query.toLowerCase() again inside the filter callback).
    final ql = query.toLowerCase();
    final m = query.isEmpty
        ? widget.options
        : widget.options.where((o) => o.toLowerCase().contains(ql)).toList();
    print('[JC] _PickerSheet build q="$query" matches=${m.length} '
        'took ${DateTime.now().microsecondsSinceEpoch - _tB} µs');
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 14, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.title, style: ct(15, FontWeight.w700, C2.navy)),
        const SizedBox(height: 10),
        TextField(autofocus: true, decoration: cInput('Search…').copyWith(prefixIcon: const Icon(Icons.search, size: 18)), onChanged: (v) => setState(() => q = v)),
        const SizedBox(height: 8),
        // Picker-only (user 2026-08-26): free-text add was letting the
        // doctor save items that don't exist in the master, which the
        // backend silently drops. If it's not in the list, it can't be
        // added — the master must be updated first.
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: m.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(query.isEmpty ? 'Type to search' : 'No match found in master list',
                      style: ct(13, FontWeight.w400, C2.text2)))
              // Lazy — 787-symptom sheet was building every row up front
              // and made the picker feel frozen (user 2026-08-25).
              // 44 was one line's worth, which clipped the master's longer
              // standard names to "Spirometry / Pulmonary Function Test
              // (with bronchodi…" (user 2026-09-29). A fixed extent is what
              // keeps this lazy, so it stays — just tall enough for two.
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: m.length,
                  itemExtent: 62,
                  itemBuilder: (_, i) => ListTile(
                    dense: true,
                    title: Text(m[i], maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ct(13.5, FontWeight.w500, C2.text)),
                    trailing: const Icon(Icons.add, size: 18, color: C2.cyan),
                    onTap: () => Navigator.pop(context, m[i]),
                  ),
                )),
      ]),
    );
  }
}

/// Multi-select picker sheet (user 2026-09-14 "checkbox user will click on
/// 10 medicine checked"). Same search-and-list layout as [_PickerSheet],
/// but each row carries a checkbox and the sheet returns every ticked
/// value at once via a bottom "Add N" button.
class _MultiPickerSheet extends StatefulWidget {
  final String title;
  final List<String> options;
  const _MultiPickerSheet({required this.title, required this.options});
  @override
  State<_MultiPickerSheet> createState() => _MultiPickerSheetState();
}

class _MultiPickerSheetState extends State<_MultiPickerSheet> {
  String q = '';
  final Set<String> _sel = <String>{};
  @override
  Widget build(BuildContext context) {
    final query = q.trim();
    final ql = query.toLowerCase();
    final m = query.isEmpty
        ? widget.options
        : widget.options.where((o) => o.toLowerCase().contains(ql)).toList();
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 14, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(widget.title, style: ct(15, FontWeight.w700, C2.navy))),
          if (_sel.isNotEmpty)
            TextButton(
              onPressed: () => setState(_sel.clear),
              child: Text('Clear (${_sel.length})',
                  style: ct(12, FontWeight.w600, C2.text2)),
            ),
        ]),
        const SizedBox(height: 6),
        TextField(autofocus: true, decoration: cInput('Search…').copyWith(prefixIcon: const Icon(Icons.search, size: 18)), onChanged: (v) => setState(() => q = v)),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: m.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(query.isEmpty ? 'Type to search' : 'No match found in master list',
                      style: ct(13, FontWeight.w400, C2.text2)))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: m.length,
                  itemExtent: 44,
                  itemBuilder: (_, i) {
                    final name = m[i];
                    final checked = _sel.contains(name);
                    return InkWell(
                      onTap: () => setState(() {
                        if (checked) { _sel.remove(name); } else { _sel.add(name); }
                      }),
                      child: Row(children: [
                        Checkbox(
                          value: checked,
                          onChanged: (v) => setState(() {
                            if (v == true) { _sel.add(name); } else { _sel.remove(name); }
                          }),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        Expanded(child: Text(name, style: ct(13.5, FontWeight.w500, C2.text))),
                      ]),
                    );
                  },
                )),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: _sel.isEmpty
              ? null
              : () => Navigator.pop(context, _sel.toList()),
          style: ElevatedButton.styleFrom(
            backgroundColor: C2.navy, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(_sel.isEmpty ? 'Select medicines' : 'Add ${_sel.length}',
              style: ct(13.5, FontWeight.w700, Colors.white)),
        )),
      ]),
    );
  }
}

/// ICD-11 diagnosis search picker — flat list of Standard Term + ICD-11 code
/// (no category / sub-category). Matches name, code AND synonyms.
/// Manage-combos sheet: pre-tick every partner already attached to
/// the primary, add unticks-as-remove + fresh-ticks-as-add, and
/// return the full final list on Save. Same look as [_MultiPickerSheet]
/// with a "Currently attached" section on top (user 2026-09-18).
/// One line in the combination-medicines sheet — a section header, a
/// tickable medicine, or the "nothing to add" note. Flattening the two
/// sections into a single list is what lets one lazy ListView.builder
/// serve the whole sheet (user 2026-09-22 slow-open fix).
enum _ComboRowKind { header, medicine, empty }

class _ComboRow {
  final _ComboRowKind kind;
  final String text;
  const _ComboRow(this.kind, this.text);
}

class _MultiComboEditSheet extends StatefulWidget {
  final String title;
  final String primaryName;
  final List<String> options;
  final Set<String> preSelected;
  const _MultiComboEditSheet({
    required this.title,
    required this.primaryName,
    required this.options,
    required this.preSelected,
  });
  @override
  State<_MultiComboEditSheet> createState() => _MultiComboEditSheetState();
}

class _MultiComboEditSheetState extends State<_MultiComboEditSheet> {
  String q = '';
  late Set<String> _sel = {...widget.preSelected};
  @override
  Widget build(BuildContext context) {
    final query = q.trim();
    final ql = query.toLowerCase();
    // Attached list stays at the top even while filtering, so the
    // doctor can always un-tick a partner to remove it.
    final attached = widget.preSelected.toList();
    final addable = widget.options
        .where((o) => !widget.preSelected.contains(o))
        .where((o) => query.isEmpty || o.toLowerCase().contains(ql))
        .toList();
    // Both sections flattened once per build into the index-addressed
    // list the ListView.builder below reads. Built here rather than in
    // itemBuilder — recomputing it per row would be O(n²).
    final items = _items(attached, addable, query);
    final media = MediaQuery.of(context);
    // Cap the sheet so its title never crosses under the status-bar
    // notch (user 2026-09-18: "combined medicine dropdown is
    // overlapping"). SafeArea on top does the pixel-perfect part.
    return SafeArea(
      top: true,
      bottom: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.85),
        child: Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 14, bottom: media.viewInsets.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(widget.title,
              style: ct(15, FontWeight.w700, C2.navy))),
          Text('with ${widget.primaryName}',
              style: ct(11.5, FontWeight.w500, C2.text2)),
        ]),
        const SizedBox(height: 6),
        TextField(
          autofocus: false,
          decoration: cInput('Search medicines…')
              .copyWith(prefixIcon: const Icon(Icons.search, size: 18)),
          onChanged: (v) => setState(() => q = v),
        ),
        const SizedBox(height: 8),
        // ONE lazy list for both sections (user 2026-09-22 "its opening
        // very slow"). The master carries 253 medicines and every row
        // holds a Checkbox, so the old SingleChildScrollView + Column
        // built and laid out all 253 before the sheet could paint — and
        // did it again on every keystroke and every tick. shrinkWrap
        // stays lazy here because Flexible hands the list a bounded
        // height, so only the visible rows are built. Same fix as the
        // 799-symptom picker got on 2026-08-25.
        Flexible(child: ListView.builder(
          shrinkWrap: true,
          itemCount: items.length,
          itemBuilder: (_, i) {
            final row = items[i];
            return switch (row.kind) {
              _ComboRowKind.header => Padding(
                  padding: EdgeInsets.only(top: row.text == 'ADD MORE' ? 10 : 0, bottom: 4),
                  child: Text(row.text, style: ct(10, FontWeight.w700, C2.text2))),
              _ComboRowKind.empty => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(row.text, style: ct(13, FontWeight.w400, C2.text2))),
              _ComboRowKind.medicine =>
                  _row(row.text, ticked: _sel.contains(row.text)),
            };
          },
        )),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: () => Navigator.pop(context, _sel.toList()),
          style: ElevatedButton.styleFrom(
            backgroundColor: C2.navy, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text('Save (${_sel.length} attached)',
              style: ct(13.5, FontWeight.w700, Colors.white)),
        )),
      ]),
    ),
      ),
    );
  }

  /// Flatten "CURRENTLY ATTACHED" + "ADD MORE" into one indexable list
  /// so a single lazy ListView can serve both sections.
  List<_ComboRow> _items(List<String> attached, List<String> addable, String query) => [
        if (attached.isNotEmpty) ...[
          const _ComboRow(_ComboRowKind.header, 'CURRENTLY ATTACHED'),
          for (final name in attached) _ComboRow(_ComboRowKind.medicine, name),
        ],
        _ComboRow(_ComboRowKind.header, attached.isEmpty ? 'ADD PARTNERS' : 'ADD MORE'),
        if (addable.isEmpty)
          _ComboRow(_ComboRowKind.empty, query.isEmpty
              ? 'No more medicines to add.'
              : 'No match in the master list.')
        else
          for (final name in addable) _ComboRow(_ComboRowKind.medicine, name),
      ];

  Widget _row(String name, {required bool ticked}) => InkWell(
        onTap: () => setState(() {
          if (ticked) { _sel.remove(name); } else { _sel.add(name); }
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Checkbox(
              value: ticked,
              onChanged: (v) => setState(() {
                if (v == true) { _sel.add(name); } else { _sel.remove(name); }
              }),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 6),
            Expanded(child: Text(name, style: ct(13.5, FontWeight.w500, C2.text))),
          ]),
        ),
      );
}

class _DiseasePickerSheet extends StatefulWidget {
  const _DiseasePickerSheet();
  @override
  State<_DiseasePickerSheet> createState() => _DiseasePickerSheetState();
}

class _DiseasePickerSheetState extends State<_DiseasePickerSheet> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final _tB = DateTime.now().microsecondsSinceEpoch;
    final matches = DiseaseMaster.search(q);
    final query = q.trim();
    print('[JC] _DiseasePickerSheet build q="$query" matches=${matches.length} '
        'took ${DateTime.now().microsecondsSinceEpoch - _tB} µs');
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 14, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Select Diagnosis', style: ct(15, FontWeight.w700, C2.navy)),
          const Spacer(),
          Text('${matches.length} of ${DiseaseMaster.all.length}', style: ct(11, FontWeight.w500, C2.text2)),
        ]),
        const SizedBox(height: 10),
        TextField(autofocus: true, decoration: cInput('Search a diagnosis…').copyWith(prefixIcon: const Icon(Icons.search, size: 18)), onChanged: (v) => setState(() => q = v)),
        const SizedBox(height: 4),
        // Picker-only (user 2026-08-26): free-text add was letting a
        // diagnosis that isn't in the ICD-11 master slip through, and
        // the backend silently drops non-master names on save.
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: matches.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(query.isEmpty ? 'Type to search' : 'No match found in master list',
                      style: ct(13, FontWeight.w400, C2.text2)))
              // Lazy row builds — used to render all 158 diseases up front
              // on every keystroke; picker felt frozen (user 2026-08-25).
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: matches.length,
                  itemExtent: 48,
                  itemBuilder: (_, i) {
                    final d = matches[i];
                    return InkWell(
                      onTap: () => Navigator.pop(context, d.display),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                        child: Row(children: [
                          Expanded(child: Text(d.term, style: ct(13.5, FontWeight.w600, C2.text))),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(color: C2.navyLight, borderRadius: BorderRadius.circular(5)),
                            child: Text(d.icd.isEmpty ? '—' : d.icd, style: ct(10.5, FontWeight.w700, C2.navy)),
                          ),
                        ]),
                      ),
                    );
                  },
                )),
      ]),
    );
  }
}

/// Row model for the Px + Rx tabular history dialogs (rule 2026-08-05).
/// `cells` maps 1:1 with the dialog's column headers. `onTap` is optional
/// — when non-null the row is selectable (currently used for attachment
/// rows in the Px table, which open the uploaded image).
class _HistoryRow {
  final List<String> cells;
  final VoidCallback? onTap;
  _HistoryRow({required this.cells, this.onTap});
}
