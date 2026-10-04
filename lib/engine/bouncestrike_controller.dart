import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/bouncestrike_constants.dart';
import '../models/bouncestrike_models.dart';
import '../services/audio_service.dart';
import '../services/storage_service.dart';
import 'bouncestrike_physics.dart';

class BounceStrikeController extends ChangeNotifier {
  static const int cols = BounceStrikeConstants.cols;
  static const int rows = BounceStrikeConstants.rows;
  static const int dangerRow = BounceStrikeConstants.dangerRow;

  final math.Random _rng = math.Random();
  final StorageService storage = StorageService();
  final AudioService audio = AudioService();

  /// Dedicated high-frequency notifier for [BounceStrikePainter] canvas repaints.
  /// Separating this from [notifyListeners] prevents the Flutter UI widget tree
  /// (HUD, buttons, shop bar) from rebuilding 60-120 times per second!
  final ValueNotifier<int> repaintNotifier = ValueNotifier<int>(0);

  // Fixed logical coordinate space (1080 x 1470) — resolution independent!
  double get boardWidth => BounceStrikeConstants.logicalWidth;
  double get boardHeight => BounceStrikeConstants.logicalHeight;
  double get cellSize => BounceStrikeConstants.cellSize;
  double get launchY => BounceStrikeConstants.launchY;

  double get baseBallRadius => BounceStrikeConstants.baseBallRadius;
  double get ballRadius => baseBallRadius * selectedSkin.radiusMultiplier;
  double get ballSpeed =>
      BounceStrikeConstants.baseBallSpeed * selectedSkin.speedMultiplier;

  // Game progress & Balanced Economy (v1.0.0)
  TurnPhase phase = TurnPhase.aiming;
  int level = 1;
  int bestLevel = 1;
  int totalBalls = BounceStrikeConstants.starterBalls;
  int bonusBallsCollectedThisTurn = 0;
  int coins = BounceStrikeConstants.starterCoins;
  int currentTurnCombo = 0;
  int maxCombo = 0;

  // Theme & Ball Skin state
  GameTheme selectedTheme = GameTheme.spaceTheme;
  final Set<GameThemeId> unlockedThemeIds = {GameThemeId.space};
  late BallSkin selectedSkin = GameTheme.spaceTheme.balls.first;
  final Set<String> unlockedSkinIds = {
    GameTheme.spaceTheme.balls.first.id,
  };

  List<BallSkin> get currentThemeBalls => selectedTheme.balls;

  // Launcher & Character state (in logical coordinates)
  double launchX = BounceStrikeConstants.logicalWidth / 2;
  double characterVisualX = BounceStrikeConstants.logicalWidth / 2;
  double? nextLaunchX;
  bool isDraggingAim = false;
  double aimAngle = -math.pi / 2;
  double cannonRecoil = 0.0;

  // Entities & Projectiles
  int _nextEntityId = 1;
  final List<GridEntity> entities = [];
  /// O(1) spatial lookup grid indexed by `row * cols + col` for instant collision checks.
  final List<GridEntity?> _spatialGrid =
      List<GridEntity?>.filled(cols * (rows + 2), null);

  final List<Ball> activeBalls = [];
  int ballsRemainingToSpawn = 0;
  double _spawnTimer = 0.0;

  // Turn timer, pulse phase & Fast-Forward
  double turnElapsedSeconds = 0.0;
  double pulseValue = 0.0;
  double _pulseTime = 0.0;
  int speedMultiplier = 1;

  // Sliding animation state
  double _slideProgress = 0.0;

  // Visual Effects
  final List<LaserBeamEffect> laserBeams = [];
  final List<ShockwaveEffect> shockwaves = [];
  final List<LightningArcEffect> lightningArcs = [];
  final List<Particle> particles = [];
  final List<FloatingText> floatingTexts = [];
  double screenShake = 0.0;
  bool reviveUsed = false;

  BounceStrikeController() {
    startNewGame();
    _initServices();
  }

  Future<void> _initServices() async {
    await storage.init();
    bestLevel = storage.getBestLevel();
    coins = storage.getCoins();

    for (final tName in storage.getUnlockedThemes()) {
      for (final theme in GameTheme.allThemes) {
        if (theme.id.name == tName) {
          unlockedThemeIds.add(theme.id);
        }
      }
    }
    unlockedSkinIds.addAll(storage.getUnlockedSkins());

    final savedThemeName = storage.getSelectedThemeId();
    if (savedThemeName != null) {
      for (final theme in GameTheme.allThemes) {
        if (theme.id.name == savedThemeName &&
            unlockedThemeIds.contains(theme.id)) {
          selectedTheme = theme;
          break;
        }
      }
    }

    final savedSkinId = storage.getSelectedSkinId();
    if (savedSkinId != null && unlockedSkinIds.contains(savedSkinId)) {
      for (final b in selectedTheme.balls) {
        if (b.id == savedSkinId) {
          selectedSkin = b;
          break;
        }
      }
    }

    await audio.init(muted: storage.getSoundMuted());
    notifyListeners();
    _markCanvasDirty();
  }

