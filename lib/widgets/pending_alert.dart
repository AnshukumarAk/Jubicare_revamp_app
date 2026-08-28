import 'package:flutter/material.dart';
import 'package:panara_dialogs/panara_dialogs.dart';

/// Split-header info dialog — one-shot pending reminder with an Okay
/// button (user 2026-08-20 chose the panara_dialogs style: coloured
/// hero header on top with an icon, white body below with title +
/// message + a blue pill button).
///
/// Fires once per screen entry via [PendingAlert.showOnce]; the same
/// `key` no-ops until the widget is popped or [PendingAlert.reset] is
/// called (e.g. when the month rolls over and a new alert should fire).
class PendingAlert {
  PendingAlert._();

  static final Set<String> _shown = {};

  static void reset(String key) => _shown.remove(key);

  /// Show once per `key` in this mount lifecycle. One-button variant.
  static void showOnce(
    BuildContext context, {
    required String key,
    required String title,
    required String message,
    PanaraDialogType type = PanaraDialogType.warning,
    String buttonLabel = 'Okay',
  }) {
    if (_shown.contains(key)) return;
    _shown.add(key);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      PanaraInfoDialog.show(
        context,
        title: title,
        message: message,
        buttonText: buttonLabel,
        onTapDismiss: () => Navigator.of(context).pop(),
        panaraDialogType: type,
        barrierDismissible: true,
      );
    });
  }

  /// Two-button variant — Cancel (grey) on the left, Confirm (coloured)
  /// on the right. `onConfirm` runs after Navigator.pop, so a scroll /
  /// focus action can safely target the underlying screen.
  static void showConfirmOnce(
    BuildContext context, {
    required String key,
    required String title,
    required String message,
    required String cancelLabel,
    required String confirmLabel,
    required VoidCallback onConfirm,
    PanaraDialogType type = PanaraDialogType.warning,
  }) {
    if (_shown.contains(key)) return;
    _shown.add(key);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      PanaraConfirmDialog.show(
        context,
        title: title,
        message: message,
        confirmButtonText: confirmLabel,
        cancelButtonText: cancelLabel,
        onTapCancel: () => Navigator.of(context).pop(),
        onTapConfirm: () {
          Navigator.of(context).pop();
          onConfirm();
        },
        panaraDialogType: type,
        barrierDismissible: true,
      );
    });
  }
}
