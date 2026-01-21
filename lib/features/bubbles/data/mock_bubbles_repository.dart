import '../domain/bubble_detail.dart';
import '../domain/bubble_opinion.dart';

class MockBubblesRepository {
  final Map<String, BubbleDetail> _details = {
    'ai': BubbleDetail(
      bubbleId: 'ai',
      summary:
          'Governments and companies are debating how artificial intelligence '
          'should be regulated to balance innovation and safety.',
      opinions: [
        BubbleOpinion(
          id: 'a',
          text: 'Regulation is necessary to prevent misuse.',
          votes: 62,
        ),
        BubbleOpinion(
          id: 'b',
          text: 'Too much regulation will slow innovation.',
          votes: 38,
        ),
      ],
    ),
    'economy': BubbleDetail(
      bubbleId: 'economy',
      summary:
          'Economic uncertainty is driving discussions about inflation, '
          'interest rates, and global growth.',
      opinions: [
        BubbleOpinion(
          id: 'a',
          text: 'Strong government intervention is needed.',
          votes: 54,
        ),
        BubbleOpinion(
          id: 'b',
          text: 'Markets should self-correct without interference.',
          votes: 46,
        ),
      ],
    ),
  };

  BubbleDetail getBubbleDetail(String bubbleId) {
    return _details[bubbleId] ??
        BubbleDetail(
          bubbleId: bubbleId,
          summary: 'This topic is currently trending.',
          opinions: [
            BubbleOpinion(
              id: 'a',
              text: 'Most people agree this matters.',
              votes: 50,
            ),
            BubbleOpinion(
              id: 'b',
              text: 'Others think it is overblown.',
              votes: 50,
            ),
          ],
        );
  }

  void vote({
    required String bubbleId,
    required String opinionId,
  }) {
    final detail = _details[bubbleId];
    if (detail == null) return;

    final opinion =
        detail.opinions.firstWhere((o) => o.id == opinionId);
    opinion.votes += 1;
  }
}
