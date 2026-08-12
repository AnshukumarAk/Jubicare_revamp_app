import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../counsellor/cw.dart';

/// Bounds we hand to speech_to_text so the OS doesn't tear the mic down on
/// its own. `listenFor` is a hard ceiling on any single listen() session
/// (some Android engines refuse durations > ~1h) and `pauseFor` is the
/// silence-timeout — both set high so a normal pause between sentences
/// never ends the recording. Combined with the auto-restart in
/// `_kickListening`, this yields the "runs until user taps stop" behaviour
/// the counsellors asked for (rule 2026-08-05).
const Duration _kListenFor = Duration(minutes: 30);
const Duration _kPauseFor  = Duration(minutes: 5);

/// "Tap to Record Transcript" box: records voice, converts speech→text, and
/// shows/edits the transcript. Writes into [controller].
class VoiceTranscriptBox extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  const VoiceTranscriptBox({super.key, required this.controller, this.hint = 'Tap to record, or type observations'});
  @override
  State<VoiceTranscriptBox> createState() => _VoiceTranscriptBoxState();
}

class _VoiceTranscriptBoxState extends State<VoiceTranscriptBox> {
  final SpeechToText _speech = SpeechToText();
  bool _ready = false, _listening = false;
  // Set to true when the USER taps stop. Distinguishes a deliberate stop
  // from an engine-side auto-stop (silence timeout / OS reclaim) — the
  // latter transparently restarts so recording feels continuous.
  bool _userStopped = false;
  String _base = '';

  Future<void> _toggle() async {
    if (_listening) {
      _userStopped = true;
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    _ready = _ready || await _speech.initialize(onStatus: (s) {
      if ((s == 'done' || s == 'notListening') && mounted) {
        // Engine stopped. If the user didn't ask for this, restart —
        // silence timeouts, brief pauses, etc. shouldn't end the session.
        if (!_userStopped && _listening) {
          _kickListening();
        } else {
          setState(() => _listening = false);
        }
      }
    }, onError: (_) { if (mounted) setState(() => _listening = false); });
    if (!_ready) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Speech recognition unavailable (needs a real device with a mic).'), backgroundColor: C2.danger));
      return;
    }
    _base = widget.controller.text.trim();
    _userStopped = false;
    setState(() => _listening = true);
    _kickListening();
  }

  /// Start (or restart, after a silence-driven auto-stop) one speech
  /// recognition session. Kept separate so onStatus can call it without
  /// having to redo the initialize/permission dance.
  void _kickListening() {
    _speech.listen(
      listenFor: _kListenFor,
      pauseFor: _kPauseFor,
      listenOptions: SpeechListenOptions(onDevice: true, partialResults: true),
      onResult: (r) {
        final t = (_base.isEmpty ? '' : '$_base ') + r.recognizedWords;
        widget.controller.value = TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
        // When the engine finalises a chunk it emits a final result — the
        // next chunk should build on top of that, not overwrite it.
        if (r.finalResult) _base = t.trim();
      },
    );
  }

  @override
  void dispose() { _userStopped = true; _speech.stop(); super.dispose(); }

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
      TextField(controller: widget.controller, minLines: 3, maxLines: 6, decoration: cInput(widget.hint)),
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

class _VoiceMicButtonState extends State<VoiceMicButton> {
  final SpeechToText _speech = SpeechToText();
  bool _ready = false, _listening = false;
  bool _userStopped = false;
  String _base = '';

  Future<void> _toggle() async {
    if (_listening) {
      _userStopped = true;
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    _ready = _ready || await _speech.initialize(onStatus: (s) {
      if ((s == 'done' || s == 'notListening') && mounted) {
        if (!_userStopped && _listening) {
          _kickListening();
        } else {
          setState(() => _listening = false);
        }
      }
    }, onError: (_) { if (mounted) setState(() => _listening = false); });
    if (!_ready) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Speech recognition unavailable (needs a real device with a mic).'), backgroundColor: C2.danger));
      return;
    }
    _base = widget.controller.text.trim();
    _userStopped = false;
    setState(() => _listening = true);
    _kickListening();
  }

  void _kickListening() {
    _speech.listen(
      listenFor: _kListenFor,
      pauseFor: _kPauseFor,
      listenOptions: SpeechListenOptions(onDevice: true, partialResults: true),
      onResult: (r) {
        final t = (_base.isEmpty ? '' : '$_base ') + r.recognizedWords;
        widget.controller.value = TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
        if (r.finalResult) _base = t.trim();
      },
    );
  }

  @override
  void dispose() { _userStopped = true; _speech.stop(); super.dispose(); }

  @override
  Widget build(BuildContext context) => IconButton(
        icon: Icon(_listening ? Icons.stop_circle : Icons.mic, color: _listening ? C2.danger : C2.navy, size: 20),
        onPressed: _toggle,
      );
}
