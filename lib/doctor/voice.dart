import 'dart:async';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../counsellor/cw.dart';

/// Bounds we hand to speech_to_text so the OS doesn't tear the mic down on
/// its own. `listenFor` is a hard ceiling on any single listen() session
/// (some Android engines refuse durations > ~1h) and `pauseFor` is the
/// silence-timeout — both set high so a normal pause between sentences
/// never ends the recording. Combined with the watchdog auto-restart in
/// [_VoiceEngine], this yields the "runs until user taps stop" behaviour
/// the counsellors asked for (rule 2026-08-05).
const Duration _kListenFor = Duration(minutes: 30);
const Duration _kPauseFor  = Duration(minutes: 5);

/// ONE recognizer for the whole app. The Android side is a singleton —
/// when each widget held its own SpeechToText instance, pages with two
/// mics (doctor Case Details: transcript box + remarks mic) cross-wired
/// their callbacks and the transcript got cut (user bug 2026-08-14).
final SpeechToText _sharedSpeech = SpeechToText();

/// The widget-state that currently owns the mic. The shared status/error
/// handlers below dispatch to it, so ownership changes never depend on
/// initialize() re-registering listeners (plugin versions differ on that).
_VoiceEngine? _activeVoice;
bool _speechInitDone = false;

Future<bool> _ensureSpeechInit() async {
  if (_speechInitDone) return true;
  _speechInitDone = await _sharedSpeech.initialize(
    onStatus: (s) => _activeVoice?._handleStatus(s),
    onError: (e) => _activeVoice?._handleError(e),
  );
  return _speechInitDone;
}

