import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

/// Ultra-low-overhead polyphonic arcade synthesizer & sound effects service.
///
/// Key FPS/main-thread optimizations:
/// 1. Pre-loads `DeviceFileSource` on every [AudioPlayer] once during [init]
///    and sets [ReleaseMode.stop] so runtime playback only invokes
///    `player.seek(Duration.zero)` + `player.resume()` instead of re-opening
///    AVPlayerItem / MediaPlayer files on every hit!
/// 2. Enforces a strict 110ms minimum interval on ball hits (~9/sec max) so
///    platform channel messages never saturate the macOS/iOS main thread when
///    50-100 balls are bouncing simultaneously.
class AudioService {
  static const int _hitPoolSize = 4;
  final List<AudioPlayer> _hitPool =
      List.generate(_hitPoolSize, (_) => AudioPlayer());
  int _hitPoolIndex = 0;

  final AudioPlayer _shootPlayer = AudioPlayer();
  final AudioPlayer _breakPlayer = AudioPlayer();
  final AudioPlayer _laserPlayer = AudioPlayer();
  final AudioPlayer _pickupPlayer = AudioPlayer();
  final AudioPlayer _boomPlayer = AudioPlayer();

  bool isMuted = false;
  bool _initialized = false;

  int _lastHitSoundMs = 0;
  int _lastShootSoundMs = 0;
  int _lastLaserSoundMs = 0;
  int _lastBreakSoundMs = 0;
  int _lastPickupSoundMs = 0;
  int _lastBoomSoundMs = 0;

  Future<void> init({bool muted = false}) async {
    isMuted = muted;

    try {
      final tempDir = Directory(
        '${Directory.systemTemp.path}/bouncestrike_sfx_v3',
      );
      if (!await tempDir.exists()) {
        await tempDir.create(recursive: true);
      }

      // 1. Shoot / Launch Pop (Upward pitch sweep 300Hz -> 620Hz)
      final shootWav = _synthesizeSweepWav(
        startFreq: 300,
        endFreq: 620,
        durationMs: 42,
        volume: 0.65,
      );

      // 2. Four harmonic hit notes (C5, E5, G5, A5) pre-bound to 4 dedicated players
      const hitFreqs = <double>[523.25, 659.25, 783.99, 880.00];
      for (int i = 0; i < _hitPoolSize; i++) {
        final wav = _synthesizeWoodMarimbaHitWav(
          freqHz: hitFreqs[i % hitFreqs.length],
          durationMs: 45,
        );
        final file = File('${tempDir.path}/hit_$i.wav');
        await file.writeAsBytes(wav, flush: true);
        await _hitPool[i].setReleaseMode(ReleaseMode.stop);
        await _hitPool[i].setVolume(0.28);
        await _hitPool[i].setSource(DeviceFileSource(file.path));
      }

      // 3. Brick Shatter / Break
      final breakWav = _synthesizeBreakWav(durationMs: 80);

      // 4. Laser Zap
      final laserWav = _synthesizeSweepWav(
        startFreq: 1450,
        endFreq: 280,
        durationMs: 90,
        volume: 0.70,
        addHarmonic: true,
      );

      // 5. Pickup Chime
      final pickupWav = _synthesizeTwoNoteChimeWav(
        firstFreq: 880.0,
        secondFreq: 1318.5,
        durationMs: 115,
      );

      // 6. Explosion / Boss Destruction
      final boomWav = _synthesizeExplosionWav(durationMs: 170);

      final shootFile = File('${tempDir.path}/shoot.wav');
      final breakFile = File('${tempDir.path}/break.wav');
      final laserFile = File('${tempDir.path}/laser.wav');
      final pickupFile = File('${tempDir.path}/pickup.wav');
      final boomFile = File('${tempDir.path}/boom.wav');

      await shootFile.writeAsBytes(shootWav, flush: true);
      await breakFile.writeAsBytes(breakWav, flush: true);
      await laserFile.writeAsBytes(laserWav, flush: true);
      await pickupFile.writeAsBytes(pickupWav, flush: true);
      await boomFile.writeAsBytes(boomWav, flush: true);

      await _configurePlayer(_shootPlayer, shootFile.path, volume: 0.20);
      await _configurePlayer(_breakPlayer, breakFile.path, volume: 0.40);
      await _configurePlayer(_laserPlayer, laserFile.path, volume: 0.36);
      await _configurePlayer(_pickupPlayer, pickupFile.path, volume: 0.46);
      await _configurePlayer(_boomPlayer, boomFile.path, volume: 0.58);

      _initialized = true;
    } catch (_) {
      _initialized = false;
    }
  }

