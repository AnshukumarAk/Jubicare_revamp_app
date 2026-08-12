import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../api/api_errors.dart';
import '../api/queues_api.dart';
import '../api/sync_service.dart';
import '../counsellor/cw.dart';
import '../counsellor/cstate.dart';
import '../counsellor/screens_dashboard.dart' show CounPatientDetail, CounPatientsList;
import '../doctor/dshell.dart' show DocHeader, DocBottomNav;
import '../doctor/ddata.dart' show kMedicineNames;
import '../doctor/voice.dart';
import '../widgets/attendance_capture.dart';

class PharmacistShell extends StatefulWidget {
  final String userName;
  const PharmacistShell({super.key, this.userName = 'J.P. Singh'});
  @override
  State<PharmacistShell> createState() => _PharmacistShellState();
}

class _PharmacistShellState extends State<PharmacistShell> {
  int _tab = 0;
  static const _nav = [
    (Icons.grid_view_rounded, 'Home'),
    (Icons.inventory_2_outlined, 'Stock'),
    // Report tab removed 2026-07-29 per user rule.
    (Icons.event_available_outlined, 'Attend'),
  ];
  void _go(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    final initials = widget.userName.isEmpty ? 'P' : widget.userName[0].toUpperCase();
    final pages = [
      PharmaDashboard(name: widget.userName),
      const PharmaStock(),
      // PharmaReport removed 2026-07-29 per user rule.
      const PharmaAttendance(),
    ];
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
      child: Scaffold(
        backgroundColor: C2.bg,
        body: Column(children: [
          DocHeader(initials: initials, userName: widget.userName, role: 'Pharmacist'),
          Expanded(child: IndexedStack(index: _tab, children: pages.map((p) =>
            SingleChildScrollView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 24), child: p)).toList())),
        ]),
        bottomNavigationBar: DocBottomNav(items: _nav, current: _tab, onTap: _go),
      ),
    );
  }
}

// ───────────────── Dashboard ─────────────────
class PharmaDashboard extends StatefulWidget {
  final String name;
  const PharmaDashboard({super.key, required this.name});
  @override
  State<PharmaDashboard> createState() => _PharmaDashboardState();
}

class _PharmaDashboardState extends State<PharmaDashboard> {
  bool _refreshing = false;
  String? _lastError;
  SyncService? _sync;
  int _lastDrainSig = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshFromBackend());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = context.read<SyncService>();
    if (!identical(_sync, s)) {
      _sync?.removeListener(_onSyncTick);
      _sync = s..addListener(_onSyncTick);
    }
  }

  @override
  void dispose() {
    _sync?.removeListener(_onSyncTick);
    super.dispose();
  }

  void _onSyncTick() {
    final sig = (_sync?.lastApplied ?? 0) * 100000 + (_sync?.lastRejected ?? 0) * 100 + (_sync?.lastFailed ?? 0);
    if (sig != _lastDrainSig && (_sync?.lastDrainAt != null)) {
      _lastDrainSig = sig;
      _refreshFromBackend();
    }
  }

  Future<void> _refreshFromBackend() async {
    if (_refreshing || !mounted) return;
    setState(() { _refreshing = true; _lastError = null; });
    try {
      final api = context.read<QueuesApi>();
      final queue = await api.pharmaQueue(limit: 200);
      if (!mounted) return;
      final store = context.read<CounsellorState>();
      // Merge with status forced to 'with_pharma' so rows land in
      // pharmaQueue regardless of what the server label happens to be.
      store.mergeBackendPatients(queue.items, statusOverride: 'with_pharma');
    } on ApiException catch (e) {
      if (mounted) setState(() => _lastError = e.message);
    } catch (e) {
      if (mounted) setState(() => _lastError = e.toString());
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<CounsellorState>();
    final name = widget.name;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GradGreeting(name: name, sub: 'Pharmacy Dashboard', initials: name.isEmpty ? 'P' : name[0].toUpperCase()),
      if (_refreshing) const SizedBox(height: 2, child: LinearProgressIndicator(minHeight: 2)),
      if (!_refreshing && _lastError != null)
        Padding(padding: const EdgeInsets.only(bottom: 6),
          child: InkWell(
            onTap: _refreshFromBackend,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFFEECEA), borderRadius: BorderRadius.circular(6)),
              child: Row(children: [
                const Icon(Icons.cloud_off, size: 14, color: C2.danger),
                const SizedBox(width: 6),
                Expanded(child: Text('Showing cached list — tap to retry',
                  style: ct(11, FontWeight.w500, C2.danger))),
                const Icon(Icons.refresh, size: 14, color: C2.danger),
              ]),
            ),
          )),
      Row(children: [
        Expanded(child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
            const PharmaQueueList())),
          child: StatTile('${s.pharmaQueue.length}', 'In Queue', C2.cyan))),
        const SizedBox(width: 8),
        Expanded(child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
            const PharmaDispensedList())),
          child: StatTile('${s.pharmaDispensed}', 'Dispensed', C2.green))),
        const SizedBox(width: 8),
        // Past 7 Days tile (rule 2026-07-31 — parity with doctor screen).
        // Reuses the counsellor patient list widget filtered to patients
        // that reached the pharmacy in the last week.
        Expanded(child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
            CounPatientsList(title: 'Past 7 Days', patients: s.pharmaPast7Days))),
          child: StatTile('${s.pharmaPast7Days.length}', 'Past 7 Days', C2.navy))),
      ]),
      const SizedBox(height: 14),
      CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SecBar('Pending Prescriptions'),
        if (s.pharmaQueue.isEmpty)
          Padding(padding: const EdgeInsets.all(16), child: Center(child: Text('No prescriptions pending', style: ct(12, FontWeight.w400, C2.text2))))
        else
          ...s.pharmaQueue.map((p) => _pendRow(context, p)),
      ])),
    ]);
  }

  Widget _pendRow(BuildContext context, CPatient p) => InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PharmaDispense(patient: p))),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C2.cyanLight))),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, style: ct(13, FontWeight.w600, C2.text)),
              Text('${p.disease.isEmpty ? "—" : p.disease} · ${p.prescription.length} meds', style: ct(11.5, FontWeight.w400, C2.text2)),
            ])),
            const CBadge('Pending', bg: Color(0xFFFEF7E0), fg: Color(0xFFB8860B)),
          ]),
        ),
      );
}

/// CR27: Home "In Queue" → searchable list of pending patients. Tap a patient
/// to see basic details (same as doctor/counsellor screens).
class PharmaQueueList extends StatefulWidget {
  const PharmaQueueList({super.key});
  @override
  State<PharmaQueueList> createState() => _PharmaQueueListState();
}

