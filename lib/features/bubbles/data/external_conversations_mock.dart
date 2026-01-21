import '../domain/external_conversation.dart';

final externalConversationsMock = <ExternalConversation>[
  ExternalConversation(
    id: 'x_1',
    topicId: '1',
    source: ExternalSource.x,
    url: 'https://x.com',
    excerpt:
        'People are debating whether AI regulation will slow innovation or finally bring accountability.',
    likes: 1200,
    replies: 340,
    shares: 210,
  ),
  ExternalConversation(
    id: 't_1',
    topicId: '1',
    source: ExternalSource.threads,
    url: 'https://www.threads.net',
    excerpt:
        'On Threads, users are sharing longer thoughts about how regulation could protect creators.',
    likes: 560,
    replies: 90,
  ),
];
