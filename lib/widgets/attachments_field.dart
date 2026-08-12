import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../counsellor/cstate.dart';
import '../counsellor/cw.dart';

/// Multi-attachment picker used on the counsellor Register form.
///
/// Every attachment carries three fields:
///   - source path (from ImagePicker — camera or gallery)
///   - kind: Prescription / Report / Other
///   - description: free-text label the counsellor types
///
/// The rendered list is fully editable — kind dropdown, description field,
/// and a delete button per row. The parent owns the list and gets a callback
/// on every change.
class AttachmentsField extends StatefulWidget {
  final List<Attachment> value;
  final ValueChanged<List<Attachment>> onChanged;
  const AttachmentsField({super.key, required this.value, required this.onChanged});

  @override
  State<AttachmentsField> createState() => _AttachmentsFieldState();
}

class _AttachmentsFieldState extends State<AttachmentsField> {
  final ImagePicker _picker = ImagePicker();
  // A description controller per attachment, keyed by list index. Kept in
  // parallel with widget.value so the TextField cursor doesn't jump on setState.
  final List<TextEditingController> _descCtrls = [];

  @override
  void initState() {
    super.initState();
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant AttachmentsField old) {
    super.didUpdateWidget(old);
    _syncControllers();
  }

  void _syncControllers() {
    while (_descCtrls.length < widget.value.length) {
      _descCtrls.add(TextEditingController(text: widget.value[_descCtrls.length].description));
    }
    while (_descCtrls.length > widget.value.length) {
      _descCtrls.removeLast().dispose();
    }
  }

  @override
  void dispose() {
    for (final c in _descCtrls) { c.dispose(); }
    super.dispose();
  }

  Future<void> _pick() async {
    // Rear camera by default — counsellors are aiming at a paper prescription,
    // not their own face. The preferredCameraDevice hint is honoured on Android
    // (opens the world-facing camera app); iOS respects it if the OS lets us.
    try {
      final shot = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1280,
        imageQuality: 70,
      );
      if (shot == null) return;
      final next = [...widget.value, Attachment(path: shot.path, kind: AttachmentKind.prescription)];
      widget.onChanged(next);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not open camera'),
          backgroundColor: C2.danger,
        ));
      }
    }
  }

  void _updateKind(int i, AttachmentKind kind) {
    final list = [...widget.value];
    list[i] = Attachment(path: list[i].path, kind: kind, description: _descCtrls[i].text);
    widget.onChanged(list);
  }

  void _updateDesc(int i, String desc) {
    // Do NOT rebuild — the TextEditingController already reflects the text.
    // We only need the parent state so the value is committed on submit.
    final list = [...widget.value];
    list[i] = Attachment(path: list[i].path, kind: list[i].kind, description: desc);
    widget.onChanged(list);
  }

  void _remove(int i) {
    // Drop primary focus BEFORE mutating the list. Without this, the "×"
    // IconButton disappears with focus still on it, focus falls back to the
    // last-focused TextField (the Symptoms input further up the form), and
    // the enclosing SingleChildScrollView auto-scrolls the viewport to reveal
    // that field — the counsellor sees the form "jump back to symptoms".
    FocusManager.instance.primaryFocus?.unfocus();
    final list = [...widget.value];
    list.removeAt(i);
    widget.onChanged(list);
  }

  @override
  Widget build(BuildContext context) {
    final hasAttachments = widget.value.isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // First-attachment prompt — a single big "Take photo" button. Once the
      // counsellor has captured one, this shrinks to a compact "+ Add another"
      // beneath the list (see below) so the UI doesn't stay bulky.
      if (!hasAttachments)
        OutlinedButton.icon(
          onPressed: _pick,
          icon: const Icon(Icons.photo_camera_outlined, size: 18, color: C2.navy),
          label: Text('Take photo of prescription or report', style: ct(13, FontWeight.w600, C2.navy)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: C2.border, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      if (!hasAttachments)
        Padding(padding: const EdgeInsets.only(top: 6),
          child: Text('You can add multiple prescriptions and reports.',
              style: ct(11.5, FontWeight.w400, C2.text2))),
      // Attachment rows.
      for (int i = 0; i < widget.value.length; i++) ...[
        if (i > 0) const SizedBox(height: 8),
        if (i == 0) const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: C2.bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: C2.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(File(widget.value[i].path), width: 48, height: 48, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(width: 48, height: 48, color: C2.border,
                    child: const Icon(Icons.description_outlined, size: 20, color: C2.text3))),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<AttachmentKind>(
                  value: widget.value[i].kind,
                  isDense: true,
                  isExpanded: true,
                  decoration: cInput().copyWith(contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                  style: ct(13, FontWeight.w600, C2.text),
                  items: AttachmentKind.values
                      .map((k) => DropdownMenuItem(value: k, child: Text(k.label)))
                      .toList(),
                  onChanged: (k) { if (k != null) _updateKind(i, k); },
                ),
              ),
              IconButton(
                onPressed: () => _remove(i),
                icon: const Icon(Icons.close, size: 18, color: C2.text2),
                tooltip: 'Remove',
              ),
            ]),
            const SizedBox(height: 6),
            TextField(
              controller: _descCtrls[i],
              onChanged: (v) => _updateDesc(i, v),
              decoration: cInput('Short description (e.g. "BP report — Aug")'),
              style: ct(12.5, FontWeight.w400, C2.text),
            ),
          ]),
        ),
      ],
      if (hasAttachments) ...[
        const SizedBox(height: 8),
        // Compact "+ Add another" — appears once at least one attachment
        // exists so the counsellor can keep appending without a busy toolbar.
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _pick,
            icon: const Icon(Icons.add_circle_outline, size: 18, color: C2.cyan),
            label: Text('Add another', style: ct(12.5, FontWeight.w600, C2.cyan)),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
          ),
        ),
      ],
    ]);
  }
}
