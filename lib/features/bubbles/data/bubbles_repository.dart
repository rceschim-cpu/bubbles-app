import 'dart:convert';
import 'package:flutter/services.dart';

import '../domain/bubble.dart';

class BubblesRepository {
  Future<List<Bubble>> loadBubbles() async {
    final jsonString =
        await rootBundle.loadString('assets/data/bubbles_enriched.json');

    final Map<String, dynamic> data = json.decode(jsonString);

    final List<dynamic> items = data['items'] ?? [];

    return items.map((item) => Bubble.fromJson(item)).toList();
  }
}
