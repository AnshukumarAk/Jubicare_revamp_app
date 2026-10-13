import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'api/api_client.dart';
import 'api/appointments_api.dart';
import 'api/attendance_api.dart';
import 'api/auth_api.dart';
import 'api/bootstrap_api.dart';
import 'api/camps_api.dart';
import 'api/devices_api.dart';
import 'api/masters_store.dart';
import 'api/patients_api.dart';
import 'api/queues_api.dart';
import 'api/requisitions_api.dart';
import 'api/staff_api.dart';
import 'api/sync_api.dart';
import 'api/sync_service.dart';
import 'api/token_store.dart';
import 'api/uploads_api.dart';
import 'models/models.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'services/fcm_service.dart';
import 'services/notification_router.dart';
import 'services/terminology_store.dart';
import 'services/notifications_service.dart';
import 'services/notifications_store.dart';
import 'state/app_state.dart';
import 'state/auth_persistence.dart';
import 'theme/app_theme.dart';
import 'counsellor/cstate.dart';
import 'counsellor/shell.dart';
import 'doctor/doctor_db_loader.dart';
import 'doctor/dshell.dart';
import 'pharmacist/pshell.dart';
import 'screens/splash.dart';
import 'services/connectivity_service.dart';
import 'services/firebase_service.dart';
import 'services/location_service.dart';

/// Global navigator key so onSignedOutRemotely can bounce back to the
/// login screen from anywhere — background timers, api-level 401
/// handlers, isolate callbacks — without needing a BuildContext
/// (user 2026-09-10).
final GlobalKey<NavigatorState> _rootNavigator = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Lock the app to portrait orientation — MMU screens are designed
  // portrait-only; landscape breaks form layouts (user 2026-09-11).
  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  // One-time cleanup: the removed on-device ASR experiments (Whisper /
  // sherpa-Dolphin, 2026-08-18) left ~340 MB of model files in app
  // storage on test phones. Fire-and-forget delete; no-op once gone.
  unawaited(_cleanupRemovedAsrModels());
  // Check-out reminder channel + Android 13 notification consent
  // (ATTEND task D2). Fire-and-forget — reminders are a courtesy.
  unawaited(NotificationsService.instance.init());
  // Initialise Firebase once at startup. Non-blocking failure — if
  // google-services.json is missing the LocationService just buffers locally
  // and the app runs otherwise normally.
  final firebase = FirebaseService();

  // FCM background/killed-state hook (ATTEND task D1) — must be a
  // top-level function registered before runApp. Notification messages
  // themselves are displayed by the OS; this keeps data messages alive.
  try {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (_) {/* Firebase not initialised — push simply stays off */}

  // Build the API layer once — the client is stateless w.r.t. the user
  // (tokens live in TokenStore, session in AuthPersistence) so a single
  // instance is safe for the whole app lifetime.
  final apiClient = ApiClient(
    onSignedOutRemotely: () async {
      await TokenStore.clear();
      await AuthPersistence.clear();
      // Bounce the user back to the login screen — clearing the prefs
      // alone left the shell mounted with dead tokens, so a stale
      // Android-11-OEM restore of a doctor session used to open the
      // Doctor shell directly (user 2026-09-10). Uses the global
      // navigator key so the callback works from anywhere in the tree,
      // including background timers and the api layer.
      final nav = _rootNavigator.currentState;
      if (nav != null) {
        await nav.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SplashScreen()),
          (_) => false,
        );
      }
    },
  );
  final authApi          = AuthApi(apiClient);
  final bootstrapApi     = BootstrapApi(apiClient);
  final syncApi          = SyncApi(apiClient);
  final queuesApi        = QueuesApi(apiClient);
  final patientsApi      = PatientsApi(apiClient);
  final appointmentsApi  = AppointmentsApi(apiClient);
  final attendanceApi    = AttendanceApi(apiClient);
  final campsApi         = CampsApi(apiClient);
  final devicesApi       = DevicesApi(apiClient);
  final requisitionsApi  = RequisitionsApi(apiClient);
  final staffApi         = StaffApi(apiClient);
  final uploadsApi       = UploadsApi(apiClient);

  final mastersStore = MastersStore(bootstrapApi);
  final terminologyStore = TerminologyStore(apiClient);
  final syncService = SyncService(syncApi, uploads: uploadsApi);

  // Prewarm the doctor's clinical decision-support DB in the background so
  // Case Details opens with no lag when a case is tapped.
  unawaited(DoctorDbLoader.load());

  // Neither of these is read before the first frame, so neither is waited
  // for. The clinical sheet is the doctor's symptom matching, several taps
  // into a case, and it is the largest blob of the set. Both stores are
  // ChangeNotifiers, so whatever is on screen when they land picks them up.
  unawaited(terminologyStore.loadCache());

  // The three the first frame DOES depend on, started together so their
  // platform-channel round trips overlap instead of queueing. Worth being
  // precise about what that buys: an isolate runs one thing at a time, so
  // this overlaps the WAITING, not the jsonDecode. Measured on a CPH2119,
  // cold start was 717 ms with these done strictly in turn.
  final initResults = await Future.wait([
    firebase.ensureInitialized().catchError((_) {}),
    AuthPersistence.load().catchError((_) => null),
    mastersStore.hydrate().catchError((_) {}),
  ]);
  final StoredSession? session = initResults[1] as StoredSession?;

  // If the app opens online with pending offline actions, drain right
  // away — this is safest even when the user hasn't signed in yet
  // (SyncService will no-op on 401 SIGNED_OUT_REMOTELY).
  //
  // drain() hydrates the queue itself before touching it, so hydrating
  // separately would read the same file twice. Signed out there is no drain,
  // so hydrate alone keeps the pending count honest for the next sign-in.
  if (session != null) {
    syncService.drain();
    unawaited(terminologyStore.refresh());
  } else {
    unawaited(syncService.hydrate());
  }
  // D1: an already-logged-in user re-registers their FCM token at every
  // app start (covers token rotation + fresh installs restoring session).
  if (session != null) unawaited(FcmService.instance.register(apiClient));
  // App-wide tap handler — every notification the user opens fires this
  // stream (both background→open and killed→open), and we push the
  // matching screen via the root navigator (user 2026-09-10 "click on
  // notification will go to that page for action"). Unawaited: never
  // block main().
  FcmService.instance.onNotificationTap.listen((RemoteMessage m) {
    final route = (m.data['route'] as String? ?? '').trim();
    final arg = (m.data['route_arg'] as String?)?.trim();
    if (route.isEmpty) return;
    // Publish to the NotificationRouter; each role shell listens and
    // switches to the matching tab / opens the matching detail. Shells
    // are already mounted so a global push here would race with the
    // shell's own tab controller.
    NotificationRouter.instance.push(route, arg);
  });
  // Per-user notification history (user 2026-08-19) — key the store to
  // whoever this stored session belongs to.
  if (session != null) {
    final u = session.backendUser;
    // Persist to prefs too so the background FCM handler (killed-app
    // state) can still find whose bell history to append to (2026-08-20).
    await NotificationsStore.setCurrentUser(
        '${(u?['id'] ?? u?['user_id']) ?? session.username}');
  }

  runApp(JubiCareApp(
    firebase:         firebase,
    session:          session,
    apiClient:        apiClient,
    authApi:          authApi,
    bootstrapApi:     bootstrapApi,
    syncApi:          syncApi,
    queuesApi:        queuesApi,
    patientsApi:      patientsApi,
    appointmentsApi:  appointmentsApi,
    attendanceApi:    attendanceApi,
    campsApi:         campsApi,
    devicesApi:       devicesApi,
    requisitionsApi:  requisitionsApi,
    staffApi:         staffApi,
    uploadsApi:       uploadsApi,
    mastersStore:     mastersStore,
    terminologyStore: terminologyStore,
    syncService:      syncService,
  ));
}

