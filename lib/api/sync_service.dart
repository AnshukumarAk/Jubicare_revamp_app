import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_errors.dart';
import 'sync_api.dart';

/// Offline write buffer + drainer for /mobile/sync/push (v2 §4).
///
/// The queue holds actions the user completed while offline (or while
/// online — every mutation the shipped screens make is enqueued so
/// there is exactly one write path). On foreground / reconnect, the
/// service drains the queue in batches of 200 through
/// [SyncApi.push], honouring the per-action status codes:
///
///   * `applied`  → drop from queue
///   * `rejected` → drop from queue (server will never accept it,
///                   `retry: false` per §4)
///   * `failed`   → keep for next drain (server-side / 5xx, retry)
///
/// `client_action_id` is generated once per enqueue and preserved
/// across app restarts. Replaying the same batch is safe — the server
/// returns the original result with `duplicate: true`.
class SyncService extends ChangeNotifier {
  static const _kQueueKey = 'sync_push_queue';

  final SyncApi api;
  final Connectivity _connectivity;

  SyncService(this.api, {Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity() {
    _connectivity.onConnectivityChanged.listen((r) {
      final online = r.any((c) => c != ConnectivityResult.none);
      if (online) unawaited(drain());
    });
  }

  final List<QueuedAction> _queue = [];
  bool _loaded = false;
  bool _draining = false;
  DateTime? _lastDrainAt;
  int _lastApplied = 0, _lastRejected = 0, _lastFailed = 0;

  int get pending => _queue.length;
  bool get isDraining => _draining;
  DateTime? get lastDrainAt => _lastDrainAt;
  int get lastApplied  => _lastApplied;
  int get lastRejected => _lastRejected;
  int get lastFailed   => _lastFailed;

  /// Read the persisted queue from disk. Idempotent.
  Future<void> hydrate() async {
    if (_loaded) return;
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kQueueKey);
    _loaded = true;
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        _queue
          ..clear()
          ..addAll([ for (final e in decoded) if (e is Map) QueuedAction.fromJson(e.cast<String, dynamic>()) ]);
        notifyListeners();
      }
    } catch (_) { /* corrupted cache; start clean */ }
  }

  /// Enqueue a mutation. Call from screen submit handlers. Returns the
  /// client_action_id so callers can correlate future drain results
  /// back to the UI row that triggered them.
  Future<String> enqueue({required String kind, required Map<String, dynamic> payload}) async {
    await hydrate();
    final id = _newClientActionId();
    _queue.add(QueuedAction(clientActionId: id, kind: kind, payload: payload, enqueuedAt: DateTime.now()));
    await _persist();
    notifyListeners();
    // Fire-and-forget: attempt to drain right away when we're online.
    unawaited(drain());
    return id;
  }

  /// Drain the queue. Safe to call any number of times — a single
  /// drain runs at a time; overlapping calls no-op.
  Future<void> drain() async {
    await hydrate();
    if (_draining || _queue.isEmpty) return;
    _draining = true;
    notifyListeners();
    try {
      while (_queue.isNotEmpty) {
        // Server accepts up to 200 actions per push (§4).
        final chunk = _queue.take(200).toList();
        late final PushResponse res;
        try {
          res = await api.push([
            for (final q in chunk)
              SyncAction(clientActionId: q.clientActionId, kind: q.kind, payload: q.payload),
          ]);
        } on ApiException catch (e) {
          if (e.code == ApiErrorCode.networkUnreachable) {
            // Nothing to do — try again on the next connectivity event.
            break;
          }
          // Session death or a server-side outage — leave the queue
          // alone and let the caller / next drain try again.
          break;
        }
        _lastApplied  = res.applied;
        _lastRejected = res.rejected;
        _lastFailed   = res.failed;
        _lastDrainAt  = DateTime.now();

        // Drop applied + rejected by client_action_id. Failed stay.
        final drop = <String>{
          for (final r in res.results)
            if (!r.retry) r.clientActionId,
        };
        _queue.removeWhere((q) => drop.contains(q.clientActionId));
        await _persist();
        notifyListeners();
        // If the server didn't accept the whole chunk (all rejected /
        // all failed) stop so we don't spin forever.
        if (drop.isEmpty) break;
      }
    } finally {
      _draining = false;
      notifyListeners();
    }
  }

  Future<void> clear() async {
    _queue.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kQueueKey, jsonEncode([ for (final q in _queue) q.toJson() ]));
  }

  int _seq = 0;
  String _newClientActionId() {
    // Deterministic, no imports of `dart:math`: microsecond + counter.
    final now = DateTime.now().microsecondsSinceEpoch;
    _seq = (_seq + 1) & 0xFFFF;
    return 'act-$now-${_seq.toRadixString(16).padLeft(4, '0')}';
  }
}

class QueuedAction {
  final String clientActionId;
  final String kind;
  final Map<String, dynamic> payload;
  final DateTime enqueuedAt;
  const QueuedAction({
    required this.clientActionId,
    required this.kind,
    required this.payload,
    required this.enqueuedAt,
  });

  Map<String, dynamic> toJson() => {
        'client_action_id': clientActionId,
        'kind':             kind,
        'payload':          payload,
        'enqueued_at':      enqueuedAt.toIso8601String(),
      };

  factory QueuedAction.fromJson(Map<String, dynamic> j) => QueuedAction(
        clientActionId: (j['client_action_id'] as String?) ?? '',
        kind:           (j['kind']             as String?) ?? '',
        payload:        (j['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
        enqueuedAt:     DateTime.tryParse(j['enqueued_at'] as String? ?? '') ?? DateTime.now(),
      );
}
