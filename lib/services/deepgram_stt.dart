import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import '../counsellor/cw.dart';
import '../doctor/voice.dart';
import 'connectivity_service.dart';

/// ─── Deepgram live STT — every mic in the app (2026-08-19) ───
///
/// User: "where i am using google's SpeechRecognizer use deepgram, also for
/// offline fallback use google SpeechRecognizer". The [RemarksMicButton] and
/// [SmartTranscriptBox] choosers below pick per connectivity:
///
///   online + key present → Deepgram cloud streaming (this file)
///   offline / key missing → Google SpeechRecognizer (doctor/voice.dart —
///                           on-device, works with no internet)
///
/// Pipeline:  mic PCM16 mono 16 kHz (record package stream, AGC+NS on,
///            software gain-boost for soft voices)
///        →   wss://api.deepgram.com/v1/listen (nova-2, language=hi —
///            locked 2026-08-19 after a 10/10 scripted field test;
///            nova-3 language=multi REJECTED: injected look-alike English
///            words into Hindi: "लिख दे रहा"→"bill", "sir…cut", "Garden")
///        →   interims painted live, finals committed, retracted interims
///            KEPT (never delete words the user already saw).
///
/// The API key is a mobile-embedded pilot key. If the pilot graduates,
/// move issuance behind the backend (short-lived Deepgram tokens) so the
/// key never ships inside the APK.
const String kDeepgramApiKey = String.fromEnvironment(
  'DEEPGRAM_KEY',
  defaultValue: _kDeepgramKeyFallback,
);

/// Paste the pilot key here (or pass --dart-define=DEEPGRAM_KEY=…).
const String _kDeepgramKeyFallback = 'bc85ff6abbf3f3ba880619afaffa36a331dea1dc';

// Model history:
//   A) nova-3 + language=multi   — Aug 19: injected English words into
//      Hindi ("likh dega" → "bill") — REJECTED without keyterm boost.
//   B) nova-2 + language=hi      — Aug 19: 10/10 scripted test, but the
//      doctor field-tested and reported "likh → link" homophone guesses
//      + patchy Hinglish handling.
//   C) nova-3 + language=hi      — Aug 20: Nova-3 now supports hi
//      directly (per Deepgram launch note: 27% WER reduction vs nova-2,
//      "improves recognition across Hinglish speech patterns"), and
//      Keyterm Prompting anchors the model to real clinic vocab so soft
//      homophones don't get invented. ← ACTIVE.
//
// Accuracy tuning (2026-08-20 "kuch bhi likh dega → link dega"):
//   endpointing=500       — wait 0.5s of silence before finalising
//                           (default 10 ms was so aggressive the model
//                            guessed on half-uttered words).
//   utterance_end_ms=1500 — 1.5s hard cap on utterance length; keeps
//                           context wide enough for late corrections.
//   numerals=true         — "do sau" → "200" instead of a fumble.
//
// Keyterm Prompting (Nova-3 only, up to 100 terms — Deepgram docs):
// clinic vocabulary that the model would otherwise homophone-guess. Send
// ONLY words the model gets wrong; over-boosting common words hurts.
// Update this list when new failure cases surface in tracking sessions.
const List<String> _kKeyterms = [
  // Hindi verbs the model kept mangling (2026-08-20 field test:
  // "likh → link", "kuch → cough"). Multi-word PHRASES boost better
  // than single tokens per Deepgram keyterm docs — one phrase = one
  // boosted term. Repeat with variants: Devanagari + romanized.
  'likh dega', 'लिख देगा', 'likh diya', 'लिख दिया', 'likh raha',
  'kuch bhi', 'कुछ भी', 'kuch nahi', 'कुछ नहीं',
  'batao', 'बताओ', 'bataya', 'बताया', 'batayenge',
  'karo', 'करो', 'karta hai', 'करता है', 'kar raha', 'कर रहा',
  'nahi hai', 'नहीं है', 'kaisa hai', 'कैसा है',
  // Symptoms + anatomy — full phrases the clinic uses
  'बुखार है', 'bukhaar hai', 'खांसी है', 'khansi hai',
  'सर दर्द', 'sir dard', 'सिरदर्द', 'सर में दर्द',
  'पेट दर्द', 'pet dard', 'पेट में दर्द', 'उल्टी', 'ulti', 'ulti ho rahi',
  'चक्कर आ रहा', 'chakkar', 'कमज़ोरी', 'kamzori', 'दस्त', 'dast',
  'खुजली', 'khujli', 'सूजन', 'sujan', 'सांस लेने में', 'saans lene mein',
  'छाती में दर्द', 'chhati mein dard', 'गला खराब', 'gala kharab',
  // English medical terms mid-sentence
  'BP', 'BP high', 'BP normal', 'sugar', 'sugar check',
  'tablet', 'capsule', 'syrup', 'ORS', 'paracetamol',
  'platelet', 'hemoglobin', 'blood pressure', 'diabetes', 'thyroid',
  'injection', 'दवाई', 'dawai', 'गोली', 'goli',
  // Frequency / timing phrases
  'दिन में', 'din mein', 'सुबह शाम', 'subah shaam',
  'तीन दिन से', 'teen din se', 'हफ्ते से',
];
String get _kDeepgramUrl {
  final base = 'wss://api.deepgram.com/v1/listen'
      '?model=nova-3'
      '&language=hi'
      '&encoding=linear16'
      '&sample_rate=16000'
      '&channels=1'
      '&interim_results=true'
      '&smart_format=true'
      '&endpointing=500'
      '&utterance_end_ms=1500'
      '&numerals=true';
  // keyterm= repeats — Deepgram accepts multiple. Each param is URL-encoded.
  final terms = _kKeyterms
      .map((t) => 'keyterm=${Uri.encodeQueryComponent(t)}')
      .join('&');
  return terms.isEmpty ? base : '$base&$terms';
}

