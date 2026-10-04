import 'package:flutter/material.dart';
import '../engine/bouncestrike_controller.dart';
import '../models/bouncestrike_models.dart';

class BounceStrikeShopSheet extends StatefulWidget {
  final BounceStrikeController controller;
  final int initialTab;

  const BounceStrikeShopSheet({
    super.key,
    required this.controller,
    this.initialTab = 0,
  });

  @override
  State<BounceStrikeShopSheet> createState() => _BounceStrikeShopSheetState();
}

class _BounceStrikeShopSheetState extends State<BounceStrikeShopSheet> {
  late int _selectedTab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final theme = controller.selectedTheme;
        return SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.82,
            ),
            decoration: BoxDecoration(
              color: theme.bgTop,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(26)),
              border: Border(
                top: BorderSide(color: theme.accentColor, width: 1.8),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'BOUNCESTRIKE $kGameVersion • MAĞAZA & TEMALAR',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Aktif Tema: ${theme.badge} ${theme.name}',
                            style: TextStyle(
                              color: theme.accentColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD740).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFFD740)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.monetization_on,
                            color: Color(0xFFFFD740),
                            size: 17,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${controller.coins} \$',
                            style: const TextStyle(
                              color: Color(0xFFFFD740),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _TabPill(
                        title: '⚾ Toplar & İncelik (6)',
                        isActive: _selectedTab == 0,
                        accentColor: theme.accentColor,
                        onTap: () => setState(() => _selectedTab = 0),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TabPill(
                        title: '🌍 Dünya Temaları (5)',
                        isActive: _selectedTab == 1,
                        accentColor: theme.accentColor,
                        onTap: () => setState(() => _selectedTab = 1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: _selectedTab == 0
                      ? _buildBallsGrid(context, controller, theme)
                      : _buildThemesList(context, controller),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBallsGrid(
    BuildContext context,
    BounceStrikeController controller,
    GameTheme theme,
  ) {
    final balls = controller.currentThemeBalls;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${theme.badge} ${theme.name} Temasının Küçülen Objeleri (%100 -> %34 Çap):',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Flexible(
          child: GridView.builder(
            shrinkWrap: true,
            itemCount: balls.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.72,
            ),
            itemBuilder: (context, index) {
              final skin = balls[index];
              final isUnlocked = controller.unlockedSkinIds.contains(skin.id);
              final isSelected = controller.selectedSkin.id == skin.id;

              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  final ok = controller.selectOrUnlockSkin(skin);
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${skin.name} için ${skin.cost}\$ gerekli! (Mevcut: ${controller.coins}\$)',
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? skin.glowColor.withValues(alpha: 0.20)
                        : theme.bgBottom.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? skin.glowColor
                          : (isUnlocked ? Colors.white24 : Colors.white12),
                      width: isSelected ? 2.0 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      _SkinIconBadge(skin: skin),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              skin.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Çap: %${skin.sizePercent}',
                              style: TextStyle(
                                color: skin.glowColor,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Geçiş Şansı: %${skin.gapPassChancePercent}',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              isSelected
                                  ? '✓ SEÇİLİ'
                                  : (isUnlocked
                                      ? 'KULLAN'
                                      : 'AÇ: ${skin.cost} \$'),
                              style: TextStyle(
                                color: isSelected
                                    ? const Color(0xFF00E676)
                                    : (isUnlocked
                                        ? Colors.white70
                                        : const Color(0xFFFFD740)),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildThemesList(
    BuildContext context,
    BounceStrikeController controller,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      itemCount: GameTheme.allThemes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final theme = GameTheme.allThemes[index];
        final isUnlocked = controller.unlockedThemeIds.contains(theme.id);
        final isSelected = controller.selectedTheme.id == theme.id;

        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            final ok = controller.selectOrUnlockTheme(theme);
            if (!ok && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${theme.name} teması için ${theme.cost}\$ gerekli! (Mevcut: ${controller.coins}\$)',
                  ),
                  duration: const Duration(seconds: 1),
                ),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.bgTop, theme.bgBottom],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? theme.accentColor
                    : (isUnlocked ? Colors.white24 : Colors.white12),
                width: isSelected ? 2.2 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.accentColor.withValues(alpha: 0.16),
                    border: Border.all(color: theme.accentColor),
                  ),
                  child: Text(
                    theme.badge,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            theme.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '• ${theme.laserName}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.accentColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        theme.description,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF00E676).withValues(alpha: 0.2)
                        : Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF00E676)
                          : (isUnlocked
                              ? Colors.white24
                              : const Color(0xFFFFD740)),
                    ),
                  ),
                  child: Text(
                    isSelected
                        ? 'AKTİF'
                        : (isUnlocked ? 'SEÇ' : '${theme.cost} \$'),
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFF00E676)
                          : (isUnlocked
                              ? Colors.white
                              : const Color(0xFFFFD740)),
                      fontWeight: FontWeight.w900,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TabPill extends StatelessWidget {
  final String title;
  final bool isActive;
  final Color accentColor;
  final VoidCallback onTap;

  const _TabPill({
    required this.title,
    required this.isActive,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive
              ? accentColor.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? accentColor : Colors.white12,
            width: isActive ? 1.6 : 1.0,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white60,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _SkinIconBadge extends StatelessWidget {
  final BallSkin skin;

  const _SkinIconBadge({required this.skin});

  IconData _iconForShape(ProjectileShape shape) {
    switch (shape) {
      case ProjectileShape.circle:
        return Icons.circle;
      case ProjectileShape.square:
        return Icons.crop_square_rounded;
      case ProjectileShape.triangle:
        return Icons.change_history_rounded;
      case ProjectileShape.star:
        return Icons.star_rounded;
      case ProjectileShape.shuriken:
        return Icons.flare_rounded;
      case ProjectileShape.microNeedle:
        return Icons.auto_awesome;
    }
  }

  @override
  Widget build(BuildContext context) {
    final visualIconSize = (26.0 * skin.radiusMultiplier).clamp(11.0, 26.0);
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: skin.glowColor.withValues(alpha: 0.14),
        border: Border.all(
          color: skin.glowColor.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        _iconForShape(skin.shape),
        color: skin.color,
        size: visualIconSize,
      ),
    );
  }
}

typedef BallShopSheet = BounceStrikeShopSheet;
