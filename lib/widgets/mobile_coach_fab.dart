// lib/widgets/mobile_coach_fab.dart
import 'package:flutter/material.dart';

class MobileCoachFab extends StatefulWidget {
  final void Function(String? initialQuestion) onOpenCoach;

  const MobileCoachFab({
    super.key,
    required this.onOpenCoach,
  });

  @override
  State<MobileCoachFab> createState() => _MobileCoachFabState();
}

class _MobileCoachFabState extends State<MobileCoachFab>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;

  late final AnimationController _floatController;
  late final Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();

    // Stronger up–down float animation (bigger jump, a bit faster)
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _floatAnimation =
        Tween<double>(begin: 0, end: -12).animate(CurvedAnimation(
      parent: _floatController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
    });
  }

  void _handleTodayInfo() {
    widget.onOpenCoach(
      'Give me a short health and activity summary for today and what I should focus on next.',
    );
  }

  void _handleHistory() {
    widget.onOpenCoach(
      'Review my recent activity and heart rate history and give me 2–3 key insights.',
    );
  }

  void _handleFullSession() {
    widget.onOpenCoach(null);
  }

  @override
  Widget build(BuildContext context) {
    const brandBorder = Color(0xFFD8E9E6);
    const brandMuted = Color(0xFF5D7B79);

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        // Animated popup menu
        Positioned(
          right: 16,
          bottom: 100,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              final offsetAnimation = Tween<Offset>(
                begin: const Offset(0.1, 0.2),
                end: Offset.zero,
              ).animate(animation);
              final scaleAnimation =
                  Tween<double>(begin: 0.9, end: 1).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: offsetAnimation,
                  child: ScaleTransition(
                    scale: scaleAnimation,
                    child: child,
                  ),
                ),
              );
            },
            child: !_isOpen
                ? const SizedBox.shrink()
                : Material(
                    key: const ValueKey('coach-menu'),
                    elevation: 10,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 240,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: brandBorder),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFE4F3F0),
                                  border: Border.all(
                                    color: brandBorder,
                                  ),
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/images/wellsync_coach.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'WellSync Coach',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1F3B3A),
                                  ),
                                ),
                              ),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF34D399),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap a shortcut for quick, health‑focused guidance.',
                            style: TextStyle(
                              fontSize: 11,
                              color: brandMuted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _MenuItem(
                            icon: Icons.today_outlined,
                            label: 'Today overview',
                            subtitle:
                                'See where you stand right now.',
                            onTap: _handleTodayInfo,
                          ),
                          _MenuItem(
                            icon: Icons.query_stats_outlined,
                            label: 'Recent trends',
                            subtitle:
                                'Spot patterns in your activity.',
                            onTap: _handleHistory,
                          ),
                          const Divider(height: 10),
                          _MenuItem(
                            icon: Icons.smart_toy_outlined,
                            label: 'Start full session',
                            subtitle:
                                'Chat freely with your coach.',
                            onTap: _handleFullSession,
                            emphasize: true,
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
        // Floating coach circle with stronger float & a tiny tilt
        Positioned(
          right: 16,
          bottom: 24,
          child: AnimatedBuilder(
            animation: _floatAnimation,
            builder: (context, child) {
              // Small rotation depending on float position
              final tilt = (_floatAnimation.value / -12) * 0.04; // ~2.3°
              return Transform.translate(
                offset: Offset(0, _isOpen ? 0 : _floatAnimation.value),
                child: Transform.rotate(
                  angle: _isOpen ? 0 : tilt,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 160),
                    scale: _isOpen ? 1.07 : 1.0,
                    curve: Curves.easeOut,
                    child: GestureDetector(
                      onTap: _toggle,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFE3F5F1),
                              Color(0xFFC5E7E0),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withValues(alpha: 0.25),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                          border: Border.all(
                            color: brandBorder,
                            width: 1,
                          ),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/wellsync_coach.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool emphasize;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
        emphasize ? const Color(0xFF1F5F63) : const Color(0xFF1F3B3A);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 18,
              color: emphasize
                  ? const Color(0xFF1F5F63)
                  : const Color(0xFF5D7B79),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          emphasize ? FontWeight.w600 : FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF5D7B79),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}