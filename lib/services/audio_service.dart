import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

/// Lightweight multi-platform sound effects manager powered by `audioplayers`.
///
/// Generates tiny PCM WAV buffers in memory once at startup so there is zero
/// disk I/O latency during gameplay, and throttles rapid hit sounds to avoid
/// audio thread saturation on low-end mobile devices.
class AudioService {
  final AudioPlayer _fxPlayer = AudioPlayer();
  bool isMuted = false;
  bool _initialized = false;
  int _lastHitSoundMs = 0;

  late final Uint8List _hitWav;
  late final Uint8List _pickupWav;
  late final Uint8List _boomWav;

  Future<void> init({bool muted = false}) async {
    isMuted = muted;
    _hitWav = _synthesizeToneWav(freqHz: 540, durationMs: 36, decay: true);
    _pickupWav = _synthesizeToneWav(freqHz: 880, durationMs: 65, decay: true);
    _boomWav = _synthesizeToneWav(freqHz: 150, durationMs: 110, decay: true);
    try {
      await _fxPlayer.setReleaseMode(ReleaseMode.stop);
      _initialized = true;
    } catch (_) {
      // Safe fallback in headless test environments
      _initialized = false;
    }
  }

  void playHit() {
    if (isMuted || !_initialized) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    // Throttle hit audio to max ~14 times/sec to prevent audio thread lag
    if (now - _lastHitSoundMs < 70) return;
    _lastHitSoundMs = now;
    _playBytes(_hitWav, volume: 0.25);
  }

  void playPickup() {
    if (isMuted || !_initialized) return;
    _playBytes(_pickupWav, volume: 0.40);
  }

  void playExplosion() {
    if (isMuted || !_initialized) return;
    _playBytes(_boomWav, volume: 0.55);
  }

  void _playBytes(Uint8List bytes, {required double volume}) {
    try {
      _fxPlayer.play(BytesSource(bytes), volume: volume);
    } catch (_) {}
  }

  Future<void> pause() async {
    if (!_initialized) return;
    try {
      await _fxPlayer.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    if (!_initialized) return;
    try {
      await _fxPlayer.dispose();
    } catch (_) {}
  }

  /// Generates a tiny 8-bit mono 8000Hz WAV buffer in memory.
  static Uint8List _synthesizeToneWav({
    required double freqHz,
    required int durationMs,
    required bool decay,
  }) {
    const sampleRate = 8000;
    final numSamples = (sampleRate * durationMs) ~/ 1000;
    final dataSize = numSamples;
    final fileSize = 36 + dataSize;

    final buffer = ByteData(44 + dataSize);
    // "RIFF"
    buffer.setUint32(0, 0x52494646, Endian.big);
    buffer.setUint32(4, fileSize, Endian.little);
    // "WAVE"
    buffer.setUint32(8, 0x57415645, Endian.big);
    // "fmt "
    buffer.setUint32(12, 0x666d7420, Endian.big);
    buffer.setUint32(16, 16, Endian.little);
    buffer.setUint16(20, 1, Endian.little); // PCM
    buffer.setUint16(22, 1, Endian.little); // Mono
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, sampleRate, Endian.little);
    buffer.setUint16(32, 1, Endian.little);
    buffer.setUint16(34, 8, Endian.little); // 8-bit
    // "data"
    buffer.setUint32(36, 0x64617461, Endian.big);
    buffer.setUint32(40, dataSize, Endian.little);

    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final env = decay ? (1.0 - (i / numSamples)) : 1.0;
      final wave = math.sin(2.0 * math.pi * freqHz * t) * env;
      final sample = (128 + (wave * 95)).round().clamp(0, 255);
      buffer.setUint8(44 + i, sample);
    }

    return buffer.buffer.asUint8List();
  }
}
