enum BubbleSize {
  small,
  medium,
  large,
}

class Bubble {
  final String id;
  final int rank;
  final String title;
  final String label;
  final String context;
  final String source;
  final String subreddit;
  final String permalink;
  final String createdAt;
  final double rawScore;
  final double relevanceScore;
  final double suggestedRadius;

  // 🔥 campos que o layout já usa
  final BubbleSize size;
  final String imageUrl;

  // 🔥 novo
  final List<BubbleOpinion> opinions;

  Bubble({
    required this.id,
    required this.rank,
    required this.title,
    required this.label,
    required this.context,
    required this.source,
    required this.subreddit,
    required this.permalink,
    required this.createdAt,
    required this.rawScore,
    required this.relevanceScore,
    required this.suggestedRadius,
    required this.size,
    required this.imageUrl,
    required this.opinions,
  });

  factory Bubble.fromJson(Map<String, dynamic> json) {
    final double score =
        (json['relevanceScore'] as num?)?.toDouble() ?? 0.0;

    return Bubble(
      id: json['id'] as String,
      rank: json['rank'] as int,
      title: json['title'] as String,
      label: json['label'] as String? ?? '',
      context: json['context'] as String? ?? '',
      source: json['source'] as String,
      subreddit: json['subreddit'] as String,
      permalink: json['permalink'] as String,
      createdAt: json['createdAt'] as String,
      rawScore: (json['rawScore'] as num).toDouble(),
      relevanceScore: score,
      suggestedRadius: (json['suggestedRadius'] as num).toDouble(),

      // 🔁 mantém lógica antiga
      size: _sizeFromScore(score),

      // ✅ CORREÇÃO: backend envia "image", não "imageUrl"
      imageUrl: json['image'] as String? ?? '',

      opinions: (json['opinions'] as List<dynamic>? ?? [])
          .map((o) => BubbleOpinion.fromJson(o))
          .toList(),
    );
  }

  static BubbleSize _sizeFromScore(double score) {
    if (score >= 0.7) return BubbleSize.large;
    if (score >= 0.4) return BubbleSize.medium;
    return BubbleSize.small;
  }
}

class BubbleOpinion {
  final String id;
  final String tone; // positive | negative | neutral
  final String text;
  final String source;
  final int votes;

  BubbleOpinion({
    required this.id,
    required this.tone,
    required this.text,
    required this.source,
    required this.votes,
  });

  factory BubbleOpinion.fromJson(Map<String, dynamic> json) {
    return BubbleOpinion(
      id: json['id'] as String,
      tone: json['tone'] as String,
      text: json['text'] as String,
      source: json['source'] as String,
      votes: json['votes'] as int? ?? 0,
    );
  }
}