/// Delete the model directories left behind by the removed on-device ASR
/// experiments (`<appSupport>/asr/**`: dolphin base+small ≈ 340 MB, and
/// whisper's ggml-base.bin ≈ 74 MB in `<appSupport>` root). Best-effort:
/// storage cleanup must never affect startup.
Future<void> _cleanupRemovedAsrModels() async {
  try {
    final support = await getApplicationSupportDirectory();
    final asrDir = Directory('${support.path}/asr');
    if (await asrDir.exists()) {
      await asrDir.delete(recursive: true);
    }
    final whisper = File('${support.path}/ggml-base.bin');
    if (await whisper.exists()) {
      await whisper.delete();
    }
  } catch (_) {/* ignore */}
}

class JubiCareApp extends StatelessWidget {
  final FirebaseService firebase;
  final StoredSession? session;
  final ApiClient apiClient;
  final AuthApi authApi;
  final BootstrapApi bootstrapApi;
  final SyncApi syncApi;
  final QueuesApi queuesApi;
  final PatientsApi patientsApi;
  final AppointmentsApi appointmentsApi;
  final AttendanceApi attendanceApi;
  final CampsApi campsApi;
  final DevicesApi devicesApi;
  final RequisitionsApi requisitionsApi;
  final StaffApi staffApi;
  final UploadsApi uploadsApi;
  final MastersStore mastersStore;
  final TerminologyStore terminologyStore;
  final SyncService syncService;

  const JubiCareApp({
    super.key,
    required this.firebase,
    required this.apiClient,
    required this.authApi,
    required this.bootstrapApi,
    required this.syncApi,
    required this.queuesApi,
    required this.patientsApi,
    required this.appointmentsApi,
    required this.attendanceApi,
    required this.campsApi,
    required this.devicesApi,
    required this.requisitionsApi,
    required this.staffApi,
    required this.uploadsApi,
    required this.mastersStore,
    required this.terminologyStore,
    required this.syncService,
    this.session,
  });