/// Connectivity-aware mic (drop-in replacement for VoiceMicButton across
/// the whole app — register remarks, doctor/pharma/counsellor notes).
/// Offline → HIDDEN entirely (user 2026-08-20: no button, no message).
class RemarksMicButton extends StatelessWidget {
  final TextEditingController controller;
  const RemarksMicButton({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final online = context.watch<ConnectivityService>().isOnline;
    if (online && kDeepgramApiKey.isNotEmpty) {
      return DeepgramMicButton(controller: controller);
    }
    // Offline / no key → hide the mic completely. TextField keeps its
    // keyboard input; user rule 2026-08-20 "hide button, no message".
    return const SizedBox.shrink();
  }
}

/// Connectivity-aware "Tap to Record Transcript" box (drop-in replacement
/// for VoiceTranscriptBox — doctor Case Details observation). Offline →
/// falls back to a plain typing field, no record button.
class SmartTranscriptBox extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  const SmartTranscriptBox({
    super.key,
    required this.controller,
    this.hint = 'Tap to record, or type observations',
  });

  @override
  Widget build(BuildContext context) {
    final online = context.watch<ConnectivityService>().isOnline;
    if (online && kDeepgramApiKey.isNotEmpty) {
      return DeepgramTranscriptBox(controller: controller, hint: hint);
    }
    // Offline: no mic — just a plain text area so the doctor can still
    // type observations (user rule 2026-08-20 "hide button, no message").
    return TextField(
      controller: controller,
      minLines: 3, maxLines: null,
      keyboardType: TextInputType.multiline,
      decoration: cInput(hint),
    );
  }
}