class _PharmaQueueListState extends State<PharmaQueueList> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final s = context.watch<CounsellorState>();
    final query = q.trim().toLowerCase();
    final list = s.pharmaQueue.where((p) => query.isEmpty
        || p.name.toLowerCase().contains(query) || p.contact.contains(query)).toList();
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
      child: Scaffold(
        backgroundColor: C2.bg,
        appBar: AppBar(backgroundColor: C2.white, foregroundColor: C2.navy, elevation: 0,
          shape: const Border(bottom: BorderSide(color: C2.cyan, width: 3)),
          title: Text('In Queue (${s.pharmaQueue.length})', style: ct(16, FontWeight.w700, C2.navy))),
        body: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
            child: TextField(decoration: cInput('Search by name or phone number').copyWith(prefixIcon: const Icon(Icons.search, size: 18, color: C2.navy)),
              onChanged: (v) => setState(() => q = v))),
          Expanded(child: list.isEmpty
            ? Center(child: Text(query.isEmpty ? 'No patients in queue' : 'No patient matches "$q"', style: ct(13, FontWeight.w400, C2.text2)))
            : ListView(padding: const EdgeInsets.fromLTRB(14, 6, 14, 20), children: [CCard(child: Column(children: list.map((p) => InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CounPatientDetail(p: p, showReAppointment: false))),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C2.cyanLight))),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.name, style: ct(13, FontWeight.w600, C2.text)),
                      Text('${p.age}y · ${p.contact} · ${p.prescription.length} meds', style: ct(11.5, FontWeight.w400, C2.text2)),
                    ])),
                    const CBadge('Pending', bg: Color(0xFFFEF7E0), fg: Color(0xFFB8860B)),
                  ]),
                ))).toList()))])),
        ]),
      ),
    );
  }
}

/// CR27: Dispensed patients — search by name/phone; tap to see dispensed meds.
class PharmaDispensedList extends StatefulWidget {
  const PharmaDispensedList({super.key});
  @override
  State<PharmaDispensedList> createState() => _PharmaDispensedListState();
}

class _PharmaDispensedListState extends State<PharmaDispensedList> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final s = context.watch<CounsellorState>();
    final query = q.trim().toLowerCase();
    final list = s.dispensedPatients.where((p) => query.isEmpty
        || p.name.toLowerCase().contains(query) || p.contact.contains(query)).toList();
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
      child: Scaffold(
        backgroundColor: C2.bg,
        appBar: AppBar(backgroundColor: C2.white, foregroundColor: C2.navy, elevation: 0,
          shape: const Border(bottom: BorderSide(color: C2.cyan, width: 3)),
          title: Text('Dispensed Patients (${s.dispensedPatients.length})', style: ct(16, FontWeight.w700, C2.navy))),
        body: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
            child: TextField(decoration: cInput('Search by name or phone number').copyWith(prefixIcon: const Icon(Icons.search, size: 18, color: C2.navy)),
              onChanged: (v) => setState(() => q = v))),
          Expanded(child: list.isEmpty
            ? Center(child: Text(query.isEmpty ? 'No dispensed patients' : 'No patient matches "$q"', style: ct(13, FontWeight.w400, C2.text2)))
            : ListView(padding: const EdgeInsets.fromLTRB(14, 6, 14, 20), children: [CCard(child: Column(children: list.map((p) => InkWell(
                onTap: () => _showDispensedMeds(context, p),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C2.cyanLight))),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.name, style: ct(13, FontWeight.w600, C2.text)),
                      Text('${p.age}y · ${p.contact} · ${p.prescription.length} meds', style: ct(11.5, FontWeight.w400, C2.text2)),
                    ])),
                    const CBadge('Dispensed', bg: Color(0xFFEDF7E0), fg: C2.green),
                    const SizedBox(width: 6), const Icon(Icons.chevron_right, color: C2.text3, size: 18),
                  ]),
                ))).toList()))])),
        ]),
      ),
    );
  }

  void _showDispensedMeds(BuildContext context, CPatient p) => showModalBottomSheet(
        context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
        builder: (_) => Container(
          decoration: const BoxDecoration(color: C2.bg, borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
          padding: const EdgeInsets.all(16),
          child: SafeArea(top: false, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: C2.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            Row(children: [
              Container(width: 44, height: 44, alignment: Alignment.center, decoration: const BoxDecoration(color: C2.cyanLight, shape: BoxShape.circle), child: Text(p.initials, style: ct(17, FontWeight.w700, C2.navy))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: ct(16, FontWeight.w700, C2.text)),
                Text('${p.age}y · ${p.contact}', style: ct(12, FontWeight.w400, C2.text2)),
              ])),
              const CBadge('Dispensed', bg: Color(0xFFEDF7E0), fg: C2.green),
            ]),
            const Divider(height: 24),
            Text('Dispensed Medicines', style: ct(12.5, FontWeight.w700, C2.navy)),
            const SizedBox(height: 6),
            if (p.prescription.isEmpty) Text('No medicines on record.', style: ct(12, FontWeight.w400, C2.text2)),
            ...p.prescription.map((m) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: C2.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: C2.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m.dosage.isEmpty ? m.name : '${m.name} · ${m.dosage}', style: ct(13, FontWeight.w600, C2.text)),
                const SizedBox(height: 2),
                Text('${m.interval} · ${m.days} · Dispensed Qty ${m.dispensedQty}', style: ct(11.5, FontWeight.w400, C2.text2)),
              ]),
            )),
            const SizedBox(height: 8),
          ]))),
        ),
      );
}

// ───────────────── Deliver one patient ─────────────────
class PharmaDispense extends StatefulWidget {
  final CPatient patient;
  const PharmaDispense({super.key, required this.patient});
  @override
  State<PharmaDispense> createState() => _PharmaDispenseState();
}

class _PharmaDispenseState extends State<PharmaDispense> {
  CPatient get p => widget.patient;
  final Map<RxItem, TextEditingController> _reason = {};

  TextEditingController _reasonCtl(RxItem m) => _reason.putIfAbsent(m, () => TextEditingController());

  @override
  void dispose() {
    for (final c in _reason.values) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<CounsellorState>();
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
      child: Scaffold(
        backgroundColor: C2.bg,
        appBar: AppBar(backgroundColor: C2.white, foregroundColor: C2.navy, elevation: 0,
          shape: const Border(bottom: BorderSide(color: C2.cyan, width: 3)), title: Text('Deliver Medicine', style: ct(16, FontWeight.w700, C2.navy))),
        body: SingleChildScrollView(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CCard(child: Row(children: [
            Container(width: 46, height: 46, alignment: Alignment.center, decoration: const BoxDecoration(color: C2.cyanLight, shape: BoxShape.circle), child: Text(p.initials, style: ct(18, FontWeight.w700, C2.navy))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, style: ct(16, FontWeight.w700, C2.text)),
              Text('${p.age}y · ${p.disease.isEmpty ? "—" : p.disease}', style: ct(12, FontWeight.w400, C2.text2)),
            ])),
          ])),
          CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SecBar('Prescribed Medicines'),
            if (p.prescription.isEmpty) Text('No medicines prescribed', style: ct(12, FontWeight.w400, C2.text2)),
            ...p.prescription.map(_medRow),
            const SizedBox(height: 8),
            CPrimaryButton('Confirm Delivery', icon: Icons.check_circle_outline, onTap: () {
              // Reason for quantity change is mandatory when delivered ≠ prescribed.
              for (final m in p.prescription) {
                if (m.dispensedQty != m.qty && _reasonCtl(m).text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enter reason for quantity change in ${m.name}'), backgroundColor: C2.danger));
                  return;
                }
              }
              s.pharmacistDispense(p);
              // Enqueue appointment.dispense for /mobile/sync/push (v2 §4).
              context.read<SyncService>().enqueue(kind: 'appointment.dispense', payload: {
                'client_appointment_ref': p.id,
                'lines': [
                  for (final m in p.prescription)
                    {
                      'medicine_name': m.name,
                      'dispensed_qty': m.dispensedQty,
                    },
                ],
              });
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delivered for ${p.name}'), backgroundColor: C2.green));
              Navigator.pop(context);
            }),
          ])),
        ])),
      ),
    );
  }

  Widget _medRow(RxItem m) {
    final changed = m.dispensedQty != m.qty;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: C2.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: C2.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(m.dosage.isEmpty ? m.name : '${m.name} · ${m.dosage}', style: ct(13, FontWeight.w600, C2.text))), const CBadge('Rx', bg: C2.navyLight, fg: C2.navy)]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: _ro('Prescribed', '${m.interval} · ${m.days} · Qty ${m.qty}')),
          const SizedBox(width: 8),
          SizedBox(width: 92, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('DELIVERED QTY', style: ct(9.5, FontWeight.w600, C2.text2)), const SizedBox(height: 3),
            SizedBox(height: 38, child: TextFormField(initialValue: '${m.dispensedQty}', keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
              textAlign: TextAlign.center, style: ct(13, FontWeight.w500, C2.text), decoration: cInput(),
              onChanged: (v) => setState(() => m.dispensedQty = int.tryParse(v) ?? 0))),
          ])),
        ]),
        if (changed)
          Padding(padding: const EdgeInsets.only(top: 6), child: TextField(controller: _reasonCtl(m),
            decoration: cInput('Reason for quantity change *'), style: ct(12.5, FontWeight.w400, C2.text), onChanged: (_) => setState(() {}))),
      ]),
    );
  }

  Widget _ro(String label, String val) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: ct(9.5, FontWeight.w600, C2.text2)), const SizedBox(height: 3),
        Container(height: 38, alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: C2.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: C2.border)),
          child: Text(val, style: ct(12, FontWeight.w500, C2.text2))),
      ]);
}

