import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'cw.dart';
import 'cdata.dart';
import 'cstate.dart';
import 'screens_dashboard.dart' show kUploadsBase;
import '../api/api_client.dart';
import '../api/api_errors.dart';
import '../config/app_config.dart';
import '../api/attendance_api.dart';
import '../api/auth_api.dart';
import '../api/camps_api.dart';
import '../api/devices_api.dart';
import '../api/masters_store.dart';
import '../api/sync_service.dart';
import '../api/uploads_api.dart';
import '../services/deepgram_stt.dart';
import '../screens/unified_login.dart';
import '../services/attendance_store.dart';
import '../services/devices_store.dart';
import '../services/fcm_service.dart';
import '../services/back_form_registry.dart';
import '../widgets/pending_alert.dart';
import '../widgets/photo_lightbox.dart';
import '../services/camps_store.dart';
import '../services/location_service.dart';
import '../services/photo_watermark.dart';
import '../services/notifications_service.dart';
import '../state/app_state.dart';
import '../widgets/attendance_capture.dart';

String apptStatusLabel(String status) => switch (status) {
      'completed' => 'Completed',
      'with_pharma' => 'At Pharmacy',
      'with_doctor' => 'With Doctor',
      'denied' => 'Delivery Denied',
      _ => 'Registered',
    };

Widget _dd(List<String> items, String? val, ValueChanged<String?> onCh, {String? hint}) =>
    SearchDropdown(items: items, value: val, hint: hint ?? 'Select', onChanged: onCh);

// ───────────────────────── Attendance ─────────────────────────
class CounAttendance extends StatefulWidget {
  /// Bumped by the shell on refresh while this tab is current.
  final Listenable? refreshSignal;
  const CounAttendance({super.key, this.refreshSignal});
  @override
  State<CounAttendance> createState() => _CounAttendanceState();
}

class _CounAttendanceState extends State<CounAttendance> {
  bool showForm = false;
  // form fields
  String _date = '';
  // Both times are captured at the moment the counsellor taps Mark
  // Check-in / Mark Check-out and shown read-only (rule 2026-08-05) — no
  // TimeOfDay backing state is needed because the picker is gone.
  String _checkIn = '';
  String _checkOut = '';
  String? location;
  String? _photoPath;
  double? _lat;
  double? _lng;
  // Check-out selfie proof (2026-07-29). Independent of the check-in photo so
  // audits have a clear morning + evening record.
  String? _photoPathOut;
  double? _latOut;
  double? _lngOut;
  // Staff attendance the counsellor confirms on the counsellor's own device
  // for Driver / Doctor / Pharmacist. Split in/out so we know who was there
  // at the start of the shift vs the end.
  bool _driverIn = false, _doctorIn = false, _pharmacistIn = false, _otherIn = false;
  bool _driverOut = false, _doctorOut = false, _pharmacistOut = false, _otherOut = false;
  // Who the "Other" person is (user 2026-08-19): free-text opens when the
  // Other box is ticked; travels inside the staff note.
  final _otherInWho = TextEditingController();
  final _otherOutWho = TextEditingController();
  final _collection = TextEditingController();
  final _startKm = TextEditingController(); // used only on first-ever login
  final _endKm = TextEditingController();
  final _notes = TextEditingController();

  // ── Backend state (user rule 2026-08-14: Attend fully dynamic) ──
  // /attendance/today decides which form shows; /attendance is the
  // history; /camps/anchors feeds the Location snap. All server-owned so
  // the tab survives app restarts.
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  bool _fromCache = false;            // rendering the offline snapshot
  Map<String, dynamic>? _todayRow;    // today's attendance row (or null)
  List<Map<String, dynamic>> _historyRows = const [];
  List<Map<String, dynamic>> _anchors = const [];
  int? _campAnchorId;                 // nearest anchor picked from GPS

  Timer? _minuteTicker;

