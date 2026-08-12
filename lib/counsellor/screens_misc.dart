import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'cw.dart';
import 'cdata.dart';
import 'cstate.dart';
import '../api/sync_service.dart';
import '../doctor/voice.dart';
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
  const CounAttendance({super.key});
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
  bool _driverIn = false, _doctorIn = false, _pharmacistIn = false;
  bool _driverOut = false, _doctorOut = false, _pharmacistOut = false;
  final _collection = TextEditingController();
  final _startKm = TextEditingController(); // used only on first-ever login
  final _endKm = TextEditingController();
  final _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    _date = fmtDate(DateTime.now());
  }

  @override
  void dispose() {
    _collection.dispose(); _startKm.dispose(); _endKm.dispose(); _notes.dispose();
    super.dispose();
  }

  String _fmtTime(TimeOfDay t) => fmtTime12(t);

  // Rough GPS anchors for the three camp locations (rule 2026-07-31). Used
  // to auto-pick the nearest camp on Mark Check-in. If a real camps master
  // ships later, swap these for its coords.
  static const _kCampCoords = <String, ({double lat, double lng})>{
    'Gajraula Camp': (lat: 28.845, lng: 78.240),
    'Amroha Camp':   (lat: 28.910, lng: 78.470),
    'Hasanpur Camp': (lat: 28.719, lng: 78.302),
  };

  /// Auto-populate the Check-in form (rule 2026-07-31): fill Check-in Time
  /// with the current time and pick the nearest camp from GPS. Runs when
  /// the counsellor taps "Mark Check-in" — safe to call more than once as
  /// it no-ops when the values are already set.
  /// Mark Check-out counterpart of _autofillCheckInFields (rule 2026-07-31).
  /// Pre-fills the current time and mirrors the "Staff Checking Out"
  /// checkboxes from whoever the counsellor marked present at check-in —
  /// the common case at end of shift.
  void _autofillCheckOutFields(AttendanceRecord open) {
    final now = TimeOfDay.now();
    setState(() {
      _checkOut = _fmtTime(now);
      _driverOut     = open.driverIn;
      _doctorOut     = open.doctorIn;
      _pharmacistOut = open.pharmacistIn;
    });
  }

  Future<void> _autofillCheckInFields() async {
    final now = TimeOfDay.now();
    // Always refresh — every tap on Mark Check-in sets it to "right now".
    setState(() {
      _checkIn = _fmtTime(now);
    });
    if (location != null) return;
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      String? nearest;
      double best = double.infinity;
      for (final e in _kCampCoords.entries) {
        final d = Geolocator.distanceBetween(pos.latitude, pos.longitude, e.value.lat, e.value.lng);
        if (d < best) { best = d; nearest = e.key; }
      }
      if (nearest != null && mounted) {
        setState(() => location = nearest);
      }
    } catch (_) {
      // GPS failed — counsellor can still pick manually.
    }
  }

  // Starting km for the shift the counsellor is about to record:
  //  - if a shift is already open, its recorded starting km is authoritative;
  //  - otherwise use the previous shift's ending km (fleet continuity);
  //  - if this is the first-ever login, use whatever the counsellor typed.
  String _startValue(CounsellorState s) {
    final open = s.openShift;
    if (open != null) return open.startKm;
    if (s.lastEndingKm.isNotEmpty) return s.lastEndingKm;
    return _startKm.text.trim();
  }

  String _totalRun(CounsellorState s) {
    final start = int.tryParse(_startValue(s));
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
      _driverIn = false; _doctorIn = false; _pharmacistIn = false;
      _driverOut = false; _doctorOut = false; _pharmacistOut = false;
      _collection.clear(); _startKm.clear(); _endKm.clear(); _notes.clear();
      _date = fmtDate(DateTime.now()); location = null;
    });
  }

  void _submitCheckIn(CounsellorState s) {
    void err(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: C2.danger));
    if (_checkIn.isEmpty) return err('Enter check-in time');
    if (location == null) return err('Select location');
    final start = _startValue(s);
    if (start.isEmpty) return err('Enter MMU starting (Km)');
    // Staff crew — at least one of Driver / Doctor / Pharmacist must be
    // marked present so the record is meaningful (rule 2026-07-29).
    if (!(_driverIn || _doctorIn || _pharmacistIn)) {
      return err('Tick at least one staff member present');
    }
    if (_photoPath == null) return err('Take a selfie to mark check-in');
    s.startShift(AttendanceRecord(
      date: _date, checkIn: _checkIn, checkOut: '',
      location: location!, status: 'Present', photo: true,
      startKm: start,
      photoPath: _photoPath!, lat: _lat, lng: _lng,
      driverIn: _driverIn, doctorIn: _doctorIn, pharmacistIn: _pharmacistIn,
    ));
    // Enqueue attendance.check_in for /mobile/sync/push (v2 §4).
    context.read<SyncService>().enqueue(kind: 'attendance.check_in', payload: {
      'attendance_date': _date,
      'check_in':        _checkIn,
      'location':        location!,
      'start_km':        int.tryParse(start) ?? 0,
      'latitude':        _lat,
      'longitude':       _lng,
      'notes':           '',
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Check-in recorded — tap Mark Check-out at end of day'), backgroundColor: C2.green));
    _resetForm();
  }

  void _submitCheckOut(CounsellorState s) {
    void err(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: C2.danger));
    if (_checkOut.isEmpty) return err('Enter check-out time');
    if (_endKm.text.trim().isEmpty) return err('Enter MMU ending (Km)');
    final run = _totalRun(s);
    if (run.isEmpty) return err('MMU ending must be greater than starting');
    if (_collection.text.trim().isEmpty) return err('Enter total collection');
    // Staff crew — same requirement at end of shift so we know who actually
    // stayed the day (rule 2026-07-29).
    if (!(_driverOut || _doctorOut || _pharmacistOut)) {
      return err('Tick at least one staff member checking out');
    }
    if (_photoPathOut == null) return err('Take a selfie to mark check-out');
    s.endShift(
      checkOut: _checkOut,
      endKm: _endKm.text.trim(),
      totalRun: run,
      collection: _collection.text.trim(),
      notes: _notes.text.trim(),
      photoPathOut: _photoPathOut!,
      latOut: _latOut, lngOut: _lngOut,
      driverOut: _driverOut, doctorOut: _doctorOut, pharmacistOut: _pharmacistOut,
    );
    context.read<SyncService>().enqueue(kind: 'attendance.check_out', payload: {
      'attendance_date': _date,
      'check_out':       _checkOut,
      'end_km':          int.tryParse(_endKm.text.trim()) ?? 0,
      'collection':      num.tryParse(_collection.text.trim()) ?? 0,
      'latitude':        _latOut,
      'longitude':       _lngOut,
      'notes':           _notes.text.trim(),
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Check-out recorded, shift closed'), backgroundColor: C2.green));
    _resetForm();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<CounsellorState>();
    final open = s.openShift;
    // "Past attendance" only lists completed shifts. An in-flight shift shows
    // up as its own banner so the counsellor can spot it and close it out.
    final past = s.attendanceRecords.where((r) => !r.isOpen).toList();

    final actionLabel = open == null ? 'Mark Check-in' : 'Mark Check-out';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.only(bottom: 8), child: SecBar('My Attendance',
        trailing: COutlineButton(showForm ? 'Close' : actionLabel,
          icon: showForm ? Icons.close : (open == null ? Icons.login : Icons.logout),
          onTap: () {
            final opening = !showForm;
            setState(() => showForm = opening);
            // On Mark Check-in (open == null and we're opening the form),
            // pre-fill time + nearest camp from GPS. Kicked off after the
            // frame so the form is already mounted when values arrive.
            if (opening && open == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _autofillCheckInFields();
              });
            }
            // On Mark Check-out (an open shift exists and we're opening
            // the form), pre-fill the current time + mirror the staff who
            // were marked at check-in (rule 2026-07-31).
            if (opening && open != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _autofillCheckOutFields(open);
              });
            }
          }))),

      // Open-shift banner — visible whenever a check-in is on file without a
      // check-out. Shown outside the form so the counsellor sees it in the
      // default (list) view too.
      if (open != null && !showForm)
        CCard(child: Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFFFEF7E0), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.pending_actions, color: C2.yellow)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Shift open since ${open.checkIn}', style: ct(13.5, FontWeight.w700, C2.navy)),
            Text('${open.date} · ${open.location} · Start ${open.startKm} km', style: ct(11.5, FontWeight.w400, C2.text2)),
            Text('Tap Mark Check-out at end of day.', style: ct(11.5, FontWeight.w600, Color(0xFFB8860B))),
          ])),
        ])),

      if (showForm)
        CCard(child: open == null ? _checkInForm(s) : _checkOutForm(s, open)),

      if (!showForm) ...[
        if (past.isEmpty)
          CCard(child: Padding(padding: const EdgeInsets.all(12), child: Center(child: Text('No attendance marked yet', style: ct(12, FontWeight.w400, C2.text2)))))
        else
          ...past.map((r) => CCard(
            onTap: () => _showDetail(r),
            child: Row(children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: C2.cyanLight, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.event_available, color: C2.cyan)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.date, style: ct(13.5, FontWeight.w700, C2.text)),
                Text('${r.checkIn} – ${r.checkOut} · ${r.location}', style: ct(11.5, FontWeight.w400, C2.text2)),
              ])),
              const CBadge('Present', bg: Color(0xFFEDF7E0), fg: C2.green),
            ]))),
      ],
    ]);
  }

  /// Morning "Check-in" form: date, check-in time, location, MMU starting km,
  /// selfie + GPS. On submit we store an open AttendanceRecord.
  Widget _checkInForm(CounsellorState s) {
    final lastEnd = s.lastEndingKm;
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
      // MMU for the day. At least one must be ticked before submit.
      CField('Staff Present (Check-in)', _staffChecklist(
        driver: _driverIn, doctor: _doctorIn, pharma: _pharmacistIn,
        onDriver: (v) => setState(() => _driverIn = v),
        onDoctor: (v) => setState(() => _doctorIn = v),
        onPharma: (v) => setState(() => _pharmacistIn = v),
      ), required: true),
      CField('Selfie + Location', AttendanceCapture(
        initialPhotoPath: _photoPath, initialLat: _lat, initialLng: _lng,
        onCaptured: (path, lat, lng) => setState(() { _photoPath = path; _lat = lat; _lng = lng; }),
      ), required: true),
      const SizedBox(height: 4),
      CPrimaryButton('Submit Check-in', icon: Icons.login, onTap: () => _submitCheckIn(s)),
    ]);
  }

  /// Three checkboxes for Driver / Doctor / Pharmacist attendance. Used on
  /// both the Check-in and Check-out forms so the counsellor confirms who
  /// was actually there.
  Widget _staffChecklist({
    required bool driver, required bool doctor, required bool pharma,
    required ValueChanged<bool> onDriver,
    required ValueChanged<bool> onDoctor,
    required ValueChanged<bool> onPharma,
  }) {
    Widget cell(String label, bool val, ValueChanged<bool> onCh) => Expanded(
      child: InkWell(
        onTap: () => onCh(!val),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 24, height: 24,
              child: Checkbox(
                value: val,
                onChanged: (v) => onCh(v ?? false),
                activeColor: C2.cyan,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(child: Text(label, style: ct(13.5, FontWeight.w600, C2.text), overflow: TextOverflow.ellipsis)),
          ]),
        ),
      ),
    );
    return Row(children: [
      cell('Driver', driver, onDriver),
      cell('Doctor', doctor, onDoctor),
      cell('Pharmacist', pharma, onPharma),
    ]);
  }

  /// End-of-day "Check-out" form: shows the open shift context (read-only),
  /// then check-out time, MMU ending km, auto total run, collection, notes.
  Widget _checkOutForm(CounsellorState s, AttendanceRecord open) {
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
        child: Text(_totalRun(s).isEmpty ? 'Auto-calculated' : _totalRun(s),
          style: ct(13.5, _totalRun(s).isEmpty ? FontWeight.w400 : FontWeight.w700,
            _totalRun(s).isEmpty ? C2.text3 : C2.navy))), required: true),
      CField('Total Collection (₹)', TextField(controller: _collection, keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
        decoration: cInput('Up to 5 digits')), required: true),
      // Staff crew checking out — same requirement as check-in: at least one
      // must be ticked so the audit trail closes cleanly.
      CField('Staff Checking Out', _staffChecklist(
        driver: _driverOut, doctor: _doctorOut, pharma: _pharmacistOut,
        onDriver: (v) => setState(() => _driverOut = v),
        onDoctor: (v) => setState(() => _doctorOut = v),
        onPharma: (v) => setState(() => _pharmacistOut = v),
      ), required: true),
      CField('Notes', TextField(controller: _notes, minLines: 2, maxLines: 3,
        decoration: cInput('Optional — type or use the mic').copyWith(suffixIcon: VoiceMicButton(controller: _notes)))),
      CField('Selfie + Location', AttendanceCapture(
        initialPhotoPath: _photoPathOut, initialLat: _latOut, initialLng: _lngOut,
        onCaptured: (path, lat, lng) => setState(() { _photoPathOut = path; _latOut = lat; _lngOut = lng; }),
      ), required: true),
      const SizedBox(height: 4),
      CPrimaryButton('Submit Check-out', icon: Icons.logout, onTap: () => _submitCheckOut(s)),
    ]);
  }

  void _showDetail(AttendanceRecord r) => showModalBottomSheet(
        context: context, backgroundColor: Colors.transparent,
        builder: (_) => Container(
          decoration: const BoxDecoration(color: C2.white, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: C2.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14),
            Text('Attendance — ${r.date}', style: ct(15, FontWeight.w700, C2.navy)),
            const SizedBox(height: 10),
            _row('Date', r.date), _row('Check-in', r.checkIn), _row('Check-out', r.checkOut),
            _row('Location', r.location),
            _row('Staff (In)', _staffSummary(r.driverIn, r.doctorIn, r.pharmacistIn)),
            _row('Staff (Out)', _staffSummary(r.driverOut, r.doctorOut, r.pharmacistOut)),
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
              ClipRRect(borderRadius: BorderRadius.circular(8),
                child: Image.file(File(r.photoPath), height: 160, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(height: 80, color: C2.border,
                    child: const Center(child: Icon(Icons.broken_image_outlined, color: C2.text3))))),
            ] else
              _row('Check-in photo', r.photo ? 'Captured' : 'Not captured'),
            if (r.photoPathOut.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Check-out photo', style: ct(11, FontWeight.w600, C2.text2)),
              const SizedBox(height: 4),
              ClipRRect(borderRadius: BorderRadius.circular(8),
                child: Image.file(File(r.photoPathOut), height: 160, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(height: 80, color: C2.border,
                    child: const Center(child: Icon(Icons.broken_image_outlined, color: C2.text3))))),
            ],
          ])),
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
  const CounCamps({super.key});
  @override
  State<CounCamps> createState() => _CounCampsState();
}

