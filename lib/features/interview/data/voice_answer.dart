import 'dart:typed_data';

/// Audio settings used for voice answers: 16 kHz, mono, 16-bit PCM.
/// Speech needs nothing more, and it keeps a 3-minute answer under 6 MB.
const int voiceSampleRate = 16000;
const int voiceChannels = 1;

/// Longest answer that can be recorded.
const Duration maxVoiceAnswer = Duration(minutes: 3);

/// A recorded spoken answer, ready to send to Gemini.
class VoiceAnswer {
  final Uint8List wavBytes;
  final Duration duration;

  const VoiceAnswer({required this.wavBytes, required this.duration});

  static const mimeType = 'audio/wav';
}

/// Wraps raw 16-bit little-endian PCM samples in a WAV file header.
Uint8List pcm16ToWav(
  List<int> pcm, {
  int sampleRate = voiceSampleRate,
  int channels = voiceChannels,
}) {
  const bitsPerSample = 16;
  final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
  final blockAlign = channels * bitsPerSample ~/ 8;
  final dataLength = pcm.length;

  final header = ByteData(44)
    ..setUint32(0, 0x52494646) // "RIFF"
    ..setUint32(4, 36 + dataLength, Endian.little)
    ..setUint32(8, 0x57415645) // "WAVE"
    ..setUint32(12, 0x666d7420) // "fmt "
    ..setUint32(16, 16, Endian.little) // fmt chunk size
    ..setUint16(20, 1, Endian.little) // PCM
    ..setUint16(22, channels, Endian.little)
    ..setUint32(24, sampleRate, Endian.little)
    ..setUint32(28, byteRate, Endian.little)
    ..setUint16(32, blockAlign, Endian.little)
    ..setUint16(34, bitsPerSample, Endian.little)
    ..setUint32(36, 0x64617461) // "data"
    ..setUint32(40, dataLength, Endian.little);

  return (BytesBuilder(copy: false)
        ..add(header.buffer.asUint8List())
        ..add(pcm))
      .takeBytes();
}

/// How long [pcmLength] bytes of voice audio last.
Duration pcmDuration(int pcmLength) => Duration(
  milliseconds: pcmLength * 1000 ~/ (voiceSampleRate * voiceChannels * 2),
);

// ─── Feedback on how the answer was spoken ─────────────────────────────────────
enum SpeakingPace {
  slow('A bit slow'),
  good('Good pace'),
  fast('A bit fast');

  final String label;
  const SpeakingPace(this.label);

  static SpeakingPace fromName(Object? name) => SpeakingPace.values.firstWhere(
    (p) => p.name == name,
    orElse: () => SpeakingPace.good,
  );
}

class VoiceDelivery {
  final int fillerWords; // um, uh, like, you know…
  final SpeakingPace pace;
  final List<String> tips;

  const VoiceDelivery({
    required this.fillerWords,
    required this.pace,
    required this.tips,
  });

  Map<String, dynamic> toMap() => {
    'fillerWords': fillerWords,
    'pace': pace.name,
    'tips': tips,
  };

  factory VoiceDelivery.fromMap(Map<String, dynamic> map) {
    return VoiceDelivery(
      fillerWords: ((map['fillerWords'] as num?)?.round() ?? 0).clamp(0, 999),
      pace: SpeakingPace.fromName(map['pace']),
      tips: (map['tips'] as List<dynamic>? ?? const [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .take(3)
          .toList(),
    );
  }
}