  @override
  void initState() {
    super.initState();
    widget.refreshSignal?.addListener(_onExternalRefresh);
    _date = fmtDate(DateTime.now());
    // First back press while the check-in/out form is open must close the
    // form (back to the attend list), not switch tabs (user 2026-08-21).
    BackFormRegistry.register('coun.attend', () {
      if (!mounted || !showForm) return false;
      // Clear whatever the counsellor typed before closing — reopening
      // must NOT resurrect a stale draft (user 2026-08-26).
      _resetForm();
      return true;
    });
    // 60-second ticker so the check-out boundary check (2:30 / 5:30 /
    // 8:30 for an 11:30 check-in) fires exactly on the minute even if
    // the counsellor is idle on this page (user 2026-08-26 "no 15-min
    // window, exact time only").
    _minuteTicker = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) setState(() {});
    });
    _load();
  }

  /// Per-user cache key (rule 2026-08-16 — no cross-user leakage).
  String get _userKey {
    final app = context.read<AppState>();
    return 'counsellor_${app.backendUserId ?? app.currentUser}';
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _fromCache = false; });
    try {
      final att = context.read<AttendanceApi>();
      final camps = context.read<CampsApi>();
      final results = await Future.wait([
        att.today(),
        att.list(dateFrom: AppConfig.dataWindowFrom, limit: 30),
        // Anchors are OPTIONAL — the endpoint ships with a later backend
        // deploy, and a facility may simply have none. A failure here
        // must not take down the whole tab (location then falls back to
        // the facility name).
        camps.anchors().catchError((_) => const <Map<String, dynamic>>[]),
      ]);
      _todayRow = (results[0] as Map<String, dynamic>)['attendance']
          as Map<String, dynamic>?;
      _historyRows = (results[1] as List).cast<Map<String, dynamic>>();
      _anchors = (results[2] as List).cast<Map<String, dynamic>>();
      // Fresh server truth → refresh the offline snapshot (user rule
      // 2026-08-18: attendance must be fully functional offline).
      try {
        final store = await AttendanceStore.open();
        await store.saveToday(_userKey, _todayRow);
        await store.saveHistory(_userKey, _historyRows);
        await store.saveAnchors(_userKey, _anchors);
      } catch (_) {/* cache write is best-effort */}
    } on ApiException catch (e) {
      if (e.code == ApiErrorCode.networkUnreachable) {
        // Offline: silently fall back to the cached rows — no error
        // banner (user rule 2026-08-20 "dont show message for offline").
        await _loadFromCache(fallbackError: null);
      } else {
        _error = e.message;
      }
    } catch (_) {
      // Unexpected error: keep working with cache, no banner.
      await _loadFromCache(fallbackError: null);
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Offline path: render the last snapshot instead of a dead error
  /// screen. Check-in/out still work — they queue through SyncService.
  Future<void> _loadFromCache({String? fallbackError}) async {
    try {
      final store = await AttendanceStore.open();
      final today = store.loadToday(_userKey);
      final history = store.loadHistory(_userKey);
      final anchors = store.loadAnchors(_userKey);
      final hasAnything =
          today != null || history.isNotEmpty || anchors.isNotEmpty;
      if (hasAnything) {
        _todayRow = today;
        _historyRows = history;
        _anchors = anchors;
        _fromCache = true;
        _error = null;
        return;
      }
    } catch (_) {/* fall through to the error */}
    _error = fallbackError;
  }

  // ── Server-row helpers ──
  /// The attendance table stores check_in / check_out as Postgres TIME
  /// (no date), so the API sends bare "23:04:33" strings —
  /// DateTime.parse chokes on those (blank times on device, user bug
  /// 2026-08-14). Handle both bare times and full timestamps.
  static String _fmtIsoTime(dynamic ts) {
    if (ts == null) return '';
    final s = ts.toString();
    final dt = DateTime.tryParse(s);
    if (dt != null) {
      return fmtTime12(TimeOfDay.fromDateTime(dt.toLocal()));
    }
    final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(s);
    if (m == null) return '';
    final h = int.tryParse(m.group(1)!);
    final min = int.tryParse(m.group(2)!);
    if (h == null || min == null || h > 23 || min > 59) return '';
    return fmtTime12(TimeOfDay(hour: h, minute: min));
  }

  static String _fmtIsoDay(dynamic d) {
    final s = (d ?? '').toString();
    if (s.length < 10) return s;
    return '${s.substring(8, 10)}-${s.substring(5, 7)}-${s.substring(0, 4)}';
  }

  static String _numStr(dynamic v) {
    if (v == null) return '';
    final n = num.tryParse(v.toString());
    if (n == null) return v.toString();
    return n == n.truncate() ? n.truncate().toString() : n.toString();
  }

  /// Server photo_path is a bare filename in the shared uploads folder —
  /// expand to the public URL the detail sheet can render. Legacy rows
  /// that somehow carry a device path are passed through untouched.
  static String _photoUrl(dynamic p) {
    final s = (p ?? '').toString().trim();
    if (s.isEmpty || s.startsWith('http') || s.startsWith('/')) return s;
    return '$kUploadsBase/patient_docs/$s';
  }

  /// Map a server attendance row onto the local record shape the list
  /// cards + detail sheet already render.
  AttendanceRecord _recFromRow(Map<String, dynamic> r) => AttendanceRecord(
        date:      _fmtIsoDay(r['attendance_date']),
        checkIn:   _fmtIsoTime(r['check_in']),
        checkOut:  _fmtIsoTime(r['check_out']),
        location:  ((r['anchor_name'] ?? r['location']) ?? '').toString(),
        // Open shift (no check-out) surfaces as "Pending" on the list row's
        // badge and detail sheet (user 2026-08-29: was showing blank).
        status:    r['check_out'] == null
                     ? 'Pending'
                     : (r['status'] ?? 'Present').toString(),
        photo:     (r['photo_path'] ?? '').toString().isNotEmpty,
        photoPath: _photoUrl(r['photo_path']),
        photoPathOut: _photoUrl(r['photo_path_out']),
        startKm:   _numStr(r['start_km']),
        endKm:     _numStr(r['end_km']),
        totalRun:  _numStr(r['total_run']),
        collection: _numStr(r['collection']),
        notes:     (r['notes'] ?? '').toString(),
        lat:  (r['latitude']  as num?)?.toDouble(),
        lng:  (r['longitude'] as num?)?.toDouble(),
      );

  bool get _checkedIn  => _todayRow != null;
  bool get _checkedOut => _todayRow?['check_out'] != null;

  /// Own-row test for the history list: match user_id when both sides
  /// have it; fall back to the role for older cached sessions that lack
  /// backendUserId.
  static bool _isMyRow(Map<String, dynamic> r, int? myId) {
    final uid = (r['user_id'] as num?)?.toInt();
    if (myId != null && uid != null) return uid == myId;
    final role = (r['role'] ?? '').toString().toLowerCase();
    return role == 'counsellor' || role == 'counselor';
  }

  /// True when someone of [role] already has today's attendance row —
  /// their own check-in or an earlier counsellor mark. Drives the locked
  /// "(checked-in)" state on the Staff Present checklist (user 2026-08-19).
  bool _roleCheckedInToday(String role) {
    final today = _isoToday();
    for (final r in _historyRows) {
      if ((r['role'] ?? '').toString().toLowerCase() != role) continue;
      final d = (r['attendance_date'] ?? '').toString();
      if (d.length >= 10 && d.substring(0, 10) == today &&
          r['check_in'] != null) {
        return true;
      }
    }
    return false;
  }

  /// True when someone of [role] already CHECKED OUT today — their own
  /// mark, on a row whose check_out is filled. Drives the locked
  /// "(checked-out)" state on the Staff Checking Out checklist (user
  /// 2026-08-20: "doctor will be show selected and no editable").
  bool _roleCheckedOutToday(String role) {
    final today = _isoToday();
    for (final r in _historyRows) {
      if ((r['role'] ?? '').toString().toLowerCase() != role) continue;
      final d = (r['attendance_date'] ?? '').toString();
      if (d.length >= 10 && d.substring(0, 10) == today &&
          r['check_out'] != null) {
        return true;
      }
    }
    return false;
  }

  /// Human list of the roles that already closed their shift today, for
  /// the friendly banner above the Staff Checking Out checklist.
  List<String> _rolesAlreadyCheckedOut() => [
        for (final e in const [
          ('driver', 'Driver'),
          ('doctor', 'Doctor'),
          ('pharmacist', 'Pharmacist'),
          ('other', 'Other'),
        ])
          if (_roleCheckedOutToday(e.$1)) e.$2,
      ];

  /// Fleet continuity: the newest closed shift's ending km (server rows
  /// come newest-first).
  String get _lastEndKm {
    for (final r in _historyRows) {
      if (r['end_km'] != null) return _numStr(r['end_km']);
    }
    return '';
  }

  /// Shell-driven refresh (pull / app-bar while this tab is current).
  void _onExternalRefresh() {
    if (!mounted) return;
    // Refresh discards the half-typed draft too (user 2026-08-26 "after
    // refresh also showing" old values). No-op when form is closed.
    if (showForm) _resetForm();
    _load();
  }

  @override
  void dispose() {
    BackFormRegistry.unregister('coun.attend');
    widget.refreshSignal?.removeListener(_onExternalRefresh);
    _collection.dispose(); _startKm.dispose(); _endKm.dispose(); _notes.dispose();
    _otherInWho.dispose(); _otherOutWho.dispose();
    _minuteTicker?.cancel();
    super.dispose();
  }

  String _fmtTime(TimeOfDay t) => fmtTime12(t);

  /// Mark Check-out counterpart of _autofillCheckInFields (rule 2026-07-31).
  /// Pre-fills the current time. (Staff Checking Out starts unticked —
  /// server rows don't carry the morning flags.)
  /// Also re-loads /attendance so the "Doctor already checked-out" lock
  /// picks up the doctor's own check-out that happened after the last
  /// refresh (user bug 2026-08-20).
  void _autofillCheckOutFields() {
    unawaited(_load());
    final now = TimeOfDay.now();
    setState(() => _checkOut = _fmtTime(now));
  }

  /// Auto-populate the Check-in form: current time + Location snapped to
  /// the nearest of the facility's camp anchors (downloaded from
  /// /camps/anchors — the old hardcoded 3-camp list showed a wrong camp
  /// whenever the phone was anywhere else; user bug 2026-08-14). With no
  /// anchors configured the facility name itself is the location.
  Future<void> _autofillCheckInFields() async {
    final now = TimeOfDay.now();
    // Always refresh — every tap on Mark Check-in sets it to "right now".
    setState(() {
      _checkIn = _fmtTime(now);
    });
    if (location != null) return;
    // Fallback shown immediately; GPS may refine it to an anchor below.
    // Bootstrap's facility block keys the name as 'name'; older cached
    // payloads may carry 'facility_name'.
    final fac = context.read<MastersStore>().facility;
    final facilityName =
        ((fac?['name'] ?? fac?['facility_name']) as String?)?.trim();
    if (_anchors.isEmpty) {
      if (facilityName != null && facilityName.isNotEmpty && mounted) {
        setState(() { location = facilityName; _campAnchorId = null; });
      }
      return;
    }
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.medium)
          .timeout(const Duration(seconds: 6));
      Map<String, dynamic>? nearest;
      double best = double.infinity;
      for (final a in _anchors) {
        final lat = (a['latitude'] as num?)?.toDouble();
        final lng = (a['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        final d = Geolocator.distanceBetween(pos.latitude, pos.longitude, lat, lng);
        if (d < best) { best = d; nearest = a; }
      }
      if (nearest != null && mounted) {
        setState(() {
          location = (nearest!['anchor_name'] ?? '').toString();
          _campAnchorId = (nearest['camp_anchor_id'] as num?)?.toInt();
        });
      }
    } catch (_) {
      // GPS failed — fall back to the facility name.
      if (facilityName != null && facilityName.isNotEmpty && mounted && location == null) {
        setState(() { location = facilityName; _campAnchorId = null; });
      }
    }
  }

  // Starting km for the shift the counsellor is about to record:
  //  - if a shift is already open, its recorded starting km is authoritative;
  //  - otherwise use the previous shift's ending km (fleet continuity —
  //    both now read from the server rows);
  //  - if this is the first-ever login, use whatever the counsellor typed.
  String _startValue() {
    if (_checkedIn) {
      final v = _numStr(_todayRow?['start_km']);
      if (v.isNotEmpty) return v;
    }
    if (_lastEndKm.isNotEmpty) return _lastEndKm;
    return _startKm.text.trim();
  }

  String _totalRun() {
    final start = int.tryParse(_startValue());
    final end = int.tryParse(_endKm.text.trim());
    if (start == null || end == null) return '';
    final run = end - start;
    return run < 0 ? '' : '$run';
  }

  void _resetForm() {
    setState(() {
      showForm = false; _checkIn = ''; _checkOut = '';
      _photoPath = null; _lat = null; _lng = null;
      _photoPathOut = null; _latOut = null; _lngOut = null;
      _driverIn = false; _doctorIn = false; _pharmacistIn = false; _otherIn = false;
      _driverOut = false; _doctorOut = false; _pharmacistOut = false; _otherOut = false;
      _otherInWho.clear(); _otherOutWho.clear();
      _collection.clear(); _startKm.clear(); _endKm.clear(); _notes.clear();
      _date = fmtDate(DateTime.now()); location = null;
    });
  }

  /// Staff ticks travel in the notes text — the attendance table has no
  /// per-role columns, and the detail sheet's Notes row shows them back.
  /// [otherWho] names the "Other" person (user 2026-08-19), e.g.
  /// "Other (Ramesh — new helper)".
  String _staffNote(String tag, bool driver, bool doctor, bool pharma,
      [bool other = false, String otherWho = '']) {
    final who = otherWho.trim();
    final names = [
      if (driver) 'Driver', if (doctor) 'Doctor', if (pharma) 'Pharmacist',
      if (other) who.isEmpty ? 'Other' : 'Other ($who)',
    ];
    return names.isEmpty ? '' : 'Staff ($tag): ${names.join(', ')}';
  }

  Future<void> _submitCheckIn() async {
    void err(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: C2.danger));
    if (_submitting) return;
    if (_checkIn.isEmpty) return err('Enter check-in time');
    if (location == null) return err('Location not detected yet');
    final start = _startValue();
    if (start.isEmpty) return err('Enter MMU starting (Km)');
    // Staff crew — at least one of Driver / Doctor / Pharmacist must be
    // marked present so the record is meaningful (rule 2026-07-29).
    if (!(_driverIn || _doctorIn || _pharmacistIn || _otherIn)) {
      return err('Tick at least one staff member present');
    }
    if (_photoPath == null) return err('Take a selfie to mark check-in');
    setState(() => _submitting = true);
    final api = context.read<AttendanceApi>();
    final sync = context.read<SyncService>();
    final uploads = context.read<UploadsApi>();
    final notes = _staffNote('In', _driverIn, _doctorIn, _pharmacistIn,
        _otherIn, _otherInWho.text);
    // Machine-readable crew list for the backend auto-create (task C) —
    // the human-readable version stays in the notes for the detail sheet.
    final staffIn = <String>[
      if (_driverIn) 'driver',
      if (_doctorIn) 'doctor',
      if (_pharmacistIn) 'pharmacist',
      if (_otherIn) 'other',
    ];
    // Watermarked selfie uploads to /mobile/uploads; the returned filename
    // rides in photo_key so the backend can store it in attendance.photo_path
    // (user rule 2026-08-16: save both check-in and check-out photos).
    // Upload failure must not block the check-in itself — attendance
    // without the photo beats no attendance.
    String? photoKey;
    try {
      final up = await uploads
          .uploadImage(_photoPath!)
          .timeout(const Duration(seconds: 25));
      photoKey = (up['file_name'] ?? '').toString();
      if (photoKey.isEmpty) photoKey = null;
    } catch (_) { /* offline / slow — record goes without the photo */ }
    final checkInLabel = _checkIn;
    try {
      await api.checkIn(
        campAnchorId: _campAnchorId,
        location: location!,
        latitude: _lat, longitude: _lng,
        startKm: int.tryParse(start),
        photoKey: photoKey,
        notes: notes,
        staffPresent: staffIn,
        staffOtherName: _otherIn ? _otherInWho.text : null,
      );
      await _load();
      // D2: 3h/6h/9h check-out reminders until the shift closes.
      unawaited(NotificationsService.instance
          .scheduleCheckoutReminders(checkInLabel: checkInLabel));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Check-in recorded — tap Mark Check-out at end of day'), backgroundColor: C2.green));
        _resetForm();
      }
    } on ApiException catch (e) {
      if (e.code == ApiErrorCode.networkUnreachable) {
        // Offline — the sync ledger delivers it later; show the shift as
        // open locally so the counsellor isn't asked to check in twice.
        sync.enqueue(kind: 'attendance.check_in', payload: {
          'attendance_date': _isoToday(),
          'location':        location!,
          'camp_anchor_id':  _campAnchorId,
          'start_km':        int.tryParse(start) ?? 0,
          'latitude':        _lat,
          'longitude':       _lng,
          'notes':           notes,
          'staff_present':   staffIn,
          if (_otherIn && _otherInWho.text.trim().isNotEmpty)
            'staff_other_name': _otherInWho.text.trim(),
          // Local file path — SyncService._liftPhotos uploads it on the
          // next drain and rewrites this key with the server file_name
          // (bug 2026-08-20: offline check-in was landing without a
          // photo because photo_key wasn't queued).
          if (photoKey != null) 'photo_key': photoKey
          else if (_photoPath != null) 'photo_key': _photoPath,
        });
        if (mounted) {
          setState(() => _todayRow = {
            'check_in': DateTime.now().toIso8601String(),
            'check_out': null,
            'location': location,
            'start_km': int.tryParse(start),
            'attendance_date': _isoToday(),
            'status': 'Present',
          });
          // Offline snapshot so a restart with no signal still shows the
          // open shift (user rule 2026-08-18).
          unawaited(AttendanceStore.open()
              .then((s) => s.saveToday(_userKey, _todayRow)));
          unawaited(NotificationsService.instance
              .scheduleCheckoutReminders(checkInLabel: checkInLabel));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Offline — check-in queued, will sync automatically'), backgroundColor: C2.navy));
          _resetForm();
        }
      } else if (mounted) {
        err('Check-in failed: ${e.message}');
      }
    } catch (_) {
      if (mounted) err('Check-in failed. Try again.');
    }
    if (mounted) setState(() => _submitting = false);
  }

  Future<void> _submitCheckOut() async {
    void err(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: C2.danger));
    if (_submitting) return;
    if (_checkOut.isEmpty) return err('Enter check-out time');
    if (_endKm.text.trim().isEmpty) return err('Enter MMU ending (Km)');
    final run = _totalRun();
    if (run.isEmpty) return err('MMU ending must be greater than starting');
    if (_collection.text.trim().isEmpty) return err('Enter total collection');
    // Staff crew — same requirement at end of shift so we know who actually
    // stayed the day (rule 2026-07-29).
    if (!(_driverOut || _doctorOut || _pharmacistOut || _otherOut)) {
      return err('Tick at least one staff member checking out');
    }
    if (_photoPathOut == null) return err('Take a selfie to mark check-out');
    setState(() => _submitting = true);
    final api = context.read<AttendanceApi>();
    final sync = context.read<SyncService>();
    final uploads = context.read<UploadsApi>();
    final staff = _staffNote('Out', _driverOut, _doctorOut, _pharmacistOut,
        _otherOut, _otherOutWho.text);
    final notes = [_notes.text.trim(), staff]
        .where((t) => t.isNotEmpty).join(' · ');
    final staffOut = <String>[
      if (_driverOut) 'driver',
      if (_doctorOut) 'doctor',
      if (_pharmacistOut) 'pharmacist',
      if (_otherOut) 'other',
    ];
    // Evening selfie -> its own column (attendance.photo_path_out, added
    // in migrate.sql 2026-08-16). Same upload pipe, same failure policy
    // as check-in.
    String? photoKey;
    var uploadFailed = false;
    try {
      final up = await uploads
          .uploadImage(_photoPathOut!)
          .timeout(const Duration(seconds: 25));
      photoKey = (up['file_name'] ?? '').toString();
      if (photoKey.isEmpty) photoKey = null;
    } catch (_) {
      uploadFailed = true;
    }
    // Upload flopped online — route through the sync queue so
    // _liftPhotos retries the selfie later instead of submitting a
    // check-out with no photo_path_out (user 2026-08-25 "check-out
    // image not showing"). Local file path rides on the payload; the
    // drainer replaces it with the server file name on the next tick.
    if (uploadFailed && _photoPathOut != null) {
      sync.enqueue(kind: 'attendance.check_out', payload: {
        'attendance_date': _isoToday(),
        'end_km':          int.tryParse(_endKm.text.trim()) ?? 0,
        'collection':      num.tryParse(_collection.text.trim()) ?? 0,
        'latitude':        _latOut,
        'longitude':       _lngOut,
        'notes':           notes,
        'staff_out':       staffOut,
        'photo_key':       _photoPathOut,
      });
      if (mounted) {
        setState(() => _todayRow = {
          ...?_todayRow,
          'check_out': DateTime.now().toIso8601String(),
        });
        unawaited(AttendanceStore.open()
            .then((s) => s.saveToday(_userKey, _todayRow)));
        unawaited(NotificationsService.instance.cancelCheckoutReminders());
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Check-out queued — selfie will upload with next sync'),
          backgroundColor: C2.navy,
        ));
        _resetForm();
      }
      if (mounted) setState(() => _submitting = false);
      return;
    }
    try {
      await api.checkOut(
        latitude: _latOut, longitude: _lngOut,
        endKm: int.tryParse(_endKm.text.trim()),
        collection: num.tryParse(_collection.text.trim()),
        photoKey: photoKey,
        notes: notes,
        staffOut: staffOut,
      );
      await _load();
      // D2: shift closed — stop the pending reminders.
      unawaited(NotificationsService.instance.cancelCheckoutReminders());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Check-out recorded, shift closed'), backgroundColor: C2.green));
        _resetForm();
      }
    } on ApiException catch (e) {
      if (e.code == ApiErrorCode.networkUnreachable) {
        sync.enqueue(kind: 'attendance.check_out', payload: {
          'attendance_date': _isoToday(),
          'end_km':          int.tryParse(_endKm.text.trim()) ?? 0,
          'collection':      num.tryParse(_collection.text.trim()) ?? 0,
          'latitude':        _latOut,
          'longitude':       _lngOut,
          'notes':           notes,
          'staff_out':       staffOut,
          // Local file path lifted on next drain (bug 2026-08-20).
          if (photoKey != null) 'photo_key': photoKey
          else if (_photoPathOut != null) 'photo_key': _photoPathOut,
        });
        if (mounted) {
          setState(() => _todayRow = {
            ...?_todayRow,
            'check_out': DateTime.now().toIso8601String(),
          });
          unawaited(AttendanceStore.open()
              .then((s) => s.saveToday(_userKey, _todayRow)));
          unawaited(NotificationsService.instance.cancelCheckoutReminders());
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Offline — check-out queued, will sync automatically'), backgroundColor: C2.navy));
          _resetForm();
        }
      } else if (mounted) {
        err('Check-out failed: ${e.message}');
      }
    } catch (_) {
      if (mounted) err('Check-out failed. Try again.');
    }
    if (mounted) setState(() => _submitting = false);
  }

  String _isoToday() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  /// Facility name for the attendance selfie strip. Camp-anchor /
  /// block names stay off the pixels (user 2026-08-31: facility_name
  /// only, single line with GPS + date + time).
  String _placeLabelForWatermark() {
    final fac = context.read<MastersStore>().facility;
    return ((fac?['name'] ?? fac?['facility_name']) as String?)?.trim() ?? '';
  }

  /// Hours the current shift has been open. `check_in` is a bare TIME
  /// value ("23:03:00") — combined with attendance_date to make an
  /// instant (plain tryParse on a time always failed → hours stuck at 0).
  int _openShiftHours() {
    final row = _todayRow;
    if (row == null) return 0;
    final d = (row['attendance_date'] ?? '').toString().split('T').first;
    final t = (row['check_in'] ?? '').toString();
    final dt = DateTime.tryParse('$d $t') ?? DateTime.tryParse(t);
    if (dt == null) return 0;
    final h = DateTime.now().difference(dt).inHours;
    return h < 0 ? 0 : h;
  }

  /// Whether the current wall clock is EXACTLY at a 3h boundary past
  /// check-in (user 2026-08-26: no 15-min slack, alert must fire at the
  /// literal 2:30 / 5:30 / 8:30 marks for an 11:30 check-in). Returns
  /// the boundary hour (3, 6, 9, …) or -1 outside those exact minutes.
  int _checkoutBoundaryHour() {
    final row = _todayRow;
    if (row == null) return -1;
    final d = (row['attendance_date'] ?? '').toString().split('T').first;
    final t = (row['check_in'] ?? '').toString();
    final dt = DateTime.tryParse('$d $t') ?? DateTime.tryParse(t);
    if (dt == null) return -1;
    final mins = DateTime.now().difference(dt).inMinutes;
    if (mins < 180) return -1;
    // Tight 1-minute window (0 <= offset < 1 minute) so it can ONLY
    // trigger during the exact boundary minute. A 60-second ticker
    // rebuilds the tree so the check runs even if the doctor is idle
    // on the page.
    if ((mins - 180) % 180 != 0) return -1;
    return mins ~/ 60;
  }

  /// Open-shift alert wording. The banner itself only renders 3+ hours
  /// in (user 2026-08-20: "it will be show after 3 hour" — not right at
  /// check-in), matching the 3-hourly push-reminder cadence.
  String _checkoutAlertText() =>
      'Checked in at ${_fmtIsoTime(_todayRow?['check_in'])} '
      '(${_openShiftHours()} hrs ago) — check-out still pending!';

  @override
  Widget build(BuildContext context) {
    // Server-owned state: an open shift = today's row without a check-out.
    final open = (_checkedIn && !_checkedOut) ? _recFromRow(_todayRow!) : null;
    final done = _checkedIn && _checkedOut;
    // Attendance list: the counsellor's OWN rows — today's open shift
    // included (user bug 2026-08-18: it showed only as the banner). The
    // /attendance endpoint returns the whole facility's rows (that's how
    // the doctor sees the counsellor's mark), and task C now auto-creates
    // doctor/pharmacist rows with the same time+camp — without this
    // filter the same shift looked triplicated (second user bug).
    final myId = context.read<AppState>().backendUserId;
    final past = [
      for (final r in _historyRows)
        if (_isMyRow(r, myId)) _recFromRow(r),
    ];

    final actionLabel = open == null ? 'Mark Check-in' : 'Mark Check-out';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.only(bottom: 8), child: SecBar('My Attendance',
        trailing: (_loading || done) ? null : COutlineButton(showForm ? 'Close' : actionLabel,
          icon: showForm ? Icons.close : (open == null ? Icons.login : Icons.logout),
          onTap: () {
            final opening = !showForm;
            if (!opening) {
              // Close = discard the draft (user 2026-08-26 "when closing
              // form and coming again showing filled values").
              _resetForm();
              return;
            }
            setState(() => showForm = true);
            // On Mark Check-in (open == null and we're opening the form),
            // pre-fill time + nearest camp anchor from GPS. Kicked off
            // after the frame so the form is mounted when values arrive.
            if (open == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _autofillCheckInFields();
              });
            } else {
              // On Mark Check-out, pre-fill the current time.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _autofillCheckOutFields();
              });
            }
          }))),

      if (_loading)
        const Padding(padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2))),

      if (!_loading && _error != null)
        Padding(padding: const EdgeInsets.only(bottom: 8), child: InkWell(
          onTap: _load,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: C2.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Icon(Icons.cloud_off, size: 16, color: C2.danger),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!, style: ct(12.5, FontWeight.w600, C2.danger))),
              const Icon(Icons.refresh, size: 16, color: C2.danger),
            ]),
          ),
        )),

      // Check-out pending alert — Panara confirm modal (user 2026-08-20
      // messages). Fires only once the shift has been open 3+ hours
      // (matches the 3-hourly push cadence). "Checkout" opens the
      // Check-out form directly so the counsellor doesn't have to tap
      // the header button.
      if (!_loading && open != null && !showForm && _checkoutBoundaryHour() > 0)
        Builder(builder: (ctx) {
          // Fires ONLY in the 15-minute window past each 3h boundary
          // (check-in + 3h / 6h / 9h / …), not any time you happen to
          // open the page after 3h have passed (user 2026-08-26).
          // PendingAlert.showOnce persists the shown-key so a page
          // reopen within the same window doesn't re-fire.
          final boundary = _checkoutBoundaryHour();
          PendingAlert.showOnce(
            ctx,
            key: 'checkout-pending-h$boundary',
            title: 'Check-out Pending',
            message: 'You checked in at '
                '${_fmtIsoTime(_todayRow?['check_in'])}. Your check-out is '
                'still pending. Please complete your check-out.',
          );
          return const SizedBox.shrink();
        }),

      // Day-done banner — both stamps on file for today.
      if (!_loading && done && !showForm)
        CCard(child: Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFFEDF7E0), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.event_available, color: C2.green)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Today\'s attendance is complete', style: ct(13.5, FontWeight.w700, C2.navy)),
            Text('${_fmtIsoTime(_todayRow?['check_in'])} – ${_fmtIsoTime(_todayRow?['check_out'])} · ${((_todayRow?['anchor_name'] ?? _todayRow?['location']) ?? '').toString()}',
                style: ct(11.5, FontWeight.w400, C2.text2)),
          ])),
        ])),

      // Open-shift banner — visible whenever a check-in is on file without a
      // check-out. Shown outside the form so the counsellor sees it in the
      // default (list) view too.
      if (!_loading && open != null && !showForm)
        CCard(
          // Tapping the open-shift banner opens the same detail sheet as a
          // list card (user bug 2026-08-18: tap did nothing).
          onTap: () => _showDetail(open),
          child: Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFFFEF7E0), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.pending_actions, color: C2.yellow)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Shift open since ${open.checkIn}', style: ct(13.5, FontWeight.w700, C2.navy)),
            Text('${open.date} · ${open.location} · Start ${open.startKm} km', style: ct(11.5, FontWeight.w400, C2.text2)),
            Text('Tap Mark Check-out at end of day.', style: ct(11.5, FontWeight.w600, Color(0xFFB8860B))),
          ])),
        ])),

      if (showForm && !_loading)
        CCard(child: open == null ? _checkInForm() : _checkOutForm(open)),

      if (!showForm && !_loading) ...[
        // Only show the "no records" placeholder when there's no past
        // attendance AND no open shift for today — otherwise the
        // "Shift open since ..." banner above already conveys the state
        // (user 2026-09-07: attendance card was contradicting itself,
        // saying "no attendance marked" while today's check-in banner
        // sat right above it).
        if (past.isEmpty && open == null)
          CCard(child: Padding(padding: const EdgeInsets.all(12), child: Center(child: Text('No attendance marked yet', style: ct(12, FontWeight.w400, C2.text2)))))
        else
          ...past.map((r) => CCard(
            onTap: () => _showDetail(r),
            child: Row(children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: C2.cyanLight, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.event_available, color: C2.cyan)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.date, style: ct(13.5, FontWeight.w700, C2.text)),
                Text('${r.checkIn} – ${r.checkOut.isEmpty ? 'Pending' : r.checkOut} · ${r.location}', style: ct(11.5, FontWeight.w400, C2.text2)),
              ])),
              CBadge(r.status,
                bg: r.status == 'Pending' ? const Color(0xFFFFF3D6) : const Color(0xFFEDF7E0),
                fg: r.status == 'Pending' ? const Color(0xFF8A6A00) : C2.green),
            ]))),
      ],
    ]);
  }

  /// Morning "Check-in" form: date, check-in time, location, MMU starting km,
  /// selfie + GPS. Submit goes to POST /attendance/check-in.
  Widget _checkInForm() {
    final lastEnd = _lastEndKm;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SecBar('Check-in'),
      CField('Date', InputDecorator(decoration: cInput().copyWith(suffixIcon: const Icon(Icons.calendar_today, size: 16, color: C2.cyan)),
        child: Text(_date, style: ct(13.5, FontWeight.w600, C2.text))), required: true),
      // Time is auto-captured "now" the moment the counsellor taps Mark
      // Check-in — surfacing it as a read-only chip removes the risk of
      // hand-typing a wrong time (rule 2026-08-05).
      CField('Check-in time', _readOnlyPill(
        icon: Icons.access_time,
        value: _checkIn.isEmpty ? 'Fetching current time…' : _checkIn,
        empty: _checkIn.isEmpty,
      ), required: true),
      // Location comes from GPS (nearest of the three camps) and cannot be
      // hand-changed — same lockdown rule as time (2026-08-05).
      CField('Location', _readOnlyPill(
        icon: Icons.location_on_outlined,
        value: location ?? 'Detecting nearest camp via GPS…',
        empty: location == null,
      ), required: true),
      CField('MMU Starting (Km)', lastEnd.isNotEmpty
        ? InputDecorator(decoration: cInput().copyWith(fillColor: C2.bg, filled: true),
            child: Text(lastEnd, style: ct(13.5, FontWeight.w600, C2.text2)))
        : TextField(controller: _startKm, keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
            onChanged: (_) => setState(() {}), decoration: cInput('First login — enter km')),
        required: true),
      // Staff crew present at check-in — counsellor confirms who's on the
      // MMU for the day. At least one must be ticked before submit. Roles
      // that already did their OWN check-in today show pre-ticked + locked
      // (user 2026-08-19).
      CField('Staff Present (Check-in)', _staffChecklist(
        driver: _driverIn, doctor: _doctorIn, pharma: _pharmacistIn, other: _otherIn,
        onDriver: (v) => setState(() => _driverIn = v),
        onDoctor: (v) => setState(() => _doctorIn = v),
        onPharma: (v) => setState(() => _pharmacistIn = v),
        onOther: (v) => setState(() => _otherIn = v),
        lockDriver: _roleCheckedInToday('driver'),
        lockDoctor: _roleCheckedInToday('doctor'),
        lockPharma: _roleCheckedInToday('pharmacist'),
        lockOther: _roleCheckedInToday('other'),
      ), required: true),
      // "Other" ticked → name the person (user 2026-08-19). Saved inside
      // the staff note: "Other (<name>)".
      if (_otherIn)
        CField('Other', upper: false, TextField(
          controller: _otherInWho,
          decoration: cInput('Name / role of the new person'))),
      CField('Selfie + Location', AttendanceCapture(
        initialPhotoPath: _photoPath, initialLat: _lat, initialLng: _lng,
        // Feeds the watermark strip's "Place: ..." row.
        placeLabel: _placeLabelForWatermark(),
        onCaptured: (path, lat, lng) => setState(() { _photoPath = path; _lat = lat; _lng = lng; }),
      ), required: true),
      const SizedBox(height: 4),
      CPrimaryButton(_submitting ? 'Submitting…' : 'Submit Check-in',
          icon: Icons.login, onTap: _submitting ? null : _submitCheckIn),
    ]);
  }

  /// Three checkboxes for Driver / Doctor / Pharmacist attendance. Used on
  /// both the Check-in and Check-out forms so the counsellor confirms who
  /// was actually there.
  Widget _staffChecklist({
    required bool driver, required bool doctor, required bool pharma, required bool other,
    required ValueChanged<bool> onDriver,
    required ValueChanged<bool> onDoctor,
    required ValueChanged<bool> onPharma,
    required ValueChanged<bool> onOther,
    bool lockDriver = false,
    bool lockDoctor = false,
    bool lockPharma = false,
    bool lockOther = false,
    // Which verb the lock tag reads as — "checked-in" on the morning
    // form, "checked-out" on the evening one (user 2026-08-20).
    String lockedTag = 'checked-in',
  }) {
    // Fixed 2-per-row grid (user 2026-08-19). A `locked` cell renders
    // ticked + disabled with a "($lockedTag)" tag — that person already
    // has their own attendance mark today, so unticking would lie.
    Widget cell(String label, bool val, ValueChanged<bool> onCh,
            {bool locked = false}) =>
        InkWell(
          onTap: locked ? null : () => onCh(!val),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: 24, height: 24,
                child: Checkbox(
                  value: locked || val,
                  onChanged: locked ? null : (v) => onCh(v ?? false),
                  activeColor: C2.cyan,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(child: Text(
                locked ? '$label ($lockedTag)' : label,
                style: ct(13.5, FontWeight.w600, locked ? C2.text2 : C2.text),
                overflow: TextOverflow.ellipsis)),
            ]),
          ),
        );
    // Driver row hidden (user 2026-09-15: MMU no longer counts driver
    // attendance separately). The `driver` state stays wired so any
    // ambient reads stay valid — the checkbox itself just doesn't
    // render, and every caller pins driver=false, so nothing is
    // silently ticked.
    return Column(children: [
      Row(children: [
        Expanded(child: cell('Doctor', doctor, onDoctor, locked: lockDoctor)),
        Expanded(child: cell('Pharmacist', pharma, onPharma, locked: lockPharma)),
      ]),
      Row(children: [
        Expanded(child: cell('Other', other, onOther, locked: lockOther)),
        const Spacer(),
      ]),
    ]);
  }

  /// End-of-day "Check-out" form: shows the open shift context (read-only),
  /// then check-out time, MMU ending km, auto total run, collection, notes.
  /// Submit goes to POST /attendance/check-out.
  Widget _checkOutForm(AttendanceRecord open) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SecBar('Check-out'),
      // Context banner — remind the counsellor what shift they're closing so
      // they don't fill the wrong day's numbers.
      Container(
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(color: C2.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: C2.border)),
        child: Row(children: [
          const Icon(Icons.login, size: 16, color: C2.cyan),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Closing check-in from ${open.checkIn}', style: ct(12.5, FontWeight.w700, C2.navy)),
            Text('${open.date} · ${open.location} · Start ${open.startKm} km',
              style: ct(11, FontWeight.w400, C2.text2)),
          ])),
        ]),
      ),
      // Check-out time is captured at the moment the counsellor taps Mark
      // Check-out — read-only so the audit trail cannot be back-dated
      // (rule 2026-08-05).
      CField('Check-out time', _readOnlyPill(
        icon: Icons.access_time,
        value: _checkOut.isEmpty ? 'Fetching current time…' : _checkOut,
        empty: _checkOut.isEmpty,
      ), required: true),
      CField('MMU Ending (Km)', TextField(controller: _endKm, keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
        onChanged: (_) => setState(() {}), decoration: cInput()), required: true),
      CField('Total Run (Km)', InputDecorator(decoration: cInput().copyWith(fillColor: C2.bg, filled: true),
        child: Text(_totalRun().isEmpty ? 'Auto-calculated' : _totalRun(),
          style: ct(13.5, _totalRun().isEmpty ? FontWeight.w400 : FontWeight.w700,
            _totalRun().isEmpty ? C2.text3 : C2.navy))), required: true),
      CField('Total Collection (₹)', TextField(controller: _collection, keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
        decoration: cInput('Up to 5 digits')), required: true),
      // Staff crew checking out — same requirement as check-in: at least
      // one must be ticked so the audit trail closes cleanly. Roles that
      // already checked out on their own device are LOCKED here (user
      // 2026-08-20: "counseller going to check doctor will be show
      // selected and no editable"), with a friendly note above.
      if (_rolesAlreadyCheckedOut().isNotEmpty)
        Padding(padding: const EdgeInsets.only(bottom: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEDF7E0),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: C2.green.withValues(alpha: 0.4)),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle_outline, size: 16, color: C2.green),
              const SizedBox(width: 8),
              Expanded(child: Text(
                '${_rolesAlreadyCheckedOut().join(', ')} '
                '${_rolesAlreadyCheckedOut().length == 1 ? 'has' : 'have'} '
                'already checked out.',
                style: ct(12.5, FontWeight.w600, C2.green))),
            ]),
          )),
      CField('Staff Checking Out', _staffChecklist(
        driver: _driverOut, doctor: _doctorOut, pharma: _pharmacistOut, other: _otherOut,
        onDriver: (v) => setState(() => _driverOut = v),
        onDoctor: (v) => setState(() => _doctorOut = v),
        onPharma: (v) => setState(() => _pharmacistOut = v),
        onOther: (v) => setState(() => _otherOut = v),
        lockDriver: _roleCheckedOutToday('driver'),
        lockDoctor: _roleCheckedOutToday('doctor'),
        lockPharma: _roleCheckedOutToday('pharmacist'),
        lockOther: _roleCheckedOutToday('other'),
        lockedTag: 'checked-out',
      ), required: true),
      if (_otherOut)
        CField('Other', upper: false, TextField(
          controller: _otherOutWho,
          decoration: cInput('Name / role of the other person'))),
      CField('Notes', TextField(controller: _notes, minLines: 2, maxLines: null,
        decoration: cInput('Optional — type or use the mic').copyWith(suffixIcon: RemarksMicButton(controller: _notes)))),
      CField('Selfie + Location', AttendanceCapture(
        initialPhotoPath: _photoPathOut, initialLat: _latOut, initialLng: _lngOut,
        placeLabel: _placeLabelForWatermark(),
        onCaptured: (path, lat, lng) => setState(() { _photoPathOut = path; _latOut = lat; _lngOut = lng; }),
      ), required: true),
      const SizedBox(height: 4),
      CPrimaryButton(_submitting ? 'Submitting…' : 'Submit Check-out',
          icon: Icons.logout, onTap: _submitting ? null : _submitCheckOut),
    ]);
  }

  void _showDetail(AttendanceRecord r) => showModalBottomSheet(
        context: context, backgroundColor: Colors.transparent,
        // The row list + two photos easily outgrow the default half-screen
        // sheet (bottom overflowed on device) — cap at 85% and scroll.
        isScrollControlled: true,
        builder: (_) => Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          decoration: const BoxDecoration(color: C2.white, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: SafeArea(top: false, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: C2.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14),
            Text('Attendance — ${r.date}', style: ct(15, FontWeight.w700, C2.navy)),
            const SizedBox(height: 10),
            _row('Date', r.date), _row('Check-in', r.checkIn), _row('Check-out', r.checkOut.isEmpty ? 'Pending' : r.checkOut),
            _row('Location', r.location),
            // Staff (In)/(Out) rows removed (user 2026-08-19) — server rows
            // never carried the flags, so they always said "None"; the crew
            // list already reads naturally from the Notes line.
            if (r.collection.isNotEmpty) _row('Collection', '₹${r.collection}'),
            if (r.startKm.isNotEmpty) _row('MMU Start', '${r.startKm} km'),
            if (r.endKm.isNotEmpty) _row('MMU End', '${r.endKm} km'),
            if (r.totalRun.isNotEmpty) _row('Total Run', '${r.totalRun} km'),
            _row('Status', r.status),
            if (r.lat != null && r.lng != null)
              _row('GPS (In)', '${r.lat!.toStringAsFixed(5)}, ${r.lng!.toStringAsFixed(5)}'),
            if (r.latOut != null && r.lngOut != null)
              _row('GPS (Out)', '${r.latOut!.toStringAsFixed(5)}, ${r.lngOut!.toStringAsFixed(5)}'),
            if (r.notes.isNotEmpty) _row('Notes', r.notes),
            if (r.photoPath.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Check-in photo', style: ct(11, FontWeight.w600, C2.text2)),
              const SizedBox(height: 4),
              // Server rows carry an uploads URL (photo_key flow); rows
              // captured before the upload shipped hold a device path.
              // Tap → fullscreen lightbox (user 2026-08-19).
              GestureDetector(
                onTap: () => showPhotoLightbox(context, r.photoPath, title: 'Check-in photo'),
                child: ClipRRect(borderRadius: BorderRadius.circular(8),
                  child: r.photoPath.startsWith('http')
                    ? Image.network(r.photoPath, height: 160, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(height: 80, color: C2.border,
                          child: const Center(child: Icon(Icons.broken_image_outlined, color: C2.text3))))
                    : Image.file(File(r.photoPath), height: 160, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(height: 80, color: C2.border,
                          child: const Center(child: Icon(Icons.broken_image_outlined, color: C2.text3)))))),
            ] else
              _row('Check-in photo', r.photo ? 'Captured' : 'Not captured'),
            if (r.photoPathOut.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Check-out photo', style: ct(11, FontWeight.w600, C2.text2)),
              const SizedBox(height: 4),
              // Server rows carry an uploads URL (photo_key flow); rows
              // captured offline hold a device path.
              // Tap → fullscreen lightbox (user 2026-08-19).
              GestureDetector(
                onTap: () => showPhotoLightbox(context, r.photoPathOut, title: 'Check-out photo'),
                child: ClipRRect(borderRadius: BorderRadius.circular(8),
                  child: r.photoPathOut.startsWith('http')
                    ? Image.network(r.photoPathOut, height: 160, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(height: 80, color: C2.border,
                          child: const Center(child: Icon(Icons.broken_image_outlined, color: C2.text3))))
                    : Image.file(File(r.photoPathOut), height: 160, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(height: 80, color: C2.border,
                          child: const Center(child: Icon(Icons.broken_image_outlined, color: C2.text3)))))),
            ],
          ]))),
        ),
      );

  Widget _row(String k, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 96, child: Text(k, style: ct(12, FontWeight.w400, C2.text2))),
        Expanded(child: Text(v, style: ct(13, FontWeight.w600, C2.text))),
      ]));

  /// Read-only pill used for auto-filled fields the counsellor must not
  /// hand-edit (Check-in/out time + Location). Mirrors the styling of a
  /// disabled TextField so it slots into the same _kv rhythm as the rest
  /// of the form. `empty=true` fades the text so the placeholder message
  /// reads as pending rather than as the answer itself.
  Widget _readOnlyPill({
    required IconData icon,
    required String value,
    bool empty = false,
  }) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: C2.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: C2.border),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: empty ? C2.text3 : C2.cyan),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: ct(13.5, empty ? FontWeight.w400 : FontWeight.w600,
                empty ? C2.text3 : C2.text),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Icon(Icons.lock_outline, size: 14, color: C2.text3),
      ]),
    );
  }

  /// Compact "Driver, Doctor" string for the detail sheet's staff rows.
  /// Empty selection reads "None" so audits don't misread a blank row.
  String _staffSummary(bool driver, bool doctor, bool pharma) {
    final on = <String>[
      if (driver) 'Driver',
      if (doctor) 'Doctor',
      if (pharma) 'Pharmacist',
    ];
    return on.isEmpty ? 'None' : on.join(', ');
  }
}

