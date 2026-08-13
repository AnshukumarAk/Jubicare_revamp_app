import 'package:flutter/material.dart';
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
import 'state/app_state.dart';
import 'state/auth_persistence.dart';
import 'theme/app_theme.dart';
import 'counsellor/cstate.dart';
import 'counsellor/shell.dart';
import 'doctor/dshell.dart';
import 'pharmacist/pshell.dart';
import 'screens/splash.dart';
import 'screens/role_login.dart';
import 'screens/role_home.dart';
import 'services/connectivity_service.dart';
import 'services/firebase_service.dart';
import 'services/location_service.dart';

/// Optional deep-link target for capturing screens, e.g.
///   flutter run --dart-define=DEMO=doctor_login
const _demo = String.fromEnvironment('DEMO', defaultValue: '');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialise Firebase once at startup. Non-blocking failure — if
  // google-services.json is missing the LocationService just buffers locally
  // and the app runs otherwise normally.
  final firebase = FirebaseService();
  await firebase.ensureInitialized();

  // Load the stored login flag (rule 2026-08-05) so the shell can render
  // before we round-trip /auth/me on the network.
  StoredSession? session;
  try {
    session = await AuthPersistence.load();
  } catch (_) { session = null; }

  // Build the API layer once — the client is stateless w.r.t. the user
  // (tokens live in TokenStore, session in AuthPersistence) so a single
  // instance is safe for the whole app lifetime.
  final apiClient = ApiClient(
    onSignedOutRemotely: () async {
      await TokenStore.clear();
      await AuthPersistence.clear();
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
  await mastersStore.hydrate();

  final syncService = SyncService(syncApi);
  await syncService.hydrate();
  // If the app opens online with pending offline actions, drain right
  // away — this is safest even when the user hasn't signed in yet
  // (SyncService will no-op on 401 SIGNED_OUT_REMOTELY).
  if (session != null) syncService.drain();

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
    syncService:      syncService,
  ));
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
      syncService.drain();
    });

    final name = s.role.fullName;
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
        home: Builder(builder: (context) {
          // Demo-mode deep-links take priority so screenshots stay reachable.
          switch (_demo) {
            case 'doctor_login':    return const RoleLoginScreen(role: Role.doctor);
            case 'counselor_home':  return const RoleHome(role: Role.counselor);
            case 'pharmacist_home': return const RoleHome(role: Role.pharmacist);
          }
          if (session != null) return _homeForSession(context);
          return const SplashScreen();
        }),
      ),
    );
  }
}
