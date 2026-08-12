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

  final BootstrapApi api;
  MastersStore(this.api);

  Map<String, dynamic>? _payload;
  DateTime? _fetchedAt;
  int? _mastersVersion;
  bool _loading = false;

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
  List<String> masterStrings(String key) {
    final v = masters?[key];
    if (v is List) return [ for (final e in v) if (e != null) e.toString() ];
    return const [];
  }

  List<Map<String, dynamic>> masterRows(String key) {
    final v = masters?[key];
    if (v is List) {
      return [ for (final e in v) if (e is Map) e.cast<String, dynamic>() ];
    }
    return const [];
  }

  /// Load the last cached payload from disk. Call on app start so the
  /// first frame of the shell doesn't wait for the network.
  Future<void> hydrate() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kBootstrap);
    if (raw == null) return;
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
    } catch (_) {
      // Bootstrap is best-effort at startup — a network hiccup should
      // not sign the user out. The cached payload keeps rendering.
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kBootstrap);
    await p.remove(_kFetchedAt);
    await p.remove(_kMastersVer);
    _payload = null;
    _fetchedAt = null;
    _mastersVersion = null;
    notifyListeners();
  }
}