class _CounCampsState extends State<CounCamps> {
  bool showForm = false;
  String? village, type;
  final _name = TextEditingController();
  final _venue = TextEditingController();
  String _campDate = '';

  @override
  Widget build(BuildContext context) {
    final s = context.watch<CounsellorState>();
    final villages = [for (final v in kBlockVillages.values) ...v];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.only(bottom: 8), child: SecBar('Camp Activities', trailing: COutlineButton(showForm ? 'Close' : 'Add New', icon: showForm ? Icons.close : Icons.add, onTap: () => setState(() => showForm = !showForm)))),
      if (showForm)
        CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SecBar('New Camp Activity'),
          CField('Village', _dd(villages, village, (v) => setState(() => village = v), hint: 'Select Village'), required: true),
          CField('Camp Type', _dd(kCampTypes, type, (v) => setState(() => type = v), hint: 'Select Type'), required: true),
          CField('Camp Name', TextField(controller: _name, decoration: cInput('Enter camp name')), required: true),
          CField('Venue', TextField(controller: _venue, decoration: cInput('Enter venue')), required: true),
          CField('Date', DateField(hint: 'Select date', first: DateTime(2025), last: DateTime(2027), onPicked: (d) => _campDate = fmtDate(d)), required: true),
          Row(children: [
            Expanded(child: CPrimaryButton('Save', icon: Icons.check, onTap: () {
              if (village == null || type == null || _name.text.trim().isEmpty || _venue.text.trim().isEmpty || _campDate.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fill all camp fields'), backgroundColor: C2.danger)); return;
              }
              s.addCamp(Camp(village: village!, type: type!, name: _name.text.trim(), venue: _venue.text.trim(), date: _campDate));
              setState(() { showForm = false; village = null; type = null; _name.clear(); _venue.clear(); _campDate = ''; });
            })),
          ]),
        ])),
      if (s.camps.isEmpty && !showForm)
        CCard(child: Padding(padding: const EdgeInsets.all(8), child: Center(child: Text('No camp activities recorded', style: ct(12, FontWeight.w400, C2.text2)))))
      else
        ...s.camps.map((c) => CCard(child: Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: C2.cyanLight, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.location_on, color: C2.cyan)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.name, style: ct(13.5, FontWeight.w700, C2.text)),
            Text('${c.type} · ${c.village} · ${c.date}', style: ct(11.5, FontWeight.w400, C2.text2)),
            Text(c.venue, style: ct(11.5, FontWeight.w400, C2.text2)),
          ])),
        ]))),
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
  const CounDevices({super.key});
  @override
  State<CounDevices> createState() => _CounDevicesState();
}

