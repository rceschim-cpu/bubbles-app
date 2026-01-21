import 'package:flutter/material.dart';

import '../domain/bubble.dart';
import '../data/bubbles_repository.dart';

class BubblesController extends ChangeNotifier {
  final BubblesRepository _repository;

  BubblesController({BubblesRepository? repository})
      : _repository = repository ?? BubblesRepository();

  List<Bubble> _bubbles = [];
  bool _isLoading = false;

  // ===== API NOVA =====
  List<Bubble> get bubbles => _bubbles;
  bool get isLoading => _isLoading;

  // ===== API ANTIGA (retrocompatibilidade) =====
  List<Bubble> get trending => _bubbles;
  bool get isLoadingTrending => _isLoading;

  Future<void> loadBubbles() async {
    _isLoading = true;
    notifyListeners();

    try {
      final loadedBubbles = await _repository.loadBubbles();

      // garante ordenação por rank (1 = mais quente)
      loadedBubbles.sort((a, b) => a.rank.compareTo(b.rank));

      _bubbles = loadedBubbles;
    } catch (e) {
      debugPrint('Erro ao carregar bolhas: $e');
      _bubbles = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}