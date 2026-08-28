import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/masters_store.dart';
import '../services/terminology_store.dart';
import 'cdata.dart';
import 'cw.dart';

/// Symptom entry with type-ahead suggestions (Hindi aliases, geo-common,
/// full list), geo + related quick-add panels, and live "Likely Conditions".
///
/// Data sources (2026-08-21 rework — no hardcoded medical data):
///  * "Related symptoms" + "Likely Conditions" — the downloaded terminology
///    JSON ([TerminologyStore], synced from GET /mobile/terminology and
///    cached, so both work offline). The old const maps remain only as a
///    first-launch fallback until the download lands.
///  * "Common in <village>" — real village trends passed in by the caller
///    from GET /appointments/{id}/advisory. Without trend data the panel
///    hides instead of showing another village's list.
class SymptomField extends StatefulWidget {
  final List<String> selected;
  final String? block;
  final ValueChanged<List<String>> onChanged;

  /// Real place name for the trends panel ("Common in <placeName>").
  final String? placeName;

  /// Village trending rows `[{term, frequency, rank}]` from the advisory
  /// API; null = caller has no trend source (e.g. Register — no case yet).
  final List<Map<String, dynamic>>? trending;

  /// Free text to mine for extra symptom hints — the doctor's dictated
  /// Observation ("bukhaar ho raha hai" surfaces the fever terms).
  final String? freeText;

  /// Server-computed related-symptoms list (from the advisory API's
  /// `related_symptoms` field, co-occurrence over real village data).
  /// When provided, this replaces the local terminology.relatedTerms
  /// output — the server's algorithm is more accurate (user 2026-08-26:
  /// client compute was surfacing "bleeding" that server never
  /// returned). Null falls back to the client-side compute so offline
  /// cases still show something.
  final List<String>? serverRelated;

  /// Suppress only the "Common in <village>" chip strip while keeping
  /// the village-share bonus flowing into Likely Conditions (user
  /// 2026-08-27 for the counsellor Register screen).
  final bool hideVillagePanel;

  /// Server-ranked Likely Conditions (from the advisory API's
  /// `likely_conditions` field). When provided, this replaces the
  /// client-side `terminology.likelyConditions` output — the server's
  /// scoring uses doctor-confirmed diagnoses for the village-share
  /// bonus (user 2026-08-27: client compute was still inflating Gout
  /// off peer symptoms even after the server switched to diagnoses).
  /// Each row: {condition/name, score/pct, icd11_code}. Null falls
  /// back to the offline client compute.
  final List<Map<String, dynamic>>? serverLikely;

  /// True while a fresh advisory-preview request is in flight — the
  /// panels then show a subtle "Analyzing…" placeholder instead of the
  /// stale reply from the previous chip set (user 2026-08-27: "data
  /// coming late, old data shown for a beat, then refreshes").
  final bool loading;

  /// True when the last advisory fetch FAILED — the panels then show a
  /// friendly "couldn't load" strip with a Retry tap that calls
  /// [onRetry] (user 2026-08-28).
  final bool error;
  final VoidCallback? onRetry;

  const SymptomField({super.key, required this.selected, required this.block,
      required this.onChanged, this.placeName, this.trending, this.freeText,
      this.serverRelated, this.hideVillagePanel = false,
      this.serverLikely, this.loading = false,
      this.error = false, this.onRetry});
  @override
  State<SymptomField> createState() => _SymptomFieldState();
}

class _SymptomFieldState extends State<SymptomField> {
  /// Compile-time flag for the "Likely Conditions" panel only. The other
  /// two suggestion cards ("Common in {block}", "Related symptoms") stay
  /// visible unconditionally. Was hidden 2026-08-13; user asked to unhide
  /// 2026-08-19 ("below related symptoms i was hide a card — unhide it").
  /// Hide again for a build with `--dart-define=SHOW_LIKELY=false`.
  static const bool _showLikelyPanel =
      bool.fromEnvironment('SHOW_LIKELY', defaultValue: true);

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