// ───────────────── Stock ─────────────────
// One draft row on the Requisition form. Unit added 2026-07-29 alongside the
// Zonal Incharge-approval workflow so the Zonal Incharge sees packaging (Tab/Strip/Vial/ml/Bottle/Sachet)
// on the dashboard side. Qty is a String so re-order can start empty.
class _Req {
  String? name;
  String dosage;
  String unit;
  String qty;
  _Req({this.name, this.dosage = '', this.unit = 'Strip', this.qty = '10'});
}

const List<String> _kMedUnits = ['Tab', 'Strip', 'Bottle', 'Vial', 'Sachet', 'ml', 'Ampoule', 'Tube', 'Piece'];

/// Pretty status label + colours for a requisition status string.
({String label, Color bg, Color fg}) _reqStatusStyle(String s) {
  switch (s) {
    case 'approved':      return (label: 'Approved',           bg: const Color(0xFFE4EEF9), fg: C2.navy);
    case 'partial':       return (label: 'Partially Approved', bg: const Color(0xFFFEF7E0), fg: const Color(0xFFB8860B));
    case 'rejected':      return (label: 'Rejected',           bg: const Color(0xFFFBE9E7), fg: C2.danger);
    case 'verified':      return (label: 'Verified',           bg: const Color(0xFFEDF7E0), fg: C2.green);
    case 'pending_zi':
    default:              return (label: 'Pending',            bg: const Color(0xFFEEF2F7), fg: C2.text2);
  }
}

class PharmaStock extends StatefulWidget {
  const PharmaStock({super.key});
  @override
  State<PharmaStock> createState() => _PharmaStockState();
}

class _PharmaStockState extends State<PharmaStock> {
  int tab = 0;
  final List<_Req> reqItems = [_Req()];

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.only(bottom: 8), child: SecBar('Stock Management')),
      Row(children: [_tabBtn('Requisition', 0), const SizedBox(width: 6), _tabBtn('Past', 1), const SizedBox(width: 6), _tabBtn('Overall Status', 2)]),
      const SizedBox(height: 12),
      if (tab == 0) _reqPanel() else if (tab == 1) _pastPanel() else _overallPanel(),
    ]);
  }

  Widget _overallPanel() {
    final reqs = context.watch<CounsellorState>().requisitions;
    final agg = <String, List<int>>{}; // name -> [requested, dispatched, received]
    for (final r in reqs) {
      for (final l in r.items) {
        final a = agg.putIfAbsent(l.name, () => [0, 0, 0]);
        a[0] += l.requested; a[1] += l.dispatched; a[2] += l.received;
      }
    }
    if (agg.isEmpty) return CCard(child: Padding(padding: const EdgeInsets.all(10), child: Center(child: Text('No stock movement yet', style: ct(12, FontWeight.w400, C2.text2)))));
    Widget cell(String t, {bool head = false, int flex = 1, TextAlign align = TextAlign.center}) => Expanded(flex: flex,
        child: Text(t, textAlign: align, style: ct(head ? 10 : 11.5, head ? FontWeight.w700 : FontWeight.w500, head ? Colors.white : C2.text)));
    return CCard(padding: const EdgeInsets.all(8), child: Column(children: [
      Container(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6), decoration: const BoxDecoration(color: C2.navy, borderRadius: BorderRadius.vertical(top: Radius.circular(6))),
        child: Row(children: [
          cell('MEDICINE', head: true, flex: 3, align: TextAlign.left),
          cell('REQ', head: true), cell('DISP', head: true), cell('RECV', head: true),
        ])),
      ...agg.entries.map((e) => Container(padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C2.border))),
        child: Row(children: [
          Expanded(flex: 3, child: Text(e.key, style: ct(11.5, FontWeight.w600, C2.text))),
          cell('${e.value[0]}'), cell('${e.value[1]}'), cell('${e.value[2]}'),
        ]))),
    ]));
  }

  Widget _tabBtn(String t, int i) => Expanded(child: InkWell(onTap: () => setState(() => tab = i), child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9), alignment: Alignment.center,
        decoration: BoxDecoration(color: tab == i ? C2.cyan : C2.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: tab == i ? C2.cyan : C2.border, width: 1.5)),
        child: Text(t, style: ct(12.5, FontWeight.w600, tab == i ? Colors.white : C2.text2)),
      )));

  Widget _reqPanel() {
    // Absorb any Re-Order prefill produced by the Past tab. Consumed after
    // the frame so setState is safe (the state's notifyListeners triggers
    // this rebuild, and we mustn't call setState synchronously in build).
    final s = context.watch<CounsellorState>();
    if (s.hasReorderTemplate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final tpl = s.consumeReorderTemplate();
        if (tpl == null) return;
        setState(() {
          reqItems
            ..clear()
            ..addAll(tpl.items.where((i) => !i.isZonalAdded).map((i) => _Req(
                  name: i.name,
                  dosage: i.dosage,
                  unit: i.unit,
                  qty: '',
                )));
          if (reqItems.isEmpty) reqItems.add(_Req());
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Re-order pre-filled from ${tpl.id}. Enter new quantities.'),
          backgroundColor: C2.navy,
        ));
      });
    }
    return CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ...reqItems.asMap().entries.map((e) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: CField('Medicine', InkWell(
            onTap: () async { final m = await _pickMed(); if (m != null) setState(() => e.value.name = m); },
            child: InputDecorator(decoration: cInput().copyWith(suffixIcon: const Icon(Icons.arrow_drop_down, color: C2.text2)),
              child: Text(e.value.name ?? 'Select Medicine', overflow: TextOverflow.ellipsis,
                style: ct(13, e.value.name == null ? FontWeight.w400 : FontWeight.w500, e.value.name == null ? C2.text3 : C2.text)))), required: true)),
          if (reqItems.length > 1) IconButton(onPressed: () => setState(() => reqItems.removeAt(e.key)), icon: const Icon(Icons.close, size: 18, color: C2.text2)),
        ]),
        Row(children: [
          Expanded(flex: 2, child: CField('Dosage (mg)', TextField(
            controller: TextEditingController(text: e.value.dosage),
            decoration: cInput('e.g. 500'),
            keyboardType: TextInputType.number,
            // 3-digit cap, digits only — no requisitioned medicine above
            // 999 mg per unit in this prototype.
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            onChanged: (v) => e.value.dosage = v,
          ), required: true)),
          const SizedBox(width: 8),
          Expanded(flex: 1, child: CField('Qty', TextField(
            controller: TextEditingController(text: e.value.qty),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
            decoration: cInput(),
            onChanged: (v) => e.value.qty = v,
          ), required: true)),
        ]),
      ]))),
      COutlineButton('Add More', icon: Icons.add_circle_outline, onTap: () => setState(() => reqItems.add(_Req()))),
      const SizedBox(height: 8),
      CPrimaryButton('Submit Requisition', icon: Icons.send, onTap: () => _submitReq(context)),
    ]));
  }

  void _submitReq(BuildContext context) {
    // Parse qty once per row so validation and construction see the same value.
    final parsed = reqItems
        .map((r) => (draft: r, qty: int.tryParse(r.qty.trim()) ?? 0))
        .toList();
    final valid = parsed.where((p) => p.draft.name != null && p.qty > 0).toList();
    if (valid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one medicine + qty'), backgroundColor: C2.danger));
      return;
    }
    if (valid.any((p) => p.draft.dosage.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter dosage for every medicine'), backgroundColor: C2.danger));
      return;
    }
    final s = context.read<CounsellorState>();
    final now = DateTime.now();
    final id = s.nextRequisitionId(now);
    s.addRequisition(Requisition(
      id: id,
      date: fmtDate(now),
      status: 'pending_zi',
      items: valid.map((p) => ReqLine(
        name: p.draft.name!,
        dosage: p.draft.dosage.trim(),
        unit: p.draft.unit,
        requested: p.qty,
        status: 'Pending',
      )).toList(),
      audit: [
        AuditEntry(when: now, actor: 'Pharmacist', action: 'Submitted requisition'),
        AuditEntry(when: now, actor: 'System',     action: 'Email sent to Zonal Incharge'),
      ],
    ));
    setState(() { reqItems..clear()..add(_Req()); tab = 1; });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$id submitted · Email sent to Zonal Incharge · Awaiting approval'),
      backgroundColor: C2.green,
    ));
  }

  Widget _pastPanel() {
    final s = context.watch<CounsellorState>();
    final reqs = s.requisitions;
    if (reqs.isEmpty) return CCard(child: Padding(padding: const EdgeInsets.all(10), child: Center(child: Text('No requisitions submitted yet', style: ct(12, FontWeight.w400, C2.text2)))));
    return Column(children: reqs.map((r) {
      final st = _reqStatusStyle(r.status);
      final summary = r.items.map((i) => '${i.name}×${i.requested}').join(', ');
      return CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _RequisitionDetail(req: r))),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${r.id}  ·  ${r.date}', style: ct(13, FontWeight.w700, C2.text)),
              const SizedBox(height: 2),
              Text(summary, maxLines: 1, overflow: TextOverflow.ellipsis, style: ct(11.5, FontWeight.w400, C2.text2)),
            ])),
            CBadge(st.label, bg: st.bg, fg: st.fg),
            const SizedBox(width: 6), const Icon(Icons.chevron_right, color: C2.text3, size: 18),
          ]),
        ),
        // Re-Order is only meaningful for a fully-completed requisition
        // (Zonal Incharge approved + pharma verified). Rule 2026-07-29 — hide it on
        // anything still moving through the workflow.
        if (r.status == 'verified') ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                s.setReorderTemplate(r);
                setState(() => tab = 0);
              },
              icon: const Icon(Icons.replay_outlined, size: 16, color: C2.cyan),
              label: Text('Re-Order', style: ct(12, FontWeight.w700, C2.cyan)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: C2.cyanLight,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ),
        ],
      ]));
    }).toList());
  }

  Future<String?> _pickMed() => showModalBottomSheet<String>(context: context, isScrollControlled: true, backgroundColor: C2.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => const _MedPicker());
}

