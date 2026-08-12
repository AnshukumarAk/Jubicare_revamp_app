import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../counsellor/cw.dart';

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
  const AttendanceCapture({
    super.key,
    required this.onCaptured,
    this.initialPhotoPath,
    this.initialLat,
    this.initialLng,
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
      // Open the system camera. Android's camera activity gives the user a
      // flip button to switch between front and rear lenses.
      final shot = await _picker.pickImage(source: ImageSource.camera, maxWidth: 1280, imageQuality: 70);
      if (shot == null) {
        setState(() => _busy = false);
        return;
      }
      _photoPath = shot.path;

      // Best-effort GPS fix. Attendance succeeds even if the user has denied
      // location; we just record what we got.
      double? lat, lng;
      try {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
          final serviceOn = await Geolocator.isLocationServiceEnabled();
          if (serviceOn) {
            final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
            lat = pos.latitude;
            lng = pos.longitude;
          }
        }
      } catch (_) {
        // Ignore — we'll fall through with lat/lng null.
      }
      _lat = lat;
      _lng = lng;
      widget.onCaptured(_photoPath!, _lat, _lng);
      if (mounted) setState(() => _busy = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not open camera: $e'),
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
          icon: Icon(_photoPath == null ? Icons.photo_camera_outlined : Icons.refresh, size: 16, color: C2.navy),
          label: Text(
            _busy ? 'Capturing…' : (_photoPath == null ? 'Take selfie + tag location' : 'Retake'),
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
