enum ExternalSource {
  x,
  threads,
}

class ExternalConversation {
  final String id;
  final String topicId;
  final ExternalSource source;

  final String url;
  final String excerpt;

  final int likes;
  final int replies;
  final int? shares;

  const ExternalConversation({
    required this.id,
    required this.topicId,
    required this.source,
    required this.url,
    required this.excerpt,
    required this.likes,
    required this.replies,
    this.shares,
  });
}