/// All session logic for a voice-input widget, shared by
/// [VoiceTranscriptBox] and [VoiceMicButton] so the two can never drift
/// apart again.
///
/// Design notes (user bugs 2026-08-14 — "old text cutting after a pause",
/// "cleared text comes back on save", "not appending"):
///  - RESTART IS WATCHDOG-DRIVEN, not callback-driven. Android reports a
///    silence stop as done/notListening AND/OR an error depending on OEM,
///    and some OEMs (ColorOS) suppress app logs so we can't even see
///    which. A 1-second poll of `isListening` revives the session no
///    matter which (or neither) callback fired. Callbacks, when they DO
///    arrive, just make the restart faster.
///  - `_base` snapshots the on-screen text every time a session starts,
///    so recognition APPENDS to whatever is there — old text can never be
///    overwritten by a fresh session.
///  - Results from a dying session (`_ignoreResults`) and after a user
///    stop (`_userStopped`) are dropped: Android flushes a buffered final
///    AFTER stop, which used to resurrect deleted text.
///  - A manual edit while live (controller text != `_lastSet`, the last
///    string WE wrote) recycles the session so the edited text becomes
///    the new base.
mixin _VoiceEngine<T extends StatefulWidget> on State<T> {
  TextEditingController get _ctrl;

  bool _ready = false, _listening = false;
  bool _userStopped = false;
  String _base = '';
  String _lastSet = '';
  // The previous raw recognizedWords of the live session. Google's
  // continuous recognizer silently starts a NEW segment after a pause —
  // no final, no status, no error; the words just reset to the new
  // utterance (caught live 2026-08-14: "...Rahane wala hun" → " filhal").
  String _lastWords = '';
  // Last time ANY result (even an empty one) arrived. The continuous
  // recognizer streams empty results through silence at ~1/s, so dead
  // air on this clock means the native session silently died — it hits
  // an internal cap and keeps claiming isListening=true (user report
  // 2026-08-14: "showing on but not taking voice").
  DateTime _lastResultAt = DateTime.now();
  // Whether the CURRENT session has delivered any result yet. A live
  // session streams results (at least empties) constantly, so dead air
  // after the first result means zombie within 8s. A freshly-started
  // session under pure silence may legitimately send nothing until
  // sound arrives — give it a longer 20s leash before recycling, or a
  // quiet room churns a restart every 8 seconds.
  bool _gotResult = false;
  // True once empty-word results arrive mid-session — the recognizer
  // emits a run of them through every silence gap (observed live), and
  // the first non-empty result AFTER such a gap is a new segment. This
  // is the reliable boundary marker: a pure prefix-comparison ate a
  // whole segment when the next one happened to start with the same
  // word ("...Chhapra mein rahata hun" lost to " Bihar ka CM...").
  bool _sawGap = false;
  bool _ignoreResults = false;
  bool _restartPending = false;
  Timer? _watchdog;

  void _attachEditGuard() => _ctrl.addListener(_onUserEdit);

  void _onUserEdit() {
    if (!_listening || _userStopped) return;
    if (_ctrl.text == _lastSet) return; // our own write
    // ignore: avoid_print
    print('[voice] userEdit detected — recycling session. text="${_ctrl.text}"');
    _ignoreResults = true;
    _sharedSpeech.stop(); // watchdog (or status callback) restarts fresh
  }

  Future<void> _startListening() async {
    // Take ownership of the shared recognizer.
    if (!identical(_activeVoice, this)) {
      _activeVoice?._yieldMic();
      _activeVoice = this;
    }
    _ready = await _ensureSpeechInit();
    if (!_ready) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Speech recognition unavailable (needs a real device with a mic).'),
            backgroundColor: C2.danger));
      }
      return;
    }
    _userStopped = false;
    if (mounted) setState(() => _listening = true);
    _kickListening();
    // The safety net: if the engine died and no callback told us (or it
    // was routed nowhere), this notices within a second and revives the
    // session with the on-screen text as the append base.
    _watchdog?.cancel();
    _watchdog = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _userStopped || !_listening) return;
      if (!_sharedSpeech.isListening && !_restartPending) {
        _restartKeepingText();
      } else if (!_restartPending &&
          DateTime.now().difference(_lastResultAt).inSeconds >=
              (_gotResult ? 8 : 20)) {
        // Zombie session: isListening still claims true but nothing has
        // arrived for 8s (even silence streams empties every second).
        // Cancel the dead session and start a fresh one over the same
        // on-screen text.
        // ignore: avoid_print
        print('[voice] zombie session — recycling');
        _sharedSpeech.cancel();
        _restartKeepingText();
      }
    });
  }

  Future<void> _stopListening() async {
    _userStopped = true;
    _watchdog?.cancel();
    await _sharedSpeech.stop();
    if (mounted) setState(() => _listening = false);
  }

  /// Another widget took the shared mic — end this session cleanly.
  void _yieldMic() {
    _userStopped = true;
    _ignoreResults = true;
    _watchdog?.cancel();
    if (mounted) setState(() => _listening = false);
  }

  void _handleStatus(String s) {
    // ignore: avoid_print
    print('[voice] status=$s listening=$_listening userStopped=$_userStopped');
    if ((s == 'done' || s == 'notListening') && mounted) {
      if (!_userStopped && _listening) {
        _restartKeepingText();
      } else {
        setState(() => _listening = false);
      }
    }
  }

  void _handleError(SpeechRecognitionError e) {
    // ignore: avoid_print
    print('[voice] error=${e.errorMsg} permanent=${e.permanent} listening=$_listening');
    // Truly fatal states never recover by retrying — surface them.
    const fatal = {'error_insufficient_permissions',
                   'error_language_not_supported',
                   'error_language_unavailable'};
    if (fatal.contains(e.errorMsg)) {
      _watchdog?.cancel();
      if (mounted) {
        setState(() => _listening = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Mic unavailable: ${e.errorMsg.replaceAll('_', ' ')}'),
            backgroundColor: C2.danger));
      }
      return;
    }
    // Everything else (speech_timeout / no_match / busy) is a pause or a
    // hiccup — keep the text, restart.
    if (!_userStopped && _listening && mounted) {
      _restartKeepingText();
    } else if (mounted) {
      setState(() => _listening = false);
    }
  }

  /// One restart at a time: status + error + watchdog can all notice the
  /// same engine stop — without this they'd race three listen() calls.
  void _restartKeepingText() {
    if (_restartPending) return;
    _restartPending = true;
    // ignore: avoid_print
    print('[voice] restart scheduled — keeping "${_ctrl.text}"');
    // The dying session may still flush a buffered final — writing it
    // would double or clobber what's on screen.
    _ignoreResults = true;
    _base = _ctrl.text.trim();
    Future.delayed(const Duration(milliseconds: 300), () {
      _restartPending = false;
      if (mounted && _listening && !_userStopped) _kickListening();
    });
  }

  void _kickListening() {
    // The controller is the on-screen truth at the moment a session
    // starts — results append to it, never replace it.
    _base = _ctrl.text.trim();
    _lastSet = _ctrl.text;
    _lastWords = '';
    _sawGap = false;
    _lastResultAt = DateTime.now();
    _gotResult = false;
    _ignoreResults = false;
    // ignore: avoid_print
    print('[voice] kick — base="$_base"');
    _sharedSpeech.listen(
      // listenFor/pauseFor MUST ride inside SpeechListenOptions — the
      // top-level parameters are deprecated and ignored by newer plugin
      // versions, so the engine fell back to its ~3s silence default and
      // ended the session on every breath (part of the pause bug).
      listenOptions: SpeechListenOptions(
        onDevice: false,
        partialResults: true,
        listenFor: _kListenFor,
        pauseFor: _kPauseFor,
      ),
      onResult: (r) {
        _lastResultAt = DateTime.now();
        _gotResult = true;
        // ignore: avoid_print
        print('[voice] result final=${r.finalResult} words="${r.recognizedWords}" '
            'dropped=${_userStopped || _ignoreResults}');
        if (_userStopped || _ignoreResults) return;
        final w = r.recognizedWords;
        final wt = w.trim();
        if (wt.isEmpty) {
          // The recognizer streams a run of EMPTY results through every
          // silence gap (observed live) — remember the gap; the next
          // real words after it belong to a NEW segment.
          if (_lastWords.isNotEmpty) _sawGap = true;
          return;
        }
        // SEGMENT RESET (the "old text deleted" bug, caught live
        // 2026-08-14): after a pause the continuous recognizer silently
        // restarts recognizedWords from scratch — no final, no status,
        // no error. Boundary = first non-empty result after a gap that
        // doesn't simply extend the previous words. (A pure
        // prefix/shrink comparison was not enough: a new segment that
        // starts with the same word as the old one ate a whole segment —
        // "...Chhapra mein rahata hun" lost to " Bihar ka CM...".)
        if (_sawGap && _lastWords.isNotEmpty && !w.startsWith(_lastWords)) {
          _base = _ctrl.text.trim();
          // ignore: avoid_print
          print('[voice] segment reset — new base="$_base"');
        }
        _sawGap = false;
        _lastWords = w;
        final t = (_base.isEmpty ? '' : '$_base ') + wt;
        _lastSet = t;
        _ctrl.value = TextEditingValue(
            text: t, selection: TextSelection.collapsed(offset: t.length));
        // A final result closes this chunk — the next builds on top.
        if (r.finalResult) {
          _base = t.trim();
          _lastWords = '';
        }
      },
    );
  }

  void _disposeVoice() {
    _ctrl.removeListener(_onUserEdit);
    _watchdog?.cancel();
    _userStopped = true;
    // Only touch the shared recognizer if this widget still owns it.
    if (identical(_activeVoice, this)) {
      _activeVoice = null;
      _sharedSpeech.stop();
    }
  }
}

