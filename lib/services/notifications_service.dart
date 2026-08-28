import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'notifications_store.dart';

/// Local notifications for the Attend flow (ATTEND task D2, 2026-08-18):
/// after a successful check-in, remind the user at +3 h, +6 h and +9 h to
/// check out; all three are cancelled the moment the check-out lands.
///
/// Local-only by design — works fully offline (user rule 2026-08-18) and
/// needs no Firebase. The +Nh instants are computed as absolute moments
/// (UTC now + N hours), so device timezone quirks cannot shift them.
///
/// Android 13+ shows nothing without POST_NOTIFICATIONS consent — [init]
/// asks once. Scheduling uses inexact alarms: nobody needs a to-the-second
/// reminder, and exact alarms would demand the SCHEDULE_EXACT_ALARM
/// permission dance on Android 12+.
class NotificationsService {
  NotificationsService._();
  static final NotificationsService instance = NotificationsService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _checkoutIds = [101, 102, 103];

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: android),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _ready = true;
  }

  /// Schedule the 3/6/9-hour check-out reminders. Replaces any previous
  /// set (same ids), so a re-check-in after midnight resets cleanly.
  Future<void> scheduleCheckoutReminders({required String checkInLabel}) async {
    try {
      await init();
      for (var i = 0; i < _checkoutIds.length; i++) {
        final hours = (i + 1) * 3;
        await _plugin.zonedSchedule(
          id: _checkoutIds[i],
          title: 'Check-out pending',
          body:
              'You checked in at $checkInLabel. Please mark your check-out.',
          scheduledDate: tz.TZDateTime.now(tz.UTC).add(Duration(hours: hours)),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'attend', 'Attendance',
              channelDescription: 'Check-out reminders',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (_) {
      // Notifications are a courtesy — never let them break a check-in.
    }
  }

  /// Cancel all pending check-out reminders (called on check-out).
  Future<void> cancelCheckoutReminders() async {
    try {
      await init();
      for (final id in _checkoutIds) {
        await _plugin.cancel(id: id);
      }
    } catch (_) {/* ignore */}
  }

  int _fcmSeq = 500;

  /// Show a notification immediately — used for FCM messages that arrive
  /// while the app is in the FOREGROUND (Android suppresses the system
  /// banner there, so we render it ourselves; background/killed states
  /// are handled by the OS automatically). ATTEND task D1. Every shown
  /// notification also lands in the per-user history (user 2026-08-19).
  Future<void> showNow({required String title, required String body}) async {
    try {
      await init();
      await _plugin.show(
        id: _fcmSeq++,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'attend', 'Attendance',
            channelDescription: 'Attendance updates',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
      unawaited(NotificationsStore.add(title: title, body: body));
    } catch (_) {/* courtesy only */}
  }

  // ── monthly device-status reminders (user 2026-08-19) ─────────────
  // If August's device status was submitted, from September 1st the
  // counsellor gets a daily reminder — EVERY day of the month, 1st to
  // the last date (user: "1 से 30 तारीख़ तक") — until September's is
  // submitted. Local-only: works offline, no cron. ~09:30 daily;
  // cancelled the moment that month's submission lands, then re-armed
  // for the month after.

  static const _deviceIdBase = 200; // ids 201..231

  /// Arm daily reminders for every day of [year]/[month] at 09:30 device
  /// time. Instants already in the past are skipped, so calling this
  /// mid-month only schedules the remaining days.
  Future<void> scheduleDeviceStatusReminders(
      {required int year, required int month}) async {
    try {
      await init();
      const monthNames = ['Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'];
      final label = '${monthNames[month - 1]} $year';
      // Day 0 of the next month = this month's last date (28/29/30/31).
      final lastDay = DateTime(year, month + 1, 0).day;
      for (var day = 1; day <= lastDay; day++) {
        final local = DateTime(year, month, day, 9, 30);
        if (!local.isAfter(DateTime.now())) continue;
        final when = tz.TZDateTime.from(local.toUtc(), tz.UTC);
        await _plugin.zonedSchedule(
          id: _deviceIdBase + day,
          title: 'Device status pending',
          body: 'Please submit $label device status in the Devices tab.',
          scheduledDate: when,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'attend', 'Attendance',
              channelDescription: 'Monthly device status reminders',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (_) {/* courtesy only */}
  }

  /// Cancel the pending device-status reminders (that month is submitted).
  Future<void> cancelDeviceStatusReminders() async {
    try {
      await init();
      for (var day = 1; day <= 31; day++) {
        await _plugin.cancel(id: _deviceIdBase + day);
      }
    } catch (_) {/* ignore */}
  }
}
