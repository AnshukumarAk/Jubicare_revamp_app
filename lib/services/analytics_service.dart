import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Thin wrapper around FirebaseAnalytics so the rest of the app can
/// log events without caring whether Firebase actually initialised
/// (user 2026-10-13). If google-services.json is missing or init
/// failed, every call becomes a safe no-op.
///
/// Standard event taxonomy: snake_case names, string params. Avoid
/// PII — never pass patient names, phone numbers, or free-text. Role
/// label and screen name are OK.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  FirebaseAnalytics? _fa;
  bool _ready = false;

  /// Wire up after Firebase.initializeApp — safe to call multiple
  /// times. If Firebase has no apps registered yet, stays disabled.
  Future<void> init() async {
    if (_ready) return;
    try {
      if (Firebase.apps.isEmpty) return;
      _fa = FirebaseAnalytics.instance;
      await _fa!.setAnalyticsCollectionEnabled(true);
      _ready = true;
      if (kDebugMode) debugPrint('[analytics] ready');
    } catch (e) {
      if (kDebugMode) debugPrint('[analytics] init failed — $e');
    }
  }

  /// NavigatorObserver instance so routes auto-log as screen_view
  /// events. Add it to MaterialApp.navigatorObservers.
  NavigatorObserver? get observer =>
      _fa == null ? null : FirebaseAnalyticsObserver(analytics: _fa!);

  /// Identify the current user — ID is the backend user id, role is
  /// one of counsellor/doctor/pharmacist. Never pass the raw name.
  Future<void> setUser({required String userId, required String role}) async {
    if (!_ready) return;
    try {
      await _fa!.setUserId(id: userId);
      await _fa!.setUserProperty(name: 'role', value: role);
    } catch (_) {/* non-fatal */}
  }

  Future<void> clearUser() async {
    if (!_ready) return;
    try {
      await _fa!.setUserId(id: null);
    } catch (_) {}
  }

  /// Log an arbitrary custom event. Params must be strings or nums.
  Future<void> logEvent(String name, {Map<String, Object>? params}) async {
    if (!_ready) return;
    try {
      await _fa!.logEvent(name: name, parameters: params);
    } catch (_) {}
  }

  // Convenience shortcuts for the events we actually fire.
  Future<void> logLogin(String role) =>
      logEvent('login', params: {'role': role});
  Future<void> logLogout(String role) =>
      logEvent('logout', params: {'role': role});
  Future<void> logPatientRegistered(String role) =>
      logEvent('patient_registered', params: {'role': role});
  Future<void> logCaseSubmitted() => logEvent('case_submitted');
  Future<void> logDispenseConfirmed() => logEvent('dispense_confirmed');
  Future<void> logRequisitionSubmitted() =>
      logEvent('requisition_submitted');
  Future<void> logCheckIn() => logEvent('check_in');
  Future<void> logCheckOut() => logEvent('check_out');
}
