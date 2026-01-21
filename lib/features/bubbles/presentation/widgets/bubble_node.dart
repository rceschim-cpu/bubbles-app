import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/widgets/glass_chip.dart';
import '../../domain/bubble.dart';

class BubbleNode extends StatefulWidget {
  final Bubble bubble;
  final double diameter;
  final VoidCallback onTap;

  const BubbleNode({
    super.key,
    required this.bubble,
    required this.diameter,
    required this.onTap,
  });

  @override
  State<BubbleNode> createState() => _BubbleNodeState();
}

class _BubbleNodeState extends State<BubbleNode> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.diameter;
    final glow = widget.bubble.trend == BubbleTrend.rising;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 1.06 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          width: d,
          height: d,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: glow
                ? [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.20),
                      blurRadius: 26,
                      spreadRadius: 2,
                    )
                  ]
                : null,
          ),
          child: ClipOval(
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: widget.bubble.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const DecoratedBox(
                    decoration: BoxDecoration(color: Color(0xFF121A24)),
                  ),
                  errorWidget: (_, __, ___) => const DecoratedBox(
                    decoration: BoxDecoration(color: Color(0xFF121A24)),
                  ),
                ),

                // contrast overlay for text
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.05),
                        Colors.black.withOpacity(0.20),
                        Colors.black.withOpacity(0.55),
                      ],
                    ),
                  ),
                ),

                // border
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.10)),
                  ),
                ),

                // title
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: _BubbleTitle(text: widget.bubble.title),
                  ),
                ),

                // tiny badge
                Positioned(
                  left: 10,
                  top: 10,
                  child: GlassChip(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    child: Text(
                      widget.bubble.trend == BubbleTrend.rising
                          ? 'RISING'
                          : widget.bubble.trend == BubbleTrend.cooling
                              ? 'COOLING'
                              : 'STABLE',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
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

class _BubbleTitle extends StatelessWidget {
  final String text;
  const _BubbleTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
          ),
        ),
      ),
    );
  }
}
