import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

/// Lightweight multi-platform sound effects manager powered by `audioplayers`.
///
/// Pre-generates tiny PCM WAV files once inside `Directory.systemTemp` (which is
/// always writable and pre-created across macOS App Sandbox, iOS, and Android)
/// and pre-loads `DeviceFileSource` on dedicated players. This completely eliminates
/// `BytesSource` cache-directory `PathNotFoundException` crashes and prevents
/// concurrent file-write race conditions during rapid ball hits.
class AudioService {
  final AudioPlayer _hitPlayer = AudioPlayer();
  final AudioPlayer _pickupPlayer = AudioPlayer();
  final AudioPlayer _boomPlayer = AudioPlayer();

  bool isMuted = false;
  bool _initialized = false;
  bool _hitBusy = false;
  int _lastHitSoundMs = 0;

  Source? _hitSource;
  Source? _pickupSource;
  Source? _boomSource;

  Future<void> init({bool muted = false}) async {
    isMuted = muted;
    final hitWav = _synthesizeToneWav(freqHz: 540, durationMs: 36, decay: true);
    final pickupWav =
        _synthesizeToneWav(freqHz: 880, durationMs: 65, decay: true);
    final boomWav =
        _synthesizeToneWav(freqHz: 150, durationMs: 110, decay: true);

    try {
      final tempDir = Directory(
        '${Directory.systemTemp.path}/bouncestrike_sfx',
      );
      if (!await tempDir.exists()) {
        await tempDir.create(recursive: true);
      }

      final hitFile = File('${tempDir.path}/hit.wav');
      final pickupFile = File('${tempDir.path}/pickup.wav');
      final boomFile = File('${tempDir.path}/boom.wav');

      await hitFile.writeAsBytes(hitWav, flush: true);
      await pickupFile.writeAsBytes(pickupWav, flush: true);
      await boomFile.writeAsBytes(boomWav, flush: true);

      _hitSource = DeviceFileSource(hitFile.path);
      _pickupSource = DeviceFileSource(pickupFile.path);
      _boomSource = DeviceFileSource(boomFile.path);

      await Future.wait([
        _hitPlayer.setReleaseMode(ReleaseMode.stop),
        _pickupPlayer.setReleaseMode(ReleaseMode.stop),
        _boomPlayer.setReleaseMode(ReleaseMode.stop),
      ]);

      _initialized = true;
    } catch (_) {
      // Safe fallback in headless test environments or restricted audio devices
      _initialized = false;
    }
  }

  void playHit() {
    if (isMuted || !_initialized || _hitBusy || _hitSource == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    // Throttle hit audio to max ~11 times/sec to prevent audio thread saturation
    if (now - _lastHitSoundMs < 90) return;
    _lastHitSoundMs = now;
    _hitBusy = true;
    _safePlay(_hitPlayer, _hitSource!, volume: 0.25).whenComplete(() {
      _hitBusy = false;
    });
  }

  void playPickup() {
    if (isMuted || !_initialized || _pickupSource == null) return;
    _safePlay(_pickupPlayer, _pickupSource!, volume: 0.40);
  }

  void playExplosion() {
    if (isMuted || !_initialized || _boomSource == null) return;
    _safePlay(_boomPlayer, _boomSource!, volume: 0.55);
  }

  Future<void> _safePlay(
    AudioPlayer player,
    Source source, {
    required double volume,
  }) async {
    try {
      await player.play(source, volume: volume);
    } catch (_) {
      // Swallow platform audio errors so gameplay never stutters or crashes
    }
  }

  Future<void> pause() async {
    if (!_initialized) return;
    try {
      await Future.wait([
        _hitPlayer.stop(),
        _pickupPlayer.stop(),
        _boomPlayer.stop(),
      ]);
    } catch (_) {}
  }

  Future<void> dispose() async {
    if (!_initialized) return;
    _initialized = false;
    try {
      await Future.wait([
        _hitPlayer.dispose(),
        _pickupPlayer.dispose(),
        _boomPlayer.dispose(),
      ]);
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
    buffer.setUint32(36 + 4, dataSize, Endian.little);

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
