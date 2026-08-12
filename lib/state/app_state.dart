import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'auth_persistence.dart';

/// In-memory app state for the reset prototype: connectivity, the logged-in
/// role, and a little mock data. Auth is a mock (any credentials accepted).
class AppState extends ChangeNotifier {
  bool online = true;
  void toggleOnline() {
    online = !online;
    notifyListeners();
  }

  // ----- Auth -----
  Role? currentRole;
  String currentUser = '';
  // Selected MMU at login. Location tracking pushes every point to Firestore
  // tagged with this mmuId so the dashboard can render it against the right
  // vehicle. Options match the seed MMUs used by the JubiCare Dashboard.
  String? currentMmuId;

  // ----- Backend user + facility (populated from /api/auth/login response;
  // v2 §1.1). Nullable so the local mock login (used when the backend is
  // unreachable) can keep working with just role + mmuId. -----
  int? backendUserId;
  int? backendOrgId;
  int? backendFacilityId;
  String? backendFacilityCode;
  String? backendFacilityName;
  String? backendFacilityType;   // 'mmu' | 'static_clinic' | 'standalone_clinic'
  int? backendStateId;
  int? backendDistrictId;
  String? backendStateName;
  String? backendDistrictName;
  String? backendBlockName;

  /// Login — validates the role's fixed username/password (CR29). The optional
  /// [mmuId] is required for the counsellor role (which vehicle they're on).
  bool login(Role role, String username, String password, {String? mmuId}) {
    if (username.trim() != role.credUser || password != role.credPass) return false;
    currentRole = role;
    currentUser = role.fullName;
    currentMmuId = mmuId;
    notifyListeners();
    return true;
  }

  void logout() {
    currentRole = null;
    currentUser = '';
    currentMmuId = null;
    backendUserId = null;
    backendOrgId = null;
    backendFacilityId = null;
    backendFacilityCode = null;
    backendFacilityName = null;
    backendFacilityType = null;
    backendStateId = null;
    backendDistrictId = null;
    backendStateName = null;
    backendDistrictName = null;
    backendBlockName = null;
    // Wipe the persisted session so a fresh app launch shows the login
    // screen again (rule 2026-08-05). Fire-and-forget — clearing prefs
    // shouldn't block the UI.
    unawaited(AuthPersistence.clear());
    notifyListeners();
  }

  /// Restore an in-memory session from persisted SharedPreferences. Called
  /// from main.dart at startup when a valid stored session exists so the
  /// role shell can render immediately without re-login.
  void restoreSession({
    required Role role,
    required String username,
    String? mmuId,
    // Backend fields — nullable for older sessions saved before v0.21.
    int? backendUserId,
    int? backendOrgId,
    int? backendFacilityId,
    String? backendFacilityCode,
    String? backendFacilityName,
    String? backendFacilityType,
    int? backendStateId,
    int? backendDistrictId,
    String? backendStateName,
    String? backendDistrictName,
    String? backendBlockName,
  }) {
    currentRole = role;
    currentUser = role.fullName;
    currentMmuId = mmuId;
    this.backendUserId = backendUserId;
    this.backendOrgId = backendOrgId;
    this.backendFacilityId = backendFacilityId;
    this.backendFacilityCode = backendFacilityCode;
    this.backendFacilityName = backendFacilityName;
    this.backendFacilityType = backendFacilityType;
    this.backendStateId = backendStateId;
    this.backendDistrictId = backendDistrictId;
    this.backendStateName = backendStateName;
    this.backendDistrictName = backendDistrictName;
    this.backendBlockName = backendBlockName;
    // No notifyListeners — called before the widget tree mounts.
  }