// ───────────────────────── Camps ─────────────────────────
class CounCamps extends StatefulWidget {
  /// Bumped by the shell on refresh while this tab is current.
  final Listenable? refreshSignal;
  const CounCamps({super.key, this.refreshSignal});
  @override
  State<CounCamps> createState() => _CounCampsState();
}

class _CounCampsState extends State<CounCamps> {
  bool showForm = false;
  // Geography cascade (user 2026-08-19): Block list = the facility's
  // district's blocks (MastersStore geo cache, downloaded at login);
  // Village list = the chosen block's villages. Nothing hardcoded.
  String? block, village, type;
  final _name = TextEditingController();
  final _venue = TextEditingController();
  String _campDateIso = ''; // yyyy-mm-dd for the server
  String _campDateShow = ''; // dd-mm-yyyy for messages
  // Photo gallery (user 2026-08-19): local paths until upload on save.
  final List<String> _photos = [];
  // True while picked shots are being watermarked (loader in the field).
  bool _processingPhotos = false;

  bool _loading = true;
  bool _submitting = false;
  String? _error;
  List<Map<String, dynamic>> _rows = const [];

  @override
  void initState() {
    super.initState();
    widget.refreshSignal?.addListener(_onExternalRefresh);
    // Back closes the open camp form AND drops its draft (user
    // 2026-08-26 — same rule as the attendance forms).
    BackFormRegistry.register('coun.camps', () {
      if (!mounted || !showForm) return false;
      _resetForm();
      return true;
    });
    _load();
  }

