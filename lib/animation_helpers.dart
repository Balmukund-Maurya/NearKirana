import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

// ============================================================
// ANIMATION HELPERS — Reusable animated widgets
// ============================================================

/// Staggered fade + slide-up for list children
class StaggeredList extends StatelessWidget {
  final List<Widget> children;
  final int delayMs;

  const StaggeredList({super.key, required this.children, this.delayMs = 80});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: children
          .asMap()
          .entries
          .map(
            (e) => e.value
                .animate(delay: Duration(milliseconds: e.key * delayMs))
                .fadeIn(duration: 300.ms, curve: Curves.easeOut)
                .slideY(
                  begin: 0.15,
                  end: 0,
                  duration: 300.ms,
                  curve: Curves.easeOut,
                ),
          )
          .toList(),
    );
  }
}

/// Fade + slide up widget (single)
extension AnimateHelpers on Widget {
  Widget fadeSlideUp({int delay = 0, int duration = 300}) {
    return animate(delay: Duration(milliseconds: delay))
        .fadeIn(
          duration: Duration(milliseconds: duration),
          curve: Curves.easeOut,
        )
        .slideY(
          begin: 0.15,
          end: 0,
          duration: Duration(milliseconds: duration),
          curve: Curves.easeOut,
        );
  }

  Widget fadeIn({int delay = 0, int duration = 350}) {
    return animate(delay: Duration(milliseconds: delay)).fadeIn(
      duration: Duration(milliseconds: duration),
      curve: Curves.easeOut,
    );
  }

  Widget popIn({int delay = 0}) {
    return animate(delay: Duration(milliseconds: delay))
        .scale(
          begin: const Offset(0.7, 0.7),
          end: const Offset(1, 1),
          duration: 300.ms,
          curve: Curves.elasticOut,
        )
        .fadeIn(duration: 200.ms);
  }

  Widget bounceIn({int delay = 0}) {
    return animate(delay: Duration(milliseconds: delay))
        .scale(
          begin: const Offset(0, 0),
          end: const Offset(1, 1),
          duration: 500.ms,
          curve: Curves.elasticOut,
        )
        .fadeIn(duration: 300.ms);
  }

  Widget slideFromRight({int delay = 0}) {
    return animate(delay: Duration(milliseconds: delay))
        .fadeIn(duration: 300.ms)
        .slideX(begin: 0.3, end: 0, duration: 300.ms, curve: Curves.easeOut);
  }
}

/// Pulsing animation (for badges, alerts)
class PulseWidget extends StatelessWidget {
  final Widget child;
  final Color color;

  const PulseWidget({super.key, required this.child, required this.color});

  @override
  Widget build(BuildContext context) {
    return child
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(
          begin: 1.0,
          end: 1.08,
          duration: 800.ms,
          curve: Curves.easeInOut,
        );
  }
}

/// Shimmer loading placeholder for cards
class ShimmerPlaceholder extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const ShimmerPlaceholder({
    super.key,
    this.width = double.infinity,
    this.height = 100,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(radius),
          ),
        )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1200.ms, color: Colors.grey.shade100);
  }
}

/// Cart badge pop animation
class AnimatedBadge extends StatelessWidget {
  final int count;

  const AnimatedBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            color: Color(0xFFD32F2F),
            shape: BoxShape.circle,
          ),
          constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
          child: Text(
            count > 99 ? '99+' : '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        )
        .animate(key: ValueKey(count))
        .scale(
          begin: const Offset(0.5, 0.5),
          end: const Offset(1, 1),
          duration: 300.ms,
          curve: Curves.elasticOut,
        );
  }
}

/// Animated count-up number (for admin earnings, etc.)
class AnimatedCounter extends StatelessWidget {
  final double value;
  final String prefix;
  final String suffix;
  final TextStyle? style;
  final int decimals;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.style,
    this.decimals = 0,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOut,
      builder: (context, val, child) {
        return Text(
          '$prefix${val.toStringAsFixed(decimals)}$suffix',
          style:
              style ??
              Theme.of(
                context,
              ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
        );
      },
    );
  }
}

/// Success overlay widget (after order placed)
class SuccessOverlay extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onDone;

  const SuccessOverlay({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF306D29).withValues(alpha: 0.96),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
                  Icons.check_circle_rounded,
                  size: 100,
                  color: const Color(0xFFA8DF8E),
                )
                .animate()
                .scale(
                  begin: const Offset(0, 0),
                  end: const Offset(1, 1),
                  duration: 600.ms,
                  curve: Curves.elasticOut,
                )
                .fadeIn(duration: 400.ms),
            const SizedBox(height: 24),
            Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                )
                .animate(delay: 400.ms)
                .fadeIn(duration: 300.ms)
                .slideY(begin: 0.2, end: 0),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ).animate(delay: 600.ms).fadeIn(duration: 300.ms),
            const SizedBox(height: 48),
            ElevatedButton(
                  onPressed: onDone,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA8DF8E),
                    foregroundColor: const Color(0xFF306D29),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  child: const Text(
                    'Theek Hai!',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                )
                .animate(delay: 800.ms)
                .fadeIn(duration: 300.ms)
                .slideY(begin: 0.3, end: 0),
          ],
        ),
      ),
    );
  }
}
