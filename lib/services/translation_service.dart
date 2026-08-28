import 'dart:async';
import 'dart:convert';

import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:http/http.dart' as http;

/// Hindi → English translation for Patient Remarks at SUBMIT time
/// (user 2026-08-19: "why the remarks is not translated to english in db",
/// then "improved translation").
///
/// THREE-TIER CHAIN — best available wins, submit never blocks:
///   1. Google web translate (translate.googleapis.com, free gtx client) —
///      full Google Translate quality, needs internet. Fixes the literal
///      ML Kit output ("Sir is painful" → "Has a headache").
///   2. ML Kit on-device (hi↔en models, ~30 MB, downloaded once by
///      [warmUp]) — works fully OFFLINE.
///   3. Raw text unchanged — translation must never cost a registration
///      (online/offline parity rule 2026-08-16).
///
/// A tiny Hindi normalisation glossary runs first so homophones the STT
/// writes ("सर दर्द") become the unambiguous form ("सिरदर्द") both
/// engines translate correctly.
class TranslationService {
  TranslationService._();

  static OnDeviceTranslator? _translator;
  static final OnDeviceTranslatorModelManager _models =
      OnDeviceTranslatorModelManager();
  static bool _warmed = false;

  static final RegExp _devanagari = RegExp(r'[ऀ-ॿ]');

  /// Hindi→Hindi disambiguation applied BEFORE translation. Keys are
  /// patterns the STT actually produces; values are forms the translators
  /// render correctly. Keep tiny and surgical.
  static const Map<String, String> _hindiGlossary = {
    'सर दर्द': 'सिरदर्द',
    'सर में दर्द': 'सिर में दर्द',
    'सर भारी': 'सिर भारी',
  };

  /// Fire-and-forget: start downloading the hi/en ML Kit models (mobile
  /// data allowed — camp phones rarely see Wi-Fi). Safe to call repeatedly.
  static void warmUp() {
    if (_warmed) return;
    _warmed = true;
    () async {
      try {
        await _ensureModels();
        // ignore: avoid_print
        print('[translate] hi/en models ready');
      } catch (e) {
        // ignore: avoid_print
        print('[translate] warmUp failed (will retry at submit): $e');
        _warmed = false; // let a later warmUp / submit retry
      }
    }();
  }

  static Future<void> _ensureModels() async {
    final hi = TranslateLanguage.hindi.bcpCode;
    final en = TranslateLanguage.english.bcpCode;
    if (!await _models.isModelDownloaded(hi)) {
      await _models.downloadModel(hi, isWifiRequired: false);
    }
    if (!await _models.isModelDownloaded(en)) {
      await _models.downloadModel(en, isWifiRequired: false);
    }
  }

  static String _normalize(String t) {
    var out = t;
    _hindiGlossary.forEach((k, v) => out = out.replaceAll(k, v));
    return out;
  }

  /// Tier 1 — Google's public web-translate endpoint (same engine as
  /// translate.google.com). Returns null on any failure so the chain
  /// falls through to ML Kit.
  static Future<String?> _webTranslate(String t) async {
    try {
      final uri = Uri.parse(
          'https://translate.googleapis.com/translate_a/single'
          '?client=gtx&sl=hi&tl=en&dt=t&q=${Uri.encodeComponent(t)}');
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body);
      // Shape: [[["translated","source",…], …], …]
      final segs = (body as List).first as List;
      final out = segs
          .map((s) => (s as List).first?.toString() ?? '')
          .join()
          .trim();
      return out.isEmpty ? null : out;
    } catch (_) {
      return null;
    }
  }

  /// Tier 2 — on-device ML Kit.
  static Future<String?> _mlkitTranslate(String t) async {
    try {
      await _ensureModels();
      _translator ??= OnDeviceTranslator(
        sourceLanguage: TranslateLanguage.hindi,
        targetLanguage: TranslateLanguage.english,
      );
      final out = (await _translator!.translateText(t)).trim();
      return out.isEmpty ? null : out;
    } catch (_) {
      return null;
    }
  }

  /// Translate [text] hi→en. Returns the RAW text unchanged when it has no
  /// Devanagari, is empty, or every engine fails. Hard-capped at [timeout]
  /// so a submit can never hang on this step.
  static Future<String> hiToEn(
    String text, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final t = text.trim();
    if (t.isEmpty || !_devanagari.hasMatch(t)) return t;
    final norm = _normalize(t);
    try {
      return await () async {
        final web = await _webTranslate(norm);
        if (web != null) {
          // ignore: avoid_print
          print('[translate] web: "$norm" → "$web"');
          return web;
        }
        final mlkit = await _mlkitTranslate(norm);
        if (mlkit != null) {
          // ignore: avoid_print
          print('[translate] mlkit: "$norm" → "$mlkit"');
          return mlkit;
        }
        // ignore: avoid_print
        print('[translate] all engines failed — keeping raw text');
        return t;
      }()
          .timeout(timeout);
    } catch (e) {
      // ignore: avoid_print
      print('[translate] failed, keeping raw text: $e');
      return t;
    }
  }
}