  void _savePersistentData() {
    storage.setBestLevel(bestLevel);
    storage.setCoins(coins);
    storage.setSelectedThemeId(selectedTheme.id.name);
    storage.setSelectedSkinId(selectedSkin.id);
    storage.setUnlockedThemes(unlockedThemeIds.map((e) => e.name));
    storage.setUnlockedSkins(unlockedSkinIds);
  }

  bool get isMuted => audio.isMuted;

  void toggleMute() {
    audio.isMuted = !audio.isMuted;
    storage.setSoundMuted(audio.isMuted);
    notifyListeners();
  }

  void _markCanvasDirty() {
    repaintNotifier.value++;
  }

  String get difficultyStageName {
    if (level <= 4) return 'Evre 1: Isınma';
    if (level <= 10) return 'Evre 2: Prizma Matrisi';
    if (level <= 18) return 'Evre 3: Fırtına Hattı';
    if (level <= 28) return 'Evre 4: Yoğun Kuşatma';
    return 'Evre 5: Kaos Overdrive';
  }

  /// Maps a physical pointer position inside a rendered widget of [renderSize]
  /// into the 1080x1470 virtual logical coordinate system.
  Offset toLogicalOffset(Offset localPosition, Size renderSize) {
    if (renderSize.width <= 0 || renderSize.height <= 0) {
      return localPosition;
    }
    return Offset(
      localPosition.dx * (boardWidth / renderSize.width),
      localPosition.dy * (boardHeight / renderSize.height),
    );
  }

  void startNewGame() {
    level = 1;
    totalBalls = BounceStrikeConstants.starterBalls;
    bonusBallsCollectedThisTurn = 0;
    currentTurnCombo = 0;
    phase = TurnPhase.aiming;
    speedMultiplier = 1;
    turnElapsedSeconds = 0.0;
    reviveUsed = false;
    entities.clear();
    activeBalls.clear();
    laserBeams.clear();
    shockwaves.clear();
    lightningArcs.clear();
    particles.clear();
    floatingTexts.clear();
    launchX = boardWidth / 2;
    characterVisualX = launchX;
    nextLaunchX = null;
    aimAngle = -math.pi / 2;

    _spawnRowForLevel(1, targetRow: 1);
    notifyListeners();
    _markCanvasDirty();
  }

  void reviveClearBottomRows() {
    if (phase != TurnPhase.gameOver || reviveUsed) return;
    reviveUsed = true;
    final toRemove = <GridEntity>[];
    for (final e in entities) {
      if (e.row >= dangerRow - 3) {
        toRemove.add(e);
        if (e.isBrick) {
          final center =
              BounceStrikePhysics.cellRect(e.col, e.visualRow, cellSize).center;
          _addParticlesCapped(
            Particle.burst(
              origin: center,
              color: selectedTheme.accentColor,
              count: 16,
              speed: 480.0,
            ),
          );
          shockwaves.add(
            ShockwaveEffect(
              origin: center,
              color: selectedTheme.accentColor,
              maxRadius: cellSize * 1.6,
            ),
          );
        }
      }
    }
    entities.removeWhere(toRemove.contains);
    screenShake = 10.0;
    phase = TurnPhase.aiming;
    audio.playExplosion();
    HapticFeedback.mediumImpact();
    notifyListeners();
    _markCanvasDirty();
  }

  bool selectOrUnlockTheme(GameTheme theme) {
    if (unlockedThemeIds.contains(theme.id)) {
      _applyTheme(theme);
      _savePersistentData();
      HapticFeedback.selectionClick();
      notifyListeners();
      _markCanvasDirty();
      return true;
    }
    if (coins >= theme.cost) {
      coins -= theme.cost;
      unlockedThemeIds.add(theme.id);
      unlockedSkinIds.add(theme.balls.first.id);
      _applyTheme(theme);
      _savePersistentData();
      audio.playPickup();
      HapticFeedback.mediumImpact();
      notifyListeners();
      _markCanvasDirty();
      return true;
    }
    return false;
  }

  void _applyTheme(GameTheme theme) {
    selectedTheme = theme;
    unlockedSkinIds.add(theme.balls.first.id);
    BallSkin bestUnlocked = theme.balls.first;
    for (final b in theme.balls) {
      if (unlockedSkinIds.contains(b.id)) {
        bestUnlocked = b;
      }
    }
    selectedSkin = bestUnlocked;
  }

