import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../api/patients_api.dart';
import '../config/app_config.dart';
import '../counsellor/cstate.dart';
import '../counsellor/cw.dart';
import 'ddata.dart' show displayDosage;

/// Doctor Case Details → "Past Medical History" (user 2026-10-13).
///
/// One card per visit DATE (Dx + Rx + files together, not split into
/// separate Dx / Rx tables). Newest first, 10 shown, "Show more" for
/// the rest. Tapping a date opens everything recorded on that day.
///
/// Source is GET /patients/{id}/history, which already carries every
/// visit's diagnoses, prescription and attachments. Offline (or a
/// patient not yet synced) falls back to what is in memory: the
/// previous-Rx list and this visit's uploads.
class PastMedicalHistoryCard extends StatefulWidget {
  final CPatient patient;
  const PastMedicalHistoryCard({super.key, required this.patient});

  @override
  State<PastMedicalHistoryCard> createState() => _PastMedicalHistoryCardState();
}

/// Everything recorded on one date — usually one visit, occasionally two.
class _DayGroup {
  final String date;
  final List<_Visit> visits;
  _DayGroup(this.date, this.visits);

  int get dxCount => visits.fold(0, (n, v) => n + v.diagnoses.length);
  int get rxCount => visits.fold(0, (n, v) => n + v.rx.length);
  int get fileCount => visits.fold(0, (n, v) => n + v.files.length);
  bool get isCurrent => visits.any((v) => v.isCurrent);
}

class _Visit {
  final int? id;
  final String doctor;
  final String status;
  final bool isCurrent;
  final List<String> diagnoses;
  final List<_RxLine> rx;
  final List<_File> files;
  final String remarks;
  _Visit({this.id, this.doctor = '', this.status = '', this.isCurrent = false,
      this.diagnoses = const [], this.rx = const [], this.files = const [],
      this.remarks = ''});
  bool get isEmpty => diagnoses.isEmpty && rx.isEmpty && files.isEmpty && remarks.isEmpty;
}

class _RxLine {
  final String name, dosage, frequency, duration;
  const _RxLine(this.name, this.dosage, this.frequency, this.duration);
}

class _File {
  final String kind, title;
  final String? url;       // server file
  final String? localPath; // capture still on this phone
  const _File(this.kind, this.title, {this.url, this.localPath});
  bool get isPdf => (url ?? localPath ?? '').toLowerCase().contains('.pdf');
}

class _PastMedicalHistoryCardState extends State<PastMedicalHistoryCard> {
  static const _initialShown = 10;

  bool _loading = false;
  bool _failed = false;
  bool _showAll = false;
  List<_DayGroup> _days = const [];
  /// Patient's own code (NO-13102026-001) — shown instead of the
  /// internal appointment id, which means nothing to the doctor.
  late String _patientCode = p.uniqueCode.trim();

  CPatient get p => widget.patient;

  @override
  void initState() {
    super.initState();
    _days = _fromLocal();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final pid = p.backendPatientId;
    if (pid == null || !mounted) return;
    setState(() { _loading = true; _failed = false; });
    try {
      final res = await context.read<PatientsApi>().history(pid);
      if (!mounted) return;
      final pc = '${(res['patient'] as Map?)?['unique_code'] ?? ''}'.trim();
      if (pc.isNotEmpty) _patientCode = pc;
      final visits = <_Visit>[];
      final dates = <String>[];
      for (final raw in (res['visits'] as List? ?? const [])) {
        if (raw is! Map) continue;
        final v = raw.cast<String, dynamic>();
        final id = (v['appointment_id'] as num?)?.toInt();
        final current = id != null && id == p.backendAppointmentId;
        final visit = _Visit(
          id: id,
          doctor: (v['doctor_name'] ?? '').toString(),
          status: (v['status'] ?? '').toString(),
          isCurrent: current,
          diagnoses: [
            for (final d in (v['diagnoses'] as List? ?? const []))
              if (d is Map && '${d['diagnosis_text'] ?? ''}'.trim().isNotEmpty)
                '${d['diagnosis_text']}'.trim(),
          ],
          rx: [
            for (final r in (v['prescription'] as List? ?? const []))
              if (r is Map)
                _RxLine(
                  '${r['medicine_name'] ?? ''}',
                  '${r['dosage'] ?? ''}',
                  '${r['frequency'] ?? ''}',
                  r['duration_days'] == null ? '' : '${r['duration_days']} days',
                ),
          ],
          files: [
            for (final a in (v['attachments'] as List? ?? const []))
              if (a is Map)
                _File(
                  '${a['kind'] ?? 'Other'}',
                  '${a['description'] ?? ''}'.trim().isNotEmpty
                      ? '${a['description']}'
                      : '${a['file_path'] ?? 'File'}',
                  url: _publicUrl(a['file_url'] as String?, a['file_path'] as String?),
                ),
          ],
          remarks: '${v['doctor_remarks_english'] ?? ''}'.trim().isNotEmpty
              ? '${v['doctor_remarks_english']}'.trim()
              : '${v['doctor_remarks'] ?? ''}'.trim(),
        );
        // Only OLD visits here — the visit being worked on now is not
        // history (user 2026-10-13).
        if (current) continue;
        if (visit.isEmpty) continue;
        visits.add(visit);
        dates.add(_ddmmyyyy((v['appointment_date'] ?? '').toString()));
      }
      setState(() {
        _days = _group(visits, dates);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _failed = true; });
    }
  }