  /// Shell-driven refresh (pull / app-bar while this tab is current).
  void _onExternalRefresh() {
    if (!mounted) return;
    if (showForm) _resetForm();
    _load();
  }

  @override
  void dispose() {
    BackFormRegistry.unregister('coun.camps');
    widget.refreshSignal?.removeListener(_onExternalRefresh);
    _name.dispose();
    _venue.dispose();
    super.dispose();
  }

  String get _userKey {
    final app = context.read<AppState>();
    return 'counsellor_${app.backendUserId ?? app.currentUser}';
  }

  /// Server camps → list; offline falls back to the cached snapshot
  /// (online/offline parity rule).
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await context.read<CampsApi>().list(dateFrom: AppConfig.dataWindowFrom, limit: 50);
      _rows = rows;
      try {
        final store = await CampsStore.open();
        await store.save(_userKey, _rows);
      } catch (_) {/* cache is best-effort */}
    } catch (_) {
      try {
        final store = await CampsStore.open();
        final cached = store.load(_userKey);
        if (cached.isNotEmpty) {
          _rows = cached;
        } else {
          _error = 'Could not load camps. Tap to retry.';
        }
      } catch (_) {
        _error = 'Could not load camps. Tap to retry.';
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  /// One-shot GPS for the camp-photo watermark. Permission already
  /// granted for attendance is reused; a timed-out fresh fix falls back
  /// to last-known so the Location segment still prints.
  Future<(double?, double?)> _gpsForWatermark() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm != LocationPermission.always &&
          perm != LocationPermission.whileInUse) {
        return (null, null);
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        return (null, null);
      }
      try {
        final pos = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.high)
            .timeout(const Duration(seconds: 8));
        return (pos.latitude, pos.longitude);
      } catch (_) {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) return (last.latitude, last.longitude);
      }
    } catch (_) {/* date/time-only strip */}
    return (null, null);
  }

  /// Camera-or-gallery chooser (user 2026-08-19: "there should be also
  /// option from camera"). Camera = one shot per tap; Gallery = multi.
  Future<void> _pickPhotos() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: C2.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: C2.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 12),
          ListTile(
            leading: Container(width: 38, height: 38,
              decoration: BoxDecoration(color: C2.cyanLight, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.photo_camera_outlined, color: C2.cyan)),
            title: Text('Take photo', style: ct(14, FontWeight.w700, C2.text)),
            subtitle: Text('Open camera', style: ct(11.5, FontWeight.w400, C2.text2)),
            onTap: () => Navigator.pop(context, 'camera'),
          ),
          ListTile(
            leading: Container(width: 38, height: 38,
              decoration: BoxDecoration(color: C2.cyanLight, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.photo_library_outlined, color: C2.cyan)),
            title: Text('Choose from gallery', style: ct(14, FontWeight.w700, C2.text)),
            subtitle: Text('Pick multiple photos', style: ct(11.5, FontWeight.w400, C2.text2)),
            onTap: () => Navigator.pop(context, 'gallery'),
          ),
        ])),
      ),
    );
    if (source == null || !mounted) return;
    try {
      // GPS BEFORE camera/gallery — same order as attendance selfies.
      // Sampling after the camera activity returns routinely times out
      // in 6s (GPS was paused), so the strip baked Date/Time only even
      // when location was already granted (user 2026-08-31).
      setState(() => _processingPhotos = true);
      final gps = await _gpsForWatermark();
      final lat = gps.$1;
      final lng = gps.$2;

      final List<String> rawPaths = [];
      if (source == 'camera') {
        final shot = await ImagePicker().pickImage(
          source: ImageSource.camera, imageQuality: 70, maxWidth: 1280);
        if (shot != null) rawPaths.add(shot.path);
      } else {
        final picks = await ImagePicker().pickMultiImage(
          imageQuality: 70, maxWidth: 1280);
        rawPaths.addAll([for (final p in picks) p.path]);
      }
      if (rawPaths.isEmpty || !mounted) {
        if (mounted) setState(() => _processingPhotos = false);
        return;
      }

      for (final path in rawPaths) {
        if (_photos.length >= 10) break; // sane cap per camp
        try {
          final stamped = await PhotoWatermark.stamp(
            File(path),
            // Camp photos stay GPS + Date + Time only. Passing village/
            // block here would print them now that `place` is live again
            // on the shared stamp (attendance uses facility_name).
            place: '',
            latitude: lat, longitude: lng,
          );
          _photos.add(stamped.path);
        } catch (_) {
          _photos.add(path); // never lose the shot over a failed stamp
        }
        if (mounted) setState(() {}); // thumbnail appears as each finishes
      }
      if (mounted) setState(() => _processingPhotos = false);
    } catch (_) {
      if (mounted) setState(() => _processingPhotos = false);
    }
  }

  Future<void> _save() async {
    void err(String m) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(m), backgroundColor: C2.danger));
    if (_submitting) return;
    if (block == null) return err('Select block');
    if (village == null) return err('Select village');
    if (type == null) return err('Select camp type');
    if (_name.text.trim().isEmpty) return err('Enter camp name');
    if (_venue.text.trim().isEmpty) return err('Enter venue');
    if (_campDateIso.isEmpty) return err('Select date');
    setState(() => _submitting = true);
    final api = context.read<CampsApi>();
    final sync = context.read<SyncService>();
    final uploads = context.read<UploadsApi>();

    // Upload the gallery first — names ride in the create payload. A
    // failed upload skips that photo rather than blocking the camp.
    final names = <String>[];
    var skipped = 0;
    for (final path in _photos) {
      try {
        final up = await uploads
            .uploadImage(path)
            .timeout(const Duration(seconds: 25));
        final n = (up['file_name'] ?? '').toString();
        if (n.isNotEmpty) { names.add(n); } else { skipped++; }
      } catch (_) { skipped++; }
    }

    // camp_type_id resolved from bootstrap master so the server
    // can skip the case-insensitive name lookup (user 2026-09-10).
    final masters = context.read<MastersStore>();
    final campTypeId = masters.masterIdOf('camp_types', type);
    final payload = {
      'village_name': village!,
      'block_name':   block!,
      'camp_type':    type!,
      if (campTypeId != null) 'camp_type_id': campTypeId,
      'camp_name':    _name.text.trim(),
      'venue':        _venue.text.trim(),
      'camp_date':    _campDateIso,
      'photos':       names,
    };
    try {
      await api.create(
        campName: _name.text.trim(),
        campType: type!,
        campTypeId: campTypeId,
        campDate: _campDateIso,
        villageName: village!,
        blockName: block!,
        venue: _venue.text.trim(),
        photos: names,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(skipped == 0
              ? 'Camp saved'
              : 'Camp saved ($skipped photo${skipped == 1 ? '' : 's'} failed to upload)'),
          backgroundColor: C2.green));
        _resetForm();
      }
    } on ApiException catch (e) {
      if (e.code == ApiErrorCode.networkUnreachable) {
        // Offline — queue for the sync drain and show it locally so the
        // counsellor's work isn't invisible until signal returns.
        sync.enqueue(kind: 'camp.create', payload: payload);
        setState(() => _rows = [
          {
            'camp_name': _name.text.trim(),
            'camp_type': type,
            'village_name': village,
            'block_name': block,
            'venue': _venue.text.trim(),
            'camp_date': _campDateIso,
            'photos': names,
            'local_photos': List<String>.from(_photos),
            'pending': true,
          },
          ..._rows,
        ]);
        unawaited(CampsStore.open().then((s) => s.save(_userKey, _rows)));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Offline — camp queued, will sync automatically'),
            backgroundColor: C2.navy));
          _resetForm();
        }
      } else if (mounted) {
        err('Save failed: ${e.message}');
      }
    } catch (_) {
      if (mounted) err('Save failed. Try again.');
    }
    if (mounted) setState(() => _submitting = false);
  }

  void _resetForm() {
    setState(() {
      showForm = false; block = null; village = null; type = null;
      _name.clear(); _venue.clear();
      _campDateIso = ''; _campDateShow = '';
      _photos.clear();
    });
  }

  /// Camp Type options — server master (bootstrap `masters.camp_types`)
  /// leads; the const `kCampTypes` list is the offline fallback. Result
  /// is deduplicated so a server list that already covers a fallback
  /// name does not repeat it. Preserves the currently-picked value even
  /// when server and hardcoded lists overlap (user 2026-09-10 dynamic
  /// camp types, mirror of the doctor-side frequency helper).
  List<String> _campTypeOptions(BuildContext ctx) {
    final server = ctx.read<MastersStore>().masterStrings('camp_types');
    if (server.isNotEmpty) {
      final seen = <String>{};
      final out = <String>[];
      for (final s in [...server, ...kCampTypes]) {
        if (s.trim().isEmpty) continue;
        if (seen.add(s)) out.add(s);
      }
      return out;
    }
    return kCampTypes;
  }

  static String _isoOf(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// dd-mm-yyyy for a server yyyy-mm-dd date.
  static String _showDate(dynamic v) {
    final s = (v ?? '').toString();
    if (s.length < 10) return s;
    return '${s.substring(8, 10)}-${s.substring(5, 7)}-${s.substring(0, 4)}';
  }

  String _photoUrl(String name) => name.startsWith('http') || name.startsWith('/')
      ? name
      : '$kUploadsBase/patient_docs/$name';

  @override
  Widget build(BuildContext context) {
    final masters = context.watch<MastersStore>();
    final blocks = masters.geoBlockNames;
    final villages = block == null ? const <String>[] : masters.geoVillagesOf(block!);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.only(bottom: 8), child: SecBar('Camp Activities', trailing: COutlineButton(showForm ? 'Close' : 'Add New', icon: showForm ? Icons.close : Icons.add,
          // Close drops the draft so reopening starts blank (user
          // 2026-08-26); Add New just opens the empty form.
          onTap: () => showForm ? _resetForm() : setState(() => showForm = true)))),
      if (showForm)
        CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SecBar('New Camp Activity'),
          // Block → Village cascade (user 2026-08-19). Changing the block
          // clears a village that no longer belongs to it.
          CField('Block', _dd(blocks, block, (v) => setState(() { block = v; village = null; }), hint: 'Select Block'), required: true),
          CField('Village', block == null
              ? InputDecorator(decoration: cInput().copyWith(fillColor: C2.bg, filled: true),
                  child: Text('Select block first', style: ct(13.5, FontWeight.w400, C2.text3)))
              : _dd(villages, village, (v) => setState(() => village = v), hint: 'Select Village'), required: true),
          // Camp Type is DYNAMIC — pulled from server's `masters.camp_types`
          // (bootstrap). Hardcoded `kCampTypes` stays as offline fallback
          // so a fresh install / cache-miss still renders a working picker
          // (user 2026-09-10 "use from master dynamic"). Server auto-
          // creates the row on save when the name doesn't match any
          // existing CampType — matches the doctor-side frequency pattern.
          CField('Camp Type', _dd(_campTypeOptions(context), type,
              (v) => setState(() => type = v), hint: 'Select Type'), required: true),
          CField('Camp Name', TextField(controller: _name, decoration: cInput('Enter camp name')), required: true),
          CField('Venue', TextField(controller: _venue, decoration: cInput('Enter venue')), required: true),
          // Future dates disabled (user 2026-08-19): last = today.
          // Cap first at today - dataWindowDays (user 2026-08-29): matches
          // the backend list-window so a camp saved outside the window
          // wouldn't disappear from Past Activities the next reload.
          CField('Date', DateField(hint: 'Select date',
              first: DateTime.now().subtract(const Duration(days: AppConfig.dataWindowDays)),
              last: DateTime.now(),
            onPicked: (d) { _campDateIso = _isoOf(d); _campDateShow = fmtDate(d); }), required: true),
          // Photo gallery — pick many, remove any, thumbnails preview.
          CField('Photos', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (var i = 0; i < _photos.length; i++)
                Stack(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(8),
                    child: Image.file(File(_photos[i]), width: 72, height: 72, fit: BoxFit.cover)),
                  Positioned(top: 2, right: 2, child: InkWell(
                    onTap: () => setState(() => _photos.removeAt(i)),
                    child: Container(
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.all(2),
                      child: const Icon(Icons.close, size: 14, color: Colors.white)),
                  )),
                ]),
              InkWell(
                onTap: (_photos.length >= 10 || _processingPhotos) ? null : _pickPhotos,
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: C2.cyanLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: C2.border)),
                  child: _processingPhotos
                      ? const Center(child: SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: C2.cyan)))
                      : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.add_photo_alternate_outlined, color: C2.cyan),
                          Text('Add', style: TextStyle(fontSize: 10, color: C2.navy)),
                        ]),
                ),
              ),
            ]),
            if (_processingPhotos) ...[
              const SizedBox(height: 6),
              const LinearProgressIndicator(minHeight: 3, color: C2.cyan, backgroundColor: C2.border),
              const SizedBox(height: 4),
              Text('Processing photos…', style: ct(10.5, FontWeight.w600, C2.navy)),
            ] else if (_photos.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 4),
                child: Text('${_photos.length}/10 photos', style: ct(10.5, FontWeight.w500, C2.text3))),
          ])),
          Row(children: [
            Expanded(child: CPrimaryButton(
              _processingPhotos ? 'Processing photos…' : (_submitting ? 'Saving…' : 'Save'),
              icon: Icons.check,
              onTap: (_submitting || _processingPhotos) ? null : _save)),
          ]),
        ])),
      if (_loading && !showForm)
        const CCard(child: Padding(padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2))))
      else if (_error != null && !showForm)
        CCard(onTap: _load, child: Padding(padding: const EdgeInsets.all(12),
          child: Center(child: Text(_error!, style: ct(12, FontWeight.w500, C2.danger)))))
      else if (_rows.isEmpty && !showForm)
        CCard(child: Padding(padding: const EdgeInsets.all(8), child: Center(child: Text('No camp activities recorded', style: ct(12, FontWeight.w400, C2.text2)))))
      else if (!showForm)
        ..._rows.map((c) {
          final photos = [
            for (final p in (c['photos'] as List? ?? const [])) p.toString(),
          ];
          final pending = c['pending'] == true;
          return CCard(
            onTap: () => _showCampDetail(c),
            child: Row(children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: C2.cyanLight, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.location_on, color: C2.cyan)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${c['camp_name'] ?? ''}', style: ct(13.5, FontWeight.w700, C2.text)),
                Text('${c['camp_type'] ?? ''} · ${c['village_name'] ?? ''} · ${_showDate(c['camp_date'])}', style: ct(11.5, FontWeight.w400, C2.text2)),
                Text('${c['venue'] ?? ''}', style: ct(11.5, FontWeight.w400, C2.text2)),
              ])),
              if (photos.isNotEmpty || (c['local_photos'] as List?)?.isNotEmpty == true)
                Padding(padding: const EdgeInsets.only(right: 6),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.photo_library_outlined, size: 15, color: C2.cyan),
                    const SizedBox(width: 2),
                    Text('${photos.isNotEmpty ? photos.length : (c['local_photos'] as List).length}',
                      style: ct(11, FontWeight.w700, C2.navy)),
                  ])),
              if (pending)
                const CBadge('Pending sync', bg: Color(0xFFFEF7E0), fg: Color(0xFFB8860B)),
            ]));
        }),
    ]);
  }

  void _showCampDetail(Map<String, dynamic> c) {
    final serverPhotos = [
      for (final p in (c['photos'] as List? ?? const [])) _photoUrl(p.toString()),
    ];
    final localPhotos = [
      for (final p in (c['local_photos'] as List? ?? const [])) p.toString(),
    ];
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: const BoxDecoration(color: C2.white, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: SafeArea(top: false, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: C2.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 14),
          Text('${c['camp_name'] ?? 'Camp'}', style: ct(15, FontWeight.w700, C2.navy)),
          const SizedBox(height: 10),
          _row('Date', _showDate(c['camp_date'])),
          _row('Type', '${c['camp_type'] ?? ''}'),
          _row('Block', '${c['block_name'] ?? ''}'),
          _row('Village', '${c['village_name'] ?? ''}'),
          _row('Venue', '${c['venue'] ?? ''}'),
          if ((serverPhotos.isNotEmpty) || localPhotos.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Photos (${serverPhotos.length + localPhotos.length})',
                style: ct(12, FontWeight.w700, C2.navy)),
            const SizedBox(height: 6),
            // Auto-scrolling carousel (user 2026-08-19) — swipes by hand
            // too; dots show the position.
            _AutoCarousel(images: [
              for (final u in serverPhotos) (network: true, path: u),
              for (final p in localPhotos) (network: false, path: p),
            ]),
          ],
        ]))),
      ),
    );
  }

  Widget _row(String k, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [
        SizedBox(width: 96, child: Text(k, style: ct(12, FontWeight.w400, C2.text2))),
        Expanded(child: Text(v, style: ct(13, FontWeight.w600, C2.text))),
      ]));
}

