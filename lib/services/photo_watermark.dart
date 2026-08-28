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
/// Format (single line, auto-scaled to photo width; user 2026-08-18):
///   Location: <lat.6f>, <lng.6f>    Date: DD-MM-YYYY    Time: hh:mm AM/PM
/// (GPS unavailable → the Location segment is dropped, Date/Time remain.)
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

    // Strip height + font pick scale with the photo — small photo,
    // small font; big photo, big font.
    final stripH = math.max(40, (im.height * 0.045).round());
    final font = _pickFont((stripH * 0.5).round());

    // Compose the stamp (user 2026-08-18; place prefix re-added 2026-08-20
    // "in watermark print also mmu name"):
    //   <MMU name>    Location: <lat>, <lng>    Date: DD-MM-YYYY    Time: hh:mm AM/PM
    // Place blank → segment dropped; GPS unavailable → Location dropped.
    final dt = DateTime.tryParse(whenIso)?.toLocal() ?? DateTime.now();
    final dateStr = '${_p2(dt.day)}-${_p2(dt.month)}-${dt.year}';
    final hour12 = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final timeStr = '${_p2(hour12)}:${_p2(dt.minute)} ${dt.hour < 12 ? 'AM' : 'PM'}';

    // Place/block prefix REMOVED from the strip (user 2026-08-21 "remove
    // ashiana nagar value means block name" — reverses 2026-08-20's "print
    // also mmu name"). The `place` param stays so call sites don't churn.
    const prefix = '';
    final locSeg = (latitude != null && longitude != null)
        ? 'Location: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)} '
        : '';
    final dtSeg = 'Date: $dateStr Time: $timeStr';

    // drawString does NOT wrap — a long place + GPS + date + time line
    // overflowed the right edge and the Time was cut off the photo (user
    // bug 2026-08-21 "Time is not showing"). Measure first; if one line
    // doesn't fit, split into two (place+GPS / date+time) and double the
    // band height so every segment stays on the pixels.
    final padX = math.max(10, (im.width * 0.015).round());
    final oneLine = '$prefix$locSeg$dtSeg';
    final maxW = im.width - padX * 2;
    final List<String> lines;
    if (_textW(font, oneLine) <= maxW || '$prefix$locSeg'.trim().isEmpty) {
      lines = [oneLine];
    } else {
      lines = ['$prefix$locSeg'.trimRight(), dtSeg];
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
