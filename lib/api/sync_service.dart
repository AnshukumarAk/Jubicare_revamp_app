import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_errors.dart';
import 'sync_api.dart';
import 'uploads_api.dart';

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
  final UploadsApi? uploads;
  final Connectivity _connectivity;

  SyncService(this.api, {UploadsApi? uploads, Connectivity? connectivity})
      : uploads = uploads,
        _connectivity = connectivity ?? Connectivity() {
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

  /// True while the given action still sits in the offline queue.
  /// Register/Case submit handlers poll this to know when the row has
  /// been shipped to the server, so the "Pending" chip on Home is
  /// gone before the snackbar / redirect fires (user 2026-09-10 "still
  /// showing sync then after some time sent").
  bool hasPending(String clientActionId) =>
      _queue.any((a) => a.clientActionId == clientActionId);

  /// Await until [clientActionId] leaves the queue (drain succeeded)
  /// or [timeout] elapses. Returns true when drained cleanly, false
  /// on timeout / offline — the caller then treats it as "queued for
  /// later" instead of blocking the submit forever.
  Future<bool> waitUntilDrained(String clientActionId,
      {Duration timeout = const Duration(seconds: 8)}) async {
    final deadline = DateTime.now().add(timeout);
    // Kick a drain in case none is running.
    unawaited(drain());
    while (DateTime.now().isBefore(deadline)) {
      if (!hasPending(clientActionId)) return true;
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    return !hasPending(clientActionId);
  }

  /// Enqueue a mutation. Call from screen submit handlers. Returns the
  /// client_action_id so callers can correlate future drain results
  /// back to the UI row that triggered them.
  Future<String> enqueue({required String kind, required Map<String, dynamic> payload}) async {
    await hydrate();
    final id = _newClientActionId();
    print('[JC] sync.enqueue kind=' + kind + ' id=' + id);
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
        // ── Photo lift (bug fix 2026-08-20: "offline photo path was
        // going into DB as /data/user/0/.../wm_XXX.jpg"). Any queued
        // action whose payload carries LOCAL device paths gets its
        // photos uploaded to /mobile/uploads NOW, and the payload
        // rewritten with the returned server filenames before push.
        // Uploads that fail are left as-is so the server drops them
        // gracefully rather than blocking the whole batch.
        if (uploads != null) {
          for (var i = 0; i < _queue.length && i < 200; i++) {
            final q = _queue[i];
            final lifted = await _liftPhotos(q.payload);
            if (lifted != null) {
              _queue[i] = QueuedAction(
                clientActionId: q.clientActionId,
                kind: q.kind,
                payload: lifted,
                enqueuedAt: q.enqueuedAt,
              );
            }
          }
          await _persist();
        }
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
            print('[JC] sync.push network unreachable/timeout — will retry');
            // Nothing to do — try again on the next connectivity event.
            break;
          }
          print('[JC] sync.push error ' + e.code.toString() + ' ' + e.message);
          // Session death or a server-side outage — leave the queue
          // alone and let the caller / next drain try again.
          break;
        }
        print('[JC] sync.push result applied=' + res.applied.toString()
            + ' rejected=' + res.rejected.toString()
            + ' failed=' + res.failed.toString());
        for (final r in res.results) {
          if (r.status != 'applied') {
            print('[JC]   -> ' + r.clientActionId + ' ' + r.status
                + ' ' + (r.code ?? '') + ' ' + (r.message ?? ''));
          }
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

  /// Detect + upload any local file paths in a queued payload. Returns
  /// a NEW payload with server filenames, or null when nothing changed.
  /// Handles the four attachment shapes the app queues:
  ///   • attachments[].file_path — patient.register (prescriptions)
  ///   • photo_key                — attendance.check_in / check_out
  ///   • photos[]                 — camp.create (camp gallery)
  ///   • invoice_path             — requisition.receive (delivery invoice)
  Future<Map<String, dynamic>?> _liftPhotos(Map<String, dynamic> payload) async {
    if (uploads == null) return null;
    var changed = false;
    final next = Map<String, dynamic>.of(payload);

    Future<String?> lift(String? raw) async {
      if (raw == null || raw.trim().isEmpty) return raw;
      // Full URL → already hosted, nothing to do.
      if (raw.startsWith('http')) return raw;
      // Bare filename (no separators) → already a server file_name.
      if (!raw.contains('/') && !raw.contains(r'\')) return raw;
      // BUG FIX 2026-08-20: the earlier `raw.startsWith('/')` shortcut
      // swallowed Android local paths (`/data/user/0/…/wm_X.jpg`) so
      // they were pushed to the server AS-IS. Now the ONLY authority
      // is `File.existsSync()` — if the string points at a real file
      // on disk, upload it; otherwise treat it as a server name.
      if (!File(raw).existsSync()) return raw;
      try {
        final res = await uploads!.uploadImage(raw)
            .timeout(const Duration(seconds: 25));
        final name = (res['file_name'] as String?)?.trim();
        return (name != null && name.isNotEmpty) ? name : raw;
      } catch (_) {
        return raw; // upload failed — leave for the next drain to retry
      }
    }

    // ── attachments[].file_path ──
    final atts = next['attachments'];
    if (atts is List) {
      final newAtts = <dynamic>[];
      for (final a in atts) {
        if (a is Map) {
          final path = (a['file_path'] ?? '').toString();
          final lifted = await lift(path);
          if (lifted != null && lifted != path) {
            newAtts.add({...a, 'file_path': lifted});
            changed = true;
          } else {
            newAtts.add(a);
          }
        } else {
          newAtts.add(a);
        }
      }
      if (changed) next['attachments'] = newAtts;
    }

    // ── photo_key (attendance selfie) ──
    final pk = (next['photo_key'] ?? '').toString();
    final liftedPk = await lift(pk);
    if (liftedPk != null && liftedPk != pk && liftedPk.isNotEmpty) {
      next['photo_key'] = liftedPk;
      changed = true;
    }

    // ── invoice_path (requisition.receive) ──
    final inv = (next['invoice_path'] ?? '').toString();
    final liftedInv = await lift(inv);
    if (liftedInv != null && liftedInv != inv && liftedInv.isNotEmpty) {
      next['invoice_path'] = liftedInv;
      changed = true;
    }

    // ── photos[] (camp gallery) ──
    final ph = next['photos'];
    if (ph is List) {
      final newPh = <dynamic>[];
      var any = false;
      for (final p in ph) {
        final s = (p ?? '').toString();
        final lifted = await lift(s);
        if (lifted != null && lifted != s) any = true;
        newPh.add(lifted ?? s);
      }
      if (any) {
        next['photos'] = newPh;
        changed = true;
      }
    }

    return changed ? next : null;
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
