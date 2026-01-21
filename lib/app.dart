import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/bubbles/data/bubbles_repository.dart';
import 'features/bubbles/presentation/bubbles_controller.dart';
import 'features/bubbles/presentation/pages/bubbles_home_page.dart';

class BubblesApp extends StatelessWidget {
  const BubblesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BubblesController(
        repository: BubblesRepository(),
      )..loadBubbles(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'bubbles',
        theme: ThemeData.dark(),
        home: const BubblesHomePage(),
      ),
    );
  }
}