/// Requisition detail — four stacked sections (Requested / Approved / Zonal Incharge
/// Added / Received) plus invoice upload + audit trail. The dev-only
/// "Simulate Zonal Incharge Approval" chip stays visible until the JubiCare Dashboard
/// side of the workflow ships and the real Zonal Incharge decision lands here.
class _RequisitionDetail extends StatefulWidget {
  final Requisition req;
  const _RequisitionDetail({required this.req});
  @override
  State<_RequisitionDetail> createState() => _RequisitionDetailState();
}

class _RequisitionDetailState extends State<_RequisitionDetail> {
  Requisition get req => widget.req;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<CounsellorState>();
    final st = _reqStatusStyle(req.status);

    final canVerify = req.status == 'approved' || req.status == 'partial';

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
      child: Scaffold(
        backgroundColor: C2.bg,
        appBar: AppBar(
          backgroundColor: C2.white, foregroundColor: C2.navy, elevation: 0,
          shape: const Border(bottom: BorderSide(color: C2.cyan, width: 3)),
          title: Text('${req.id} · ${req.date}', style: ct(14, FontWeight.w700, C2.navy)),
        ),
        body: ListView(padding: const EdgeInsets.all(14), children: [
          // Header card — id, date, status, Zonal Incharge remark if present.
          CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(req.id, style: ct(14, FontWeight.w700, C2.navy))),
              CBadge(st.label, bg: st.bg, fg: st.fg),
            ]),
            const SizedBox(height: 4),
            Text('Raised on ${req.date}', style: ct(11.5, FontWeight.w400, C2.text2)),
            if (req.zonalRemark.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: C2.bg, borderRadius: BorderRadius.circular(6), border: Border.all(color: C2.border)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.person_outline, size: 15, color: C2.navy),
                  const SizedBox(width: 6),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Zonal Incharge Remark', style: ct(10.5, FontWeight.w700, C2.text2)),
                    const SizedBox(height: 2),
                    Text(req.zonalRemark, style: ct(12, FontWeight.w500, C2.text)),
                  ])),
                ]),
              ),
            ],
            // Approval happens in the web portal (rule 2026-08-05) — the
            // pharmacist can only view and, later, verify what actually
            // arrived. No in-app approval shortcut.
          ])),

          const SizedBox(height: 12),
          // ── Section: Requested Medicines ─────────────────────────
          _sectionCard('Requested Medicines',
              subtitle: 'What the pharmacist asked for.',
              rows: req.requestedItems.map((i) => _lineRow(i, showApproved: req.status != 'pending_zi')).toList()),

          // ── Section: Approved Medicines (once Zonal Incharge acts) ─────────
          if (req.status != 'pending_zi') ...[
            const SizedBox(height: 12),
            _sectionCard('Zonal Incharge Approvals',
                subtitle: 'Zonal Incharge decision on each requested medicine.',
                rows: req.requestedItems.map((i) => _approvedRow(i)).toList()),
          ],

          // ── Section: Zonal Incharge-added extras ─────────
          if (req.zonalAddedItems.isNotEmpty) ...[
            const SizedBox(height: 12),
            _sectionCard('Medicines Added by Zonal Incharge',
                subtitle: 'Extra medicines the Zonal Incharge added on top of the request.',
                rows: req.zonalAddedItems.map(_approvedRow).toList()),
          ],

          // ── Section: Received / verification ─────────
          if (canVerify || req.status == 'verified') ...[
            const SizedBox(height: 12),
            _verificationCard(context, s, editable: canVerify),
          ],

          const SizedBox(height: 12),
          _auditCard(),
        ]),
      ),
    );
  }

  // ─────────────────────── section builders ────────────────────────

  Widget _sectionCard(String title, {required String subtitle, required List<Widget> rows}) {
    return CCard(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(title, style: ct(13, FontWeight.w700, C2.navy)),
      const SizedBox(height: 2),
      Text(subtitle, style: ct(11, FontWeight.w400, C2.text2)),
      const SizedBox(height: 8),
      if (rows.isEmpty)
        Padding(padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('—', style: ct(12, FontWeight.w400, C2.text3)))
      else
        ...rows,
    ]));
  }

  Widget _lineRow(ReqLine i, {required bool showApproved}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C2.border))),
      child: Row(children: [
        Expanded(flex: 4, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(i.name, style: ct(12.5, FontWeight.w700, C2.text)),
          if (i.dosage.isNotEmpty)
            Text('${i.dosage} mg', style: ct(10.5, FontWeight.w400, C2.text2)),
        ])),
        Expanded(flex: 2, child: Text('Req ${i.requested}', textAlign: TextAlign.center, style: ct(11.5, FontWeight.w600, C2.text))),
        if (showApproved)
          Expanded(flex: 3, child: Text(
            i.approvedQty < 0 ? '—' : (i.approvedQty == 0 ? 'Rejected' : 'Approved ${i.approvedQty}'),
            textAlign: TextAlign.right,
            style: ct(11.5, FontWeight.w700, i.approvedQty == 0 ? C2.danger : (i.approvedQty > 0 ? C2.green : C2.text3)),
          )),
      ]),
    );
  }

  Widget _approvedRow(ReqLine i) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C2.border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(i.name, style: ct(12.5, FontWeight.w700, C2.text))),
          Text(
            i.approvedQty <= 0 ? 'Rejected' : 'Approved ${i.approvedQty}',
            style: ct(12, FontWeight.w700, i.approvedQty <= 0 ? C2.danger : C2.green),
          ),
        ]),
        if (i.dosage.isNotEmpty)
          Text('${i.dosage} mg', style: ct(10.5, FontWeight.w400, C2.text2)),
        if (i.zonalRemark.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 4),
            child: Text('Note: ${i.zonalRemark}', style: ct(11, FontWeight.w500, C2.text2))),
      ]),
    );
  }

  Widget _verificationCard(BuildContext context, CounsellorState s, {required bool editable}) {
    final rows = req.items.where((l) => l.approvedQty > 0).toList();
    return CCard(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Received Medicines', style: ct(13, FontWeight.w700, C2.navy)),
      const SizedBox(height: 2),
      Text(editable
          ? 'Confirm quantities on receipt, attach invoice, complete verification.'
          : 'Final received quantities and attached invoice.', style: ct(11, FontWeight.w400, C2.text2)),
      const SizedBox(height: 8),
      Container(padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        decoration: const BoxDecoration(color: C2.navy, borderRadius: BorderRadius.vertical(top: Radius.circular(6))),
        child: Row(children: [
          Expanded(flex: 4, child: Text('MEDICINE', style: ct(10, FontWeight.w700, Colors.white))),
          Expanded(flex: 2, child: Text('APPROVED', textAlign: TextAlign.center, style: ct(10, FontWeight.w700, Colors.white))),
          Expanded(flex: 3, child: Text('RECEIVED', textAlign: TextAlign.center, style: ct(10, FontWeight.w700, Colors.white))),
        ])),
      ...rows.map((i) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C2.border))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(flex: 4, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(i.name + (i.isZonalAdded ? '  ★' : ''), style: ct(12, FontWeight.w700, C2.text)),
            if (i.dosage.isNotEmpty)
              Text('${i.dosage} mg', style: ct(10.5, FontWeight.w400, C2.text2)),
          ])),
          Expanded(flex: 2, child: Text('${i.approvedQty}', textAlign: TextAlign.center, style: ct(11.5, FontWeight.w700, C2.text))),
          Expanded(flex: 3, child: SizedBox(height: 34, child: TextFormField(
            initialValue: '${i.received}',
            keyboardType: TextInputType.number, textAlign: TextAlign.center,
            enabled: editable,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
            style: ct(12, FontWeight.w700, C2.text),
            decoration: cInput().copyWith(contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6)),
            onChanged: (v) { i.received = int.tryParse(v) ?? 0; s.updateRequisitions(); },
          ))),
        ]),
      )),
      const SizedBox(height: 10),
      // Invoice attachment. The button flips label + colour once a file is
      // captured so the pharmacist can tell verification is unblocked.
      Row(children: [
        Expanded(child: OutlinedButton.icon(
          icon: Icon(req.invoicePath.isEmpty ? Icons.upload_file_outlined : Icons.check_circle_outline,
              size: 16, color: req.invoicePath.isEmpty ? C2.navy : C2.green),
          label: Text(
            req.invoicePath.isEmpty ? 'Upload Invoice (PDF/Image)' : 'Invoice attached',
            style: ct(12, FontWeight.w700, req.invoicePath.isEmpty ? C2.navy : C2.green),
          ),
          onPressed: editable ? () async {
            final path = await _pickInvoice();
            if (path == null) return;
            setState(() => req.invoicePath = path);
          } : null,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 40),
            side: BorderSide(color: req.invoicePath.isEmpty ? C2.navy : C2.green),
          ),
        )),
      ]),
      if (editable) ...[
        const SizedBox(height: 10),
        CPrimaryButton(
          'Complete Verification',
          icon: Icons.verified_outlined,
          onTap: () {
            if (req.invoicePath.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Attach the invoice before completing verification'),
                backgroundColor: C2.danger,
              ));
              return;
            }
            if (req.items.every((l) => l.received <= 0)) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Enter received quantity for at least one medicine'),
                backgroundColor: C2.danger,
              ));
              return;
            }
            s.completeVerification(req, invoicePath: req.invoicePath);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Verification complete — requisition closed'),
              backgroundColor: C2.green,
            ));
          },
        ),
      ],
    ]));
  }

  Widget _auditCard() {
    if (req.audit.isEmpty) return const SizedBox.shrink();
    // Newest at the top so the current state is what the reader sees first.
    final entries = req.audit.reversed.toList();
    String fmtWhen(DateTime d) {
      final date = fmtDate(d);
      final h = d.hour.toString().padLeft(2, '0');
      final m = d.minute.toString().padLeft(2, '0');
      return '$date · $h:$m';
    }
    return CCard(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Audit Trail', style: ct(13, FontWeight.w700, C2.navy)),
      const SizedBox(height: 8),
      ...entries.map((e) => Padding(padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 5, right: 8),
            decoration: const BoxDecoration(color: C2.cyan, shape: BoxShape.circle)),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${e.actor} — ${e.action}', style: ct(12, FontWeight.w700, C2.text)),
            Text(fmtWhen(e.when), style: ct(10.5, FontWeight.w400, C2.text2)),
            if (e.note.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 2), child: Text(e.note, style: ct(11, FontWeight.w500, C2.text2))),
          ])),
        ]),
      )),
    ]));
  }

  /// Invoice capture — image_picker's file/gallery flow. Web builds get a
  /// gallery picker; Android gets both camera and gallery from the same
  /// picker so the pharmacist can shoot a photo of a paper invoice too.
  Future<String?> _pickInvoice() async {
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      return x?.path;
    } catch (_) {
      return null;
    }
  }
}

