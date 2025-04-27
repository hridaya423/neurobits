import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/supabase.dart';
class ChallengeInviteBanner extends ConsumerWidget {
  final Map<String, dynamic> challenge;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final bool isLoading;
  const ChallengeInviteBanner({
    Key? key,
    required this.challenge,
    this.onAccept,
    this.onDecline,
    this.isLoading = false,
  }) : super(key: key);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quizData = challenge['quiz_data'] ?? {};
    final inviterId = challenge['initiator_id'] ?? challenge['sender_id'];
    return FutureBuilder<Map<String, dynamic>?>(
      future: SupabaseService.getUserById(inviterId),
      builder: (context, snapshot) {
        final inviterName = snapshot.data?['username'] ?? 'A friend';
        return Material(
          elevation: 6,
          color: Theme.of(context).colorScheme.secondary.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.sports_esports, color: Colors.white, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$inviterName challenged you!',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _quizSummary(quizData),
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                if (!isLoading) ...[
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 28),
                    tooltip: 'Accept',
                    onPressed: onAccept,
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 28),
                    tooltip: 'Decline',
                    onPressed: onDecline,
                  ),
                ] else ...[
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                ]
              ],
            ),
          ),
        );
      },
    );
  }
  static String _quizSummary(Map<String, dynamic> quizData) {
    final topic = quizData['topic'] ?? 'Quiz';
    final difficulty = quizData['difficulty'] ?? 'any';
    final numQuestions = quizData['numQuestions']?.toString() ?? '?';
    return 'Topic: $topic | $difficulty | $numQuestions Qs';
  }
}