/// Auto-scrolling photo carousel for the camp detail sheet (user
/// 2026-08-19). Advances every 3 s, loops, and still swipes by hand; a
/// dot row marks the position. `network` picks Image.network vs
/// Image.file per entry.
class _AutoCarousel extends StatefulWidget {
  final List<({bool network, String path})> images;
  const _AutoCarousel({required this.images});

  @override
  State<_AutoCarousel> createState() => _AutoCarouselState();
}

class _AutoCarouselState extends State<_AutoCarousel> {
  final PageController _page = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    if (widget.images.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (!mounted || !_page.hasClients) return;
        final next = (_index + 1) % widget.images.length;
        _page.animateToPage(next,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _page.dispose();
    super.dispose();
  }

  /// BoxFit.contain on a dark ground — the WHOLE photo shows (user
  /// 2026-08-20: "photo is cutting" — cover cropped tall images).
  /// Tap → fullscreen lightbox, same as attendance photos.
  Widget _img(({bool network, String path}) e, int index) => GestureDetector(
      onTap: () => showPhotoLightbox(context, e.path,
          title: 'Camp photo ${index + 1} / ${widget.images.length}'),
      child: Container(
        color: const Color(0xFF10151B),
        child: e.network
            ? Image.network(e.path, fit: BoxFit.contain, width: double.infinity,
                errorBuilder: (_, __, ___) => Container(color: C2.border,
                  child: const Center(child: Icon(Icons.broken_image_outlined, color: C2.text3))))
            : Image.file(File(e.path), fit: BoxFit.contain, width: double.infinity,
                errorBuilder: (_, __, ___) => Container(color: C2.border,
                  child: const Center(child: Icon(Icons.broken_image_outlined, color: C2.text3)))),
      ));

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) return const SizedBox.shrink();
    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 200,
          width: double.infinity,
          child: PageView.builder(
            controller: _page,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => _img(widget.images[i], i),
          ),
        ),
      ),
      if (widget.images.length > 1) ...[
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < widget.images.length; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _index ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == _index ? C2.cyan : C2.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ]),
      ],
    ]);
  }
}