  Widget _homeForSession(BuildContext context) {
    final s = session!;
    // Populate the in-memory AppState so downstream widgets (e.g. the
    // counsellor Register form, which reads currentMmuState / District) get
    // the right values on first frame. If a backend user snapshot was
    // cached alongside the session flag, restore that too.
    final app = context.read<AppState>();
    app.restoreSession(role: s.role, username: s.username, mmuId: s.mmuId);
    if (s.backendUser != null) {
      app.applyBackendUser(s.backendUser!, mmuId: s.mmuId);
    }
    // Refresh masters + drain sync queue in the background — don't
    // block first paint. On bootstrap success also propagate facility
    // geography (state/district/block names) into AppState so any
    // sync-push queued from a mounted screen has valid strings.
    Future.microtask(() async {
      // Hydrate from cache first so applyBootstrapFacility has data
      // even before the network round-trip lands.
      final cachedFacility = mastersStore.facility;
      if (cachedFacility != null) app.applyBootstrapFacility(cachedFacility);
      await mastersStore.refresh();
      final freshFacility = mastersStore.facility;
      if (freshFacility != null) app.applyBootstrapFacility(freshFacility);
      // Re-apply the fresh user block from bootstrap so a backend-side
      // change (org.plan_type flipped between free ↔ paid, role edited,
      // facility reassigned) reflects on the very next app open without
      // a logout+login (user 2026-09-08). applyBackendUser is the same
      // method the login response uses — no new code path.
      final freshUser = mastersStore.user;
      if (freshUser != null) app.applyBackendUser(freshUser, mmuId: s.mmuId);
      // Clinical terminology too — at boot the network refresh only runs
      // when a session already exists, so a FRESH INSTALL's first login
      // reached the doctor screen with an empty sheet: legacy likely-list,
      // advisory falling back to the local scorer with no ICD (user
      // 2026-08-22 "still showing Malaria (22%) … icd code not coming").
      unawaited(terminologyStore.refresh());
      syncService.drain();
    });

    // Display name priority: cached backend full_name (saved at login) →
    // the username they typed → role label. No hardcoded person names
    // anywhere (user rule 2026-08-14: real API users only).
    final backendName = (s.backendUser?['full_name'] as String?)?.trim();
    final name = (backendName?.isNotEmpty ?? false)
        ? backendName!
        : (s.username.trim().isNotEmpty ? s.username : s.role.label);
    return switch (s.role) {
      Role.counselor  => CounsellorShell(userName: name),
      Role.doctor     => DoctorShell(userName: name),
      Role.pharmacist => PharmacistShell(userName: name),
    };
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // In-memory app state (role, MMU, backend snapshot).
        ChangeNotifierProvider(create: (_) => AppState()),
        // Legacy in-memory counsellor / patient store. Kept for now so
        // the shipped UI keeps working; screen-by-screen migration
        // replaces reads with QueuesApi / PatientsApi calls.
        ChangeNotifierProvider(create: (_) => CounsellorState()),
        // API layer — one instance each, exposed through Provider so
        // any screen can grab what it needs via context.read.
        Provider<ApiClient>.value(value: apiClient),
        Provider<AuthApi>.value(value: authApi),
        Provider<BootstrapApi>.value(value: bootstrapApi),
        Provider<SyncApi>.value(value: syncApi),
        Provider<QueuesApi>.value(value: queuesApi),
        Provider<PatientsApi>.value(value: patientsApi),
        Provider<AppointmentsApi>.value(value: appointmentsApi),
        Provider<AttendanceApi>.value(value: attendanceApi),
        Provider<CampsApi>.value(value: campsApi),
        Provider<DevicesApi>.value(value: devicesApi),
        Provider<RequisitionsApi>.value(value: requisitionsApi),
        Provider<StaffApi>.value(value: staffApi),
        Provider<UploadsApi>.value(value: uploadsApi),
        ChangeNotifierProvider<MastersStore>.value(value: mastersStore),
        ChangeNotifierProvider<TerminologyStore>.value(value: terminologyStore),
        ChangeNotifierProvider<SyncService>.value(value: syncService),
        // Existing services.
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
        Provider<FirebaseService>.value(value: firebase),
        ChangeNotifierProvider(create: (_) => LocationService(firebase)),
      ],
      child: MaterialApp(
        title: 'JubiCare MMU',
        debugShowCheckedModeBanner: false,
        theme: buildJubiCareTheme(),
        navigatorKey: _rootNavigator,
        home: Builder(builder: (context) {
          if (session != null) return _homeForSession(context);
          return const SplashScreen();
        }),
      ),
    );
  }
}