/// All Deepgram session logic, shared by [DeepgramMicButton] and
/// [DeepgramTranscriptBox] (same pattern as voice.dart's _VoiceEngine so
/// the two UIs can never drift apart).
mixin _DeepgramEngine<T extends StatefulWidget> on State<T> {
  TextEditingController get _ctrl;

  final AudioRecorder _rec = AudioRecorder();
  IOWebSocketChannel? _ch;
  StreamSubscription? _audioSub;
  StreamSubscription? _wsSub;
  Timer? _keepAlive;

  bool _live = false;       // mic + socket running
  bool _connecting = false; // between tap and mic start (~0.2 s)
  bool _stopping = false;   // user tapped stop; drop late repaints

  /// Text committed so far this session = base snapshot + final utterances.
  String _committed = '';
  /// The last string WE wrote — a controller value differing from this is
  /// a manual user edit (same trick as the Google-STT engine).
  String _lastSet = '';
  /// Words painted live but not yet finalised. If Deepgram then RETRACTS
  /// the utterance (empty final — happens with soft speech), we commit
  /// these instead of letting the on-screen words vanish (user bug
  /// 2026-08-19: "he wrote then remove it and delete it").
  String _lastInterim = '';

  // ── live-tracking counters (adb logcat instrumentation — user
  //    2026-08-19: "add log … then you will track everything") ──
  int _chunks = 0;
  int _bytes = 0;
  DateTime? _startedAt;
  bool _gotFirstResult = false;
  // Smoothed software-gain applied to quiet speech (see _boost).
  double _gain = 1.0;

  /// Every stage prints under one greppable tag:
  ///   adb logcat -s flutter | grep deepgram
  void _log(String m) {
    // ignore: avoid_print
    print('[deepgram] $m');
  }

  void _initEngine() => _ctrl.addListener(_onUserEdit);

  void _disposeEngine() {
    _ctrl.removeListener(_onUserEdit);
    _teardown(sendClose: true);
    _rec.dispose();
  }

  /// Manual edit while live → adopt the edited text as the new base so
  /// dictation appends to it instead of resurrecting the old string.
  void _onUserEdit() {
    if (!_live || _stopping) return;
    if (_ctrl.text == _lastSet) return; // our own write
    _committed = _ctrl.text.trim();
    _lastInterim = '';
    _log('user edit — new base "${_committed.length > 40 ? '…${_committed.substring(_committed.length - 40)}' : _committed}"');
  }

  Future<void> _start() async {
    _log('start tapped — key=${kDeepgramApiKey.isEmpty ? "MISSING" : "set (${kDeepgramApiKey.length} chars)"}');
    if (kDeepgramApiKey.isEmpty) {
      _snack('Deepgram API key not set — ask admin to add it and rebuild.');
      return;
    }
    if (_connecting || _live) return;
    setState(() => _connecting = true);
    try {
      if (!await _rec.hasPermission()) {
        _log('mic permission DENIED');
        _snack('Microphone permission denied.');
        setState(() => _connecting = false);
        return;
      }
      _log('mic permission OK');

      // 1. MIC FIRST — capture starts the instant the user taps (the old
      //    socket-first flow made "start" feel 4-5 s slow and LOST the
      //    words spoken while connecting — user 2026-08-19). Chunks are
      //    buffered locally and flushed the moment the socket is ready.
      // autoGain = Android's OS-level AGC (evens out volume across
      // speakers).  noiseSuppress DISABLED 2026-08-20 after community
      // + Deepgram guidance: NS on the mic driver was stripping soft
      // clinic speech BEFORE Deepgram saw it, then our software gain
      // amplified the leftover distortion — the "kuch bhi likh dega →
      // link dega" homophone soup. Let Nova-3 do its own signal
      // processing on clean audio.
      final audio = await _rec.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        autoGain: true,
        noiseSuppress: false,
      ));
      _log('recorder STREAMING (pcm16 / 16 kHz / mono, AGC on, NS off) — speak now');
      _chunks = 0;
      _bytes = 0;
      _gain = 1.0;
      _startedAt = DateTime.now();
      _gotFirstResult = false;
      final pending = <Uint8List>[]; // pre-connect audio backlog
      var socketReady = false;
      _audioSub = audio.listen((chunk) {
        _chunks++;
        _bytes += chunk.length;
        final boosted = _boost(chunk);
        if (_chunks == 1) {
          _log('first audio chunk ${chunk.length} bytes');
        } else if (_chunks % 500 == 0) {
          // ~40 s heartbeat (every 50 flooded logcat — session 2026-08-19).
          _log('audio flowing: $_chunks chunks / ${(_bytes / 1024).toStringAsFixed(0)} KB, '
              'gain=${_gain.toStringAsFixed(1)}x');
        }
        if (socketReady) {
          _ch?.sink.add(boosted);
        } else {
          pending.add(boosted);
          // ~24 s cap — if connect is that slow it has already failed;
          // bound memory instead of growing forever.
          if (pending.length > 300) pending.removeAt(0);
        }
      });

      // Go LIVE in the UI immediately — red stop icon, user speaks now.
      _committed = _ctrl.text.trim();
      _lastSet = _ctrl.text;
      _lastInterim = '';
      _stopping = false;
      setState(() {
        _connecting = false;
        _live = true;
      });

      // 2. Socket IN PARALLEL with capture.
      _log('connecting socket → nova-3 / hi / endpointing=500 / ${_kKeyterms.length} keyterms …');
      final t0 = DateTime.now();
      final ch = IOWebSocketChannel.connect(
        Uri.parse(_kDeepgramUrl),
        headers: {'Authorization': 'Token $kDeepgramApiKey'},
      );
      await ch.ready; // throws on 401 / DNS / offline
      if (_stopping || !mounted) {
        // User already tapped stop while we were connecting.
        try { ch.sink.close(ws_status.normalClosure); } catch (_) {}
        return;
      }
      _ch = ch;
      _log('socket CONNECTED in ${DateTime.now().difference(t0).inMilliseconds} ms '
          '— flushing ${pending.length} buffered chunks');

      _wsSub = ch.stream.listen(_onMessage, onError: (e) {
        _log('socket ERROR: $e');
        _fail('Deepgram connection error');
      }, onDone: () {
        _log('socket closed (onDone) live=$_live stopping=$_stopping');
        // Server closed on us mid-session (idle timeout, network drop).
        if (_live && !_stopping) _fail('Deepgram connection closed');
      });

      // Flush the pre-connect backlog, then switch to direct streaming.
      // No awaits between the loop and the flag, so ordering is safe.
      for (final b in pending) {
        ch.sink.add(b);
      }
      pending.clear();
      socketReady = true;

      // 3. Belt-and-braces: Deepgram drops sockets silent for ~10 s; the
      //    mic streams silence frames continuously so this rarely fires,
      //    but a KeepAlive every 6 s costs nothing.
      _keepAlive = Timer.periodic(const Duration(seconds: 6),
          (_) => _ch?.sink.add(jsonEncode({'type': 'KeepAlive'})));
    } catch (e) {
      // ignore: avoid_print
      print('[deepgram] connect failed: $e');
      _teardown(sendClose: false);
      if (mounted) {
        setState(() {
          _connecting = false;
          _live = false;
        });
        _snack('Could not reach Deepgram — check internet / API key.');
      }
    }
  }

  /// Software gain for QUIET speech (user 2026-08-19: "not taking slow
  /// volume sound"). Per chunk: measure RMS + peak, lift towards a target
  /// RMS of ~6% full-scale, capped so the loudest sample never clips
  /// (peak-limited — the lesson from the Dolphin field test, where an
  /// RMS-only gain clipped long utterances into "") and never above 10×.
  /// Gain is smoothed across chunks so it doesn't pump; true silence
  /// (< ~-48 dB) is left alone so we don't amplify the noise floor.
  Uint8List _boost(Uint8List chunk) {
    final n = chunk.length ~/ 2;
    if (n == 0) return chunk;
    final bd = ByteData.sublistView(chunk, 0, n * 2);
    double sumSq = 0;
    int peak = 1;
    for (var i = 0; i < n; i++) {
      final s = bd.getInt16(i * 2, Endian.little);
      sumSq += (s * s).toDouble();
      final a = s.abs();
      if (a > peak) peak = a;
    }
    final rms = math.sqrt(sumSq / n) / 32768.0;
    if (rms < 0.004) return chunk; // silence / room noise — don't boost
    // Cap gain at 4× (down from 10× — 2026-08-20). With noiseSuppress
    // off, whispers arrive intact; extreme amplification just adds
    // distortion Deepgram then misreads as look-alike words. 4× is
    // enough to lift a soft counsellor's voice to model-friendly RMS.
    final desired = math.min(
      math.min(0.06 / rms, (0.95 * 32767) / peak),
      4.0,
    );
    // Smooth: quick enough to catch a soft sentence, slow enough not to pump.
    _gain = (_gain * 0.7) + (math.max(1.0, desired) * 0.3);
    if (_gain <= 1.02) return chunk; // nothing meaningful to do
    final out = Uint8List(n * 2);
    final ob = ByteData.sublistView(out);
    for (var i = 0; i < n; i++) {
      final s = (bd.getInt16(i * 2, Endian.little) * _gain).round();
      ob.setInt16(i * 2, s.clamp(-32768, 32767), Endian.little);
    }
    return out;
  }

  void _onMessage(dynamic raw) {
    if (_stopping) return;
    Map<String, dynamic> m;
    try {
      m = (jsonDecode(raw as String) as Map).cast<String, dynamic>();
    } catch (_) {
      return;
    }
    if (m['type'] != 'Results') {
      _log('msg type=${m['type']}');
      return;
    }
    final alts = (((m['channel'] as Map?)?['alternatives']) as List?) ?? const [];
    if (alts.isEmpty) return;
    final alt = (alts.first as Map);
    final transcript = (alt['transcript'] as String? ?? '').trim();
    final conf = alt['confidence'];
    final isFinal = m['is_final'] == true;
    final speechFinal = m['speech_final'] == true;

    if (!_gotFirstResult) {
      _gotFirstResult = true;
      final ms = _startedAt == null
          ? '?'
          : DateTime.now().difference(_startedAt!).inMilliseconds.toString();
      _log('FIRST result after $ms ms');
    }
    // Raw view of what the model actually heard — the accuracy debug line
    // (user 2026-08-19: "its not taking proper words"). Empty finals are
    // silence markers Deepgram emits every couple of seconds — skip them
    // or they drown the log.
    if (transcript.isNotEmpty) {
      _log('result final=$isFinal speech_final=$speechFinal '
          'conf=${conf is num ? conf.toStringAsFixed(2) : '?'} "$transcript"');
    }
    if (transcript.isEmpty) {
      // Empty FINAL after words were already painted = Deepgram retracted
      // a soft/uncertain utterance. Keep what the user saw instead of
      // deleting it ("he wrote then remove it and delete it", 2026-08-19).
      if (isFinal && _lastInterim.isNotEmpty) {
        final joined =
            (_committed.isEmpty ? '' : '$_committed ') + _lastInterim;
        _log('empty final — keeping painted interim "$_lastInterim"');
        _committed = joined;
        _lastInterim = '';
        _lastSet = joined;
        _ctrl.value = TextEditingValue(
          text: joined,
          selection: TextSelection.collapsed(offset: joined.length),
        );
      }
      return;
    }

    // Peak-preservation vs overlapping voices (user 2026-08-20: "when
    // another person saying something at the same time my words is
    // removing"). Deepgram sometimes SHRINKS interims/finals when it
    // picks up an overlapping speaker — the dictated words then vanish
    // from screen. Two guards, both keyed on "new result doesn't
    // continue the peak interim":
    //   • Interim: if shorter AND unrelated → drop it (keep peak).
    //   • Final:   if much shorter AND unrelated → commit the peak
    //     interim FIRST (as its own utterance), then land the final on
    //     top as a new segment.
    final peakPrefix = _lastInterim.isEmpty
        ? ''
        : _lastInterim.substring(0, math.min(3, _lastInterim.length));
    final unrelated =
        _lastInterim.isNotEmpty && !transcript.startsWith(peakPrefix);

    if (!isFinal && transcript.length < _lastInterim.length && unrelated) {
      _log('drop shrinking interim "$transcript" — keeping peak "$_lastInterim"');
      return;
    }
    if (isFinal &&
        unrelated &&
        _lastInterim.length > transcript.length + 4) {
      _log('rescue peak interim "$_lastInterim" before unrelated final "$transcript"');
      _committed = (_committed.isEmpty ? '' : '$_committed ') + _lastInterim;
    }

    final joined = (_committed.isEmpty ? '' : '$_committed ') + transcript;
    if (isFinal) {
      // Utterance closed — it becomes part of the base; the next interim
      // paints after it.
      _committed = joined;
      _lastInterim = '';
    } else {
      _lastInterim = transcript;
    }
    _lastSet = joined;
    _ctrl.value = TextEditingValue(
      text: joined,
      selection: TextSelection.collapsed(offset: joined.length),
    );
  }

  Future<void> _stop() async {
    // Words still in interim state get committed NOW — the flush final
    // after CloseStream is dropped once _stopping is set, and losing
    // just-spoken words on stop is the same "wrote then deleted" bug.
    if (_lastInterim.isNotEmpty) {
      final joined = (_committed.isEmpty ? '' : '$_committed ') + _lastInterim;
      _committed = joined;
      _lastInterim = '';
      _lastSet = joined;
      _ctrl.value = TextEditingValue(
        text: joined,
        selection: TextSelection.collapsed(offset: joined.length),
      );
    }
    _log('stop tapped — $_chunks chunks / ${(_bytes / 1024).toStringAsFixed(0)} KB total, '
        'committed ${_committed.length} chars');
    _stopping = true;
    // Ask Deepgram to flush any buffered final before we go.
    try {
      _ch?.sink.add(jsonEncode({'type': 'CloseStream'}));
    } catch (_) {}
    _teardown(sendClose: true);
    if (mounted) {
      setState(() {
        _live = false;
        _connecting = false;
      });
    }
  }

  /// Connection died underneath a live session.
  void _fail(String msg) {
    _log('FAIL: $msg');
    if (_stopping) return;
    _teardown(sendClose: false);
    if (mounted) {
      setState(() {
        _live = false;
        _connecting = false;
      });
      _snack(msg);
    }
  }

  void _teardown({required bool sendClose}) {
    _keepAlive?.cancel();
    _keepAlive = null;
    _audioSub?.cancel();
    _audioSub = null;
    _wsSub?.cancel();
    _wsSub = null;
    try {
      _rec.stop();
    } catch (_) {}
    try {
      if (sendClose) {
        _ch?.sink.close(ws_status.normalClosure);
      } else {
        _ch?.sink.close();
      }
    } catch (_) {}
    _ch = null;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: C2.danger));
  }
}

