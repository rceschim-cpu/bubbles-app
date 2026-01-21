import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/bubbles_c_lite_logo.dart';

import '../../domain/bubble.dart';
import '../bubbles_controller.dart';
import '../widgets/bubble_map.dart';
import 'bubble_detail_page.dart';

class BubblesHomePage extends StatelessWidget {
  const BubblesHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<BubblesController>();

    if (controller.isLoadingTrending) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.white70,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Container(
              height: 56,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withOpacity(0.06),
                  ),
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // LOGO — C-Lite
                    const BubblesCLiteLogo(size: 24),
                    const SizedBox(width: 10),
                    Text(
                      'bubbles',
                      style: GoogleFonts.nunito(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // MAPA DE BOLHAS
            Expanded(
              child: ClipRect(
                child: BubbleMap(
                  bubbles: controller.trending,
                  onTapBubble: (Bubble bubble) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BubbleDetailPage(bubble: bubble),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
