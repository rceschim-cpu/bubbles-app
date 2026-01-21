import 'bubble_opinion.dart';

class BubbleDetail {
  final String bubbleId;
  final String summary;
  final List<BubbleOpinion> opinions;

  BubbleDetail({
    required this.bubbleId,
    required this.summary,
    required this.opinions,
  });

  int get totalVotes =>
      opinions.fold(0, (sum, o) => sum + o.votes);
}