/// Inline mic (drop-in for VoiceMicButton) that live-transcribes through
/// Deepgram into [controller]. Appends to whatever text is already on
/// screen; interim words repaint live and firm up when Deepgram finalises.
class DeepgramMicButton extends StatefulWidget {
  final TextEditingController controller;
  const DeepgramMicButton({super.key, required this.controller});

  @override
  State<DeepgramMicButton> createState() => _DeepgramMicButtonState();
}

class _DeepgramMicButtonState extends State<DeepgramMicButton>
    with _DeepgramEngine {
  @override
  TextEditingController get _ctrl => widget.controller;

  @override
  void initState() {
    super.initState();
    _initEngine();
  }

  @override
  void dispose() {
    _disposeEngine();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_connecting) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: C2.navy)),
      );
    }
    return IconButton(
      icon: Icon(_live ? Icons.stop_circle : Icons.mic,
          color: _live ? C2.danger : C2.navy, size: 20),
      tooltip: _live ? 'Stop dictation' : 'Dictate (Deepgram)',
      onPressed: _live ? _stop : _start,
    );
  }
}

/// "Tap to Record Transcript" box on the Deepgram engine — visual twin of
/// VoiceTranscriptBox (doctor Case Details observation) so switching
/// engines per connectivity is invisible to the user.
class DeepgramTranscriptBox extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  const DeepgramTranscriptBox({
    super.key,
    required this.controller,
    this.hint = 'Tap to record, or type observations',
  });

  @override
  State<DeepgramTranscriptBox> createState() => _DeepgramTranscriptBoxState();
}

class _DeepgramTranscriptBoxState extends State<DeepgramTranscriptBox>
    with _DeepgramEngine {
  @override
  TextEditingController get _ctrl => widget.controller;

  @override
  void initState() {
    super.initState();
    _initEngine();
  }

  @override
  void dispose() {
    _disposeEngine();
    super.dispose();
  }

  Future<void> _toggle() => _live ? _stop() : _start();

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InkWell(
        onTap: _connecting ? null : _toggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: _live
                ? const LinearGradient(colors: [C2.danger, Color(0xFFB8860B)])
                : const LinearGradient(colors: [C2.navy, C2.cyan]),
            borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(_live ? Icons.stop_circle : Icons.mic,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(_live ? 'Listening… tap to stop' : 'Tap to Record Transcript',
                style: ct(13, FontWeight.w600, Colors.white)),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      // maxLines null — the box GROWS with the transcript instead of
      // hiding the newest words behind an inner scroll (user 2026-08-14).
      TextField(controller: widget.controller, minLines: 3, maxLines: null,
          keyboardType: TextInputType.multiline, decoration: cInput(widget.hint)),
    ]);
  }
}
