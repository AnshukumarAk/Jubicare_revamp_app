import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Bakes a Place / GPS / Date-Time strip onto the bottom of a captured
/// photo — GPS Map Camera style (user rule 2026-08-16). The strip is
/// PART OF THE PIXELS: exported/shared/printed copies keep it, and no
/// user or downstream tool can strip it off.
///
/// Runs in an isolate — even a 12 MP image takes 100-400 ms to re-encode,
/// which would jank the capture screen on the UI thread.
///
/// Format (always a single line; user 2026-08-31):
///   <place>  Location: <lat.6f>, <lng.6f> Date: DD-MM-YYYY Time: hh:mm AM/PM
/// Empty [place] (other capture screens) omits the prefix. GPS unavailable
/// drops the Location segment; Date/Time remain. Font steps down so a
/// long place name does not clip Time.
///
/// Returns a NEW File in the app's temp dir — the source file is left
/// alone so the OS-level camera thumbnail keeps working.
class PhotoWatermark {
  /// Overlay `photo` and return the watermarked file. Falls back to the
  /// source path on any failure (a photo without the strip is better
  /// than an aborted check-in).
  static Future<File> stamp(
    File photo, {
    required String place,
    double? latitude,
    double? longitude,
    DateTime? when,
  }) async {
    try {
      final bytes = await photo.readAsBytes();
      final dir = await getTemporaryDirectory();
      final out = File(
          '${dir.path}/wm_${DateTime.now().microsecondsSinceEpoch}.jpg');
      final result = await Isolate.run(() => _bakeSync(
            bytes,
            place: place,
            latitude: latitude,
            longitude: longitude,
            whenIso: (when ?? DateTime.now()).toIso8601String(),
          ));
      await out.writeAsBytes(result);
      return out;
    } catch (_) {
      return photo;
    }
  }

  /// Runs on the isolate. `image` package must be imported here too —
  /// the isolate has its own memory space.
  static Uint8List _bakeSync(
    Uint8List bytes, {
    required String place,
    double? latitude,
    double? longitude,
    required String whenIso,
  }) {
    var im = img.decodeImage(bytes);
    if (im == null) return bytes;

    // Some Android cameras write huge 4000x3000 shots — cap the long
    // edge at 1600px so upload is under ~500 KB and the strip text
    // stays readable on a phone.
    const maxEdge = 1600;
    final longEdge = math.max(im.width, im.height);
    if (longEdge > maxEdge) {
      final scale = maxEdge / longEdge;
      im = img.copyResize(
        im,
        width: (im.width * scale).round(),
        height: (im.height * scale).round(),
        interpolation: img.Interpolation.average,
      );
    }

    // Strip height scales with the photo; the actual bitmap font is
    // picked below so a long facility name still fits on one line.
    final stripH = math.max(40, (im.height * 0.045).round());

    // Compose the stamp — always ONE line (user 2026-08-31):
    //   <place>  Location: <lat>, <lng> Date: DD-MM-YYYY Time: hh:mm AM/PM
    // `place` empty (attachments / camp photos) → that prefix is omitted
    // so those callers keep GPS + Date + Time only. GPS unavailable →
    // the Location segment is dropped; Date/Time remain.
    final dt = DateTime.tryParse(whenIso)?.toLocal() ?? DateTime.now();
    final dateStr = '${_p2(dt.day)}-${_p2(dt.month)}-${dt.year}';
    final hour12 = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final timeStr = '${_p2(hour12)}:${_p2(dt.minute)} ${dt.hour < 12 ? 'AM' : 'PM'}';

    final placeSeg = place.trim();
    final prefix = placeSeg.isEmpty ? '' : '$placeSeg  ';
    final locSeg = (latitude != null && longitude != null)
        ? 'Location: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)} '
        : '';
    final dtSeg = 'Date: $dateStr Time: $timeStr';
    final oneLine = '$prefix$locSeg$dtSeg';

    final padX = math.max(10, (im.width * 0.015).round());
    final maxW = im.width - padX * 2;
    // Try to keep the whole stamp on ONE line by stepping the font down.
    // If even arial14 doesn't fit (long facility name + full GPS + date
    // + time on a narrow portrait photo picked from the gallery — user
    // 2026-09-07 "watermark it cuting not fitting fully in single line"),
    // fall back to TWO lines: <place>+<location> on the first,
    // <date+time> on the second. Second line will always fit at any
    // font size because it's short.
    var font = _pickFont((stripH * 0.5).round());
    for (final f in <img.BitmapFont>[font, img.arial24, img.arial14]) {
      font = f;
      if (_textW(font, oneLine) <= maxW) break;
    }
    final List<String> lines;
    if (_textW(font, oneLine) <= maxW) {
      lines = [oneLine];
    } else {
      // Wrap point: keep prefix+location on line 1, date+time on line 2.
      // If line 1 STILL overflows (very long place name), drop the
      // prefix on that line — the date+time on line 2 is what the audit
      // must never lose.
      final line1 = '$prefix$locSeg'.trimRight();
      lines = [
        _textW(font, line1) <= maxW ? line1 : locSeg.trimRight(),
        dtSeg,
      ].where((l) => l.isNotEmpty).toList();
      if (lines.isEmpty) lines.add(dtSeg);
    }

    // Semi-transparent black band across the bottom, tall enough for
    // every line. ~65% opacity keeps the photo visible through it.
    final bandH = math.max(stripH, (font.lineHeight + 6) * lines.length + 8);
    final stripY = im.height - bandH;
    final bg = img.ColorRgba8(0, 0, 0, 165);
    img.fillRect(
      im,
      x1: 0,
      y1: stripY,
      x2: im.width - 1,
      y2: im.height - 1,
      color: bg,
    );

    final white = img.ColorRgba8(255, 255, 255, 255);
    // Vertically center the block of lines inside the band.
    final blockH = font.lineHeight * lines.length + 6 * (lines.length - 1);
    var y = stripY + ((bandH - blockH) / 2).round();
    for (final line in lines) {
      img.drawString(im, line, font: font, x: padX, y: y, color: white);
      y += font.lineHeight + 6;
    }

    return img.encodeJpg(im, quality: 82);
  }

  /// Pick the closest built-in bitmap font — the image package ships
  /// with a handful of pre-rasterised fonts and picking the nearest
  /// height beats stretching them.
  static img.BitmapFont _pickFont(int height) {
    if (height >= 44) return img.arial48;
    if (height >= 22) return img.arial24;
    if (height >= 16) return img.arial14;
    return img.arial14;
  }

  /// Pixel width of `s` in `font` — sum of per-glyph advances. Missing
  /// glyphs fall back to half the font base size (space-ish).
  static int _textW(img.BitmapFont font, String s) {
    var w = 0;
    for (final c in s.codeUnits) {
      final g = font.characters[c];
      w += g?.xAdvance ?? (font.base ~/ 2);
    }
    return w;
  }

  static String _p2(int n) => n.toString().padLeft(2, '0');
}
