import 'package:flutter/material.dart';

class BubbleSkeleton extends StatelessWidget {
  const BubbleSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(14, (i) {
        final size = (i % 3 == 0) ? 140.0 : (i % 3 == 1) ? 110.0 : 80.0;
        final left = (i * 37) % 280;
        final top = (i * 71) % 520;
        return Positioned(
          left: left.toDouble(),
          top: top.toDouble(),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
          ),
        );
      }),
    );
  }
}
