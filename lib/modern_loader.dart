import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'app_theme.dart';

class ModernLoader extends StatelessWidget {
  final double size;
  final Color? color;

  const ModernLoader({
    super.key,
    this.size = 40.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.primaryDark;

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          return Container(
            width: size * 0.25,
            height: size * 0.25,
            margin: EdgeInsets.symmetric(horizontal: size * 0.05),
            decoration: BoxDecoration(
              color: effectiveColor,
              shape: BoxShape.circle,
            ),
          )
              .animate(
                onPlay: (controller) => controller.repeat(),
                delay: (index * 200).ms, // Staggered delay for the wave
              )
              .scaleXY(
                begin: 0.5,
                end: 1.2,
                curve: Curves.easeInOutSine,
                duration: 600.ms,
              )
              .then()
              .scaleXY(
                begin: 1.2,
                end: 0.5,
                curve: Curves.easeInOutSine,
                duration: 600.ms,
              )
              .animate(
                onPlay: (controller) => controller.repeat(),
                delay: (index * 200).ms,
              )
              .slideY(
                begin: 0,
                end: -0.5,
                curve: Curves.easeInOutSine,
                duration: 600.ms,
              )
              .then()
              .slideY(
                begin: -0.5,
                end: 0,
                curve: Curves.easeInOutSine,
                duration: 600.ms,
              );
        }),
      ),
    );
  }
}