// ───────────────────────── Devices ─────────────────────────
//
// Flow (matches the web portal):
//   1. Pick the status date (today or any past date).
//   2. Radios pre-fill with whatever status each device had on that date
//      (most recent history record ≤ date, defaults to Working).
//   3. Change as needed → tap Submit. One history record per device is
//      written for the chosen date.
//   4. Past Submissions table at the bottom lists every date that has
//      records, with the status of each device on that date.
class CounDevices extends StatefulWidget {
  /// Bumped by the shell on refresh while this tab is current.
  final Listenable? refreshSignal;
  const CounDevices({super.key, this.refreshSignal});
  @override
  State<CounDevices> createState() => _CounDevicesState();
}

class _CounDevicesState extends State<CounDevices> {
  /// Device state options — dynamic from bootstrap `masters.device_states`
  /// (user 2026-09-10). Hardcoded `kDeviceStates` remains the offline
  /// fallback; dedupe keeps a saved value valid regardless of source.
  List<String> _deviceStateOptions(BuildContext ctx) {
    final server = ctx.read<MastersStore>().masterStrings('device_states');
    if (server.isEmpty) return kDeviceStates;
    final seen = <String>{};
    return [
      for (final s in [...server, ...kDeviceStates])
        if (s.trim().isNotEmpty && seen.add(s)) s,
    ];
  }

