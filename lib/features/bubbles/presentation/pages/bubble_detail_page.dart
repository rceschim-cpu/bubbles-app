import 'dart:ui';
import 'package:flutter/material.dart';

import '../../domain/bubble.dart';
import '../../data/local_vote_store.dart';

class BubbleDetailPage extends StatefulWidget {
  final Bubble bubble;

  const BubbleDetailPage({
    super.key,
    required this.bubble,
  });

  @override
  State<BubbleDetailPage> createState() => _BubbleDetailPageState();
}

class _BubbleDetailPageState extends State<BubbleDetailPage> {
  String? _selectedOpinionId;
  bool _hasVoted = false;
  Map<String, int> _counts = {};

  @override
  void initState() {
    super.initState();
    _loadVote();
  }

  Future<void> _loadVote() async {
    final voted = await LocalVoteStore.hasVoted(widget.bubble.id);
    final vote = await LocalVoteStore.getVote(widget.bubble.id);

    Map<String, int> counts = {};
    if (voted) {
      counts = await LocalVoteStore.getCounts(
        widget.bubble.id,
        widget.bubble.opinions.map((o) => o.id).toList(),
      );
    }

    setState(() {
      _hasVoted = voted;
      _selectedOpinionId = vote;
      _counts = counts;
    });
  }

  Future<void> _vote(String opinionId) async {
    if (_hasVoted) return;

    await LocalVoteStore.saveVote(
      bubbleId: widget.bubble.id,
      opinionId: opinionId,
    );

    final counts = await LocalVoteStore.getCounts(
      widget.bubble.id,
      widget.bubble.opinions.map((o) => o.id).toList(),
    );

    setState(() {
      _hasVoted = true;
      _selectedOpinionId = opinionId;
      _counts = counts;
    });
  }

  int _totalVotes() {
    return _counts.values.fold(0, (a, b) => a + b);
  }

  int _percentage(String opinionId) {
    final total = _totalVotes();
    if (total == 0) return 0;
    return (((_counts[opinionId] ?? 0) / total) * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final bubble = widget.bubble;
    final opinions = bubble.opinions;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(bubble.label.isNotEmpty ? bubble.label : bubble.title),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // =======================
                // IMAGEM / FAIXA EDITORIAL
                // =======================
                if (bubble.imageUrl.isNotEmpty)
                  SizedBox(
                    height: 240,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          bubble.imageUrl,
                          fit: BoxFit.cover,
                        ),

                        // escurecimento base
                        Container(
                          color: Colors.black.withOpacity(0.35),
                        ),

                        // gradiente editorial
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black87,
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),

                        // título dentro da imagem
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: Text(
                              bubble.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    height: 1.25,
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // =======================
                // CONTEÚDO
                // =======================
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (bubble.context.isNotEmpty) ...[
                        Text(
                          bubble.context,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 24),
                      ],

                      Text(
                        'O que as pessoas estão dizendo',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),

                      ...opinions.map((opinion) {
                        final bool isSelected =
                            opinion.id == _selectedOpinionId;
                        final bool showResult = _hasVoted;
                        final int percent =
                            showResult ? _percentage(opinion.id) : 0;

                        return _OpinionTile(
                          text: opinion.text,
                          selected: isSelected,
                          enabled: !_hasVoted,
                          showPercentage: showResult,
                          percentage: percent,
                          onTap: () => _vote(opinion.id),
                        );
                      }),

                      if (_hasVoted) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Resultado baseado nos votos locais deste dispositivo.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OpinionTile extends StatelessWidget {
  final String text;
  final bool selected;
  final bool enabled;
  final bool showPercentage;
  final int percentage;
  final VoidCallback onTap;

  const _OpinionTile({
    required this.text,
    required this.selected,
    required this.enabled,
    required this.showPercentage,
    required this.percentage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? Theme.of(context).colorScheme.primary
        : Colors.grey.shade300;

    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (showPercentage) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: percentage / 100.0,
                minHeight: 6,
              ),
              const SizedBox(height: 4),
              Text(
                '$percentage%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
