import 'package:flutter/material.dart';

/// The MMU mobile-app roles, each with its own login.
/// (Lab Technician is NOT a mobile-app role.)
enum Role { counselor, doctor, pharmacist }

extension RoleX on Role {
  String get label => switch (this) {
        Role.counselor => 'Counsellor',
        Role.doctor => 'Doctor',
        Role.pharmacist => 'Pharmacist',
      };

  String get subtitle => switch (this) {
        Role.counselor => 'Register patients & capture details',
        Role.doctor => 'Consult, diagnose & prescribe',
        Role.pharmacist => 'Dispense medicines & manage stock',
      };

  IconData get icon => switch (this) {
        Role.counselor => Icons.badge_outlined,
        Role.doctor => Icons.medical_services_outlined,
        Role.pharmacist => Icons.local_pharmacy_outlined,
      };

  Color get color => switch (this) {
        Role.counselor => const Color(0xFF1E5BB8),
        Role.doctor => const Color(0xFF2BB673),
        Role.pharmacist => const Color(0xFFFBB615),
      };

  /// Demo display name shown after login.
  String get demoUser => fullName;

  /// Full display name shown after login (CR29).
  String get fullName => switch (this) {
        Role.counselor => 'Sanjeev Mahto',
        Role.doctor => 'Dr. Aakanksha Dua',
        Role.pharmacist => 'Kedar Dash',
      };

  /// Login username for this role (CR29).
  String get credUser => switch (this) {
        Role.counselor => 'con_test',
        Role.doctor => 'doc_test',
        Role.pharmacist => 'pha_test',
      };

  /// Login password for this role (CR29).
  String get credPass => switch (this) {
        Role.counselor => 'con@123',
        Role.doctor => 'doc@123',
        Role.pharmacist => 'pha@123',
      };
}

/// MMU vehicle option shown in the counsellor login dropdown. IDs match
/// the seed MMU IDs used by the JubiCare Dashboard (JubiCare org fleet).
class MmuOption {
  final String id;
  final String name;
  // Every MMU is assigned to a fixed state+district by the web admin.
  // These flow through the counsellor's login so the Register form can
  // scope Block+Village pickers to the correct district automatically
  // (user rule 2026-07-29).
  final String state;
  final String district;
  const MmuOption(this.id, this.name, {required this.state, required this.district});
}

const List<MmuOption> kMmuOptions = [
  MmuOption('MMU001', 'MMU-Gajraula-01', state: 'Uttar Pradesh', district: 'Amroha'),
  MmuOption('MMU002', 'MMU-Hasanpur-02', state: 'Uttar Pradesh', district: 'Amroha'),
  MmuOption('MMU003', 'MMU-Haridwar-03', state: 'Uttarakhand',   district: 'Roorkee'),
];

/// Minimal patient record (mock data).
class Patient {
  final String id;
  final String name;
  final String gender;
  final int age;
  final String village;
  final String symptoms;

  const Patient({
    required this.id,
    required this.name,
    required this.gender,
    required this.age,
    required this.village,
    this.symptoms = '',
  });

  String get initials => name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
}
