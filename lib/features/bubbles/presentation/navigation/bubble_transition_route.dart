import 'dart:ui';
import 'package:flutter/material.dart';

class BubbleTransitionRoute extends PageRouteBuilder {
  final Widget page;

  BubbleTransitionRoute({required this.page})
      : super(
          transitionDuration: const Duration(milliseconds: 520),
          reverseTransitionDuration: const Duration(milliseconds: 380),
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOutCubic,
            );

            // Escala mais forte (sensação de fechamento)
            final scaleAnimation = Tween<double>(
              begin: 0.92,
              end: 1.0,
            ).animate(curved);

            // Fade mais suave
            final fadeAnimation = Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: const Interval(0.15, 1.0),
              ),
            );

            // Blur progressivo (efeito lente)
            final blurAnimation = Tween<double>(
              begin: 8.0,
              end: 0.0,
            ).animate(curved);

            return AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                return BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: blurAnimation.value,
                    sigmaY: blurAnimation.value,
                  ),
                  child: FadeTransition(
                    opacity: fadeAnimation,
                    child: ScaleTransition(
                      scale: scaleAnimation,
                      child: child,
                    ),
                  ),
                );
              },
            );
          },
        );
}
