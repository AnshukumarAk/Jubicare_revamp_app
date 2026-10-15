import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../counsellor/cw.dart';

/// Post-login Terms & Conditions acceptance (user 2026-10-12).
///
/// Shown ONCE per user — the acceptance flag is keyed by the signed-in
/// user id so a shared handset asks every new user, but never a user
/// who has already agreed. User must scroll + tick the acceptance
/// checkbox before Submit enables (user 2026-10-12 "after checkbox
/// submit button will be enable"). Back-press or Submit-without-tick
/// counts as decline; caller then signs the user out.
class TermsDialog {
  TermsDialog._();

  static String _key(String userKey) => 'tnc_accepted_v1:$userKey';

  /// True if this user has already accepted the current T&C version.
  static Future<bool> hasAccepted(String userKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key(userKey)) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Show the popup and return the user's decision. `true` = agreed +
  /// submitted, `false` = back-pressed / declined. Persists the flag
  /// so this never asks again for the same user.
  static Future<bool> show(BuildContext context, String userKey) async {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _TermsSheet(),
    );
    final ok = accepted == true;
    if (ok) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_key(userKey), true);
      } catch (_) {/* best-effort — worst case the dialog shows again */}
    }
    return ok;
  }
}

class _TermsSheet extends StatefulWidget {
  const _TermsSheet();
  @override
  State<_TermsSheet> createState() => _TermsSheetState();
}

class _TermsSheetState extends State<_TermsSheet> {
  // Submit stays disabled until the user ticks the acceptance box
  // (user 2026-10-12: "after checkbox submit button will be enable").
  bool _agreed = false;

  static const _bullets = <String>[
    'The application is intended to support healthcare service delivery, patient management, and coordination among healthcare personnel.',
    'AI-generated diagnosis and prescription suggestions are for decision-support purposes only and must not be treated as definitive medical advice or an authorised prescription.',
    'The final diagnosis, treatment decisions, and prescription authorisation remain the responsibility of the qualified and authorised doctor.',
    'All users must perform activities only within their assigned roles and access permissions.',
    'Users are responsible for ensuring that the patient information, clinical records, prescriptions, and laboratory results they enter are accurate and complete.',
    'Users must maintain patient confidentiality and protect all personal and medical information accessed through the application.',
    'Login credentials must be kept secure and must not be shared with unauthorised persons.',
    'Users must not misuse the application, access unauthorised information, or alter records without proper authorisation.',
    'Users must comply with applicable laws, professional standards, clinical protocols, and organisational policies while using the application.',
    'The application and its AI-generated outputs may contain errors or experience technical interruptions. Users must independently verify critical information and prioritise patient safety.',
    'Application usage may be logged or monitored for security, audit, and quality assurance purposes, subject to applicable policies and laws.',
    'By selecting Submit, you confirm that you have read, understood, and agree to comply with these Terms and Conditions.',
  ];

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return WillPopScope(
      // Back-press on this dialog = decline (caller will sign the
      // user out). Nothing can land the user inside the app without
      // ticking the checkbox + Submit.
      onWillPop: () async {
        Navigator.of(context).pop(false);
        return false;
      },
      child: Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: media.size.height * 0.86,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
            child: Row(children: [
              const Icon(Icons.gavel_outlined, color: C2.navy, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Text('Terms and Conditions',
                  style: ct(16, FontWeight.w700, C2.navy))),
            ]),
          ),
          const Divider(height: 1),
          // Scrollable terms body — user must scroll through to read.
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                'By using this application, you agree to the following Terms and Conditions:',
                style: ct(13, FontWeight.w500, C2.text),
              ),
              const SizedBox(height: 10),
              for (final b in _bullets) Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('• ', style: ct(13.5, FontWeight.w700, C2.navy)),
                  Expanded(child: Text(b, style: ct(12.5, FontWeight.w400, C2.text))),
                ]),
              ),
            ]),
          )),
          const Divider(height: 1),
          // Acceptance checkbox — tapping label or box toggles it.
          InkWell(
            onTap: () => setState(() => _agreed = !_agreed),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 14, 0),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Checkbox(
                  value: _agreed,
                  onChanged: (v) => setState(() => _agreed = v ?? false),
                  activeColor: C2.navy,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 6),
                Expanded(child: Text(
                  'I agree to the above Terms and Conditions.',
                  style: ct(13, FontWeight.w600, C2.text),
                )),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                // Button disabled until the checkbox is ticked.
                onPressed: _agreed ? () => Navigator.of(context).pop(true) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: C2.navy,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: C2.border,
                  disabledForegroundColor: C2.text3,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Submit',
                    style: ct(14, FontWeight.w700,
                        _agreed ? Colors.white : C2.text3)),
              ),
            ),
          ),
        ]),
      ),
      ),
    );
  }
}
