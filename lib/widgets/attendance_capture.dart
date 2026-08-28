import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../counsellor/cw.dart';
import '../services/photo_watermark.dart';

/// Capture card used by both counsellor and doctor Attendance flows.
///
/// Presents a "Take selfie + tag location" button. When tapped:
///   1. Opens the system camera (ImagePicker.camera). The user can tap flip
///      inside the camera app to switch between front and rear — Android's
///      camera doesn't expose a lens-selection API to the app.
///   2. After the photo is taken, requests a one-shot GPS reading.
///   3. Reports both (photo path + lat/lng) back via [onCaptured].
///
/// If the user denies location, the photo is still returned but lat/lng are
/// null; the attendance form's own validation decides whether to accept that.
class AttendanceCapture extends StatefulWidget {
  final String? initialPhotoPath;
  final double? initialLat;
  final double? initialLng;
  final void Function(String path, double? lat, double? lng) onCaptured;
  /// Human-readable place text baked into the watermark strip
  /// (e.g. "Gajraula Camp, Block Gajraula"). Blank string = no place row.
  final String placeLabel;
  const AttendanceCapture({
    super.key,
    required this.onCaptured,
    this.initialPhotoPath,
    this.initialLat,
    this.initialLng,
    this.placeLabel = '',
  });

  @override
  State<AttendanceCapture> createState() => _AttendanceCaptureState();
}

class _AttendanceCaptureState extends State<AttendanceCapture> {
  final ImagePicker _picker = ImagePicker();
  String? _photoPath;
  double? _lat;
  double? _lng;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _photoPath = widget.initialPhotoPath;
    _lat = widget.initialLat;
    _lng = widget.initialLng;
  }

  Future<void> _capture() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // Ask for LOCATION first, camera second (user 2026-08-26 "ask
      // location before photo"). Two prompts back-to-back on the
      // pre-camera screen is a cleaner UX than the camera opening,
      // closing, and then a permission popup appearing on top of the
      // captured photo. Location is still best-effort — a deny only
      // costs the GPS row in the watermark.
      double? lat, lng;
      try {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.always ||
            perm == LocationPermission.whileInUse) {
          final serviceOn = await Geolocator.isLocationServiceEnabled();
          if (serviceOn) {
            final pos = await Geolocator.getCurrentPosition(
                    desiredAccuracy: LocationAccuracy.high)
                .timeout(const Duration(seconds: 6));
            lat = pos.latitude;
            lng = pos.longitude;
          }
        }
      } catch (_) {
        // Timeout / denied — watermark falls back to date-time only.
      }
      _lat = lat;
      _lng = lng;

      // Now the camera — its permission popup (first launch) fires
      // BEFORE the photo is taken, so the user only sees one prompt at
      // a time.
      final shot = await _picker.pickImage(source: ImageSource.camera, maxWidth: 1280, imageQuality: 70);
      if (shot == null) {
        setState(() => _busy = false);
        return;
      }
      _photoPath = shot.path;
      // Bake the watermark strip BEFORE handing the file off. The result
      // file is what uploads, so the Place/GPS/Date-Time proof is stuck
      // to the pixels forever (user rule 2026-08-16).
      final stamped = await PhotoWatermark.stamp(
        File(_photoPath!),
        place: widget.placeLabel,
        latitude: lat,
        longitude: lng,
      );
      _photoPath = stamped.path;
      widget.onCaptured(_photoPath!, _lat, _lng);
      if (mounted) setState(() => _busy = false);
    } on PlatformException catch (e) {
      // Raw PlatformException text on screen read as a crash (user
      // 2026-08-22) — translate the two common denials into plain words.
      // A once-denied permission IS re-asked on the next tap; only
      // "don't ask again" / a second deny needs the Settings route.
      if (mounted) {
        final denied = e.code == 'camera_access_denied';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(denied
              ? 'Camera permission needed for the selfie. Tap the button '
                  'again and choose Allow — if no prompt appears, enable '
                  'Camera in Phone Settings → Apps → JubiCare → Permissions.'
              : 'Camera is not available right now. Please try again.'),
          backgroundColor: C2.navy,
          duration: const Duration(seconds: 5),
        ));
        setState(() => _busy = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not open the camera. Please try again.'),
          backgroundColor: C2.danger,
        ));
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: OutlinedButton.icon(
          onPressed: _busy ? null : _capture,
          // Visible loader while the photo is compressed + the GPS/date
          // watermark strip is baked in (takes a moment on big shots —
          // user 2026-08-19: "add a loader").
          icon: _busy
              ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: C2.navy))
              : Icon(_photoPath == null ? Icons.photo_camera_outlined : Icons.refresh, size: 16, color: C2.navy),
          label: Text(
            _busy
                ? 'Processing photo…'
                : (_photoPath == null ? 'Take selfie + tag location' : 'Retake'),
            style: ct(13, FontWeight.w600, C2.navy),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: C2.border, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        )),
      ]),
      if (_photoPath != null) ...[
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(File(_photoPath!), width: 72, height: 72, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 72, height: 72, color: C2.border,
                child: const Icon(Icons.broken_image_outlined, color: C2.text3))),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.check_circle, size: 14, color: C2.green),
              const SizedBox(width: 4),
              Text('Selfie captured', style: ct(12, FontWeight.w700, C2.green)),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Icon(_lat == null ? Icons.location_off : Icons.location_on,
                  size: 13, color: _lat == null ? C2.danger : C2.navy),
              const SizedBox(width: 4),
              Expanded(child: Text(
                _lat == null
                  ? 'Location not available'
                  : '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
                style: ct(11.5, FontWeight.w500, _lat == null ? C2.danger : C2.text2),
                overflow: TextOverflow.ellipsis,
              )),
            ]),
          ])),
        ]),
      ],
    ]);
  }
}
