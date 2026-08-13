import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/masters_store.dart';
import '../services/connectivity_service.dart';
import 'cdata.dart';
import 'cw.dart';

/// Symptom entry with type-ahead suggestions (Hindi aliases, geo-common,
/// full list), geo + related quick-add panels, and live "Likely Conditions".
class SymptomField extends StatefulWidget {
  final List<String> selected;
  final String? block;
  final ValueChanged<List<String>> onChanged;
  const SymptomField({super.key, required this.selected, required this.block, required this.onChanged});
  @override
  State<SymptomField> createState() => _SymptomFieldState();
}

class _SymptomFieldState extends State<SymptomField> {
  /// Compile-time flag for the "Likely Conditions" panel only. The other
  /// two suggestion cards ("Common in {block}", "Related symptoms") stay
  /// visible unconditionally. Off by default because scoreDiseases() runs
  /// on hardcoded kDiseaseDb weights — enable with
  /// `flutter run --dart-define=SHOW_LIKELY=true` for local demos.
  static const bool _showLikelyPanel =
      bool.fromEnvironment('SHOW_LIKELY', defaultValue: false);

  final _c = TextEditingController();
  final _focus = FocusNode();
  String _q = '';

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<String> get _sel => widget.selected;
  bool _has(String s) => _sel.map((e) => e.toLowerCase()).contains(s.toLowerCase());

  void _add(String s) {
    final v = s.trim();
    if (v.isEmpty) return;
    if (!_has(v)) widget.onChanged([..._sel, v]);
    _c.clear();
    setState(() => _q = '');
  }

  void _remove(String s) => widget.onChanged(_sel.where((e) => e != s).toList());

