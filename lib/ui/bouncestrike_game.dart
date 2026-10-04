import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../constants/bouncestrike_constants.dart';
import '../engine/bouncestrike_controller.dart';
import '../models/bouncestrike_models.dart';
import 'bouncestrike_painter.dart';
import 'bouncestrike_shop_sheet.dart';

class BounceStrikeGame extends StatefulWidget {
  const BounceStrikeGame({super.key});

  @override
  State<BounceStrikeGame> createState() => _BounceStrikeGameState();
}

class _BounceStrikeGameState extends State<BounceStrikeGame>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final BounceStrikeController _controller;
  late final Ticker _ticker;
  late final AnimationController _pulseController;
  late final BounceStrikePainter _gamePainter;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller = BounceStrikeController();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);

    // Single reusable BounceStrikePainter instance driven by Listenable.merge
    _gamePainter = BounceStrikePainter(
      controller: _controller,
      pulseAnimation: _pulseController,
    );

    _ticker = createTicker((elapsed) {
      final dt = _lastElapsed == Duration.zero
          ? 0.016
          : (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
      _lastElapsed = elapsed;
      _controller.update(dt);
    });
    _ticker.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        if (_ticker.isActive) {
          _ticker.stop();
        }
        _pulseController.stop();
        _controller.audio.pause();
        _lastElapsed = Duration.zero;
        break;
      case AppLifecycleState.resumed:
        _lastElapsed = Duration.zero;
        if (!_ticker.isActive) {
          _ticker.start();
        }
        if (!_pulseController.isAnimating) {
          _pulseController.repeat(reverse: true);
        }
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _pulseController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _openShop({int initialTab = 0}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BounceStrikeShopSheet(
        controller: _controller,
        initialTab: initialTab,
      ),
    );
  }

  void _showRulesDialog() {
    final theme = _controller.selectedTheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.bgTop,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: theme.accentColor, width: 1.4),
        ),
        title: const Text(
          'BOUNCESTRIKE $kGameVersion : REHBER',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16.5,
          ),
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RuleRow(
                badge: '🌍 5 Tema',
                title: '5 Farklı Dünya & Özel Toplar',
                desc:
                    'Uzay, Futbol Sahası, 1. Dünya Savaşı, Samuray ve Magma temalarını altınla aç! Her temanın kendine özel 6 topu, lazeri ve sahası vardır.',
              ),
              SizedBox(height: 10),
              _RuleRow(
                badge: '🔍 %34',
                title: 'Küçülen Çap & Aradan Geçiş',
                desc:
                    'Toplar %100 çaptan %34 çapa kadar incelir. İnce toplar (%98 geçiş şansı) en dar blok aralıklarından bile sızıp üstten vurur!',
              ),
              SizedBox(height: 10),
              _RuleRow(
                badge: '📈 5 Evre',
                title: 'Kademeli Zorluk & Boss Dalgası',
                desc:
                    'Her 1 top 1 can götürür, seviyeler ilerledikçe blok canları 1\'er 1\'er artar ve özel Boss blokları maksimum 2x güçte gelir.',
              ),
              SizedBox(height: 10),
              _RuleRow(
                badge: '⚡ 💣 💎',
                title: 'Özel Matris Blokları',
                desc:
                    '⚡ Elektrik komşuları çarpar, 💣 Bomba 3x3 patlatır, 💎 Kristal +7 Altın ve 👑 Boss +14 Altın kazandırır.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OYUNA DÖN',
              style: TextStyle(
                color: theme.accentColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final theme = _controller.selectedTheme;
        return Scaffold(
          backgroundColor: theme.bgTop,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, outerConstraints) {
                final isCompactWidth = outerConstraints.maxWidth < 360;
                return Column(
                  children: [
                    RepaintBoundary(
                      child: _buildTopHud(theme, isCompactWidth),
                    ),
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: BounceStrikeConstants.boardAspectRatio,
                          child: LayoutBuilder(
                            builder: (context, boardConstraints) {
                              final boardSize = Size(
                                boardConstraints.maxWidth,
                                boardConstraints.maxHeight,
                              );
                              return Stack(
                                fit: StackFit.expand,
                                children: [
                                  RepaintBoundary(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            theme.bgTop,
                                            theme.bgBottom,
                                          ],
                                        ),
                                        border: Border.symmetric(
                                          horizontal: BorderSide(
                                            color: theme.accentColor
                                                .withValues(alpha: 0.45),
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onPanDown: (d) =>
                                            _controller.onAimStart(
                                          _controller.toLogicalOffset(
                                            d.localPosition,
                                            boardSize,
                                          ),
                                        ),
                                        onPanUpdate: (d) =>
                                            _controller.onAimUpdate(
                                          _controller.toLogicalOffset(
                                            d.localPosition,
                                            boardSize,
                                          ),
                                        ),
                                        onPanCancel: _controller.onAimCancel,
                                        onPanEnd: (_) => _controller.onAimEnd(),
                                        child: CustomPaint(
                                          painter: _gamePainter,
                                          isComplex: true,
                                          willChange: true,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 6,
                                    left: 8,
                                    child: IgnorePointer(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black45,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: Colors.white12,
                                          ),
                                        ),
                                        child: Text(
                                          '${theme.badge} ${_controller.difficultyStageName}',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_controller.currentTurnCombo >= 5)
                                    Positioned(
                                      top: 6,
                                      right: 8,
                                      child: IgnorePointer(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xCC1A1032),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: Border.all(
                                              color: const Color(0xFFFFD740),
                                            ),
                                          ),
                                          child: Text(
                                            _controller.currentTurnCombo >= 40
                                                ? '⚡ SÜPER KOMBO x${_controller.currentTurnCombo}'
                                                : '🔥 KOMBO x${_controller.currentTurnCombo}',
                                            style: const TextStyle(
                                              color: Color(0xFFFFD740),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (_controller.phase == TurnPhase.shooting)
                                    Positioned(
                                      right: 10,
                                      bottom: 10,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _ActionChipButton(
                                            icon: Icons
                                                .keyboard_double_arrow_down,
                                            label: 'İndir',
                                            color: const Color(0xFFFF5252),
                                            onTap: _controller.recallAllBalls,
                                          ),
                                          const SizedBox(width: 8),
                                          _ActionChipButton(
                                            icon: Icons.fast_forward_rounded,
                                            label:
                                                '${_controller.speedMultiplier}x Hız',
                                            color: theme.accentColor,
                                            onTap:
                                                _controller.toggleFastForward,
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (_controller.phase == TurnPhase.gameOver)
                                    _buildGameOverOverlay(theme),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    RepaintBoundary(
                      child: _buildBottomControlPanel(theme),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopHud(GameTheme theme, bool isCompact) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 12,
        vertical: 6,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  _HudPill(
                    label: 'REKOR',
                    value: '${_controller.bestLevel}',
                    color: theme.accentColor,
                  ),
                  const SizedBox(width: 8),
                  _HudPill(
                    label: 'ALTIN',
                    value: '\$${_controller.coins}',
                    color: const Color(0xFFFFD740),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              children: [
                const Text(
                  'SEVİYE ($kGameVersion)',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  '${_controller.level}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: _controller.isMuted ? 'Sesi Aç' : 'Sesi Kapat',
                onPressed: _controller.toggleMute,
                icon: Icon(
                  _controller.isMuted
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  color: _controller.isMuted
                      ? Colors.white38
                      : theme.accentColor,
                  size: 21,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Oyun Rehberi',
                onPressed: _showRulesDialog,
                icon: const Icon(
                  Icons.help_outline_rounded,
                  color: Colors.white70,
                  size: 21,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Yeniden Başlat',
                onPressed: _controller.startNewGame,
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white70,
                  size: 21,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControlPanel(GameTheme theme) {
    final bonus = _controller.bonusBallsCollectedThisTurn;
    final balls = _controller.currentThemeBalls;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      decoration: BoxDecoration(
        color: theme.bgTop,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: theme.bgBottom,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.blur_circular_rounded,
                          color: _controller.selectedSkin.glowColor,
                          size: 15,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Obje: x${_controller.totalBalls}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                        if (bonus > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            '(+$bonus)',
                            style: const TextStyle(
                              color: Color(0xFF00E676),
                              fontWeight: FontWeight.w900,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _controller.selectedSkin.glowColor
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Çap: %${_controller.selectedSkin.sizePercent} • Geçiş: %${_controller.selectedSkin.gapPassChancePercent}',
                            style: TextStyle(
                              color: _controller.selectedSkin.glowColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(11),
                    onTap: () => _openShop(initialTab: 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: theme.bgBottom,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: theme.accentColor.withValues(alpha: 0.65),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            theme.badge,
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Temalar',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    borderRadius: BorderRadius.circular(11),
                    onTap: () => _openShop(initialTab: 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: theme.bgBottom,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color:
                              const Color(0xFFFFD740).withValues(alpha: 0.65),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.shopping_bag_outlined,
                            size: 14,
                            color: Color(0xFFFFD740),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Toplar',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: balls.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final skin = balls[index];
                final isSelected = _controller.selectedSkin.id == skin.id;
                final isUnlocked =
                    _controller.unlockedSkinIds.contains(skin.id);

                return GestureDetector(
                  onTap: () {
                    final ok = _controller.selectOrUnlockSkin(skin);
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${skin.name} için ${skin.cost}\$ gerekli! (Mevcut: ${_controller.coins}\$)',
                          ),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? skin.glowColor.withValues(alpha: 0.24)
                          : theme.bgBottom,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? skin.glowColor
                            : (isUnlocked ? Colors.white24 : Colors.white10),
                        width: isSelected ? 1.8 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isUnlocked ? Icons.lens_blur : Icons.lock_outline,
                          size: (16 * skin.radiusMultiplier).clamp(10.0, 16.0),
                          color: isUnlocked ? skin.color : Colors.white38,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isUnlocked
                              ? '${skin.name} (%${skin.sizePercent})'
                              : '${skin.name} (${skin.cost}\$)',
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : (isUnlocked
                                    ? Colors.white70
                                    : const Color(0xFFFFD740)),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameOverOverlay(GameTheme theme) {
    return Container(
      color: const Color(0xD9080B14),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.bgBottom,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFFF1744), width: 1.8),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF1744).withValues(alpha: 0.25),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'MATRİS DOLDU!',
                  style: TextStyle(
                    color: Color(0xFFFF5252),
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ulaşılan Seviye: ${_controller.level}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Obje Ordusu: x${_controller.totalBalls} • En Yüksek Kombo: x${_controller.maxCombo}',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 22),
                if (!_controller.reviveUsed) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _controller.reviveClearBottomRows,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.bolt_rounded),
                      label: const Text(
                        'ALT 3 SATIRI PATLAT & DEVAM ET',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _controller.startNewGame,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.accentColor,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text(
                      'YENİ OYUN BAŞLAT',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HudPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HudPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionChipButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xCC151C33),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.8)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  final String badge;
  final String title;
  final String desc;

  const _RuleRow({
    required this.badge,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF151C35),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          alignment: Alignment.center,
          child: Text(
            badge,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF00E5FF),
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

typedef GameScreen = BounceStrikeGame;