  // Submissions are MONTHLY and always for the CURRENT month, stored
  // server-side against its 1st (user rule 2026-08-14: one update per
  // month; the form unlocks again when the next month starts). Computed
  // fresh on every read (user 2026-08-26: date changed to 1-Sep but
  // banner still said "Aug pending" — the field used to cache the month
  // at page-mount time).
  DateTime get _month {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  bool _loading = true;
  bool _submitting = false;
  String? _error;
  // Device roster straight from device_master (GET /devices/status) —
  // nothing hardcoded, a device added on the web portal appears here.
  List<Map<String, dynamic>> _devices = const [];
  final Map<int, String> _chosen = {}; // device_id → status in the form
  // Server-persisted history (GET /devices/history) — survives app
  // close/switch, unlike the old in-memory submissions list.
  List<Map<String, dynamic>> _history = const [];
  bool _lockedThisMonth = false;

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static const _kMonthShort = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  String _fmtMonthLabel(DateTime d) => '${_kMonthShort[d.month - 1]} ${d.year}';
  DateTime get _nextMonth => _month.month == 12
      ? DateTime(_month.year + 1, 1, 1)
      : DateTime(_month.year, _month.month + 1, 1);

  // Scrollbar(thumbVisibility: true) needs its own controller — without
  // one it hunts for a PrimaryScrollController and throws on this page
  // (exception seen live 2026-08-14).
  final ScrollController _histScroll = ScrollController();

  /// Shell-driven refresh (pull / app-bar while this tab is current).
  /// _load → _applyHydratedState resets the status dropdowns to server
  /// truth, so any unsaved draft edits are dropped (user 2026-08-26).
  void _onExternalRefresh() {
    if (mounted) _load();
  }

  @override
  void dispose() {
    BackFormRegistry.unregister('coun.devices');
    widget.refreshSignal?.removeListener(_onExternalRefresh);
    _histScroll.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    widget.refreshSignal?.addListener(_onExternalRefresh);
    // Back off the Devices tab drops unsaved dropdown edits — the next
    // visit shows server truth again (user 2026-08-26). Returns false so
    // the back press still switches tabs normally.
    BackFormRegistry.register('coun.devices', () {
      if (mounted && !_lockedThisMonth) {
        _applyHydratedState();
        setState(() {});
      }
      return false;
    });
    _load();
  }

  /// Rows of THIS month's monthly submission — used both for the month
  /// lock and to show the submitted values back in the form. Monthly
  /// submissions always land on the month's 1st; matching that exact
  /// date keeps legacy daily rows (from the old per-day design) from
  /// locking a month nobody has submitted yet.
  List<Map<String, dynamic>> get _thisMonthRows {
    final first = _iso(_month);
    return [ for (final r in _history) if ((r['status_date'] ?? '').toString().startsWith(first)) r ];
  }

  /// Per-user cache key for DevicesStore — same isolation rule as
  /// AttendanceStore ("no cross-user leakage"). 2026-08-20.
  String get _devicesUserKey {
    final app = context.read<AppState>();
    return 'counsellor_${app.backendUserId ?? app.currentUser}';
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = context.read<DevicesApi>();
      final devices = await api.status();
      // Device reports are monthly, so the audit trail needs a much
      // longer look-back than attendance/camps (user 2026-08-29:
      // "devices 8 month"). Backend caps identically via
      // DEVICES_HISTORY_DEFAULT_DAYS = 240 in field_views.py.
      final history =
          await api.history(dateFrom: AppConfig.deviceWindowFrom);
      _devices = devices;
      _history = history;
      // Persist for offline use (user rule 2026-08-20 "update device
      // status offline; when online data will be sent" — submit already
      // goes via SyncService's offline queue).
      try {
        final store = await DevicesStore.open();
        await store.saveDevices(_devicesUserKey, devices);
        await store.saveHistory(_devicesUserKey, history);
      } catch (_) {/* cache write is best-effort */}
      _applyHydratedState();
    } on ApiException catch (e) {
      // Offline / network error: silent — hydrate from cache so the
      // form still opens and the counsellor can update statuses. Real
      // API errors (401 / 500) still surface.
      if (e.code == ApiErrorCode.networkUnreachable) {
        await _loadDevicesFromCache();
      } else {
        _error = e.message;
      }
    } catch (_) {
      await _loadDevicesFromCache();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadDevicesFromCache() async {
    try {
      final store = await DevicesStore.open();
      _devices = store.loadDevices(_devicesUserKey);
      _history = store.loadHistory(_devicesUserKey);
      if (_devices.isNotEmpty) _applyHydratedState();
    } catch (_) {/* fall through — empty state */}
  }

  void _applyHydratedState() {
    final monthRows = _thisMonthRows;
    _lockedThisMonth = monthRows.isNotEmpty;
    // Monthly reminders moved SERVER-SIDE (user decision 2026-08-19).
    unawaited(NotificationsService.instance.cancelDeviceStatusReminders());
    _chosen.clear();
    for (final d in _devices) {
      final id = (d['device_id'] as num?)?.toInt();
      if (id == null) continue;
      final name = (d['device_name'] ?? '').toString();
      final sub = monthRows.where((r) => r['device_name'] == name).toList();
      _chosen[id] = (sub.isNotEmpty
              ? sub.first['status']
              : (d['status'] ?? 'Working'))
          .toString();
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_devices.isEmpty) {
      // Nothing to submit because the server's Device master is empty —
      // say so instead of silently doing nothing (user bug 2026-08-21).
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No devices configured on the server — '
            'run seed_devices / add devices in Masters, then refresh'),
        backgroundColor: C2.danger,
      ));
      return;
    }
    setState(() => _submitting = true);
    // Grab services before the first await — context reads across async
    // gaps are unsafe once the widget can unmount mid-flight.
    final api = context.read<DevicesApi>();
    final sync = context.read<SyncService>();
    final lines = [
      for (final d in _devices)
        if ((d['device_id'] as num?) != null)
          {
            'device_id': (d['device_id'] as num).toInt(),
            'status': _chosen[(d['device_id'] as num).toInt()] ?? 'Working',
          },
    ];
    print('[JC] devices.submit: devices=${_devices.length} lines=$lines date=${_iso(_month)}');
    try {
      await api.submitStatus(date: _iso(_month), lines: lines);
      print('[JC] devices.submit: API OK');
      await _load(); // re-pull history → the month locks itself
      // Server cron owns the monthly reminders now — locally just make
      // sure nothing stale keeps firing on this handset.
      unawaited(NotificationsService.instance.cancelDeviceStatusReminders());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Device status submitted for ${_fmtMonthLabel(_month)}'),
          backgroundColor: C2.green,
        ));
      }
    } on ApiException catch (e) {
      print('[JC] devices.submit: ApiException ${e.code} ${e.message}');
      if (e.code == ApiErrorCode.networkUnreachable) {
        // Offline — queue through sync (backend upserts on
        // device_id+facility+date, so a later online retry is harmless).
        for (final l in lines) {
          sync.enqueue(kind: 'device.status', payload: {
            'device_id':   l['device_id'],
            'status':      l['status'],
            'status_date': _iso(_month),
          });
        }
        unawaited(NotificationsService.instance.cancelDeviceStatusReminders());
        if (mounted) {
          setState(() => _lockedThisMonth = true);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Offline — ${_fmtMonthLabel(_month)} status queued, will sync automatically'),
            backgroundColor: C2.navy,
          ));
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Submit failed: ${e.message}'), backgroundColor: C2.danger));
      }
    } catch (e) {
      print('[JC] devices.submit: THREW ${e.runtimeType} $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Submit failed. Try again.'), backgroundColor: C2.danger));
      }
    }
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    Color dc(String st) => st == 'Working' ? C2.green : (st == 'Not Working' ? C2.danger : C2.text2);
    String legend(String st) => st == 'Working' ? 'W' : st == 'Not Working' ? 'NW' : st == 'Not Applicable' ? 'NA' : '-';

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.only(bottom: 8), child: SecBar('Health Devices')),

      // Pending-month alert — Panara confirm modal on tab entry (user
      // 2026-08-20 messages). "Update" scrolls back to the top of the
      // form so the counsellor lands right on the first device.
      if (!_loading && _error == null && !_lockedThisMonth)
        Builder(builder: (ctx) {
          // Single-button dialog (user 2026-08-20 "if redirect not
          // possible then remove the button"). Form is on the same
          // screen; the OK button just dismisses.
          PendingAlert.showOnce(
            ctx,
            key: 'devices-pending-${_month.year}-${_month.month}',
            title: 'Device Status Pending',
            message: 'Your device status for ${_fmtMonthLabel(_month)} is '
                'pending. Please update the status of each device and tap '
                'Submit.',
          );
          return const SizedBox.shrink();
        }),

      if (_loading)
        const Padding(padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2))),

      if (!_loading && _error != null)
        Padding(padding: const EdgeInsets.only(bottom: 8), child: InkWell(
          onTap: _load,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: C2.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Icon(Icons.cloud_off, size: 16, color: C2.danger),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!, style: ct(12.5, FontWeight.w600, C2.danger))),
              const Icon(Icons.refresh, size: 16, color: C2.danger),
            ]),
          ),
        )),

      // ── Submission form ──
      if (!_loading && _error == null)
        CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SecBar('Record Device Status'),
          Padding(padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _lockedThisMonth
                  ? 'This month is recorded. The form opens again in ${_fmtMonthLabel(_nextMonth)}.'
                  : 'Set each device\'s status for this month, then Submit.',
              style: ct(11.5, FontWeight.w400, C2.text2))),

          // Locked to the CURRENT month — one submission per month.
          CField('Status Month',
            InputDecorator(
              decoration: cInput().copyWith(
                suffixIcon: const Icon(Icons.lock_outline, size: 16, color: C2.text3),
              ),
              child: Text(_fmtMonthLabel(_month),
                  style: ct(13.5, FontWeight.w600, C2.text)),
            ),
            required: true,
          ),

          if (_lockedThisMonth)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: C2.green.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.check_circle, size: 16, color: C2.green),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  '${_fmtMonthLabel(_month)} status submitted — next update in ${_fmtMonthLabel(_nextMonth)}',
                  style: ct(12.5, FontWeight.w600, C2.green))),
              ]),
            )),

          ..._devices.map((d) {
            final id = (d['device_id'] as num?)?.toInt() ?? -1;
            final name = (d['device_name'] ?? '').toString();
            final st = _chosen[id] ?? 'Working';
            return CField(name, Row(children: [
              Icon(Icons.circle, size: 10, color: dc(st)),
              const SizedBox(width: 8),
              Expanded(
                child: _lockedThisMonth
                    // Read-only once the month is submitted.
                    ? InputDecorator(
                        decoration: cInput().copyWith(
                          suffixIcon: const Icon(Icons.lock_outline, size: 16, color: C2.text3),
                        ),
                        child: Text(st, style: ct(13.5, FontWeight.w600, C2.text)),
                      )
                    : _dd(_deviceStateOptions(context), st,
                        (v) => setState(() { if (v != null) _chosen[id] = v; })),
              ),
            ]));
          }),

          if (_devices.isEmpty)
            Padding(padding: const EdgeInsets.all(8),
              child: Text('No devices configured for this facility.',
                style: ct(12, FontWeight.w400, C2.text2))),

          if (!_lockedThisMonth && _devices.isNotEmpty) ...[
            const SizedBox(height: 8),
            CPrimaryButton(_submitting ? 'Submitting…' : 'Submit',
                icon: Icons.check_circle_outline,
                onTap: _submitting ? null : _submit),
          ],
        ])),

      // ── Past submissions — straight from /devices/history, so they
      // survive app switches and restarts (user bug 2026-08-14: the old
      // in-memory list vanished whenever the app was closed). ──
      if (!_loading && _error == null)
        Builder(builder: (context) {
          final deviceCols = _devices.isNotEmpty
              ? [ for (final d in _devices) (d['device_name'] ?? '').toString() ]
              : { for (final r in _history) (r['device_name'] ?? '').toString() }.toList();
          // Group history rows into one table row per date (newest first —
          // the server already orders DESC).
          final dates = <String>[];
          final byDateName = <String, Map<String, String>>{};
          for (final r in _history) {
            final dt = (r['status_date'] ?? '').toString();
            final key = dt.length >= 10 ? dt.substring(0, 10) : dt;
            (byDateName[key] ??= (() { dates.add(key); return <String, String>{}; })())
                [(r['device_name'] ?? '').toString()] = (r['status'] ?? '').toString();
          }
          // Monthly submissions land on the 1st — show "Aug 2026"; any
          // legacy daily rows keep their full date.
          String fmtCell(String d) {
            final p = d.split('-');
            if (p.length != 3) return d;
            final m = int.tryParse(p[1]);
            if (m == null || m < 1 || m > 12) return d;
            return p[2] == '01' ? '${_kMonthShort[m - 1]} ${p[0]}' : '${p[2]}-${p[1]}-${p[0]}';
          }
          return Padding(padding: const EdgeInsets.only(top: 4),
            child: CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SecBar('Past Device Status Submissions'),
              if (dates.isEmpty)
                Padding(padding: const EdgeInsets.all(8),
                  child: Center(child: Text('No submissions yet. Use the form above.',
                    style: ct(12, FontWeight.w400, C2.text2)))),
              if (dates.isNotEmpty)
                // Wide tables overflow the narrow phone width when device
                // names are long (Sphygmomanometer / Haemoglobinometer).
                // Scroll horizontally so every column stays reachable.
                Scrollbar(
                  controller: _histScroll,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _histScroll,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Table(
                      border: TableBorder.all(color: C2.border, width: 0.5),
                      defaultColumnWidth: const IntrinsicColumnWidth(),
                      children: [
                        TableRow(
                          decoration: const BoxDecoration(color: C2.bg),
                          children: [
                            Padding(padding: const EdgeInsets.all(6), child: Text('Month', style: ct(11, FontWeight.w700, C2.navy))),
                            ...deviceCols.map((d) => Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(d, style: ct(10.5, FontWeight.w700, C2.navy), textAlign: TextAlign.center))),
                          ],
                        ),
                        ...dates.map((dt) => TableRow(children: [
                          Padding(padding: const EdgeInsets.all(6), child: Text(fmtCell(dt), style: ct(11, FontWeight.w500, C2.text))),
                          ...deviceCols.map((d) {
                            final v = byDateName[dt]?[d];
                            return Padding(
                              padding: const EdgeInsets.all(6),
                              child: Center(child: Text(v == null ? '—' : legend(v),
                                style: ct(11, FontWeight.w700, v == null ? C2.text3 : dc(v)))),
                            );
                          }),
                        ])),
                      ],
                    ),
                  ),
                ),
            ])));
        }),
    ]);
  }
}

// ───────────────────────── Reports ─────────────────────────
class CounReports extends StatefulWidget {
  const CounReports({super.key});
  @override
  State<CounReports> createState() => _CounReportsState();
}

class _CounReportsState extends State<CounReports> {
  String? selected;
  String _from = '';
  String _to = '';
  int _tick = 0; // bumped to reset the date fields to placeholders after generating

  // Parses dd-MM-yyyy (the fmtDate format since 2026-07-29). If any older
  // dd-MMM-yyyy strings are still lying around we still try to read them so
  // report filters don't break on legacy records.
  static const _mAbbr = {'Jan':1,'Feb':2,'Mar':3,'Apr':4,'May':5,'Jun':6,'Jul':7,'Aug':8,'Sep':9,'Oct':10,'Nov':11,'Dec':12};
  DateTime? _parseDate(String s) {
    final t = s.trim();
    final num = RegExp(r'^(\d{1,2})-(\d{1,2})-(\d{4})$').firstMatch(t);
    if (num != null) {
      return DateTime(int.parse(num.group(3)!), int.parse(num.group(2)!), int.parse(num.group(1)!));
    }
    final abbr = RegExp(r'^(\d{1,2})-([A-Za-z]{3})-(\d{4})$').firstMatch(t);
    if (abbr != null) {
      final mo = _mAbbr[abbr.group(2)];
      if (mo != null) return DateTime(int.parse(abbr.group(3)!), mo, int.parse(abbr.group(1)!));
    }
    return null;
  }