class _MedPicker extends StatefulWidget {
  const _MedPicker();
  @override
  State<_MedPicker> createState() => _MedPickerState();
}

class _MedPickerState extends State<_MedPicker> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final m = kMedicineNames.where((o) => q.isEmpty || o.toLowerCase().contains(q.toLowerCase())).toList();
    return Padding(padding: EdgeInsets.only(left: 16, right: 16, top: 14, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Select Medicine', style: ct(15, FontWeight.w700, C2.navy)), const SizedBox(height: 10),
        TextField(autofocus: true, decoration: cInput('Type to search…').copyWith(prefixIcon: const Icon(Icons.search, size: 18)), onChanged: (v) => setState(() => q = v)),
        const SizedBox(height: 8),
        ConstrainedBox(constraints: const BoxConstraints(maxHeight: 320), child: ListView(shrinkWrap: true,
          children: m.map((o) => ListTile(dense: true, title: Text(o, style: ct(13.5, FontWeight.w500, C2.text)),
            trailing: const Icon(Icons.add, size: 18, color: C2.cyan), onTap: () => Navigator.pop(context, o))).toList())),
      ]));
  }
}

// ───────────────── Pharmacy Report ─────────────────
class PharmaReport extends StatefulWidget {
  const PharmaReport({super.key});
  @override
  State<PharmaReport> createState() => _PharmaReportState();
}

