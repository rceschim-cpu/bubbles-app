import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:bubbles_app/features/bubbles/domain/bubble.dart';
import 'package:bubbles_app/features/bubbles/presentation/widgets/bubble_widget.dart';

class BubbleMap extends StatefulWidget {
  final List<Bubble> bubbles;
  final void Function(Bubble) onTapBubble;

  const BubbleMap({
    super.key,
    required this.bubbles,
    required this.onTapBubble,
  });

  @override
  State<BubbleMap> createState() => _BubbleMapState();
}

class _BubbleMapState extends State<BubbleMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  final Map<Bubble, double> _phase = {};
  final Map<Bubble, _SpherePoint> _spherePoints = {};

  List<_Packed> _packed = [];
  Size? _lastSize;

  // ===== ROTATION / INÉRCIA =====
  Offset _rotation = Offset.zero;
  Offset _velocity = Offset.zero;
  Offset _lastDrag = Offset.zero;

  static const double _canvasScale = 3.0;

  static const double _rotationFactor = 0.0028;
  static const double _friction = 0.90;
  static const double _minVelocity = 0.04;

  // ===== ESCALA EDITORIAL =====
  static const List<double> _rankScales = [
    1.35,
    1.20,
    1.12,
    1.05,
    0.98,
    0.92,
    0.86,
    0.80,
    0.75,
    0.70,
  ];

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat();

    final rnd = Random();
    for (final b in widget.bubbles) {
      _phase[b] = rnd.nextDouble() * pi * 2;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final vw = constraints.maxWidth;
        final vh = constraints.maxHeight;

        if (widget.bubbles.isEmpty || vw <= 0 || vh <= 0) {
          return const SizedBox.shrink();
        }

        final canvasSize = Size(vw * _canvasScale, vh * _canvasScale);
        final center = Offset(canvasSize.width / 2, canvasSize.height / 2);

        const baseSize = 130.0;

        if (_packed.isEmpty || _lastSize != canvasSize) {
          _packed = _packCompact(
            bubbles: widget.bubbles,
            center: center,
            baseSize: baseSize,
          );
          _lastSize = canvasSize;

          // ===== GERA ESFERA REAL (UMA VEZ) =====
          _spherePoints.clear();
          final rnd = Random();

          for (final p in _packed) {
            final u = rnd.nextDouble();
            final v = rnd.nextDouble();

            final theta = 2 * pi * u;
            final phi = acos(2 * v - 1);

            final x = sin(phi) * cos(theta);
            final y = sin(phi) * sin(theta);
            final z = cos(phi);

            _spherePoints[p.bubble] = _SpherePoint(x, y, z);
          }
        }

        return GestureDetector(
          onPanStart: (d) {
            _lastDrag = d.localPosition;
            _velocity = Offset.zero;
          },
          onPanUpdate: (d) {
            final delta = d.localPosition - _lastDrag;
            _lastDrag = d.localPosition;

            setState(() {
              _rotation += Offset(
                delta.dy * _rotationFactor,
                delta.dx * _rotationFactor,
              );
              _velocity = delta;
            });
          },
          onPanEnd: (_) {},
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                if (_velocity.distance > _minVelocity) {
                  _velocity *= _friction;
                  _rotation += Offset(
                    _velocity.dy * _rotationFactor,
                    _velocity.dx * _rotationFactor,
                  );
                } else {
                  _velocity = Offset.zero;
                }

                final t = _controller.value * 2 * pi;

                return Stack(
                  clipBehavior: Clip.none,
                  children: _packed.map((p) {
                    final phase = _phase[p.bubble] ?? 0;
                    final sp = _spherePoints[p.bubble]!;

                    double x = sp.x;
                    double y = sp.y;
                    double z = sp.z;

                    final sinX = sin(_rotation.dx);
                    final cosX = cos(_rotation.dx);
                    final sinY = sin(_rotation.dy);
                    final cosY = cos(_rotation.dy);

                    // eixo X
                    double ry = y * cosX - z * sinX;
                    double rz = y * sinX + z * cosX;

                    // eixo Y
                    double rx = x * cosY + rz * sinY;
                    rz = -x * sinY + rz * cosY;

                    final projected = Offset(
                      rx * (vw * 0.45),
                      ry * (vh * 0.45),
                    );

                    // micro movimento
                    final dx = sin(t * 0.9 + phase) * 3.0;
                    final dy = cos(t * 1.3 + phase) * 2.4;

                    final size = p.r * 2;

                    final pos = Offset(
                      vw / 2 + projected.dx + dx - size / 2,
                      vh / 2 + projected.dy + dy - size / 2,
                    );

                    // profundidade real
                    final depth = ((1 - rz) / 2).clamp(0.0, 1.0);
                    final scale = lerpDouble(1.28, 0.78, depth)!;
                    final opacity = lerpDouble(1.0, 0.35, depth)!;

                    return Positioned(
                      left: pos.dx,
                      top: pos.dy,
                      child: Transform.scale(
                        scale: scale,
                        child: Opacity(
                          opacity: opacity,
                          child: SizedBox(
                            width: size,
                            height: size,
                            child: BubbleWidget(
                              bubble: p.bubble,
                              onTap: () => widget.onTapBubble(p.bubble),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // =======================
  // PACKING COMPACTO
  // =======================
  List<_Packed> _packCompact({
    required List<Bubble> bubbles,
    required Offset center,
    required double baseSize,
  }) {
    const double gap = 6;
    const int relaxIters = 36;
    const double pullStep = 4.5;

    double radiusForIndex(int index) {
      final scale =
          _rankScales[index.clamp(0, _rankScales.length - 1)];
      return (baseSize * scale) / 2;
    }

    final placed = <_Packed>[
      _Packed(
        bubble: bubbles.first,
        r: radiusForIndex(0),
        c: center,
      ),
    ];

    final rnd = Random();

    for (int i = 1; i < bubbles.length; i++) {
      final r = radiusForIndex(i);
      Offset candidate = center;

      double angle = rnd.nextDouble() * pi * 2;
      double dist = r + placed.first.r;

      for (int tries = 0; tries < 2000; tries++) {
        angle += 0.25;
        dist += 0.15;

        candidate = Offset(
          center.dx + cos(angle) * dist,
          center.dy + sin(angle) * dist,
        );

        bool collision = false;
        for (final p in placed) {
          if ((candidate - p.c).distance < (r + p.r + gap)) {
            collision = true;
            break;
          }
        }

        if (!collision) break;
      }

      placed.add(_Packed(bubble: bubbles[i], r: r, c: candidate));
    }

    for (int iter = 0; iter < relaxIters; iter++) {
      for (int i = 1; i < placed.length; i++) {
        final p = placed[i];
        final dir = center - p.c;
        final dist = dir.distance;
        if (dist < 0.01) continue;

        final candidate = p.c + dir / dist * pullStep;

        bool ok = true;
        for (int j = 0; j < placed.length; j++) {
          if (j == i) continue;
          final other = placed[j];
          if ((candidate - other.c).distance <
              (p.r + other.r + gap)) {
            ok = false;
            break;
          }
        }

        if (ok) placed[i] = p.copyWith(c: candidate);
      }
    }

    return placed;
  }
}

// =======================
// MODELOS AUXILIARES
// =======================

class _Packed {
  final Bubble bubble;
  final double r;
  final Offset c;

  const _Packed({
    required this.bubble,
    required this.r,
    required this.c,
  });

  _Packed copyWith({Offset? c}) {
    return _Packed(
      bubble: bubble,
      r: r,
      c: c ?? this.c,
    );
  }
}

class _SpherePoint {
  final double x;
  final double y;
  final double z;

  const _SpherePoint(this.x, this.y, this.z);
}