  void _generate(CounsellorState s) {
    if (_from.isEmpty || _to.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select both From and To dates'), backgroundColor: C2.danger));
      return;
    }
    final from = _from, to = _to;
    final isPatient = selected == 'patient';
    final lines = <String>[];
    if (isPatient) {
      final pending = s.patients.where((p) => p.status != 'completed').length;
      lines.add('Total registered: ${s.patients.length}');
      lines.add('Pending: $pending');
      lines.add('Completed: ${s.visitsCompleted}');
      lines.add('');
      for (final p in s.patients.take(12)) {
        lines.add('• ${p.regDate.isEmpty ? "" : "${p.regDate} · "}${p.name} (${p.age}y) — ${p.disease.isEmpty ? "—" : p.disease}');
      }
    } else {
      s.deviceStatus.forEach((k, v) => lines.add('• $k — $v'));
    }
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: C2.white,
      title: Text('${isPatient ? 'Patient' : 'Device'} Report', style: ct(15, FontWeight.w700, C2.navy)),
      content: SizedBox(width: double.maxFinite, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$from  →  $to', style: ct(11.5, FontWeight.w600, C2.text2)),
        const Divider(),
        ...lines.map((l) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(l, style: ct(12.5, FontWeight.w400, C2.text)))),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Close', style: ct(13, FontWeight.w600, C2.text2))),
        TextButton(onPressed: () { Navigator.pop(context); _exportPdf(s, from, to); }, child: Text('Export PDF', style: ct(13, FontWeight.w700, C2.cyan))),
      ],
    ));
    // Revert the From/To fields to their placeholder once generated.
    setState(() { _from = ''; _to = ''; _tick++; });
  }

  Future<void> _exportPdf(CounsellorState s, String from, String to) async {
    final isPatient = selected == 'patient';
    final doc = pw.Document();
    if (isPatient) {
      final pending = s.patients.where((p) => p.status != 'completed').length;
      doc.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4.landscape, build: (ctx) => [
        pw.Header(level: 0, child: pw.Text('JubiCare - Patient Report', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
        pw.Text('Period: $from to $to'),
        pw.SizedBox(height: 10),
        pw.Text('Total registered: ${s.patients.length}    Pending: $pending    Completed: ${s.visitsCompleted}'),
        pw.SizedBox(height: 12),
        pw.Table.fromTextArray(
          headers: ['Date', 'Patient', 'Age/Gender', 'Village', 'Diagnosis', 'Symptoms', 'Status'],
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          columnWidths: {for (var i = 0; i < 7; i++) i: const pw.IntrinsicColumnWidth()},
          data: s.patients.map((p) => [
            p.regDate.isEmpty ? '-' : p.regDate, p.name, '${p.age}/${p.gender}', p.village.isEmpty ? '-' : p.village,
            p.disease.isEmpty ? '-' : p.disease,
            p.symptoms.isEmpty ? '-' : p.symptoms.join(', '),
            apptStatusLabel(p.status),
          ]).toList(),
        ),
      ]));
    } else {
      // Device report — landscape, one column per day in the selected duration.
      // All cells use softWrap:false so no header or data text wraps; column
      // widths auto-fit via IntrinsicColumnWidth.
      // NOTE: no day-count cap. The earlier `days.length < 20` cap silently
      // dropped today's column when the range exceeded 20 days, so device
      // changes made today never appeared in the report. We chunk into
      // 20-day sub-tables below so each chunk still fits the page width.
      final fromD = _parseDate(from), toD = _parseDate(to);
      final days = <DateTime>[];
      if (fromD != null && toD != null && !toD.isBefore(fromD)) {
        var d = fromD;
        while (!d.isAfter(toD)) { days.add(d); d = d.add(const Duration(days: 1)); }
      }
      const int chunkSize = 20;
      final chunks = <List<DateTime>>[];
      for (var i = 0; i < days.length; i += chunkSize) {
        chunks.add(days.sublist(i, i + chunkSize > days.length ? days.length : i + chunkSize));
      }
      String legend(String c) => switch (c) {
        'Working' => 'W', 'Not Working' => 'NW', 'Not Applicable' => 'NA', _ => '-' };
      pw.Widget noWrapCell(String text, {bool header = false, bool center = false, double size = 9}) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        alignment: center ? pw.Alignment.center : pw.Alignment.centerLeft,
        child: pw.Text(text,
          softWrap: false, maxLines: 1, overflow: pw.TextOverflow.visible,
          style: pw.TextStyle(fontSize: size, fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );
      final headerDecoration = const pw.BoxDecoration(color: PdfColors.grey300);
      final border = pw.TableBorder.all(color: PdfColors.grey500, width: 0.5);
      doc.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4.landscape, build: (ctx) => [
        pw.Header(level: 0, child: pw.Text('JubiCare - Device Report', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
        pw.Text('Period: $from to $to'),
        pw.SizedBox(height: 4),
        pw.Text('Legend:  W = Working,  NW = Not Working,  NA = Not Applicable', style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 10),
        if (days.isEmpty)
          pw.Table(
            border: border,
            columnWidths: {for (var i = 0; i < 2; i++) i: const pw.IntrinsicColumnWidth()},
            children: [
              pw.TableRow(decoration: headerDecoration, children: [
                noWrapCell('Device', header: true),
                noWrapCell('Condition', header: true),
              ]),
              ...s.deviceStatus.entries.map((e) => pw.TableRow(children: [
                noWrapCell(e.key),
                noWrapCell(e.value),
              ])),
            ],
          )
        else
          // One sub-table per 20-day chunk. pw.MultiPage flows them across
          // pages automatically.
          ...chunks.expand((chunkDays) => [
            pw.Table(
              border: border,
              columnWidths: {for (var i = 0; i < 1 + chunkDays.length; i++) i: const pw.IntrinsicColumnWidth()},
              children: [
                pw.TableRow(decoration: headerDecoration, children: [
                  noWrapCell('Device', header: true, size: 8),
                  ...chunkDays.map((d) => noWrapCell(
                    '${d.day}-${_mAbbr.keys.firstWhere((k) => _mAbbr[k] == d.month)}',
                    header: true, center: true, size: 8)),
                ]),
                // Per-date lookup: each column shows the status that was active
                // on that specific day (most recent change on or before it).
                ...kDeviceNames.map((dev) => pw.TableRow(children: [
                  noWrapCell(dev),
                  ...chunkDays.map((day) {
                    final iso = '${day.year.toString().padLeft(4, '0')}-'
                        '${day.month.toString().padLeft(2, '0')}-'
                        '${day.day.toString().padLeft(2, '0')}';
                    return noWrapCell(legend(s.getDeviceStatusOn(dev, iso)), center: true);
                  }),
                ])),
              ],
            ),
            pw.SizedBox(height: 12),
          ]),
      ]));
    }
    await Printing.layoutPdf(onLayout: (f) => doc.save(), name: 'JubiCare_${isPatient ? "Patient" : "Device"}_Report');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<CounsellorState>();
    final today = DateTime.now();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.only(bottom: 8), child: SecBar('Reports')),
      _reportCard('Patient Report', 'Patient data with diagnosis, tests, prescriptions', Icons.description, C2.cyan, 'patient'),
      _reportCard('Device Report', 'Health device condition status report', Icons.thermostat, C2.navy, 'device'),
      if (selected != null)
        CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SecBar('Select Duration'),
          Row(children: [
            Expanded(child: CField('From', DateField(key: ValueKey('from$_tick'), hint: 'Select date', first: DateTime(2024), last: today, onPicked: (d) => setState(() => _from = fmtDate(d))))),
            const SizedBox(width: 8),
            Expanded(child: CField('To', DateField(key: ValueKey('to$_tick'), hint: 'Select date', first: DateTime(2024), last: today, onPicked: (d) => setState(() => _to = fmtDate(d))))),
          ]),
          CPrimaryButton('Generate Report', icon: Icons.download, onTap: () => _generate(s)),
        ])),
    ]);
  }

  Widget _reportCard(String title, String sub, IconData icon, Color color, String key) => CCard(
        onTap: () => setState(() => selected = key),
        child: Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: ct(13.5, FontWeight.w700, C2.navy)),
            Text(sub, style: ct(11, FontWeight.w400, C2.text2)),
          ])),
          Icon(selected == key ? Icons.check_circle : Icons.chevron_right, color: selected == key ? C2.green : C2.text3),
        ]),
      );
}

// ───────────────────────── Profile ─────────────────────────
/// My Profile — everything on this screen comes from the backend session:
/// the bootstrap `user` block (username / full_name / role / facility) and
/// the `facility` block (code, block, district, vehicle). Nothing typed by
/// hand (user bug report 2026-08-13: card showed hardcoded Divya / CNS-01 /
/// MMU-01 regardless of who signed in).
class CounProfile extends StatelessWidget {
  final String name;
  const CounProfile({super.key, required this.name});

  String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final masters = context.watch<MastersStore>();
    final u = masters.user;      // bootstrap user block
    final f = masters.facility;  // bootstrap facility block

    final displayName = ((u?['full_name'] as String?)?.trim().isNotEmpty ?? false)
        ? (u!['full_name'] as String).trim()
        : name;
    final role = _cap((u?['role'] ?? 'counsellor').toString());
    final username = (u?['username'] ?? '').toString();
    final facilityName = (f?['name'] ?? u?['facility_name'] ?? '—').toString();
    final facilityCode = (f?['code'] ?? u?['facility_code'] ?? '').toString();
    final blockName    = (f?['block_name'] ?? '').toString();
    final districtName = (f?['district_name'] ?? '').toString();
    final vehicleNo    = (f?['vehicle_no'] ?? '').toString();
    final status       = _cap((f?['status'] ?? 'active').toString());
    final location = [
      if (blockName.isNotEmpty) blockName,
      if (districtName.isNotEmpty) districtName,
    ].join(', ');

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
      child: Scaffold(
        backgroundColor: C2.bg,
        appBar: AppBar(
          backgroundColor: C2.white, foregroundColor: C2.navy, elevation: 0,
          shape: const Border(bottom: BorderSide(color: C2.cyan, width: 3)),
          title: Text('My Profile', style: ct(16, FontWeight.w700, C2.navy)),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Header card — full-width gradient banner so the card no
            // longer floats as a narrow strip in the middle of the page.
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(vertical: 22),
              decoration: BoxDecoration(
                gradient: C2.headerGrad,
                borderRadius: BorderRadius.circular(14),
                boxShadow: C2.shadow,
              ),
              child: Column(children: [
                Container(
                  width: 72, height: 72, alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white70, width: 2),
                  ),
                  child: Text(
                    displayName.isEmpty ? 'C' : displayName[0].toUpperCase(),
                    style: ct(28, FontWeight.w700, Colors.white)),
                ),
                const SizedBox(height: 10),
                Text(displayName, style: ct(18, FontWeight.w700, Colors.white)),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(role, style: ct(11.5, FontWeight.w600, Colors.white)),
                ),
              ]),
            ),
            CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SecBar('Details'),
              _kv('Role', role),
              if (username.isNotEmpty) _kv('Username', username),
              _kv('Facility', facilityCode.isEmpty
                  ? facilityName : '$facilityName ($facilityCode)'),
              if (location.isNotEmpty) _kv('Location', location),
              if (vehicleNo.isNotEmpty) _kv('Vehicle No', vehicleNo),
              _kv('Status', status),
            ])),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: () async {
                if (!await confirmLogout(context)) return;
                if (!context.mounted) return;
                // Real logout (was popUntil → just went Home while the
                // session stayed alive). Mirrors the shell menu's logout:
                // stop the GPS sampler, end the server session, clear the
                // local session, land on the login screen with no back
                // stack.
                context.read<LocationService>().stop();
                unawaited(context.read<AuthApi>().logout().catchError((_) {}));
                // Kill FCM so pushes stop coming for the old user
                // (bug 2026-08-20).
                unawaited(FcmService.instance
                    .unregister(context.read<ApiClient>())
                    .catchError((_) {}));
                // Wipe cached patient/requisition/attendance lists so
                // the next user doesn't see this one's data (user rule
                // 2026-08-16). Same lines in every logout site.
                context.read<CounsellorState>().resetForNewUser();
                context.read<AppState>().logout();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const UnifiedLoginScreen()),
                  (route) => false,
                );
              },
              icon: const Icon(Icons.logout, color: C2.danger),
              label: Text('Log out', style: ct(14, FontWeight.w600, C2.danger)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: C2.danger), padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))))),
          ]),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [
        SizedBox(width: 96, child: Text(k, style: ct(12, FontWeight.w400, C2.text2))),
        Expanded(child: Text(v, style: ct(13, FontWeight.w600, C2.text))),
      ]));
}
