/// The single place every server address lives.
///
/// Nothing else in the app may hardcode a host. To point a build at another
/// environment, either edit these defaults or override at build time:
///
///   flutter build apk --release \
///     --dart-define=API_BASE=https://staging.example.com \
///     --dart-define=UPLOADS_BASE=https://staging.example.com/media
class AppConfig {
  AppConfig._();

  /// Django backend origin. The mobile contract is mounted at
  /// [apiPrefix] below it ([apiBase] + `/api/m/auth/login`, …).
  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://revamp-back2.indevconsultancy.in',
  );

  /// Mount point of the mobile API on [apiBase] — the Django `mobile` app
  /// lives at /api/m (the web portal owns /api).
  static const String apiPrefix = '/api/m';

  /// How much history the handset downloads for its lists (attendance,
  /// camps, requisitions) — every role, every user
  /// (user rule 2026-08-21). On-demand drill-downs (patient search /
  /// clinical history) stay full: they are pulled per patient, not bulk.
  static const int dataWindowDays = 8;

  /// Device reports land monthly, so the audit trail needs a much longer
  /// look-back than the attendance/camp lists (user 2026-08-29:
  /// "devices 8 month"). Matched on the server default (240 days).
  static const int deviceWindowDays = 240;

  /// ISO date `dataWindowDays` ago — ready for date_from params.
  static String get dataWindowFrom => DateTime.now()
      .subtract(const Duration(days: dataWindowDays))
      .toIso8601String()
      .substring(0, 10);

  /// ISO date `deviceWindowDays` ago — used only by the Devices tab.
  static String get deviceWindowFrom => DateTime.now()
      .subtract(const Duration(days: deviceWindowDays))
      .toIso8601String()
      .substring(0, 10);

  /// Where uploaded files (patient docs, selfies, camp photos, invoices)
  /// are published. The server's nginx exposes Django's MEDIA_ROOT on the
  /// FRONT domain (verified 2026-08-21: the same file 200s on
  /// revamp-front2 and 404s on revamp-back2). Photos resolve as
  /// `$uploadsBase/patient_docs/<file_name>`.
  static const String uploadsBase = String.fromEnvironment(
    'UPLOADS_BASE',
    defaultValue: 'https://revamp-front2.indevconsultancy.in/media',
  );
}
