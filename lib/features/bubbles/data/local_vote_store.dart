import 'package:shared_preferences/shared_preferences.dart';

class LocalVoteStore {
  static const String _voteKeyPrefix = 'bubble_vote_';
  static const String _countKeyPrefix = 'bubble_vote_count_';

  static String _countKey(String bubbleId, String opinionId) =>
      '$_countKeyPrefix${bubbleId}_$opinionId';

  /// true se já votou nesta bolha
  static Future<bool> hasVoted(String bubbleId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_voteKeyPrefix + bubbleId);
  }

  /// opinionId votado
  static Future<String?> getVote(String bubbleId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_voteKeyPrefix + bubbleId);
  }

  /// incrementa contador local da opinião
  static Future<void> _incrementCount(
    String bubbleId,
    String opinionId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _countKey(bubbleId, opinionId);
    final current = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, current + 1);
  }

  /// salva voto (1 por bolha)
  static Future<void> saveVote({
    required String bubbleId,
    required String opinionId,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (prefs.containsKey(_voteKeyPrefix + bubbleId)) return;

    await prefs.setString(_voteKeyPrefix + bubbleId, opinionId);
    await _incrementCount(bubbleId, opinionId);
  }

  /// retorna contagem por opinionId
  static Future<Map<String, int>> getCounts(
    String bubbleId,
    List<String> opinionIds,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, int> result = {};

    for (final id in opinionIds) {
      result[id] = prefs.getInt(_countKey(bubbleId, id)) ?? 0;
    }
    return result;
  }
}