  @override
  Widget build(BuildContext context) {
    final geo = kGeoDb[widget.block] ?? kGeoDb['Gajraula']!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // chips + input
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: C2.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _focus.hasFocus ? C2.cyan : C2.border, width: 1.5),
        ),
        child: Wrap(spacing: 4, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          ..._sel.map((s) => Chip(
                label: Text(s, style: ct(12, FontWeight.w600, C2.navy)),
                backgroundColor: C2.cyanLight,
                side: BorderSide.none,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                deleteIcon: const Icon(Icons.close, size: 13),
                deleteIconColor: C2.text2,
                onDeleted: () => _remove(s),
              )),
          SizedBox(
            width: 130,
            child: TextField(
              controller: _c,
              focusNode: _focus,
              style: ct(13, FontWeight.w400, C2.text),
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                isDense: true, border: InputBorder.none, hintText: 'Type symptoms...',
                contentPadding: EdgeInsets.symmetric(vertical: 6),
              ),
              onChanged: (v) => setState(() => _q = v),
              onSubmitted: _add,
            ),
          ),
        ]),
      ),
      // suggestion dropdown
      if (_focus.hasFocus) _suggestions(geo),
      // Symptom panels below the input. Two are visible:
      //   * "Common in {block}"   — geo-common symptom quick-adds
      //   * "Related symptoms"    — suggestions based on picks so far
      // "Likely Conditions" is hidden per user request (2026-08-13). The
      // underlying kDiseaseDb weights are local hardcoded rather than
      // backend-driven, so the percentages can drift from what the doctor
      // actually diagnoses. Turn back on with `flutter run
      // --dart-define=SHOW_LIKELY=true` once a backend endpoint provides
      // the disease-scoring feed.
      if (_sel.isNotEmpty) ...[
        const SizedBox(height: 8),
        _geoPanel(geo),
        const SizedBox(height: 6),
        _relatedPanel(),
        if (_showLikelyPanel &&
            context.watch<ConnectivityService>().isOnline) ...[
          const SizedBox(height: 6),
          _likelyPanel(),
        ],
      ],
    ]);
  }

  /// Symptom list pulled from the backend masters cache (bootstrap →
  /// MastersStore). Rows are `{id, term}`; we return just the terms so
  /// the suggestion dropdown is drop-in compatible with the old
  /// `kAllSymptoms` list. Falls back to the local hardcoded list if
  /// the masters cache hasn't hydrated yet (first launch, no network) —
  /// so the counsellor is never staring at an empty picker.
  List<String> _symptomTerms(MastersStore masters) {
    final rows = masters.masterRows('symptoms');
    if (rows.isEmpty) return kAllSymptoms;
    return [
      for (final r in rows)
        if ((r['term'] ?? r['name'] ?? r['symptom_name']) != null)
          (r['term'] ?? r['name'] ?? r['symptom_name']).toString()
    ];
  }

  Widget _suggestions(GeoBlock geo) {
    final q = _q.trim().toLowerCase();
    final children = <Widget>[];
    // Pull the symptom list from backend masters so the counsellor only
    // picks values the DB actually knows — no more "Rash selected on
    // mobile but silently dropped because symptom_master doesn't have it".
    final masters = context.watch<MastersStore>();
    final allSymptoms = _symptomTerms(masters);
    if (q.isEmpty) {
      children.add(_sugHeader('Common in ${widget.block ?? "Gajraula"}', const Color(0xFFFEF7E0), const Color(0xFFB8860B)));
      for (final s in geo.geo.where((s) => !_has(s)).take(6)) {
        children.add(_sugItem(s, Icons.location_on, C2.yellow));
      }
    } else {
      if (kSymAlias.containsKey(q)) {
        children.add(_sugHeader('Did you mean', const Color(0xFFEDF7E0), C2.green));
        for (final s in kSymAlias[q]!.where((s) => !_has(s))) {
          children.add(_sugItem(s, Icons.subdirectory_arrow_right, C2.green));
        }
      }
      final matches = allSymptoms.where((s) => s.toLowerCase().contains(q) && !_has(s)).take(8).toList();
      if (matches.isNotEmpty) {
        children.add(_sugHeader('Symptoms', C2.navyLight, C2.navy));
        for (final s in matches) {
          children.add(_sugItem(s, null, null));
        }
      }
      // Master-driven only (2026-08-13 rule). If nothing in the master
      // list matches what the counsellor typed, show a gentle prompt
      // instead of an "Add typed symptom" shortcut — the earlier
      // free-text path polluted symptom_master with duplicate variants
      // ("Rash" vs "Skin rash"). Missing entries are a backend
      // data-seed issue: add the row via migrate.sql, not from the app.
      if (matches.isEmpty && !kSymAlias.containsKey(q)) {
        children.add(_sugHeader('Not in list', const Color(0xFFFEECEA), C2.danger));
        children.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Text(
            '"${_q.trim()}" is not a recognised symptom. Try a keyword like "fever" or "rash" — or ask the admin to add it to the master list.',
            style: ct(11.5, FontWeight.w400, C2.text2),
          ),
        ));
      }
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 4),
      constraints: const BoxConstraints(maxHeight: 240),
      decoration: BoxDecoration(
        color: C2.white, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: C2.border, width: 1.5), boxShadow: C2.shadow),
      child: ListView(shrinkWrap: true, padding: EdgeInsets.zero, children: children),
    );
  }

  Widget _sugHeader(String t, Color bg, Color fg) => Container(
        width: double.infinity, color: bg,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(t.toUpperCase(), style: ct(10, FontWeight.w700, fg)),
      );

  Widget _sugItem(String s, IconData? icon, Color? iconColor, {String? value}) => InkWell(
        onTap: () => _add(value ?? s),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(children: [
            if (icon != null) ...[Icon(icon, size: 14, color: iconColor), const SizedBox(width: 6)],
            Text(s, style: ct(13, FontWeight.w500, C2.text)),
          ]),
        ),
      );

  Widget _geoPanel(GeoBlock geo) {
    final btns = geo.geo.where((s) => !_has(s)).take(5).toList();
    if (btns.isEmpty) return const SizedBox.shrink();
    return _panel(
      const LinearGradient(colors: [C2.navy, Color(0xFF005A8D)]),
      Icons.location_on, 'Common in ${widget.block ?? "Gajraula"}', btns);
  }

  Widget _relatedPanel() {
    final rel = <String>{};
    for (final s in _sel) {
      for (final r in (kRelated[s.toLowerCase()] ?? const [])) {
        if (!_has(r)) rel.add(r);
      }
    }
    if (rel.isEmpty) return const SizedBox.shrink();
    return _panel(
      const LinearGradient(colors: [C2.cyan, C2.green]),
      Icons.link, 'Related symptoms', rel.take(5).toList());
  }

  Widget _panel(Gradient g, IconData icon, String title, List<String> btns) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(gradient: g, borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, size: 13, color: Colors.white70), const SizedBox(width: 5),
          Text(title, style: ct(11.5, FontWeight.w600, Colors.white))]),
        const SizedBox(height: 6),
        Wrap(spacing: 4, runSpacing: 4, children: btns.map((s) => InkWell(
          onTap: () => _add(s),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Text(s, style: ct(11, FontWeight.w500, Colors.white)),
          ),
        )).toList()),
      ]),
    );
  }

  Widget _likelyPanel() {
    final scored = scoreDiseases(_sel, widget.block);
    if (scored.isEmpty) return const SizedBox.shrink();
    Color fill(String l) => l == 'h' ? C2.yellow : (l == 'm' ? C2.cyanLight : C2.green);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [C2.navy, Color(0xFF004DB3)]),
        borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.memory, size: 14, color: Colors.white), const SizedBox(width: 6),
          Text('Likely Conditions', style: ct(12, FontWeight.w700, Colors.white)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(color: C2.cyan, borderRadius: BorderRadius.circular(4)),
            child: Text('LIVE', style: ct(8.5, FontWeight.w700, Colors.white)),
          ),
        ]),
        const SizedBox(height: 8),
        ...scored.map((d) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Expanded(child: Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ct(12, FontWeight.w500, Colors.white))),
            const SizedBox(width: 8),
            SizedBox(width: 60, child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: d.pct / 100, minHeight: 5,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(fill(d.level)),
              ),
            )),
            const SizedBox(width: 8),
            SizedBox(width: 34, child: Text('${d.pct}%', textAlign: TextAlign.right, style: ct(11.5, FontWeight.w700, fill(d.level)))),
          ]),
        )),
      ]),
    );
  }
}