class _CounDevicesState extends State<CounDevices> {
  // Month-wise Status Date (rule 2026-07-31). Kept as a DateTime pointing
  // to the 1st of the chosen month so downstream ISO lookups still work.
  DateTime _date = DateTime(DateTime.now().year, DateTime.now().month, 1);
  final Map<String, String> _statuses = {};

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static const _kMonthShort = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  String _fmtMonthLabel(DateTime d) => '${_kMonthShort[d.month - 1]} ${d.year}';

  /// Lightweight month picker (rule 2026-07-31). Uses a bottom-sheet with
  /// year navigation and a 3x4 month grid — clamped so the counsellor can
  /// only record for months up to and including the current one.
  Future<DateTime?> _pickMonth(DateTime initial) async {
    var year = initial.year;
    final firstAllowed = DateTime(2020, 1, 1);
    final lastAllowed  = DateTime(DateTime.now().year, DateTime.now().month, 1);
    return showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSB) {
          bool inRange(DateTime m) => !m.isBefore(firstAllowed) && !m.isAfter(lastAllowed);
          return Container(
            decoration: const BoxDecoration(
              color: C2.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
            child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: C2.border, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 10),
              // Year navigator.
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: C2.navy),
                  onPressed: year > firstAllowed.year ? () => setSB(() => year--) : null,
                ),
                const SizedBox(width: 8),
                Text('$year', style: ct(16, FontWeight.w800, C2.navy)),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: C2.navy),
                  onPressed: year < lastAllowed.year ? () => setSB(() => year++) : null,
                ),
              ]),
              const SizedBox(height: 6),
              // 3x4 month grid.
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.9,
                children: List.generate(12, (i) {
                  final m = DateTime(year, i + 1, 1);
                  final enabled = inRange(m);
                  final selected = m.year == initial.year && m.month == initial.month;
                  return InkWell(
                    onTap: enabled ? () => Navigator.of(ctx).pop(m) : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? C2.cyan : (enabled ? C2.white : C2.bg),
                        border: Border.all(color: selected ? C2.cyan : C2.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_kMonthShort[i],
                          style: ct(13, FontWeight.w700,
                              selected ? Colors.white : (enabled ? C2.text : C2.text3))),
                    ),
                  );
                }),
              ),
            ])),
          );
        });
      },
    );
  }

  void _refreshStatusesFor(DateTime date, CounsellorState s) {
    for (final d in kDeviceNames) {
      _statuses[d] = s.getDeviceStatusOn(d, _iso(date));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<CounsellorState>();
    if (_statuses.isEmpty) _refreshStatusesFor(_date, s);

    Color dc(String st) => st == 'Working' ? C2.green : (st == 'Not Working' ? C2.danger : C2.text2);
    String legend(String st) => st == 'Working' ? 'W' : st == 'Not Working' ? 'NW' : st == 'Not Applicable' ? 'NA' : st == 'Purchase Requested' ? 'PR' : '-';

    final submissions = s.getDeviceSubmissions();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.only(bottom: 8), child: SecBar('Health Devices')),

      // ── Submission form ──
      CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SecBar('Record Device Status'),
        Padding(padding: const EdgeInsets.only(bottom: 8),
          child: Text('Pick the month this status applies to, set each device, then Submit.',
            style: ct(11.5, FontWeight.w400, C2.text2))),

        CField('Status Date',
          InkWell(
            onTap: () async {
              final picked = await _pickMonth(_date);
              if (picked != null) setState(() { _date = picked; _refreshStatusesFor(picked, s); });
            },
            child: InputDecorator(
              decoration: cInput().copyWith(
                suffixIcon: const Icon(Icons.calendar_today, size: 16, color: C2.cyan),
              ),
              child: Text(_fmtMonthLabel(_date),
                  style: ct(13.5, FontWeight.w600, C2.text)),
            ),
          ),
          required: true,
        ),

        ...kDeviceNames.map((d) => CField(d, Row(children: [
          Icon(Icons.circle, size: 10, color: dc(_statuses[d] ?? 'Working')),
          const SizedBox(width: 8),
          Expanded(child: _dd(kDeviceStates, _statuses[d], (v) => setState(() { _statuses[d] = v!; }))),
        ]))),

        const SizedBox(height: 8),
        CPrimaryButton('Submit', icon: Icons.check_circle_outline, onTap: () {
          s.submitDeviceStatusReport(_iso(_date), Map<String, String>.from(_statuses));
          // Enqueue one device.status action per device — the server
          // accepts them independently so a rejected row doesn't lose
          // the rest. Server requires device_id (from /api/masters/devices),
          // not device_name; use the stable master ids seeded in the DB.
          const kDeviceIdByName = {
            'SPHYGMOMANOMETER':   1,
            'GLUCOMETER':         2,
            'HAEMOGLOBINOMETER':  3,
            'WEIGHING MACHINE':   4,
          };
          final sync = context.read<SyncService>();
          for (final e in _statuses.entries) {
            final id = kDeviceIdByName[e.key.toUpperCase()];
            if (id == null) continue;  // unknown device — skip rather than push a broken row
            sync.enqueue(kind: 'device.status', payload: {
              'device_id':   id,
              'status':      e.value,
              'status_date': _iso(_date),
            });
          }
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Device status saved for ${_fmtMonthLabel(_date)}'),
            backgroundColor: C2.green,
          ));
        }),
      ])),

      // ── Past submissions ──
      Padding(padding: const EdgeInsets.only(top: 4),
        child: CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SecBar('Past Device Status Submissions'),
          if (submissions.isEmpty)
            Padding(padding: const EdgeInsets.all(8),
              child: Center(child: Text('No submissions yet. Use the form above.',
                style: ct(12, FontWeight.w400, C2.text2)))),
          if (submissions.isNotEmpty)
            // Wide tables overflow the narrow phone width when device names
            // are long (Sphygmomanometer / Haemoglobinometer). Scroll
            // horizontally so the counsellor can see every column.
            Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 8),
                child: Table(
                  border: TableBorder.all(color: C2.border, width: 0.5),
                  defaultColumnWidth: const IntrinsicColumnWidth(),
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(color: C2.bg),
                      children: [
                        Padding(padding: const EdgeInsets.all(6), child: Text('Date', style: ct(11, FontWeight.w700, C2.navy))),
                        ...kDeviceNames.map((d) => Padding(
                          padding: const EdgeInsets.all(6),
                          child: Text(d, style: ct(10.5, FontWeight.w700, C2.navy), textAlign: TextAlign.center))),
                      ],
                    ),
                    ...submissions.map((sub) => TableRow(children: [
                      Padding(padding: const EdgeInsets.all(6), child: Text(sub.date, style: ct(11, FontWeight.w500, C2.text))),
                      ...kDeviceNames.map((d) {
                        final v = sub.statuses[d];
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
        ]))),
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
        'Working' => 'W', 'Not Working' => 'NW', 'Not Applicable' => 'NA', 'Purchase Requested' => 'PR', _ => '-' };
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
        pw.Text('Legend:  W = Working,  NW = Not Working,  NA = Not Applicable,  PR = Purchase Requested', style: const pw.TextStyle(fontSize: 9)),
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
class CounProfile extends StatelessWidget {
  final String name;
  const CounProfile({super.key, required this.name});
  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
      child: Scaffold(
        backgroundColor: C2.bg,
        appBar: AppBar(
          backgroundColor: C2.white, foregroundColor: C2.navy, elevation: 0,
          shape: const Border(bottom: BorderSide(color: C2.cyan, width: 3)),
          title: Text('My Profile', style: ct(16, FontWeight.w700, C2.navy)),
        ),
        body: SingleChildScrollView(padding: const EdgeInsets.all(14), child: Column(children: [
          CCard(child: Column(children: [
            Container(width: 64, height: 64, alignment: Alignment.center, decoration: const BoxDecoration(gradient: C2.headerGrad, shape: BoxShape.circle),
              child: Text(name.isEmpty ? 'C' : name[0].toUpperCase(), style: ct(26, FontWeight.w700, Colors.white))),
            const SizedBox(height: 10),
            Text(name, style: ct(17, FontWeight.w700, C2.text)),
            Text('Counsellor', style: ct(12.5, FontWeight.w400, C2.text2)),
          ])),
          CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SecBar('Details'),
            _kv('Role', 'Counsellor'),
            _kv('Staff Code', 'CNS-01'),
            _kv('Phone', '9097513232'),
            _kv('Facility', 'MMU-01 · Gajraula Block, Amroha'),
            _kv('Status', 'Active'),
          ])),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            icon: const Icon(Icons.logout, color: C2.danger),
            label: Text('Log out', style: ct(14, FontWeight.w600, C2.danger)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: C2.danger), padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))))),
        ])),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [
        SizedBox(width: 96, child: Text(k, style: ct(12, FontWeight.w400, C2.text2))),
        Expanded(child: Text(v, style: ct(13, FontWeight.w600, C2.text))),
      ]));
}