  /// In-memory fallback: previous prescriptions grouped by their date,
  /// plus this visit's uploads.
  List<_DayGroup> _fromLocal() {
    final visits = <_Visit>[];
    final dates = <String>[];
    final byDate = <String, List<PrevRx>>{};
    for (final r in p.previousRx) {
      byDate.putIfAbsent(r.date, () => []).add(r);
    }
    for (final e in byDate.entries) {
      visits.add(_Visit(rx: [
        for (final r in e.value)
          _RxLine(r.medicine, r.dosage, r.frequency, r.duration),
      ]));
      dates.add(e.key);
    }
    return _group(visits, dates);
  }

  List<_DayGroup> _group(List<_Visit> visits, List<String> dates) {
    final order = <String>[];
    final map = <String, List<_Visit>>{};
    for (var i = 0; i < visits.length; i++) {
      final d = dates[i].isEmpty ? '—' : dates[i];
      if (!map.containsKey(d)) order.add(d);
      map.putIfAbsent(d, () => []).add(visits[i]);
    }
    return [for (final d in order) _DayGroup(d, map[d]!)];
  }

  @override
  Widget build(BuildContext context) {
    final shown = _showAll ? _days : _days.take(_initialShown).toList();
    return CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(child: SecBar('Past Medical History and Prescription')),
        if (_loading)
          const SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2)),
      ]),
      if (p.pastHistory.trim().isNotEmpty) ...[
        Text(p.pastHistory.trim(), style: ct(12, FontWeight.w400, C2.text2)),
        const SizedBox(height: 8),
      ],
      if (_days.isEmpty && !_loading)
        Padding(padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(_failed ? 'Could not load history.' : 'No past records on file.',
              style: ct(12, FontWeight.w400, C2.text2))),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final d in shown) _dateTile(d),
      ]),
      if (_days.length > _initialShown)
        Padding(padding: const EdgeInsets.only(top: 6),
          child: TextButton(
            onPressed: () => setState(() => _showAll = !_showAll),
            child: Text(_showAll ? 'Show less' : 'Show more (${_days.length - _initialShown})',
                style: ct(12.5, FontWeight.w700, C2.navy)),
          )),
      if (_failed)
        TextButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh, size: 16),
          label: Text('Retry', style: ct(12, FontWeight.w600, C2.navy)),
        ),
    ]));
  }

  Widget _dateTile(_DayGroup d) {
    final parts = [
      if (d.dxCount > 0) '${d.dxCount} Dx',
      if (d.rxCount > 0) '${d.rxCount} Rx',
      if (d.fileCount > 0) '${d.fileCount} file${d.fileCount == 1 ? '' : 's'}',
    ];
    return InkWell(
      onTap: () => _openDay(d),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minWidth: 110),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C2.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(d.date, style: ct(13, FontWeight.w700, C2.navy)),
            if (d.isCurrent) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: C2.cyanLight, borderRadius: BorderRadius.circular(8)),
                child: Text('This visit', style: ct(9.5, FontWeight.w700, C2.navy)),
              ),
            ],
          ]),
          const SizedBox(height: 2),
          Text(parts.isEmpty ? 'No details' : parts.join(' · '),
              style: ct(11, FontWeight.w500, C2.text2)),
        ]),
      ),
    );
  }

  void _openDay(_DayGroup d) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 8, 4),
              child: Row(children: [
                const Icon(Icons.history, color: C2.navy, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(d.date, style: ct(17, FontWeight.w800, C2.navy))),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ]),
            ),
            const Divider(height: 1),
            Flexible(child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              children: [
                for (var i = 0; i < d.visits.length; i++) ...[
                  if (i > 0) const Divider(height: 28),
                  _visitBody(d.visits[i]),
                ],
              ],
            )),
          ]),
        ),
      ),
    );
  }

  Widget _visitBody(_Visit v) {
    final meta = [
      if (_patientCode.isNotEmpty) _patientCode,
      if (v.doctor.isNotEmpty) 'Dr. ${v.doctor}',
      // LAMA is not shown in history (user 2026-10-14).
      if (v.status.isNotEmpty && v.status != 'lama') _statusLabel(v.status),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (meta.isNotEmpty) ...[
        Text(meta.join(' · '), style: ct(12, FontWeight.w600, C2.text2)),
        const SizedBox(height: 12),
      ],
      _label('Dx · Diagnosis'),
      Text(v.diagnoses.isEmpty ? 'Not recorded' : v.diagnoses.join(', '),
          style: ct(13.5, FontWeight.w600, v.diagnoses.isEmpty ? C2.text3 : C2.text)),
      const SizedBox(height: 14),
      _label('Rx · Medicines'),
      if (v.rx.isEmpty)
        Text('No medicines prescribed.', style: ct(13.5, FontWeight.w600, C2.text3))
      else
        for (final r in v.rx)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(padding: EdgeInsets.only(top: 5),
                  child: Icon(Icons.circle, size: 6, color: C2.navy)),
              const SizedBox(width: 8),
              Expanded(child: Text.rich(TextSpan(children: [
                TextSpan(text: r.name, style: ct(13.5, FontWeight.w700, C2.text)),
                TextSpan(
                  text: [
                    if (r.dosage.isNotEmpty) displayDosage(r.dosage),
                    if (r.frequency.isNotEmpty) r.frequency,
                    if (r.duration.isNotEmpty) r.duration,
                  ].map((s) => '  ·  $s').join(),
                  style: ct(12, FontWeight.w500, C2.text2),
                ),
              ]))),
            ]),
          ),
      if (v.remarks.isNotEmpty) ...[
        const SizedBox(height: 14),
        _label('Doctor Remarks'),
        Text(v.remarks, style: ct(13, FontWeight.w500, C2.text)),
      ],
      const SizedBox(height: 14),
      _label('Reports & files'),
      if (v.files.isEmpty)
        Text('No files.', style: ct(13, FontWeight.w500, C2.text3))
      else
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final f in v.files) _fileTile(f),
        ]),
    ]);
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(t, style: ct(11.5, FontWeight.w600, C2.text2)),
      );

  Widget _fileTile(_File f) {
    final isRx = f.kind.toLowerCase().startsWith('presc');
    final tint = isRx ? const Color(0xFFE7F3DC) : C2.cyanLight;
    final tag = isRx ? C2.green : C2.cyan;
    final canOpen = f.url != null || (f.localPath != null && File(f.localPath!).existsSync());
    return InkWell(
      onTap: canOpen ? () => _openFile(f) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C2.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            height: 70,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Stack(children: [
              Positioned(left: 6, top: 6, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: tag, borderRadius: BorderRadius.circular(5)),
                child: Text(f.kind, style: ct(10, FontWeight.w700, Colors.white)),
              )),
              Center(child: Icon(
                  f.isPdf ? Icons.picture_as_pdf_outlined
                      : (isRx ? Icons.medication_outlined : Icons.description_outlined),
                  size: 26, color: C2.navy)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(f.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: ct(11.5, FontWeight.w600, canOpen ? C2.text : C2.text3)),
          ),
        ]),
      ),
    );
  }

  Future<void> _openFile(_File f) async {
    if (f.isPdf) {
      Uint8List? bytes;
      try {
        if (f.url != null) {
          final res = await http.get(Uri.parse(f.url!));
          if (res.statusCode == 200) bytes = res.bodyBytes;
        } else if (f.localPath != null) {
          bytes = await File(f.localPath!).readAsBytes();
        }
      } catch (_) {/* shown below */}
      if (!mounted) return;
      if (bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not open this file.'), backgroundColor: C2.danger));
        return;
      }
      final data = bytes;
      Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
        appBar: AppBar(title: Text(f.title, overflow: TextOverflow.ellipsis)),
        body: PdfPreview(
          build: (_) async => data,
          canChangePageFormat: false,
          canChangeOrientation: false,
          canDebug: false,
        ),
      )));
      return;
    }
    showDialog(context: context, builder: (ctx) => Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(8),
      child: Stack(children: [
        InteractiveViewer(
          maxScale: 5,
          child: f.url != null
              ? Image.network(f.url!, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(40),
                      child: Text('Could not load image', style: TextStyle(color: Colors.white))))
              : Image.file(File(f.localPath!), fit: BoxFit.contain),
        ),
        Positioned(top: 4, right: 4, child: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(ctx).pop(),
        )),
      ]),
    ));
  }

  /// The server builds `file_url` from the host Django sees behind the
  /// proxy (an internal LAN address like 192.168.x.x), which a phone can
  /// never reach. Keep only the path under /media/ and serve it from the
  /// public uploads base — same rule the counsellor screen uses.
  static String? _publicUrl(String? fileUrl, String? filePath) {
    final u = (fileUrl ?? '').trim();
    final ix = u.indexOf('/media/');
    if (ix >= 0) return '${AppConfig.uploadsBase}/${u.substring(ix + 7)}';
    final f = (filePath ?? '').trim();
    if (f.isEmpty) return u.isEmpty ? null : u;
    return '${AppConfig.uploadsBase}/${f.contains('/') ? f : 'patient_docs/$f'}';
  }

  /// "2026-09-29" → "29-09-2026"; anything else is shown as given.
  static String _ddmmyyyy(String s) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
    return m == null ? s : '${m[3]}-${m[2]}-${m[1]}';
  }

  static String _statusLabel(String s) => switch (s) {
        'completed' => 'Completed',
        'with_pharma' || 'with_pharmacist' => 'At Pharmacist',
        'with_doctor' => 'With Doctor',
        'with_lab' => 'At Lab',
        'with_counsellor' => 'Payment Due',
        'lama' => 'LAMA',
        'cancelled' => 'Cancelled',
        'registered' => 'Registered',
        _ => s,
      };
}
