import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bootstrap_api.dart';

/// Caches the /mobile/bootstrap payload (v2 §2) — user, facility,
/// today's camp, and every master list. Screens read from here instead
/// of hitting the network on every mount.
///
/// Persisted so a cold start on one bar of signal still renders Home;
/// refreshed from the server whenever `refresh()` is called or the
/// stored payload is older than the staleness window.
class MastersStore extends ChangeNotifier {
  static const _kBootstrap  = 'bootstrap_payload_v2';
  static const _kFetchedAt  = 'bootstrap_fetched_at';
  static const _kMastersVer = 'bootstrap_masters_version';
  // Geography cascade cache (rule 2026-08-13): the facility's district's
  // blocks, each carrying its villages. Downloaded right after login /
  // bootstrap refresh from /masters/blocks + /masters/villages so the
  // Register + Status dropdowns run off live DB names instead of the
  // hardcoded kBlockVillages map.
  static const _kGeoBlocks   = 'geo_blocks_v1';
  static const _kGeoDistrict = 'geo_district_id';

  final BootstrapApi api;
  MastersStore(this.api);

  Map<String, dynamic>? _payload;
  DateTime? _fetchedAt;
  int? _mastersVersion;
  bool _loading = false;

  /// [{block_id, block_name, villages: [{village_id, village_name}]}]
  List<Map<String, dynamic>> _geoBlocks = [];
  bool _geoLoading = false;

  Map<String, dynamic>? get payload => _payload;
  bool get isLoaded => _payload != null;
  bool get isLoading => _loading;
  DateTime? get fetchedAt => _fetchedAt;
  int? get mastersVersion => _mastersVersion;

  Map<String, dynamic>? get user => _sub('user');
  Map<String, dynamic>? get facility => _sub('facility');
  Map<String, dynamic>? get todayCamp => _sub('today_camp');
  Map<String, dynamic>? get masters => _sub('masters');

  Map<String, dynamic>? _sub(String k) {
    final v = _payload?[k];
    return v is Map ? v.cast<String, dynamic>() : null;
  }

  /// Convenience readers for the enum lists inside `masters` — used to
  /// seed dropdowns instead of hand-typed constants.
  /// Names from a master list. Handles BOTH shapes bootstrap emits:
  ///   * plain `List<String>` (older format for enums)
  ///   * `List<{id, name}>` (id-first format, 2026-09-10 upgrade)
  /// so a mixed bootstrap response never surfaces "{id: 3, name: O+}"
  /// as a dropdown label.
  List<String> masterStrings(String key) {
    final v = masters?[key];
    if (v is! List) return const [];
    return [
      for (final e in v)
        if (e is String) e
        else if (e is Map)
          if ((e['name'] ?? e['term'] ?? e['code'] ?? e['label']) != null)
            (e['name'] ?? e['term'] ?? e['code'] ?? e['label']).toString(),
    ];
  }

  /// Lookup the pk id for a value in one of the master enums bootstrap
  /// now ships as `[{id, name}]` rows (blood_groups, camp_types,
  /// frequencies, and any other rows-shape master). Returns null when
  /// the value isn't in the master or the row doesn't carry an id
  /// (fallback rows do carry `id: null`).
  int? masterIdOf(String key, String? name) {
    if (name == null || name.trim().isEmpty) return null;
    final target = name.trim().toLowerCase();
    for (final r in masterRows(key)) {
      final n = (r['name'] ?? r['term'] ?? r['code'] ?? r['label'])?.toString();
      if (n != null && n.trim().toLowerCase() == target) {
        final id = r['id'];
        if (id is int) return id;
        if (id is num) return id.toInt();
        return int.tryParse(id?.toString() ?? '');
      }
    }
    return null;
  }

  /// Resolve a lab test name to its master id.
  /// Tries `standard_name` first (the advisory's masterName), then falls
  /// back to `name` (the original DB name). Returns null when no match.
  int? labTestIdOf(String testName) {
    if (testName.trim().isEmpty) return null;
    final target = testName.trim().toLowerCase();
    for (final r in masterRows('lab_tests')) {
      final sn = (r['standard_name'] ?? '').toString().trim().toLowerCase();
      if (sn.isNotEmpty && sn == target) {
        return _extractId(r);
      }
    }
    // Fallback: match by the original test name.
    for (final r in masterRows('lab_tests')) {
      final n = (r['name'] ?? '').toString().trim().toLowerCase();
      if (n.isNotEmpty && n == target) {
        return _extractId(r);
      }
    }
    return null;
  }

  static int? _extractId(Map<String, dynamic> r) {
    final id = r['id'];
    if (id is int) return id;
    if (id is num) return id.toInt();
    return int.tryParse(id?.toString() ?? '');
  }

  /// Medicine names from the server master (bootstrap). The requisition
  /// and prescription pickers MUST offer only names the backend can match
  /// — a hardcoded name the master lacks fails with
  /// "No line matched a known medicine" (bug found live 2026-08-21).
  List<String> medicineNames() {
    return [
      for (final r in masterRows('medicines'))
        if ((r['name'] ?? r['medicine_name']) != null)
          (r['name'] ?? r['medicine_name']).toString()
    ];
  }

  List<Map<String, dynamic>> masterRows(String key) {
    final v = masters?[key];
    if (v is List) {
      return [ for (final e in v) if (e is Map) e.cast<String, dynamic>() ];
    }
    return const [];
  }

  // ── Geography readers ──
  bool get hasGeo => _geoBlocks.isNotEmpty;