  Future<void> _configurePlayer(
    AudioPlayer player,
    String filePath, {
    required double volume,
  }) async {
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setVolume(volume);
    await player.setSource(DeviceFileSource(filePath));
  }

  /// Played when the launcher fires a ball (throttled to max ~5/sec).
  void playShoot() {
    if (isMuted || !_initialized) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastShootSoundMs < 180) return;
    _lastShootSoundMs = now;
    _replayPreloaded(_shootPlayer);
  }

  /// Played when a ball bounces off a brick (throttled to max ~9/sec).
  void playHit({int combo = 0}) {
    if (isMuted || !_initialized) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastHitSoundMs < 110) return;
    _lastHitSoundMs = now;

    final player = _hitPool[_hitPoolIndex];
    _hitPoolIndex = (_hitPoolIndex + 1) % _hitPoolSize;
    _replayPreloaded(player);
  }

  /// Played when a brick's HP reaches 0 and shatters (throttled to max ~7/sec).
  void playBrickBreak() {
    if (isMuted || !_initialized) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastBreakSoundMs < 140) return;
    _lastBreakSoundMs = now;
    _replayPreloaded(_breakPlayer);
  }

  /// Played when a horizontal, vertical, or cross laser beam fires.
  void playLaser() {
    if (isMuted || !_initialized) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastLaserSoundMs < 150) return;
    _lastLaserSoundMs = now;
    _replayPreloaded(_laserPlayer);
  }

  /// Played when collecting +1 Ball, +3 MultiBall, or Gold Coins.
  void playPickup() {
    if (isMuted || !_initialized) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastPickupSoundMs < 120) return;
    _lastPickupSoundMs = now;
    _replayPreloaded(_pickupPlayer);
  }

  /// Played on bomb detonations, boss kills, or danger-zone impact.
  void playExplosion() {
    if (isMuted || !_initialized) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastBoomSoundMs < 180) return;
    _lastBoomSoundMs = now;
    _replayPreloaded(_boomPlayer);
  }

  /// Replays an already pre-loaded [AudioPlayer] without re-setting its source!
  Future<void> _replayPreloaded(AudioPlayer player) async {
    try {
      await player.seek(Duration.zero);
      await player.resume();
    } catch (_) {}
  }

  Future<void> pause() async {
    if (!_initialized) return;
    try {
      await Future.wait([
        for (final p in _hitPool) p.stop(),
        _shootPlayer.stop(),
        _breakPlayer.stop(),
        _laserPlayer.stop(),
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
        for (final p in _hitPool) p.dispose(),
        _shootPlayer.dispose(),
        _breakPlayer.dispose(),
        _laserPlayer.dispose(),
        _pickupPlayer.dispose(),
        _boomPlayer.dispose(),
      ]);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // 16-BIT 22050Hz PCM WAV SYNTHESIZERS
  // ---------------------------------------------------------------------------

  static const int _sampleRate = 22050;

  static Uint8List _encodePcm16Wav(Int16List samples) {
    final dataSize = samples.length * 2;
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
    buffer.setUint32(24, _sampleRate, Endian.little);
    buffer.setUint32(28, _sampleRate * 2, Endian.little);
    buffer.setUint16(32, 2, Endian.little);
    buffer.setUint16(34, 16, Endian.little); // 16-bit
    // "data"
    buffer.setUint32(36, 0x64617461, Endian.big);
    buffer.setUint32(40, dataSize, Endian.little);

    for (int i = 0; i < samples.length; i++) {
      buffer.setInt16(44 + i * 2, samples[i], Endian.little);
    }
    return buffer.buffer.asUint8List();
  }

  static Uint8List _synthesizeWoodMarimbaHitWav({
    required double freqHz,
    required int durationMs,
  }) {
    final numSamples = (_sampleRate * durationMs) ~/ 1000;
    final samples = Int16List(numSamples);

    for (int i = 0; i < numSamples; i++) {
      final t = i / _sampleRate;
      final progress = i / numSamples;
      final env = math.pow(1.0 - progress, 2.4).toDouble();
      final fundamental = math.sin(2.0 * math.pi * freqHz * t);
      final overtone = math.sin(2.0 * math.pi * (freqHz * 2.0) * t) * 0.35;
      final wave = (fundamental + overtone) * env * 0.72;
      samples[i] = (wave * 26000).round().clamp(-32767, 32767);
    }
    return _encodePcm16Wav(samples);
  }

  static Uint8List _synthesizeSweepWav({
    required double startFreq,
    required double endFreq,
    required int durationMs,
    required double volume,
    bool addHarmonic = false,
  }) {
    final numSamples = (_sampleRate * durationMs) ~/ 1000;
    final samples = Int16List(numSamples);
    double phase = 0.0;

    for (int i = 0; i < numSamples; i++) {
      final progress = i / numSamples;
      final freq = startFreq + (endFreq - startFreq) * progress;
      phase += (2.0 * math.pi * freq) / _sampleRate;
      final env = math.pow(1.0 - progress, 1.4).toDouble();
      var wave = math.sin(phase);
      if (addHarmonic) {
        wave = (wave + 0.4 * math.sin(phase * 1.5)) * 0.75;
      }
      samples[i] = (wave * env * volume * 28000).round().clamp(-32767, 32767);
    }
    return _encodePcm16Wav(samples);
  }

  static Uint8List _synthesizeBreakWav({required int durationMs}) {
    final numSamples = (_sampleRate * durationMs) ~/ 1000;
    final samples = Int16List(numSamples);
    final rng = math.Random(42);

    for (int i = 0; i < numSamples; i++) {
      final t = i / _sampleRate;
      final progress = i / numSamples;
      final env = math.pow(1.0 - progress, 1.9).toDouble();
      final pop = math.sin(2.0 * math.pi * (680.0 - 260.0 * progress) * t);
      final chime = math.sin(2.0 * math.pi * 1046.5 * t) * 0.45;
      final crunch = (rng.nextDouble() * 2.0 - 1.0) * 0.18;
      final wave = (pop * 0.55 + chime + crunch) * env;
      samples[i] = (wave * 26000).round().clamp(-32767, 32767);
    }
    return _encodePcm16Wav(samples);
  }

  static Uint8List _synthesizeTwoNoteChimeWav({
    required double firstFreq,
    required double secondFreq,
    required int durationMs,
  }) {
    final numSamples = (_sampleRate * durationMs) ~/ 1000;
    final samples = Int16List(numSamples);
    final split = (numSamples * 0.42).round();

    for (int i = 0; i < numSamples; i++) {
      final t = i / _sampleRate;
      final isSecond = i >= split;
      final localProg = isSecond
          ? (i - split) / (numSamples - split)
          : i / split;
      final freq = isSecond ? secondFreq : firstFreq;
      final env = math.pow(1.0 - localProg, 1.6).toDouble();
      final wave = (math.sin(2.0 * math.pi * freq * t) +
              0.3 * math.sin(2.0 * math.pi * freq * 2.0 * t)) *
          env *
          0.75;
      samples[i] = (wave * 27000).round().clamp(-32767, 32767);
    }
    return _encodePcm16Wav(samples);
  }

  static Uint8List _synthesizeExplosionWav({required int durationMs}) {
    final numSamples = (_sampleRate * durationMs) ~/ 1000;
    final samples = Int16List(numSamples);
    final rng = math.Random(99);

    for (int i = 0; i < numSamples; i++) {
      final t = i / _sampleRate;
      final progress = i / numSamples;
      final env = math.pow(1.0 - progress, 1.65).toDouble();
      final subBass = math.sin(2.0 * math.pi * (135.0 - 80.0 * progress) * t);
      final punch = math.sin(2.0 * math.pi * 220.0 * t) * (1.0 - progress);
      final noise = (rng.nextDouble() * 2.0 - 1.0) * 0.38;
      final wave = (subBass * 0.65 + punch * 0.35 + noise) * env;
      samples[i] = (wave * 29000).round().clamp(-32767, 32767);
    }
    return _encodePcm16Wav(samples);
  }
}