class _PharmaReportState extends State<PharmaReport> {
  String? _kind;    // 'patient' | 'stock'
  String _from = '';
  String _to = '';
  DateTime? _fromDt, _toDt;
  bool _generated = false;

  /// Reverse of `fmtDate` so we can compare a Requisition's stored date
  /// ("24-Jun-2026") with the From/To range chosen by the user.
  DateTime? _parseFmtDate(String s) {
    final parts = s.split('-');
    if (parts.length != 3) return null;
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final day = int.tryParse(parts[0]);
    final monthIdx = months.indexOf(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || year == null || monthIdx < 0) return null;
    return DateTime(year, monthIdx + 1, day);
  }

  Widget _reportCard(String title, String sub, IconData icon, Color color, String kind) => InkWell(
    onTap: () => setState(() { _kind = kind; _generated = false; }),
    child: CCard(child: Row(children: [
      Container(width: 40, height: 40, alignment: Alignment.center,
        decoration: BoxDecoration(color: color.withAlpha(40), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 20)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: ct(13.5, FontWeight.w700, C2.text)),
        Text(sub, style: ct(11.5, FontWeight.w400, C2.text2)),
      ])),
      if (_kind == kind) const Icon(Icons.check_circle, color: C2.green, size: 18),
    ])),
  );

  @override
  Widget build(BuildContext context) {
    final s = context.watch<CounsellorState>();
    final dispensed = s.dispensedPatients;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.only(bottom: 8), child: SecBar('Pharmacy Report')),
      _reportCard('Patient Report', 'Dispensed patients & medicines', Icons.description, C2.cyan, 'patient'),
      _reportCard('Stock Report',   'Requisitions raised, dispatch + receive status', Icons.inventory_2, C2.navy, 'stock'),

      if (_kind != null) ...[
        CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SecBar('Select Duration'),
          Row(children: [
            Expanded(child: CField('From', DateField(hint: 'Select date', first: DateTime(2024), last: DateTime.now(),
              onPicked: (d) => setState(() { _fromDt = d; _from = fmtDate(d); })), required: true)),
            const SizedBox(width: 8),
            Expanded(child: CField('To', DateField(hint: 'Select date', first: DateTime(2024), last: DateTime.now(),
              onPicked: (d) => setState(() { _toDt = d; _to = fmtDate(d); })), required: true)),
          ]),
          CPrimaryButton('Generate Report', icon: Icons.assessment, onTap: () {
            if (_from.isEmpty || _to.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select both From and To dates'), backgroundColor: C2.danger));
              return;
            }
            setState(() => _generated = true);
          }),
        ])),
      ],

      if (_generated && _kind == 'patient')
        CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SecBar('Patient Report · $_from – $_to'),
          Row(children: [
            Expanded(child: StatTile('${s.pharmaQueue.length}', 'Pending', C2.cyan)),
            const SizedBox(width: 8),
            Expanded(child: StatTile('${dispensed.length}', 'Dispensed', C2.green)),
            const SizedBox(width: 8),
            Expanded(child: StatTile('${s.deniedDeliveries.length}', 'Denied', C2.danger)),
          ]),
          const SizedBox(height: 10),
          Text('Dispensed Patients & Medicines', style: ct(12.5, FontWeight.w700, C2.navy)),
          const SizedBox(height: 4),
          if (dispensed.isEmpty) Text('None in this period.', style: ct(12, FontWeight.w400, C2.text2)),
          ...dispensed.map((p) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: C2.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: C2.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${p.name} · ${p.age}/${p.gender}', style: ct(12.5, FontWeight.w700, C2.text)),
              if (p.prescription.isEmpty) Text('No medicines', style: ct(11, FontWeight.w400, C2.text2)),
              ...p.prescription.map((m) => Padding(padding: const EdgeInsets.only(top: 3),
                child: Text('• ${m.dosage.isEmpty ? m.name : "${m.name} ${m.dosage}"} · ${m.interval} · Qty ${m.dispensedQty}', style: ct(11.5, FontWeight.w400, C2.text2)))),
            ]),
          )),
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerRight, child: SizedBox(width: 160,
            child: CPrimaryButton('Export PDF', icon: Icons.picture_as_pdf, onTap: () => _exportPatientPdf(dispensed, s.deniedDeliveries.length)))),
        ])),

      if (_generated && _kind == 'stock') ...[
        (() {
          // Filter requisitions to the chosen range.
          final inRange = s.requisitions.where((r) {
            final d = _parseFmtDate(r.date);
            if (d == null || _fromDt == null || _toDt == null) return false;
            final t = DateTime(d.year, d.month, d.day);
            final f = DateTime(_fromDt!.year, _fromDt!.month, _fromDt!.day);
            final to = DateTime(_toDt!.year, _toDt!.month, _toDt!.day);
            return !t.isBefore(f) && !t.isAfter(to);
          }).toList();
          int totalReq = 0, totalDisp = 0, totalRec = 0, lineCount = 0;
          for (final r in inRange) {
            for (final l in r.items) {
              totalReq += l.requested;
              totalDisp += (l.dispatched > 0 ? l.dispatched : l.requested);
              totalRec  += l.received;
              lineCount++;
            }
          }
          return CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SecBar('Stock Report · $_from – $_to'),
            // Two balanced tiles instead of three — the old "Received/Req."
            // tile was visibly wider than the single-number ones.
            Row(children: [
              Expanded(child: StatTile('${inRange.length} / $lineCount', 'Requisitions / Lines', C2.cyan)),
              const SizedBox(width: 8),
              Expanded(child: StatTile('$totalRec / $totalReq', 'Received / Req. Qty', C2.green)),
            ]),
            const SizedBox(height: 10),
            Text('Requisitions Raised', style: ct(12.5, FontWeight.w700, C2.navy)),
            const SizedBox(height: 4),
            if (inRange.isEmpty) Text('None in this period.', style: ct(12, FontWeight.w400, C2.text2)),
            ...inRange.map((r) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: C2.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: C2.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(r.date, style: ct(12.5, FontWeight.w700, C2.text)),
                  CBadge(r.status, bg: C2.navyLight, fg: C2.navy),
                ]),
                ...r.items.map((l) => Padding(padding: const EdgeInsets.only(top: 3),
                  child: Text('• ${l.dosage.isEmpty ? l.name : "${l.name} ${l.dosage}"} · Req ${l.requested} · Disp ${l.dispatched > 0 ? l.dispatched : l.requested} · Rec ${l.received}',
                    style: ct(11.5, FontWeight.w400, C2.text2)))),
              ]),
            )),
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerRight, child: SizedBox(width: 160,
              child: CPrimaryButton('Export PDF', icon: Icons.picture_as_pdf, onTap: () => _exportStockPdf(inRange)))),
          ]));
        })(),
      ],
    ]);
  }

  Future<void> _exportPatientPdf(List<CPatient> dispensed, int denied) async {
    // One row per dispensed medicine: Date, Patient, Diagnosis, Medicine, Dosage, Frequency, Qty.
    String dose(RxItem m) {
      if (m.dosage.trim().isNotEmpty) return m.dosage;
      final (_, d) = splitMedicine(m.name); // derive strength from the name if missing
      return d.isEmpty ? '-' : d;
    }
    final rows = <List<String>>[];
    for (final p in dispensed) {
      final date = p.regDate.isEmpty ? '-' : p.regDate;
      final dx = p.disease.isEmpty ? '-' : p.disease;
      if (p.prescription.isEmpty) {
        rows.add([date, p.name, dx, '—', '—', '—', '—']);
      } else {
        for (final m in p.prescription) {
          rows.add([date, p.name, dx, m.name, dose(m), m.interval, '${m.dispensedQty}']);
        }
      }
    }
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4.landscape, build: (ctx) => [
      pw.Header(level: 0, child: pw.Text('JubiCare - Pharmacy Patient Report', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
      pw.Text('Period: ${_from.isEmpty ? "—" : _from} to ${_to.isEmpty ? "—" : _to}'),
      pw.SizedBox(height: 6),
      pw.Text('Dispensed patients: ${dispensed.length}    Denied: $denied'),
      pw.SizedBox(height: 12),
      pw.Text('Dispensed Medicines', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      pw.Table.fromTextArray(
        headers: ['Date', 'Patient', 'Diagnosis', 'Medicine', 'Dosage', 'Frequency', 'Qty'],
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        columnWidths: {for (var i = 0; i < 7; i++) i: const pw.IntrinsicColumnWidth()},
        data: rows,
      ),
    ]));
    await Printing.layoutPdf(onLayout: (f) => doc.save(), name: 'JubiCare_Pharmacy_Patient_Report');
  }

  /// Stock Report PDF — one row per requisition line raised in the picked
  /// range. Mirrors the portal's pharmaStockPDF output.
  Future<void> _exportStockPdf(List<Requisition> reqs) async {
    final rows = <List<String>>[];
    int totalReq = 0, totalDisp = 0, totalRec = 0;
    for (final r in reqs) {
      for (final l in r.items) {
        final disp = l.dispatched > 0 ? l.dispatched : l.requested;
        final lineStatus = l.received >= disp
            ? 'Received'
            : (l.received > 0 ? 'Partial' : 'Pending');
        rows.add([
          r.date,
          l.name,
          l.dosage.isEmpty ? '-' : '${l.dosage} mg',
          '${l.requested}',
          '$disp',
          '${l.received}',
          lineStatus,
          r.status,
        ]);
        totalReq += l.requested;
        totalDisp += disp;
        totalRec  += l.received;
      }
    }
    if (rows.isNotEmpty) {
      rows.add(['—', 'TOTAL (${rows.length} lines)', '', '$totalReq', '$totalDisp', '$totalRec', '', '']);
    }

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4.landscape, build: (ctx) => [
      pw.Header(level: 0, child: pw.Text('JubiCare - Pharmacy Stock Report', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
      pw.Text('Period: ${_from.isEmpty ? "—" : _from} to ${_to.isEmpty ? "—" : _to}'),
      pw.SizedBox(height: 6),
      pw.Text('Requisitions: ${reqs.length}'),
      pw.SizedBox(height: 12),
      pw.Table.fromTextArray(
        headers: ['Date', 'Medicine', 'Dosage', 'Requested', 'Dispatched', 'Received', 'Line Status', 'Req Status'],
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        columnWidths: {for (var i = 0; i < 8; i++) i: const pw.IntrinsicColumnWidth()},
        data: rows.isEmpty ? [List.filled(8, '—')] : rows,
      ),
    ]));
    await Printing.layoutPdf(onLayout: (f) => doc.save(), name: 'JubiCare_Pharmacy_Stock_Report');
  }
}