  bool selectOrUnlockSkin(BallSkin skin) {
    if (!unlockedThemeIds.contains(skin.themeId)) {
      return false;
    }
    if (unlockedSkinIds.contains(skin.id)) {
      selectedSkin = skin;
      _savePersistentData();
      HapticFeedback.selectionClick();
      notifyListeners();
      _markCanvasDirty();
      return true;
    }
    if (coins >= skin.cost) {
      coins -= skin.cost;
      unlockedSkinIds.add(skin.id);
      selectedSkin = skin;
      _savePersistentData();
      audio.playPickup();
      HapticFeedback.lightImpact();
      notifyListeners();
      _markCanvasDirty();
      return true;
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // AIMING & INPUT
  // ---------------------------------------------------------------------------

  void onAimStart(Offset logicalPos) {
    if (phase != TurnPhase.aiming) return;
    isDraggingAim = true;
    _updateAimFromLogicalTouch(logicalPos);
    _markCanvasDirty();
  }

  void onAimUpdate(Offset logicalPos) {
    if (phase != TurnPhase.aiming || !isDraggingAim) return;
    _updateAimFromLogicalTouch(logicalPos);
    _markCanvasDirty();
  }

  void onAimCancel() {
    if (!isDraggingAim) return;
    isDraggingAim = false;
    _markCanvasDirty();
  }

  void onAimEnd() {
    if (phase != TurnPhase.aiming || !isDraggingAim) return;
    isDraggingAim = false;
    _launchBalls();
  }

  void _updateAimFromLogicalTouch(Offset touch) {
    final origin = Offset(launchX, launchY);
    var delta = touch - origin;

    if (delta.dy > 40) {
      delta = -delta;
    }

    if (delta.distance < 18.0) return;

    var angle = math.atan2(delta.dy, delta.dx);
    const minAngle =
        -math.pi + (BounceStrikeConstants.minAimAngleDeg * math.pi / 180.0);
    const maxAngle = -(BounceStrikeConstants.minAimAngleDeg * math.pi / 180.0);

    if (angle > 0) {
      angle = touch.dx < launchX ? minAngle : maxAngle;
    } else {
      angle = angle.clamp(minAngle, maxAngle);
    }
    aimAngle = angle;
  }

  TrajectoryPreview? get currentTrajectory {
    if (phase != TurnPhase.aiming || !isDraggingAim) return null;
    return BounceStrikePhysics.computeTrajectory(
      start: Offset(launchX, launchY),
      angle: aimAngle,
      ballRadius: ballRadius,
      boardWidth: boardWidth,
      launchY: launchY,
      cellSize: cellSize,
      entities: entities,
    );
  }

  void _launchBalls() {
    phase = TurnPhase.shooting;
    ballsRemainingToSpawn = totalBalls;
    bonusBallsCollectedThisTurn = 0;
    currentTurnCombo = 0;
    _spawnTimer = 0.0;
    turnElapsedSeconds = 0.0;
    speedMultiplier = 1;
    nextLaunchX = null;
    activeBalls.clear();

    for (final e in entities) {
      e.overlappingBallIds.clear();
    }

    _spawnSingleBall();
    HapticFeedback.selectionClick();
    notifyListeners();
    _markCanvasDirty();
  }

  void _spawnSingleBall() {
    if (ballsRemainingToSpawn <= 0) return;
    final id = totalBalls - ballsRemainingToSpawn + 1;
    ballsRemainingToSpawn--;
    cannonRecoil = 1.0;
    audio.playShoot();

    final dir = Offset(math.cos(aimAngle), math.sin(aimAngle));
    activeBalls.add(
      Ball(
        id: id,
        position: Offset(launchX, launchY - 5.0),
        velocity: dir * ballSpeed,
        radius: ballRadius,
      )..isLaunched = true,
    );
  }

  void toggleFastForward() {
    if (phase != TurnPhase.shooting) return;
    if (speedMultiplier == 1) {
      speedMultiplier = 2;
    } else if (speedMultiplier == 2) {
      speedMultiplier = 4;
    } else {
      speedMultiplier = 1;
    }
    notifyListeners();
  }

  void recallAllBalls() {
    if (phase != TurnPhase.shooting) return;
    ballsRemainingToSpawn = 0;
    nextLaunchX ??= launchX;
    for (final b in activeBalls) {
      b.isReturned = true;
      b.position = Offset(nextLaunchX!, launchY);
    }
    HapticFeedback.lightImpact();
    _finishShootingPhase();
  }

  // ---------------------------------------------------------------------------
  // MAIN GAME TICK (DECOUPLED CANVAS vs UI REBUILD)
  // ---------------------------------------------------------------------------

  void _rebuildSpatialGrid() {
    _spatialGrid.fillRange(0, _spatialGrid.length, null);
    for (final e in entities) {
      if (e.col >= 0 && e.col < cols && e.row >= 0 && e.row < rows + 2) {
        _spatialGrid[e.row * cols + e.col] = e;
      }
    }
  }

  void update(double dt) {
    final safeDt = dt.clamp(0.0, 0.033);

    // Smooth 0.0 <-> 1.0 triangle wave for ambient animations (replaces extra AnimationController)
    _pulseTime = (_pulseTime + safeDt * 1.15) % 2.0;
    pulseValue = _pulseTime <= 1.0 ? _pulseTime : 2.0 - _pulseTime;

    _updateVisualEffects(safeDt);

    if (phase == TurnPhase.shooting) {
      turnElapsedSeconds += safeDt;
      final effectiveDt = safeDt * speedMultiplier;
      _updateShootingPhase(effectiveDt);
      _markCanvasDirty();
    } else if (phase == TurnPhase.slidingDown) {
      _updateSlidingPhase(safeDt);
      _markCanvasDirty();
    } else {
      // Aiming or GameOver: still tick ambient theme animations smoothly
      _markCanvasDirty();
    }
  }

  void _addParticlesCapped(List<Particle> newParticles) {
    final available =
        BounceStrikeConstants.maxActiveParticles - particles.length;
    if (available <= 0) return;
    if (newParticles.length <= available) {
      particles.addAll(newParticles);
    } else {
      particles.addAll(newParticles.take(available));
    }
  }

  void _updateVisualEffects(double dt) {
    if (screenShake > 0) {
      screenShake = math.max(0.0, screenShake - dt * 28.0);
    }
    if (cannonRecoil > 0) {
      cannonRecoil = math.max(0.0, cannonRecoil - dt * 8.0);
    }

    final targetCharX = nextLaunchX ?? launchX;
    final charDiff = targetCharX - characterVisualX;
    if (charDiff.abs() > 1.0) {
      characterVisualX += charDiff * (dt * 12.0).clamp(0.0, 1.0);
    } else {
      characterVisualX = targetCharX;
    }

    for (final e in entities) {
      if (e.hitFlash > 0) {
        e.hitFlash = math.max(0.0, e.hitFlash - dt * 6.5);
      }
      if (e.scale > 1.0) {
        e.scale = math.max(1.0, e.scale - dt * 3.5);
      }
    }

    for (int i = laserBeams.length - 1; i >= 0; i--) {
      laserBeams[i].life -= dt * 4.5;
      if (laserBeams[i].life <= 0) {
        laserBeams.removeAt(i);
      }
    }

    for (int i = shockwaves.length - 1; i >= 0; i--) {
      final sw = shockwaves[i];
      sw.progress += dt * sw.speed;
      if (sw.progress >= 1.0) {
        shockwaves.removeAt(i);
      }
    }

    for (int i = lightningArcs.length - 1; i >= 0; i--) {
      lightningArcs[i].life -= dt * 5.5;
      if (lightningArcs[i].life <= 0) {
        lightningArcs.removeAt(i);
      }
    }

    for (int i = particles.length - 1; i >= 0; i--) {
      final p = particles[i];
      p.position += p.velocity * dt;
      p.velocity =
          Offset(p.velocity.dx * 0.93, p.velocity.dy * 0.93 + 420 * dt);
      p.rotation += p.angularVelocity * dt;
      p.life -= dt * 2.4;
      if (p.life <= 0) {
        particles.removeAt(i);
      }
    }

    for (int i = floatingTexts.length - 1; i >= 0; i--) {
      final ft = floatingTexts[i];
      ft.position += Offset(0, -110.0 * dt);
      ft.life -= dt * 1.45;
      if (ft.life <= 0) {
        floatingTexts.removeAt(i);
      }
    }
  }

  void _updateShootingPhase(double dt) {
    if (ballsRemainingToSpawn > 0) {
      _spawnTimer += dt;
      while (_spawnTimer >= BounceStrikeConstants.ballSpawnInterval &&
          ballsRemainingToSpawn > 0) {
        _spawnTimer -= BounceStrikeConstants.ballSpawnInterval;
        _spawnSingleBall();
      }
    }

    _rebuildSpatialGrid();

    // Cap subSteps to max 5 so 100+ balls at 4x speed never cause CPU frame drops
    final double maxStepDistance = math.max(9.0, ballRadius * 0.85);
    final int subSteps =
        math.max(1, ((ballSpeed * dt) / maxStepDistance).ceil()).clamp(1, 5);
    final double subDt = dt / subSteps;

    bool uiDirty = false;

    for (int step = 0; step < subSteps; step++) {
      for (int bIdx = 0; bIdx < activeBalls.length; bIdx++) {
        final ball = activeBalls[bIdx];
        if (ball.isReturned) {
          if (nextLaunchX != null) {
            final diff = nextLaunchX! - ball.position.dx;
            if (diff.abs() > 3.0) {
              ball.position = Offset(
                ball.position.dx + diff * (subDt * 20.0).clamp(0.0, 1.0),
                launchY,
              );
            } else {
              ball.position = Offset(nextLaunchX!, launchY);
            }
          }
          continue;
        }

        ball.position += ball.velocity * subDt;
        ball.rotation += 11.0 * subDt;

        // Wall reflections (Left, Right, Top)
        if (ball.position.dx - ball.radius <= 0) {
          ball.position = Offset(ball.radius, ball.position.dy);
          ball.velocity = Offset(ball.velocity.dx.abs(), ball.velocity.dy);
          _checkHorizontalLoopGuard(ball);
        } else if (ball.position.dx + ball.radius >= boardWidth) {
          ball.position = Offset(boardWidth - ball.radius, ball.position.dy);
          ball.velocity = Offset(-ball.velocity.dx.abs(), ball.velocity.dy);
          _checkHorizontalLoopGuard(ball);
        }

        if (ball.position.dy - ball.radius <= 0) {
          ball.position = Offset(ball.position.dx, ball.radius);
          ball.velocity = Offset(ball.velocity.dx, ball.velocity.dy.abs());
          ball.horizontalBounceCount = 0;
        }

        // Bottom baseline check
        if (ball.position.dy >= launchY) {
          ball.position = Offset(
            ball.position.dx
                .clamp(cellSize * 0.45, boardWidth - cellSize * 0.45),
            launchY,
          );
          ball.velocity = Offset.zero;
          ball.isReturned = true;
          ball.trail.clear();
          nextLaunchX ??= ball.position.dx;
          continue;
        }

        if (_handleBallEntityInteractions(ball)) {
          uiDirty = true;
        }
      }
    }

    // Record trail only when ball count is moderate to avoid thousands of drawLine calls
    if (activeBalls.length <= 35) {
      for (final ball in activeBalls) {
        if (!ball.isReturned) {
          ball.recordTrail();
        }
      }
    }

    if (uiDirty) {
      notifyListeners();
    }

    if (ballsRemainingToSpawn == 0 && activeBalls.every((b) => b.isReturned)) {
      _finishShootingPhase();
    }
  }

  void _checkHorizontalLoopGuard(Ball ball) {
    if ((ball.position.dy - ball.lastBounceY).abs() < 12.0) {
      ball.horizontalBounceCount++;
      if (ball.horizontalBounceCount >= 6) {
        final signX = ball.velocity.dx >= 0 ? 1.0 : -1.0;
        final nudged = Offset(signX * 0.97, 0.24);
        ball.velocity = nudged * ballSpeed;
        ball.horizontalBounceCount = 0;
      }
    } else {
      ball.horizontalBounceCount = 0;
    }
    ball.lastBounceY = ball.position.dy;
  }

  /// O(1) 3x3 neighborhood collision check around the ball's current grid cell.
  /// Returns `true` ONLY if coins or bonusBalls changed (never on combo changes).
  bool _handleBallEntityInteractions(Ball ball) {
    bool hudChanged = false;

    final int centerCol = (ball.position.dx ~/ cellSize).clamp(0, cols - 1);
    final int centerRow = (ball.position.dy ~/ cellSize).clamp(0, rows);

    final int minC = math.max(0, centerCol - 1);
    final int maxC = math.min(cols - 1, centerCol + 1);
    final int minR = math.max(0, centerRow - 1);
    final int maxR = math.min(rows + 1, centerRow + 1);

    for (int r = minR; r <= maxR; r++) {
      final int rowOffset = r * cols;
      for (int c = minC; c <= maxC; c++) {
        final entity = _spatialGrid[rowOffset + c];
        if (entity == null) continue;

        if (entity.isBrick) {
          final bounced = BounceStrikePhysics.resolveBallBrickCollision(
            ball,
            entity,
            cellSize,
          );
          if (bounced) {
            final currentSpeed = ball.velocity.distance;
            if (currentSpeed > 1e-4) {
              ball.velocity = (ball.velocity / currentSpeed) * ballSpeed;
            }
            currentTurnCombo++;
            if (currentTurnCombo > maxCombo) {
              maxCombo = currentTurnCombo;
            }

            audio.playHit(combo: currentTurnCombo);

            // Spawn hit sparks only if particle count is low to keep 60-120 FPS
            if (particles.length < 36) {
              _addParticlesCapped(
                Particle.burst(
                  origin: ball.position,
                  color: selectedSkin.glowColor,
                  count: 2,
                  speed: 240.0,
                ),
              );
            }

            // 1 ball strictly deals 1 HP damage
            if (_damageBrick(entity, 1)) {
              hudChanged = true;
            }

            if (entity.hp > 0 &&
                entity.modifier == BrickModifier.electric &&
                _rng.nextDouble() < 0.45) {
              _triggerElectricChain(entity);
            }
            return hudChanged;
          }
        } else if (entity.isItem) {
          final rect = BounceStrikePhysics.cellRect(
            entity.col,
            entity.visualRow,
            cellSize,
          );
          final center = rect.center;
          final pickupRadius = cellSize * 0.30 + ball.radius;
          final distSq = (ball.position - center).distanceSquared;

          if (distSq <= pickupRadius * pickupRadius) {
            if (!entity.overlappingBallIds.contains(ball.id)) {
              entity.overlappingBallIds.add(ball.id);
              if (_triggerItem(entity, ball, center)) {
                hudChanged = true;
              }
            }
          } else {
            entity.overlappingBallIds.remove(ball.id);
          }
        }
      }
    }
    return hudChanged;
  }

  bool _damageBrick(GridEntity brick, int amount) {
    if (!entities.contains(brick)) return false;
    brick.hp -= amount;
    brick.hitFlash = 1.0;
    brick.scale = 1.14;

    final rect =
        BounceStrikePhysics.cellRect(brick.col, brick.visualRow, cellSize);

    if (brick.hp <= 0) {
      entities.remove(brick);
      if (brick.col >= 0 &&
          brick.col < cols &&
          brick.row >= 0 &&
          brick.row < rows + 2) {
        _spatialGrid[brick.row * cols + brick.col] = null;
      }
      final baseColor = colorForHp(brick.maxHp);

      _addParticlesCapped(
        Particle.burst(
          origin: rect.center,
          color: baseColor,
          count: 14,
          speed: 520.0,
        ),
      );
      shockwaves.add(
        ShockwaveEffect(
          origin: rect.center,
          color: baseColor,
          maxRadius: cellSize * 1.15,
          speed: 3.6,
        ),
      );

      if (brick.modifier == BrickModifier.bomb) {
        _triggerBombExplosion(brick.col, brick.row, rect.center);
        return true;
      } else if (brick.modifier == BrickModifier.goldCore) {
        coins += 7;
        audio.playPickup();
        floatingTexts.add(
          FloatingText(
            position: rect.center,
            text: '+7 ALTIN!',
            color: const Color(0xFFFFD740),
            fontSize: 36,
          ),
        );
        return true;
      } else if (brick.modifier == BrickModifier.boss) {
        coins += 14;
        screenShake = 7.0;
        audio.playExplosion();
        floatingTexts.add(
          FloatingText(
            position: rect.center,
            text: 'BOSS YIKILDI! +14\$',
            color: const Color(0xFFFFD740),
            fontSize: 38,
          ),
        );
        return true;
      } else {
        audio.playBrickBreak();
      }
    }
    return false;
  }

  void _triggerElectricChain(GridEntity sourceBrick) {
    final sourceCenter = BounceStrikePhysics.cellRect(
      sourceBrick.col,
      sourceBrick.visualRow,
      cellSize,
    ).center;
    final candidates = entities
        .where((e) =>
            e.isBrick &&
            e.id != sourceBrick.id &&
            (e.col - sourceBrick.col).abs() <= 2 &&
            (e.row - sourceBrick.row).abs() <= 2)
        .toList();
    if (candidates.isEmpty) return;

    final target = candidates[_rng.nextInt(candidates.length)];
    final targetCenter =
        BounceStrikePhysics.cellRect(target.col, target.visualRow, cellSize)
            .center;

    lightningArcs.add(
      LightningArcEffect(
        start: sourceCenter,
        end: targetCenter,
        color: selectedTheme.accentColor,
      ),
    );
    audio.playLaser();
    _damageBrick(target, 1);
  }

  void _triggerBombExplosion(int centerCol, int centerRow, Offset centerPos) {
    screenShake = 11.0;
    audio.playExplosion();
    HapticFeedback.heavyImpact();
    floatingTexts.add(
      FloatingText(
        position: centerPos,
        text: 'MEGA BOOM!',
        color: const Color(0xFFFF5252),
        fontSize: 40,
      ),
    );
    shockwaves.add(
      ShockwaveEffect(
        origin: centerPos,
        color: const Color(0xFFFF6E40),
        maxRadius: cellSize * 2.6,
        speed: 2.5,
        strokeWidth: 14.0,
      ),
    );
    _addParticlesCapped(
      Particle.burst(
        origin: centerPos,
        color: const Color(0xFFFF6E40),
        count: 24,
        speed: 620.0,
      ),
    );

    final neighbors = entities
        .where((e) =>
            e.isBrick &&
            (e.col - centerCol).abs() <= 1 &&
            (e.row - centerRow).abs() <= 1)
        .toList();

    final bombDamage = math.max(6, (level * 0.75).ceil());
    for (final n in neighbors) {
      _damageBrick(n, bombDamage);
    }
  }

  bool _triggerItem(GridEntity item, Ball ball, Offset itemCenter) {
    void clearGridSlot() {
      if (item.col >= 0 &&
          item.col < cols &&
          item.row >= 0 &&
          item.row < rows + 2) {
        _spatialGrid[item.row * cols + item.col] = null;
      }
    }

    switch (item.itemType!) {
      case ItemType.addBall:
        bonusBallsCollectedThisTurn += 1;
        entities.remove(item);
        clearGridSlot();
        audio.playPickup();
        shockwaves.add(
          ShockwaveEffect(
            origin: itemCenter,
            color: const Color(0xFF00E676),
            maxRadius: cellSize * 0.9,
          ),
        );
        _addParticlesCapped(
          Particle.burst(
            origin: itemCenter,
            color: const Color(0xFF00E676),
            count: 12,
            speed: 380.0,
          ),
        );
        floatingTexts.add(
          FloatingText(
            position: itemCenter,
            text: '+1 TOP',
            color: const Color(0xFF00E676),
            fontSize: 34,
          ),
        );
        return true;

      case ItemType.multiBall:
        bonusBallsCollectedThisTurn += 3;
        entities.remove(item);
        clearGridSlot();
        audio.playPickup();
        shockwaves.add(
          ShockwaveEffect(
            origin: itemCenter,
            color: selectedTheme.accentColor,
            maxRadius: cellSize * 1.3,
          ),
        );
        _addParticlesCapped(
          Particle.burst(
            origin: itemCenter,
            color: selectedTheme.accentColor,
            count: 16,
            speed: 420.0,
          ),
        );
        floatingTexts.add(
          FloatingText(
            position: itemCenter,
            text: '+3 SÜPER TOP!',
            color: selectedTheme.accentColor,
            fontSize: 36,
          ),
        );
        return true;

      case ItemType.coin:
        coins += 4;
        entities.remove(item);
        clearGridSlot();
        audio.playPickup();
        _addParticlesCapped(
          Particle.burst(
            origin: itemCenter,
            color: const Color(0xFFFFD740),
            count: 10,
            speed: 360.0,
          ),
        );
        floatingTexts.add(
          FloatingText(
            position: itemCenter,
            text: '+4 ALTIN',
            color: const Color(0xFFFFD740),
            fontSize: 34,
          ),
        );
        return true;

      case ItemType.laserHorizontal:
        item.activatedThisTurn = true;
        item.scale = 1.28;
        audio.playLaser();
        _fireLaserRow(item.row);
        return false;

      case ItemType.laserVertical:
        item.activatedThisTurn = true;
        item.scale = 1.28;
        audio.playLaser();
        _fireLaserCol(item.col);
        return false;

      case ItemType.laserCross:
        item.activatedThisTurn = true;
        item.scale = 1.28;
        audio.playLaser();
        _fireLaserRow(item.row);
        _fireLaserCol(item.col);
        return false;

      case ItemType.deflector:
        item.activatedThisTurn = true;
        item.scale = 1.32;
        audio.playHit(combo: 3);
        final randomAngle =
            (-155.0 + _rng.nextDouble() * 130.0) * (math.pi / 180.0);
        ball.velocity =
            Offset(math.cos(randomAngle), math.sin(randomAngle)) * ballSpeed;
        shockwaves.add(
          ShockwaveEffect(
            origin: itemCenter,
            color: const Color(0xFFFF9100),
            maxRadius: cellSize * 0.85,
          ),
        );
        return false;
    }
  }

  void _fireLaserRow(int row) {
    laserBeams.add(
      LaserBeamEffect(
        isHorizontal: true,
        index: row,
        color: selectedTheme.horizontalLaserColor,
      ),
    );
    final targets = entities.where((e) => e.isBrick && e.row == row).toList();
    for (final brick in targets) {
      _damageBrick(brick, 1);
    }
  }

  void _fireLaserCol(int col) {
    laserBeams.add(
      LaserBeamEffect(
        isHorizontal: false,
        index: col,
        color: selectedTheme.verticalLaserColor,
      ),
    );
    final targets = entities.where((e) => e.isBrick && e.col == col).toList();
    for (final brick in targets) {
      _damageBrick(brick, 1);
    }
  }

  void _finishShootingPhase() {
    launchX = (nextLaunchX ?? launchX)
        .clamp(cellSize * 0.45, boardWidth - cellSize * 0.45);
    totalBalls += bonusBallsCollectedThisTurn;
    bonusBallsCollectedThisTurn = 0;
    speedMultiplier = 1;
    activeBalls.clear();

    if (currentTurnCombo >= 25) {
      final comboGold = currentTurnCombo >= 80
          ? 10
          : (currentTurnCombo >= 50 ? 6 : 3);
      coins += comboGold;
      floatingTexts.add(
        FloatingText(
          position: Offset(boardWidth / 2, boardHeight * 0.45),
          text: 'KOMBO ÖDÜLÜ +$comboGold\$!',
          color: const Color(0xFFFFD740),
          fontSize: 40,
        ),
      );
    }

    final remainingBricks = entities.where((e) => e.isBrick).isEmpty;
    if (remainingBricks && level >= 2) {
      coins += 12;
      shockwaves.add(
        ShockwaveEffect(
          origin: Offset(boardWidth / 2, boardHeight * 0.35),
          color: const Color(0xFFFFD740),
          maxRadius: boardWidth * 0.65,
          speed: 2.2,
          strokeWidth: 14.0,
        ),
      );
      floatingTexts.add(
        FloatingText(
          position: Offset(boardWidth / 2, boardHeight * 0.35),
          text: 'TAM TEMİZLİK! +12\$',
          color: const Color(0xFF00E676),
          fontSize: 42,
        ),
      );
    }

    entities.removeWhere((e) => e.isItem && e.activatedThisTurn);

    level++;
    if (level > bestLevel) {
      bestLevel = level;
    }
    _savePersistentData();

    for (final e in entities) {
      e.row += 1;
    }

    _spawnRowForLevel(level, targetRow: 1, startVisualRow: 0.0);

    _slideProgress = 0.0;
    phase = TurnPhase.slidingDown;
    notifyListeners();
    _markCanvasDirty();
  }

  void _updateSlidingPhase(double dt) {
    _slideProgress = (_slideProgress + dt * 5.2).clamp(0.0, 1.0);
    final eased = Curves.easeOutCubic.transform(_slideProgress);

    for (final e in entities) {
      e.visualRow = (e.row - 1) + eased;
    }

    if (_slideProgress >= 1.0) {
      for (final e in entities) {
        e.visualRow = e.row.toDouble();
      }

      entities.removeWhere((e) => e.isItem && e.row >= dangerRow);

      final anyBrickInDanger =
          entities.any((e) => e.isBrick && e.row >= dangerRow);
      if (anyBrickInDanger) {
        phase = TurnPhase.gameOver;
        screenShake = 12.0;
        audio.playExplosion();
        HapticFeedback.heavyImpact();
      } else {
        phase = TurnPhase.aiming;
      }
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // GRADUAL & ENGAGING MATRIX ROW SPAWNER (v1.0.0)
  // ---------------------------------------------------------------------------

  void _spawnRowForLevel(
    int currentLevel, {
    required int targetRow,
    double? startVisualRow,
  }) {
    final availableCols = List<int>.generate(cols, (i) => i)..shuffle(_rng);
    final vRow = startVisualRow ?? targetRow.toDouble();

    // 1. Strictly spawn 1 '+1 Ball' item per level progression
    final addBallCol = availableCols.removeLast();
    entities.add(
      GridEntity.item(
        id: _nextEntityId++,
        col: addBallCol,
        row: targetRow,
        type: ItemType.addBall,
      )..visualRow = vRow,
    );

    // 2. Smoothly scale matrix brick density by level phase
    int minBricks;
    int maxBricks;
    if (currentLevel <= 3) {
      minBricks = 3;
      maxBricks = 4;
    } else if (currentLevel <= 9) {
      minBricks = 4;
      maxBricks = 5;
    } else if (currentLevel <= 18) {
      minBricks = 5;
      maxBricks = 6;
    } else {
      minBricks = 6;
      maxBricks = 7;
    }

    final brickCount = minBricks + _rng.nextInt(maxBricks - minBricks + 1);
    final isBossWave = currentLevel % 5 == 0;

    final specialShapes = [
      BrickShape.triangleBL,
      BrickShape.triangleBR,
      BrickShape.triangleTL,
      BrickShape.triangleTR,
      BrickShape.diamond,
      BrickShape.hexagon,
    ];

    final polygonChance = currentLevel <= 3 ? 0.25 : 0.46;

    for (int i = 0; i < brickCount && availableCols.isNotEmpty; i++) {
      final col = availableCols.removeLast();

      BrickShape shape = BrickShape.square;
      if (_rng.nextDouble() < polygonChance) {
        shape = specialShapes[_rng.nextInt(specialShapes.length)];
      }

      BrickModifier modifier = BrickModifier.none;
      // Base HP increases strictly 1 by 1 with level (Level 1 -> 1, Level 90 -> 90)
      int hp = currentLevel;

      if (isBossWave && i == 0) {
        modifier = BrickModifier.boss;
        // Maximum 2x of current level (e.g., Level 90 -> max 180)
        hp = currentLevel * 2;
      } else if (currentLevel >= 3) {
        final roll = _rng.nextDouble();
        if (roll < 0.11) {
          modifier = BrickModifier.bomb;
        } else if (roll < 0.21 && currentLevel >= 5) {
          modifier = BrickModifier.electric;
        } else if (roll < 0.30) {
          modifier = BrickModifier.goldCore;
          hp = math.min(currentLevel * 2, (currentLevel * 1.4).ceil());
        }
      }

      entities.add(
        GridEntity.brick(
          id: _nextEntityId++,
          col: col,
          row: targetRow,
          shape: shape,
          hp: hp,
          modifier: modifier,
        )..visualRow = vRow,
      );
    }

    // 3. Spawn Laser / Deflector / MultiBall / Coin in remaining matrix slot
    if (availableCols.isNotEmpty && _rng.nextDouble() < 0.78) {
      final specialCol = availableCols.removeLast();
      final roll = _rng.nextDouble();
      ItemType specialType;
      if (roll < 0.22) {
        specialType = ItemType.laserHorizontal;
      } else if (roll < 0.44) {
        specialType = ItemType.laserVertical;
      } else if (roll < 0.60 && currentLevel >= 4) {
        specialType = ItemType.laserCross;
      } else if (roll < 0.74) {
        specialType = ItemType.deflector;
      } else if (roll < 0.84 && currentLevel >= 6) {
        specialType = ItemType.multiBall;
      } else {
        specialType = ItemType.coin;
      }

      entities.add(
        GridEntity.item(
          id: _nextEntityId++,
          col: specialCol,
          row: targetRow,
          type: specialType,
        )..visualRow = vRow,
      );
    }
  }

  Color colorForHp(int hp) {
    final hue = (selectedTheme.baseBrickHue + hp * 18.0) % 360.0;
    return HSLColor.fromAHSL(1.0, hue, 0.88, 0.54).toColor();
  }

  @override
  void dispose() {
    repaintNotifier.dispose();
    audio.dispose();
    super.dispose();
  }
}

typedef GameController = BounceStrikeController;