  /// Block names of the facility's district, sorted by the server.
  List<String> get geoBlockNames =>
      [for (final b in _geoBlocks) (b['block_name'] ?? '').toString()];

  /// Villages of one block (by display name). Empty when unknown.
  List<String> geoVillagesOf(String blockName) {
    for (final b in _geoBlocks) {
      if ((b['block_name'] ?? '').toString() == blockName) {
        final vs = b['villages'];
        if (vs is List) {
          return [for (final v in vs) if (v is Map) (v['village_name'] ?? '').toString()];
        }
      }
    }
    return const [];
  }

  /// Village id for a (block name, village name) pair — needed by the
  /// counsellor Register screen to preview village-boosted advisory
  /// (user 2026-08-27). Returns null when unknown.
  int? geoVillageId(String? blockName, String? villageName) {
    if (blockName == null || villageName == null ||
        blockName.isEmpty || villageName.isEmpty) return null;
    for (final b in _geoBlocks) {
      if ((b['block_name'] ?? '').toString() != blockName) continue;
      final vs = b['villages'];
      if (vs is! List) return null;
      for (final v in vs) {
        if (v is Map && (v['village_name'] ?? '').toString() == villageName) {
          final id = v['village_id'];
          if (id is int) return id;
          if (id is num) return id.toInt();
          return int.tryParse(id?.toString() ?? '');
        }
      }
    }
    return null;
  }

  /// Every village across the district — the Status search dropdown.
  List<String> get geoAllVillages => [
        for (final b in _geoBlocks)
          if (b['villages'] is List)
            for (final v in (b['villages'] as List))
              if (v is Map) (v['village_name'] ?? '').toString()
      ];

  /// Load the last cached payload from disk. Call on app start so the
  /// first frame of the shell doesn't wait for the network.
  Future<void> hydrate() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kBootstrap);
    // Geography cache loads independently of the bootstrap payload so a
    // partially-written cache can't blank both.
    final geoRaw = p.getString(_kGeoBlocks);
    if (geoRaw != null) {
      try {
        final decoded = jsonDecode(geoRaw);
        if (decoded is List) {
          _geoBlocks = [for (final e in decoded) if (e is Map) e.cast<String, dynamic>()];
        }
      } catch (_) { /* stale geo cache — next refresh rebuilds it */ }
    }
    if (raw == null) { if (_geoBlocks.isNotEmpty) notifyListeners(); return; }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        _payload = decoded.cast<String, dynamic>();
        final ts = p.getString(_kFetchedAt);
        _fetchedAt = ts == null ? null : DateTime.tryParse(ts);
        _mastersVersion = p.getInt(_kMastersVer);
        notifyListeners();
      }
    } catch (_) { /* ignore — stale cache, we'll refresh */ }
  }

  /// Pull the latest bootstrap from the server and persist. Safe to
  /// call whenever — will no-op if a refresh is already running.
  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();
    try {
      final fresh = await api.fetch();
      _payload = fresh;
      _fetchedAt = DateTime.now();
      _mastersVersion = (fresh['masters_version'] as num?)?.toInt();
      final p = await SharedPreferences.getInstance();
      await p.setString(_kBootstrap, jsonEncode(fresh));
      await p.setString(_kFetchedAt, _fetchedAt!.toIso8601String());
      if (_mastersVersion != null) await p.setInt(_kMastersVer, _mastersVersion!);
      // Geography cascade rides on every successful bootstrap refresh —
      // that includes the one fired right after login, which is where the
      // district_id first becomes known (user rule 2026-08-13).
      final districtId = (facility?['district_id'] as num?)?.toInt();
      if (districtId != null) unawaited(refreshGeo(districtId));
    } catch (_) {
      // Bootstrap is best-effort at startup — a network hiccup should
      // not sign the user out. The cached payload keeps rendering.
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Download the district's blocks + each block's villages and cache
  /// them. Roughly 1 + N requests (N = blocks in district, typically
  /// 5-15); villages fetch in parallel so wall-clock is one round trip
  /// after the block list. Failures keep the previous cache.
  Future<void> refreshGeo(int districtId) async {
    if (_geoLoading) return;
    _geoLoading = true;
    try {
      final blocks = await api.blocks(districtId);
      final withVillages = await Future.wait(blocks.map((b) async {
        final id = (b['block_id'] as num?)?.toInt();
        List<Map<String, dynamic>> vs = const [];
        if (id != null) {
          try { vs = await api.villages(id); } catch (_) { /* keep empty */ }
        }
        return {
          'block_id':   b['block_id'],
          'block_name': b['block_name'],
          'villages':   vs,
        };
      }));
      if (withVillages.isNotEmpty) {
        _geoBlocks = withVillages;
        final p = await SharedPreferences.getInstance();
        await p.setString(_kGeoBlocks, jsonEncode(_geoBlocks));
        await p.setInt(_kGeoDistrict, districtId);
        notifyListeners();
      }
    } catch (_) {
      // Offline / server hiccup — cached (or hardcoded fallback) geo
      // keeps the dropdowns usable.
    } finally {
      _geoLoading = false;
    }
  }

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kBootstrap);
    await p.remove(_kFetchedAt);
    await p.remove(_kMastersVer);
    await p.remove(_kGeoBlocks);
    await p.remove(_kGeoDistrict);
    _payload = null;
    _fetchedAt = null;
    _mastersVersion = null;
    _geoBlocks = [];
    notifyListeners();
  }
}