  /// Trending term chips from the advisory API (already-selected filtered).
  List<String> get _trendTerms => [
        for (final t in (widget.trending ?? const <Map<String, dynamic>>[]))
          if ((t['term'] ?? '').toString().trim().isNotEmpty &&
              !_has((t['term'] ?? '').toString()))
            (t['term'] as Object).toString(),
      ];

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // chips + input — full row, like every other form field (the Wrap
      // used to shrink the box to its content; user 2026-08-14).
      Container(
        width: double.infinity,
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
              // Picker-only: free-text "body pain" was silently dropped
              // by the backend because symptom_master lookup is by ID
              // (user 2026-08-26). Enter now only inserts a chip when
              // the typed text exactly matches a master term — otherwise
              // the box just clears. Suggestions dropdown still filters
              // as the user types; tapping any suggestion always works.
              onSubmitted: (v) {
                final term = v.trim();
                if (term.isEmpty) { setState(() => _q = ''); return; }
                final masters = context.read<MastersStore>();
                final all = _symptomTerms(masters);
                final exact = all.firstWhere(
                  (s) => s.toLowerCase() == term.toLowerCase(),
                  orElse: () => '',
                );
                if (exact.isNotEmpty) {
                  _add(exact);
                } else {
                  _c.clear();
                  setState(() => _q = '');
                }
              },
            ),
          ),
        ]),
      ),
      // suggestion dropdown
      if (_focus.hasFocus) _suggestions(),
      // Symptom panels below the input:
      //   * "Common in {village}" — real village trends (advisory API)
      //   * "Related symptoms"    — terminology JSON standard-term matches
      //   * "Likely Conditions"   — terminology scoring (case + village)
      // Shown as soon as there is ANY signal — selected chips OR dictated
      // Observation text (user 2026-08-21: panels were dead while only
      // the Observation carried symptoms).
      if (_sel.isNotEmpty ||
          (widget.freeText ?? '').trim().isNotEmpty) ...[
        const SizedBox(height: 8),
        _geoPanel(),
        const SizedBox(height: 6),
        _relatedPanel(),
        if (_showLikelyPanel) ...[
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

  Widget _suggestions() {
    final q = _q.trim().toLowerCase();
    final children = <Widget>[];
    // Pull the symptom list from backend masters so the counsellor only
    // picks values the DB actually knows — no more "Rash selected on
    // mobile but silently dropped because symptom_master doesn't have it".
    final masters = context.watch<MastersStore>();
    final allSymptoms = _symptomTerms(masters);
    if (q.isEmpty) {
      // Quick adds on focus (the yellow rows). Village trends when the
      // caller has them (doctor case, advisory API); otherwise the first
      // symptoms of the server's own master list — never a hardcoded
      // village's list under another village's name (bug fixed 2026-08-21),
      // and never a blank dropdown (regression fixed same day).
      final trend = _trendTerms.take(6).toList();
      if (trend.isNotEmpty) {
        children.add(_sugHeader(
            'Common in ${widget.placeName ?? widget.block ?? ""}',
            const Color(0xFFFEF7E0), const Color(0xFFB8860B)));
        for (final s in trend) {
          children.add(_sugItem(s, Icons.location_on, C2.yellow));
        }
      } else {
        final common =
            allSymptoms.where((s) => !_has(s)).take(6).toList();
        if (common.isNotEmpty) {
          children.add(_sugHeader('Common symptoms',
              const Color(0xFFFEF7E0), const Color(0xFFB8860B)));
          for (final s in common) {
            children.add(_sugItem(s, Icons.location_on, C2.yellow));
          }
        }
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
      // Master-driven only (2026-08-13 rule). No fallback shown when
      // nothing matches — the dropdown simply doesn't surface a
      // suggestion for that keystroke, and the counsellor keeps typing
      // or backs off to something the master knows. Silent is better
      // than a red "Not in list" banner that adds visual noise on every
      // typo.
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

  Widget _geoPanel() {
    // Suppressed entirely on screens that opt out (Register — user
    // 2026-08-27). The village-share bonus into Likely Conditions is
    // unaffected because that reads `widget.trending` directly.
    if (widget.hideVillagePanel) return const SizedBox.shrink();
    // Loading placeholder — matches Related / Likely (user 2026-08-27).
    final place0 = widget.placeName ?? widget.block;
    final placeTitle =
        'Common in ${place0 == null || place0.isEmpty ? "village" : place0}';
    if (widget.loading) {
      return _loadingPanel(placeTitle,
          const LinearGradient(colors: [C2.navy, Color(0xFF005A8D)]));
    }
    if (widget.error) {
      return _errorPanel(placeTitle,
          const LinearGradient(colors: [C2.navy, Color(0xFF005A8D)]));
    }
    // Real village trends only (advisory API). Without them the panel
    // hides — showing another village's hardcoded list under this
    // village's name is exactly the bug this replaces.
    final btns = _trendTerms.take(5).toList();
    if (btns.isEmpty) return const SizedBox.shrink();
    final place = widget.placeName ?? widget.block;
    return _panel(
      const LinearGradient(colors: [C2.navy, Color(0xFF005A8D)]),
      Icons.location_on,
      place == null || place.isEmpty ? 'Common here' : 'Common in $place',
      btns);
  }

  Widget _loadingPanel(String title, Gradient g) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(gradient: g, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          const SizedBox(width: 12, height: 12,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white)),
          const SizedBox(width: 8),
          Text('$title — analyzing…',
              style: ct(11.5, FontWeight.w600, Colors.white)),
        ]),
      );

  /// Friendly failure strip with a Retry tap (user 2026-08-28).
  Widget _errorPanel(String title, Gradient g) => InkWell(
        onTap: widget.onRetry,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              gradient: g, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Icons.wifi_off_rounded, size: 14, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text("$title — couldn't load",
                style: ct(11.5, FontWeight.w600, Colors.white))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(children: [
                const Icon(Icons.refresh, size: 13, color: Colors.white),
                const SizedBox(width: 4),
                Text('Retry', style: ct(11.5, FontWeight.w700, Colors.white)),
              ]),
            ),
          ]),
        ),
      );

  Widget _relatedPanel() {
    // Loading state (user 2026-08-27): don't flash stale server data
    // for the previous chip while a fresh preview request is in flight.
    if (widget.loading) {
      return _loadingPanel('Related symptoms',
          const LinearGradient(colors: [C2.cyan, C2.green]));
    }
    if (widget.error) {
      return _errorPanel('Related symptoms',
          const LinearGradient(colors: [C2.cyan, C2.green]));
    }
    // Server-computed list wins when available (see field docstring).
    if (widget.serverRelated != null && widget.serverRelated!.isNotEmpty) {
      final rel = [
        for (final r in widget.serverRelated!)
          if (r.trim().isNotEmpty && !_has(r)) r,
      ];
      if (rel.isEmpty) return const SizedBox.shrink();
      return _panel(
        const LinearGradient(colors: [C2.cyan, C2.green]),
        Icons.link, 'Related symptoms', rel.take(5).toList());
    }
    // Downloaded terminology JSON — the input (incl. Hindi/Roman-Hindi,
    // "zukam", "sardi"…) resolves through the sheet's synonyms to its
    // Standard Term. Falls back to the old const map only until the
    // first terminology download lands.
    final terminology = context.watch<TerminologyStore>();
    List<String> rel;
    if (terminology.isLoaded) {
      // Selected chips + the free Observation text both resolve through
      // the sheet's synonyms to Standard Terms.
      final inputs = [
        ..._sel,
        if ((widget.freeText ?? '').trim().isNotEmpty) widget.freeText!.trim(),
      ];
      rel = terminology.relatedTerms(inputs).where((r) => !_has(r)).toList();
    } else {
      final legacy = <String>{};
      for (final s in _sel) {
        for (final r in (kRelated[s.toLowerCase()] ?? const [])) {
          if (!_has(r)) legacy.add(r);
        }
      }
      rel = legacy.toList();
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
    // Loading state — same reason as _relatedPanel (2026-08-27).
    if (widget.loading) {
      return _loadingPanel('Likely Conditions',
          const LinearGradient(colors: [C2.navy, Color(0xFF004DB3)]));
    }
    if (widget.error) {
      return _errorPanel('Likely Conditions',
          const LinearGradient(colors: [C2.navy, Color(0xFF004DB3)]));
    }
    // Server-ranked list wins when the caller supplied one (see
    // serverLikely docstring). Server uses doctor-confirmed diagnoses
    // for the village-share bonus — closer to clinical truth than the
    // client's compute over trending-symptom frequencies.
    if (widget.serverLikely != null && widget.serverLikely!.isNotEmpty) {
      String _lvl(int p) => p >= 60 ? 'h' : (p >= 35 ? 'm' : 'l');
      final scored = <({String name, int pct, String level})>[
        for (final r in widget.serverLikely!.take(5))
          (
            name: (r['condition'] ?? r['name'] ?? '').toString(),
            pct: (r['score'] ?? r['pct'] ?? 0) is num
                ? (r['score'] ?? r['pct'] ?? 0).toInt()
                : int.tryParse('${r['score'] ?? r['pct'] ?? 0}') ?? 0,
            level: _lvl((r['score'] ?? r['pct'] ?? 0) is num
                ? (r['score'] ?? r['pct'] ?? 0).toInt()
                : 0),
          ),
      ].where((c) => c.name.isNotEmpty).toList();
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
            const Icon(Icons.memory, size: 14, color: Colors.white),
            const SizedBox(width: 6),
            Text('Likely Conditions', style: ct(12, FontWeight.w700, Colors.white)),
          ]),
          const SizedBox(height: 8),
          ...scored.map((d) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Expanded(child: Text(d.name, maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ct(12, FontWeight.w500, Colors.white))),
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
              SizedBox(width: 34, child: Text('${d.pct}%',
                textAlign: TextAlign.right,
                style: ct(11.5, FontWeight.w700, fill(d.level)))),
            ]),
          )),
        ]),
      );
    }
    // Terminology-driven scoring: how much of THIS case points at the
    // condition (0.7) + the condition's share of the village trend (0.3).
    // Same formula as the server's advisory endpoint. Legacy const-map
    // scoring only until the first terminology download.
    final terminology = context.watch<TerminologyStore>();
    final List<({String name, int pct, String level})> scored;
    if (terminology.isLoaded) {
      final inputs = [
        ..._sel,
        if ((widget.freeText ?? '').trim().isNotEmpty) widget.freeText!.trim(),
      ];
      scored = [
        for (final c in terminology.likelyConditions(inputs,
            trending: widget.trending ?? const []))
          (name: c.name, pct: c.pct, level: c.level),
      ];
    } else {
      scored = [
        for (final d in scoreDiseases(_sel, widget.block))
          (name: d.name, pct: d.pct, level: d.level),
      ];
    }
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
