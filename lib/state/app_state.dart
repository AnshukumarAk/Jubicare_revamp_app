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

  // The old fixed-credential login(role, user, pass) is gone — sign-in
  // happens exclusively through /api/auth/login (user rule 2026-08-14:
  // real API, real users; no demo credentials compiled into the app).

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
    // The typed username is the only real identity we have until the
    // cached backend user block (applyBackendUser) overwrites it with
    // full_name — never a hardcoded person name.
    currentUser = username.trim().isNotEmpty ? username : role.label;
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
      currentUser = (u['full_name'] as String?) ?? mappedRole.label;
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
  /// Counsellor's assigned state/district (Register form shows them as
  /// read-only badges; sync payloads carry them as the geography resolve
  /// chain). Backend bootstrap facility names are the source of truth —
  /// the legacy kMmuOptions lookup only serves sessions from before the
  /// backend login existed (its ids never match a facility code, which
  /// is what currentMmuId holds now; that mismatch left the form
  /// showing "— · —" — user bug report 2026-08-14).
  String get currentMmuState    => backendStateName    ?? currentMmu?.state    ?? '';
  String get currentMmuDistrict => backendDistrictName ?? currentMmu?.district ?? '';

  // No seed/mock data — every list in the app hydrates from the API
  // (user rule: blank static arrays).
  final List<Patient> patients = const [];
}
