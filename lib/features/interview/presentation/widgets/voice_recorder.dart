import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/voice_answer.dart';

enum _RecorderPhase { idle, starting, recording, recorded }

/// Records a spoken answer as 16 kHz mono WAV.
///
/// The audio is streamed as PCM and kept in memory, which works the same on
/// Android and the web (no temporary files). [onChanged] receives the
/// finished recording, or null while there is none (recording, discarded).
class VoiceRecorder extends StatefulWidget {
  final bool enabled;
  final ValueChanged<VoiceAnswer?> onChanged;

  /// Lets tests replace the real microphone.
  final AudioRecorder Function()? recorderFactory;

  const VoiceRecorder({
    super.key,
    required this.onChanged,
    this.enabled = true,
    this.recorderFactory,
  });

  @override
  State<VoiceRecorder> createState() => _VoiceRecorderState();
}

class _VoiceRecorderState extends State<VoiceRecorder> {
  static const _minLength = Duration(seconds: 2);
  static const _bars = 28;

  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _audioSub;
  StreamSubscription<Amplitude>? _levelSub;
  Timer? _ticker;

  BytesBuilder _pcm = BytesBuilder(copy: false);
  _RecorderPhase _phase = _RecorderPhase.idle;
  Duration _elapsed = Duration.zero;
  VoiceAnswer? _answer;
  String? _message;
  final List<double> _levels = List.filled(_bars, 0);

  @override
  void dispose() {
    _ticker?.cancel();
    _audioSub?.cancel();
    _levelSub?.cancel();
    final recorder = _recorder;
    if (recorder != null) {
      // Stops the microphone if the user leaves while recording.
      recorder.cancel().catchError((_) {}).whenComplete(recorder.dispose);
    }
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _phase = _RecorderPhase.starting;
      _message = null;
    });

    try {
      final recorder = _recorder ??=
          (widget.recorderFactory ?? AudioRecorder.new)();

      if (!await recorder.hasPermission()) {
        _reset(
          message:
              'Microphone access is needed to answer by voice. '
              'Allow it in your phone or browser settings, then try again.',
        );
        return;
      }

      _pcm = BytesBuilder(copy: false);
      final stream = await recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: voiceSampleRate,
          numChannels: voiceChannels,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
        ),
      );
      _audioSub = stream.listen(_pcm.add);
      _levelSub = recorder
          .onAmplitudeChanged(const Duration(milliseconds: 120))
          .listen(_onLevel);

      final startedAt = DateTime.now();
      _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
        final elapsed = DateTime.now().difference(startedAt);
        if (elapsed >= maxVoiceAnswer) {
          _stop();
        } else if (mounted) {
          setState(() => _elapsed = elapsed);
        }
      });

      if (mounted) setState(() => _phase = _RecorderPhase.recording);
      widget.onChanged(null);
    } catch (_) {
      _reset(
        message:
            'Could not start the microphone. Check that no other app is '
            'using it and try again.',
      );
    }
  }

  void _onLevel(Amplitude amplitude) {
    if (!mounted) return;
    // dBFS: about -60 is silence, 0 is the loudest.
    final level = ((amplitude.current + 60) / 60).clamp(0.05, 1.0);
    setState(() {
      _levels.removeAt(0);
      _levels.add(level.toDouble());
    });
  }

  Future<void> _stop() async {
    if (_phase != _RecorderPhase.recording) return;
    _ticker?.cancel();
    try {
      await _recorder?.stop();
    } catch (_) {
      // The data already received is still usable.
    }
    await _audioSub?.cancel();
    await _levelSub?.cancel();
    _audioSub = null;
    _levelSub = null;

    final pcm = _pcm.takeBytes();
    final duration = pcmDuration(pcm.length);
    if (duration < _minLength) {
      _reset(message: 'That was too short. Tap the mic and give your answer.');
      return;
    }

    final answer = VoiceAnswer(wavBytes: pcm16ToWav(pcm), duration: duration);
    if (!mounted) return;
    setState(() {
      _answer = answer;
      _elapsed = duration;
      _phase = _RecorderPhase.recorded;
    });
    widget.onChanged(answer);
  }

  void _reset({String? message}) {
    _ticker?.cancel();
    if (!mounted) return;
    setState(() {
      _phase = _RecorderPhase.idle;
      _answer = null;
      _elapsed = Duration.zero;
      _message = message;
      _levels.fillRange(0, _bars, 0);
    });
    widget.onChanged(null);
  }

  String _format(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final recording = _phase == _RecorderPhase.recording;
    final recorded = _phase == _RecorderPhase.recorded;
    final color = recording ? AppColors.error : AppColors.primary;

    final String title;
    final String subtitle;
    switch (_phase) {
      case _RecorderPhase.idle:
        title = 'Tap the mic and answer out loud';
        subtitle =
            'Speak as you would in the interview · up to '
            '${maxVoiceAnswer.inMinutes} min';
      case _RecorderPhase.starting:
        title = 'Starting the microphone…';
        subtitle = 'Allow microphone access if you are asked';
      case _RecorderPhase.recording:
        title = 'Recording  ${_format(_elapsed)}';
        subtitle = 'Tap stop when you finish';
      case _RecorderPhase.recorded:
        title = 'Answer recorded  ${_format(_answer!.duration)}';
        subtitle = 'Submit it, or record again';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: recording
              ? AppColors.error.withValues(alpha: 0.5)
              : (isDark ? const Color(0xFF2A2A40) : const Color(0xFFEEEEF9)),
        ),
      ),
      child: Column(
        children: [
          Semantics(
            button: true,
            label: recording ? 'Stop recording' : 'Start recording',
            child: GestureDetector(
              onTap: !widget.enabled || _phase == _RecorderPhase.starting
                  ? null
                  : recording
                  ? _stop
                  : _start,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.enabled ? color : AppColors.textGrey,
                  boxShadow: [
                    if (widget.enabled)
                      BoxShadow(
                        color: color.withValues(alpha: recording ? 0.45 : 0.3),
                        blurRadius: recording ? 22 : 14,
                        spreadRadius: recording ? 4 : 0,
                      ),
                  ],
                ),
                child: _phase == _RecorderPhase.starting
                    ? const Padding(
                        padding: EdgeInsets.all(26),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        recording
                            ? Icons.stop_rounded
                            : recorded
                            ? Icons.mic_rounded
                            : Icons.mic_none_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 34,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (final level in _levels)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 4,
                    height: recording ? 4 + level * 30 : 4,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: (recording ? AppColors.error : AppColors.textGrey)
                          .withValues(alpha: recording ? 0.85 : 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textGrey, fontSize: 12.5),
          ),
          if (recorded) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: widget.enabled ? _reset : null,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Record again'),
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 10),
            Text(
              _message!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.errorText(context),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