/// "Tap to Record Transcript" box: records voice, converts speech→text, and
/// shows/edits the transcript. Writes into [controller].
class VoiceTranscriptBox extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  const VoiceTranscriptBox({super.key, required this.controller, this.hint = 'Tap to record, or type observations'});
  @override
  State<VoiceTranscriptBox> createState() => _VoiceTranscriptBoxState();
}

class _VoiceTranscriptBoxState extends State<VoiceTranscriptBox> with _VoiceEngine {
  @override
  TextEditingController get _ctrl => widget.controller;

  @override
  void initState() {
    super.initState();
    _attachEditGuard();
  }

  @override
  void dispose() {
    _disposeVoice();
    super.dispose();
  }

  Future<void> _toggle() =>
      _listening ? _stopListening() : _startListening();

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InkWell(
        onTap: _toggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: _listening ? const LinearGradient(colors: [C2.danger, Color(0xFFB8860B)]) : const LinearGradient(colors: [C2.navy, C2.cyan]),
            borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(_listening ? Icons.stop_circle : Icons.mic, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(_listening ? 'Listening… tap to stop' : 'Tap to Record Transcript', style: ct(13, FontWeight.w600, Colors.white)),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      // maxLines null — the box GROWS with the transcript instead of
      // hiding the newest words behind an inner scroll (user 2026-08-14).
      TextField(controller: widget.controller, minLines: 3, maxLines: null, keyboardType: TextInputType.multiline, decoration: cInput(widget.hint)),
    ]);
  }
}

/// Inline mic that appends speech→text into [controller] (e.g. Doctor Remarks).
class VoiceMicButton extends StatefulWidget {
  final TextEditingController controller;
  const VoiceMicButton({super.key, required this.controller});
  @override
  State<VoiceMicButton> createState() => _VoiceMicButtonState();
}

class _VoiceMicButtonState extends State<VoiceMicButton> with _VoiceEngine {
  @override
  TextEditingController get _ctrl => widget.controller;

  @override
  void initState() {
    super.initState();
    _attachEditGuard();
  }

  @override
  void dispose() {
    _disposeVoice();
    super.dispose();
  }

  Future<void> _toggle() =>
      _listening ? _stopListening() : _startListening();

  @override
  Widget build(BuildContext context) => IconButton(
        icon: Icon(_listening ? Icons.stop_circle : Icons.mic, color: _listening ? C2.danger : C2.navy, size: 20),
        onPressed: _toggle,
      );
}
