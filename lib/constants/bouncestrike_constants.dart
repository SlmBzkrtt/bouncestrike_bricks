/// Centralized game constants & virtual coordinate system for
/// BounceStrike: Quantum Bricks (v1.0.0).
///
/// Using a fixed logical coordinate space (1080 x 1470) decouples physics,
/// ball velocities, and gap-passing hitboxes from physical screen pixel density
/// or window resizing across phones, tablets, and desktop.
abstract final class BounceStrikeConstants {
  static const String version = 'v1.0.0';
  static const String appTitle = 'BounceStrike: Quantum Bricks';

  // ---------------------------------------------------------------------------
  // LOGICAL VIRTUAL COORDINATE SYSTEM (9 : 12.25 Aspect Ratio)
  // ---------------------------------------------------------------------------
  static const int cols = 9;
  static const int rows = 12;
  static const int dangerRow = 11;

  /// Virtual width in logical game units (9 cols * 120.0 units per cell).
  static const double logicalWidth = 1080.0;

  /// Virtual height in logical game units (12.25 rows * 120.0 units per cell).
  static const double logicalHeight = 1470.0;

  /// Aspect ratio of the active playfield.
  static const double boardAspectRatio = logicalWidth / logicalHeight;

  /// Logical width & height of a single grid cell (1080 / 9 = 120).
  static const double cellSize = logicalWidth / cols;

  /// Baseline Y coordinate in logical units where the launcher sits.
  static const double launchY = (dangerRow + 0.58) * cellSize;

  /// Padding around each brick cell in logical units (creates narrow seams).
  static const double brickPadding = 9.6;

  /// Base ball radius at 100% size (`cellSize * 0.20 = 24.0` logical units).
  static const double baseBallRadius = cellSize * 0.20;

  /// Base ball speed in logical units per second.
  static const double baseBallSpeed = cellSize * 15.0;

  // ---------------------------------------------------------------------------
  // GAMEPLAY & PERFORMANCE LIMITS
  // ---------------------------------------------------------------------------
  static const int starterBalls = 1;
  static const int starterCoins = 35;
  static const double ballSpawnInterval = 0.052;
  static const double minAimAngleDeg = 9.0;

  /// Hard cap on active particles to prevent GPU overdraw on low-end devices.
  static const int maxActiveParticles = 96;
  static const int maxTrailLength = 7;

  // ---------------------------------------------------------------------------
  // SHARED PREFERENCES KEYS
  // ---------------------------------------------------------------------------
  static const String prefBestLevel = 'bouncestrike_best_level';
  static const String prefCoins = 'bouncestrike_coins';
  static const String prefSelectedTheme = 'bouncestrike_selected_theme';
  static const String prefSelectedSkin = 'bouncestrike_selected_skin';
  static const String prefUnlockedThemes = 'bouncestrike_unlocked_themes';
  static const String prefUnlockedSkins = 'bouncestrike_unlocked_skins';
  static const String prefSoundMuted = 'bouncestrike_sound_muted';
}

typedef GameConstants = BounceStrikeConstants;