// ───────────────── My Attendance (history + mark) ─────────────────
class PharmaAttendance extends StatefulWidget {
  const PharmaAttendance({super.key});
  @override
  State<PharmaAttendance> createState() => _PharmaAttendanceState();
}

// Same 3 camp anchors used by the doctor / counsellor auto-location pickers.
const Map<String, ({double lat, double lng})> _kPharmaCampCoords = {
  'Gajraula Camp': (lat: 28.845, lng: 78.240),
  'Amroha Camp':   (lat: 28.910, lng: 78.470),
  'Hasanpur Camp': (lat: 28.719, lng: 78.302),
};

class _PharmaAttendanceState extends State<PharmaAttendance> {
  bool showForm = false;
  // Mode selector (rule 2026-08-05) — Check-In / Check-Out are mutually
  // exclusive so the pharmacist marks one side at a time.
  String _mode = 'in';
  String _date = '';
  String _checkIn = '';
  String _checkOut = '';
  String? location;
  final _notes = TextEditingController();
  // Selfie + GPS captured for whichever mode is active (rule 2026-08-05).
  // On Check-In this fills photoPath / lat / lng; on Check-Out the same
  // fields ride into photoPathOut / latOut / lngOut so the audit trail
  // has a photo for both ends of the shift.
  String? _photoPath;
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    _date = fmtDate(DateTime.now());
  }

  @override
  void dispose() { _notes.dispose(); super.dispose(); }

  /// Today's open check-in record for the pharmacist (rule 2026-08-05).
  /// Non-null when a check-in without a matching check-out exists — the
  /// only state where Check-Out is allowed.
  AttendanceRecord? _openPharmaShift(CounsellorState s) {
    for (final r in s.pharmaAttendance) {
      if (r.date == _date && r.checkIn.isNotEmpty && r.checkOut.isEmpty) {
        return r;
      }
    }
    return null;
  }

  Future<void> _autofill(CounsellorState s) async {
    final now = TimeOfDay.now();
    final open = _openPharmaShift(s);
    setState(() {
      if (_mode == 'in') {
        _checkIn = fmtTime12(now);
      } else {
        _checkOut = fmtTime12(now);
      }
    });
    if (_mode == 'out' && open != null) {
      setState(() => location = open.location);
      return;
    }
    if (location != null) return;
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      String? nearest;
      double best = double.infinity;
      for (final e in _kPharmaCampCoords.entries) {
        final d = Geolocator.distanceBetween(pos.latitude, pos.longitude, e.value.lat, e.value.lng);
        if (d < best) { best = d; nearest = e.key; }
      }
      if (nearest != null && mounted) setState(() => location = nearest);
    } catch (_) { /* fall through */ }
  }

  void _submit(CounsellorState s) {
    void err(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: C2.danger));
    final open = _openPharmaShift(s);
    // Guard rule 2026-08-05: Check-Out only if today's Check-In exists.
    if (_mode == 'out' && open == null) {
      return err('Please complete Check-In before Check-Out');
    }
    if (_mode == 'in' && open != null) {
      return err('Check-In already recorded — use Check-Out to close the shift');
    }
    if (_mode == 'in' && _checkIn.isEmpty) return err('Waiting for current time…');
    if (_mode == 'out' && _checkOut.isEmpty) return err('Waiting for current time…');
    if (location == null) return err('Waiting for GPS to pick the nearest camp…');
    if (_photoPath == null) return err('Take a selfie to mark attendance');
    if (_mode == 'in') {
      s.addPharmaAttendance(AttendanceRecord(
        date: _date,
        checkIn: _checkIn, checkOut: '',
        location: location!,
        status: 'Present', notes: _notes.text.trim(),
        photo: true, photoPath: _photoPath!, lat: _lat, lng: _lng,
      ));
      context.read<SyncService>().enqueue(kind: 'attendance.check_in', payload: {
        'attendance_date': _date,
        'check_in':        _checkIn,
        'location':        location!,
        'latitude':        _lat,
        'longitude':       _lng,
        'notes':           _notes.text.trim(),
      });
    } else {
      final closed = open!.copyWith(
        checkOut: _checkOut,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        photoPathOut: _photoPath!,
        latOut: _lat, lngOut: _lng,
      );
      s.closePharmaShift(open, closed);
      context.read<SyncService>().enqueue(kind: 'attendance.check_out', payload: {
        'attendance_date': _date,
        'check_out':       _checkOut,
        'latitude':        _lat,
        'longitude':       _lng,
        'notes':           _notes.text.trim(),
      });
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Attendance (${_mode == 'in' ? 'Check-In' : 'Check-Out'}) submitted'),
      backgroundColor: C2.green,
    ));
    setState(() {
      showForm = false; _checkIn = ''; _checkOut = '';
      _date = fmtDate(DateTime.now()); location = null; _notes.clear();
      _photoPath = null; _lat = null; _lng = null;
      _mode = 'in';
    });
  }

  Widget _modeBtn(String key, String label, IconData icon, {bool enabled = true}) {
    final selected = _mode == key;
    return Expanded(child: InkWell(
      onTap: !enabled ? null : () {
        if (_mode == key) return;
        setState(() => _mode = key);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _autofill(context.read<CounsellorState>());
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: !enabled ? C2.bg : (selected ? C2.cyan : C2.white),
          border: Border.all(color: !enabled ? C2.border : (selected ? C2.cyan : C2.border), width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(!enabled ? Icons.lock_outline : icon, size: 16,
              color: !enabled ? C2.text3 : (selected ? Colors.white : C2.text2)),
          const SizedBox(width: 6),
          Text(label, style: ct(12.5, FontWeight.w700,
              !enabled ? C2.text3 : (selected ? Colors.white : C2.text2))),
        ]),
      ),
    ));
  }

  Widget _readOnlyPill({required IconData icon, required String value, bool empty = false}) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: C2.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: C2.border)),
      child: Row(children: [
        Icon(icon, size: 16, color: empty ? C2.text3 : C2.cyan),
        const SizedBox(width: 8),
        Expanded(child: Text(value,
          style: ct(13.5, empty ? FontWeight.w400 : FontWeight.w600, empty ? C2.text3 : C2.text),
          overflow: TextOverflow.ellipsis)),
        Icon(Icons.lock_outline, size: 14, color: C2.text3),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<CounsellorState>();
    final open = _openPharmaShift(s);
    if (open == null && _mode == 'out') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_openPharmaShift(context.read<CounsellorState>()) == null && _mode == 'out') {
          setState(() => _mode = 'in');
        }
      });
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.only(bottom: 8), child: SecBar('My Attendance',
        trailing: COutlineButton(showForm ? 'Close' : (open == null ? 'Mark Check-In' : 'Mark Check-Out'),
          icon: showForm ? Icons.close : (open == null ? Icons.login : Icons.logout),
          onTap: () {
            final opening = !showForm;
            setState(() {
              showForm = opening;
              if (opening) _mode = open == null ? 'in' : 'out';
            });
            if (opening) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _autofill(context.read<CounsellorState>());
              });
            }
          }))),
      if (showForm)
        CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SecBar('Mark Attendance'),
          if (open != null)
            Padding(padding: const EdgeInsets.only(top: 6, bottom: 2),
              child: Text('Closing check-in from ${open.checkIn} · ${open.location}',
                style: ct(11.5, FontWeight.w600, C2.navy))),
          const SizedBox(height: 4),
          Row(children: [
            _modeBtn('in', 'Check-In', Icons.login, enabled: open == null),
            const SizedBox(width: 8),
            _modeBtn('out', 'Check-Out', Icons.logout, enabled: open != null),
          ]),
          CField('Date', InputDecorator(decoration: cInput().copyWith(suffixIcon: const Icon(Icons.calendar_today, size: 16, color: C2.cyan)),
            child: Text(_date, style: ct(13.5, FontWeight.w600, C2.text)))),
          if (_mode == 'in')
            CField('Check-in time', _readOnlyPill(
              icon: Icons.access_time,
              value: _checkIn.isEmpty ? 'Fetching current time…' : _checkIn,
              empty: _checkIn.isEmpty,
            ), required: true)
          else
            CField('Check-out time', _readOnlyPill(
              icon: Icons.access_time,
              value: _checkOut.isEmpty ? 'Fetching current time…' : _checkOut,
              empty: _checkOut.isEmpty,
            ), required: true),
          CField('Location', _readOnlyPill(
            icon: Icons.location_on_outlined,
            value: location ?? 'Detecting nearest camp via GPS…',
            empty: location == null,
          ), required: true),
          CField('Notes', TextField(controller: _notes, minLines: 2, maxLines: 3, decoration: cInput('Optional — type or use the mic').copyWith(
            suffixIcon: VoiceMicButton(controller: _notes)))),
          // Selfie + GPS proof for whichever mode is active (rule
          // 2026-08-05). Same widget the doctor + counsellor use — the
          // captured photo path + lat/lng ride into photoPath /
          // photoPathOut depending on Check-In vs Check-Out.
          CField('Selfie + Location', AttendanceCapture(
            initialPhotoPath: _photoPath, initialLat: _lat, initialLng: _lng,
            onCaptured: (path, lat, lng) => setState(() { _photoPath = path; _lat = lat; _lng = lng; }),
          ), required: true),
          const SizedBox(height: 4),
          CPrimaryButton(_mode == 'in' ? 'Submit Check-In' : 'Submit Check-Out',
            icon: Icons.check_circle_outline, onTap: () => _submit(s)),
        ])),
      if (!showForm) ...[
        if (s.pharmaAttendance.isEmpty)
          CCard(child: Padding(padding: const EdgeInsets.all(12), child: Center(child: Text('No attendance marked yet', style: ct(12, FontWeight.w400, C2.text2)))))
        else
          ...s.pharmaAttendance.map((r) => CCard(
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
            _drow('Date', r.date), _drow('Check-in', r.checkIn), _drow('Check-out', r.checkOut),
            _drow('Location', r.location), _drow('Status', r.status),
            if (r.notes.isNotEmpty) _drow('Notes', r.notes),
          ])),
        ),
      );

  Widget _drow(String k, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [
        SizedBox(width: 96, child: Text(k, style: ct(12, FontWeight.w400, C2.text2))),
        Expanded(child: Text(v, style: ct(13, FontWeight.w600, C2.text))),
      ]));
}
