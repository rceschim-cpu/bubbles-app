import 'dart:ui';

import 'package:flutter/material.dart';
import '../../domain/bubble.dart';

class BubbleWidget extends StatelessWidget {
  final Bubble bubble;
  final VoidCallback onTap;

  const BubbleWidget({
    super.key,
    required this.bubble,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double size = _bubbleSize(bubble.size);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: ClipOval(
          child: Stack(
            children: [
              // 1️⃣ FUNDO (imagem OU gradiente)
              Positioned.fill(
                child: _buildBackground(),
              ),

              // 2️⃣ OVERLAY DE PROFUNDIDADE (escurece + dá contraste)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.3, -0.3),
                      radius: 1.1,
                      colors: [
                        Colors.black.withOpacity(0.05),
                        Colors.black.withOpacity(0.1),
                      ],
                    ),
                  ),
                ),
              ),

              // 3️⃣ EFEITO DE LENTE (glass)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 0.4, sigmaY: 0.4),
                  child: Container(
                    color: Colors.white.withOpacity(0.025),
                  ),
                ),
              ),

              // 4️⃣ TEXTO
              Padding(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: RadialGradient(
                        radius: 1.2,
                        colors: [
                          Colors.black.withOpacity(0.35),
                          Colors.black.withOpacity(0.15),
                          Colors.black.withOpacity(0.0),
                        ],
                      ),
                    ),
                    child: Text(
                      bubble.label,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: _textSize(bubble.size),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                        height: 1.25,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ),
                ),
              ),

              // 5️⃣ BORDA (define a célula)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.14),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =======================
  // TAMANHOS
  // =======================

  double _bubbleSize(BubbleSize size) {
    switch (size) {
      case BubbleSize.large:
        return 120;
      case BubbleSize.medium:
        return 88;
      case BubbleSize.small:
        return 64;
    }
  }

  double _textSize(BubbleSize size) {
    switch (size) {
      case BubbleSize.large:
        return 14;
      case BubbleSize.medium:
        return 12;
      case BubbleSize.small:
        return 10;
    }
  }

  // =======================
  // FUNDO
  // =======================

  Widget _buildBackground() {
    final url = bubble.imageUrl.trim();

    if (url.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.4, -0.4),
            radius: 0.9,
            colors: [
              Colors.white.withOpacity(0.16),
              Colors.white.withOpacity(0.06),
              Colors.white.withOpacity(0.02),
            ],
          ),
        ),
      );
    }

    Widget img;

    if (url.startsWith('assets/')) {
      img = Image.asset(url, fit: BoxFit.cover);
    } else if (url.startsWith('data:image/')) {
      try {
        final bytes = UriData.parse(url).contentAsBytes();
        img = Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {
        img = const SizedBox.shrink();
      }
    } else {
      img = Image.network(url, fit: BoxFit.cover);
    }

    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        Colors.black.withOpacity(0.5),
        BlendMode.darken,
      ),
      child: img,
    );
  }
}