  /// Populate the facility geography (state/district/block names) from a
  /// bootstrap `facility` block. The login response only carries
  /// state_id / district_id — the human names come from bootstrap and
  /// are required by the server on every sync push (village name must
  /// resolve inside its block, block inside its district).
  void applyBootstrapFacility(Map<String, dynamic> f) {
    backendFacilityId    = (f['id']    as num?)?.toInt() ?? backendFacilityId;
    backendFacilityCode  = (f['code']  as String?) ?? backendFacilityCode;
    backendFacilityName  = (f['name']  as String?) ?? backendFacilityName;
    backendFacilityType  = (f['type']  as String?) ?? backendFacilityType;
    backendStateId       = (f['state_id']    as num?)?.toInt() ?? backendStateId;
    backendDistrictId    = (f['district_id'] as num?)?.toInt() ?? backendDistrictId;
    backendStateName     = (f['state_name']    as String?) ?? backendStateName;
    backendDistrictName  = (f['district_name'] as String?) ?? backendDistrictName;
    backendBlockName     = (f['block_name']    as String?) ?? backendBlockName;
    currentMmuId         = (f['code'] as String?) ?? currentMmuId;
    notifyListeners();
  }

  /// Populate AppState from the /api/auth/login `user` block. Callable
  /// after a successful backend login OR after refreshing /auth/me.
  void applyBackendUser(Map<String, dynamic> u, {String? mmuId}) {
    // Match backend role names → app-side Role enum. Backend uses the
    // full role_t enum (§4) — mobile only cares about the three roles
    // the shells cover for now.
    final roleRaw = (u['role'] as String?)?.toLowerCase() ?? '';
    Role? mappedRole;
    for (final r in Role.values) {
      if (r.name == roleRaw || r.name == roleRaw.replaceAll('counsellor', 'counselor')) {
        mappedRole = r; break;
      }
    }
    if (roleRaw == 'counsellor' || roleRaw == 'counselor') mappedRole = Role.counselor;
    if (roleRaw == 'doctor')     mappedRole = Role.doctor;
    if (roleRaw == 'pharmacist') mappedRole = Role.pharmacist;

    if (mappedRole != null) {
      currentRole = mappedRole;
      currentUser = (u['full_name'] as String?) ?? mappedRole.fullName;
    }
    currentMmuId          = mmuId ?? (u['facility_code'] as String?) ?? currentMmuId;
    backendUserId         = (u['id'] as num?)?.toInt() ?? (u['user_id'] as num?)?.toInt();
    backendOrgId          = (u['org_id'] as num?)?.toInt();
    backendFacilityId     = (u['facility_id'] as num?)?.toInt();
    backendFacilityCode   = u['facility_code'] as String?;
    backendFacilityName   = u['facility_name'] as String?;
    backendFacilityType   = u['facility_type'] as String?;
    backendStateId        = (u['state_id'] as num?)?.toInt();
    backendDistrictId     = (u['district_id'] as num?)?.toInt();
    backendStateName      = u['state_name'] as String?;
    backendDistrictName   = u['district_name'] as String?;
    backendBlockName      = u['block_name'] as String?;
    notifyListeners();
  }

  /// Look up the assigned MMU (or null if the counsellor isn't logged in
  /// or the id no longer matches a known option).
  MmuOption? get currentMmu {
    if (currentMmuId == null) return null;
    for (final m in kMmuOptions) {
      if (m.id == currentMmuId) return m;
    }
    return null;
  }
  /// Counsellor's assigned state (from web-admin profile). Falls back to
  /// empty when not logged in. User rule 2026-07-29 — the Register form
  /// no longer asks for State + District; it reads them from here.
  String get currentMmuState    => currentMmu?.state    ?? '';
  String get currentMmuDistrict => currentMmu?.district ?? '';

  // ----- Mock data (placeholder until further instructions) -----
  final List<Patient> patients = const [
    Patient(id: '1365201', name: 'Vandana Sharma', gender: 'Female', age: 28, village: 'Naipura', symptoms: 'Cold & cough, mild fever'),
    Patient(id: '1365202', name: 'Narayan Singh', gender: 'Male', age: 50, village: 'Gajraula', symptoms: 'Body pain, fatigue'),
    Patient(id: '1365203', name: 'Payal Devi', gender: 'Female', age: 11, village: 'Dhanaura', symptoms: 'Cough, sore throat'),
  ];
}
