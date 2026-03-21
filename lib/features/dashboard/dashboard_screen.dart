import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neurobits/core/providers.dart';
import 'package:neurobits/services/auth_service.dart';
import 'package:neurobits/services/convex_client_service.dart';
import 'package:go_router/go_router.dart';
import 'package:neurobits/core/widgets/facehash_avatar.dart';
import '../onboarding/learning_path_onboarding_screen.dart';
import 'learning_path_banner.dart';
import 'completed_paths_screen.dart';
import '../../core/learning_path_providers.dart';
import '../learning_path/learning_path_roadmap_screen.dart';
import 'package:shimmer/shimmer.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late final TextEditingController _topicController;
  bool _isRefreshing = false;
  @override
  void initState() {
    super.initState();
    _topicController = TextEditingController();
    _topicController.addListener(_onTopicChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      initializeUserPathProvider(ref);
    });
  }

  @override
  void dispose() {
    _topicController.removeListener(_onTopicChanged);
    _topicController.dispose();
    super.dispose();
  }

  void _onTopicChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      final user = ref.read(userProvider).valueOrNull;
      if (user != null) {
        await Future.wait([
          ref.refresh(userStatsProvider.future),
          ref.refresh(activeLearningPathProvider.future),
          ref.refresh(userPathDataProvider.future),
        ]);
        ref.invalidate(practiceRecommendationsProvider);
        ref.invalidate(enrichedPracticeProvider);
        ref.invalidate(suggestedNewTopicsWithReasonsProvider);
        ref.invalidate(recommendationsCacheProvider);
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  String _capitalizeTopicName(String topic) {
    if (topic.isEmpty) return topic;
    final words = topic.split(' ');
    return words.map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  Map<int, List<Map<String, dynamic>>> _groupChallengesByDay(
      List<Map<String, dynamic>> challenges) {
    final grouped = <int, List<Map<String, dynamic>>>{};
    for (final challenge in challenges) {
      final day = (challenge['day'] as num?)?.toInt();
      if (day == null) continue;
      grouped.putIfAbsent(day, () => []).add(challenge);
    }
    return grouped;
  }

  Future<void> _startNextDayEarly({
    required int currentDay,
    required String nextDayTopic,
    int? nextDayNumber,
    String? nextDayChallengeId,
    String? userPathId,
  }) async {
    try {
      final pathRepo = ref.read(pathRepositoryProvider);
      final result = await pathRepo.checkAndAdvanceStep();
      if (userPathId != null) {
        ref.invalidate(userPathChallengesProvider(userPathId));
      }
      ref.invalidate(userPathProvider);
      ref.invalidate(activeLearningPathProvider);

      if (!mounted) return;
      if (result['advanced'] == true) {
        final encoded = Uri.encodeComponent(nextDayTopic);
        context.push(
          '/topic/$encoded',
          extra: nextDayChallengeId != null
              ? {'userPathChallengeId': nextDayChallengeId}
              : null,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Finish Day $currentDay minimum first to start Day ${nextDayNumber ?? (currentDay + 1)} early.',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not advance to next day yet.'),
        ),
      );
    }
  }

  Widget _buildPathDayTile(
    BuildContext context, {
    required int day,
    required Map<String, dynamic> primaryChallenge,
    required int totalChallenges,
    required int completedChallenges,
    required bool isCurrent,
    VoidCallback? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final topic = _capitalizeTopicName(primaryChallenge['topic']?.toString() ??
        primaryChallenge['title']?.toString() ??
        '');
    final description = primaryChallenge['description']?.toString() ?? '';
    final progressText = completedChallenges > 0
        ? '$completedChallenges/$totalChallenges done'
        : '$totalChallenges challenges';
    final containerColor = isCurrent
        ? colorScheme.primaryContainer.withValues(alpha: 0.22)
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.18);
    final borderColor = isCurrent
        ? colorScheme.primary
        : colorScheme.outline.withValues(alpha: 0.4);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: containerColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? colorScheme.primary.withValues(alpha: 0.18)
                          : colorScheme.secondaryContainer
                              .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Day $day',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isCurrent
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    progressText,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                topic,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLearnHubHeader(
    BuildContext context, {
    required Map<String, dynamic> user,
    required Map<String, dynamic> stats,
    required bool isInLearningPathMode,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final username = user['username']?.toString().trim();
    final email = user['email']?.toString() ?? 'Learner';
    final emailLower = user['emailLower']?.toString().trim();
    final avatarSeed = user['avatarSeed']?.toString().trim();
    final fallbackName = email.contains('@') ? email.split('@').first : email;
    final displayName =
        (username != null && username.isNotEmpty) ? username : fallbackName;
    final avatarKey = (avatarSeed != null && avatarSeed.isNotEmpty)
        ? avatarSeed
        : (emailLower != null && emailLower.isNotEmpty)
            ? emailLower
            : displayName;
    final avatarUrl = user['avatarUrl']?.toString().trim();
    final createdAt = (user['createdAt'] as num?)?.toInt();
    final accountAgeDays = createdAt == null
        ? 0
        : (DateTime.now().millisecondsSinceEpoch - createdAt) ~/ 86400000;
    final showWeeklyReport = accountAgeDays >= 7;
    final reportLabel = showWeeklyReport ? 'Weekly report' : 'Daily report';
    final reportPeriod = showWeeklyReport ? 'weekly' : 'daily';
    final level = (user['level'] as num?)?.toInt() ?? 1;
    final xp = (user['xp'] as num?)?.toInt() ?? 0;
    final streak = (stats['currentStreak'] as num?)?.toInt() ?? 0;
    final streakGoal = (user['streakGoal'] as num?)?.toInt() ?? 1;
    const xpPerLevel = 100;
    final previousLevelXp = (level - 1) * xpPerLevel;
    final xpIntoLevel = (xp - previousLevelXp).clamp(0, xpPerLevel);
    final xpProgress = xpPerLevel > 0 ? xpIntoLevel / xpPerLevel : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildAvatar(
                context,
                avatarUrl: avatarUrl,
                avatarKey: avatarKey,
                fallbackName: displayName,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hi $displayName',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isInLearningPathMode ? 'Learning Path' : 'Free Mode',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '$streak',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Level $level',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: xpProgress,
                    minHeight: 8,
                    backgroundColor: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.4),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${xpIntoLevel.toInt()}/$xpPerLevel XP',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Daily goal: $streakGoal ${streakGoal == 1 ? 'day' : 'days'} streak',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.push('/reports?period=$reportPeriod'),
              icon: const Icon(Icons.assessment_outlined, size: 16),
              label: Text(reportLabel),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(0, 32),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(
    BuildContext context, {
    required String? avatarUrl,
    required String avatarKey,
    required String fallbackName,
    required double size,
  }) {
    final name = avatarKey.isNotEmpty ? avatarKey : fallbackName;
    final radius = BorderRadius.circular(size / 2);
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return FacehashAvatar(
        name: name,
        size: size,
        variant: FacehashVariant.gradient,
        intensity3d: FacehashIntensity.dramatic,
        showInitial: false,
        showMouth: true,
        enableBlink: true,
        shape: FacehashShape.round,
      );
    }
    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        avatarUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return FacehashAvatar(
            name: name,
            size: size,
            variant: FacehashVariant.gradient,
            intensity3d: FacehashIntensity.dramatic,
            showInitial: false,
            showMouth: true,
            enableBlink: true,
            shape: FacehashShape.round,
          );
        },
      ),
    );
  }

  Widget _buildCurrentFocusCard(
    BuildContext context, {
    required int currentStep,
    required int totalSteps,
    required String? topicName,
    required String? topicDescription,
    required int completedChallenges,
    required int totalChallenges,
    bool showCompletionActions = false,
    VoidCallback? onMoreTopic,
    VoidCallback? onStartNextDay,
    String? startNextDayLabel,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final percent =
        totalSteps > 0 ? (currentStep / totalSteps).clamp(0.0, 1.0) : 0.0;
    final minToComplete =
        totalChallenges > 0 ? ((totalChallenges * 2) / 3).ceil() : 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.14), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today\'s focus',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (topicName != null && topicName.isNotEmpty) ...[
            Text(
              _capitalizeTopicName(topicName),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ] else ...[
            Text(
              'No topic available',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
          if (topicDescription != null && topicDescription.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              topicDescription,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 4,
              backgroundColor: colorScheme.onSurface.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation(colorScheme.primary),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                'Step $currentStep of $totalSteps',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const Spacer(),
              if (totalChallenges > 0)
                Text(
                  '$completedChallenges/$totalChallenges',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
            ],
          ),
          if (totalChallenges > 0 && !showCompletionActions)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Finish today: $minToComplete of $totalChallenges',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          if (showCompletionActions) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                      color: colorScheme.primary.withValues(alpha: 0.22)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check,
                            size: 14, color: Colors.green),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          'Today\'s target reached',
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$completedChallenges/$totalChallenges',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.primary,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Target: $minToComplete complete challenges. You can continue today or start early.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 9),
                  if (onMoreTopic != null && onStartNextDay != null)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onMoreTopic,
                            icon: const Icon(Icons.auto_awesome, size: 15),
                            label: const Text('More today'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: onStartNextDay,
                            icon: const Icon(Icons.play_arrow, size: 15),
                            label: Text(startNextDayLabel ?? 'Start next day'),
                          ),
                        ),
                      ],
                    )
                  else if (onMoreTopic != null)
                    OutlinedButton.icon(
                      onPressed: onMoreTopic,
                      icon: const Icon(Icons.auto_awesome, size: 15),
                      label: const Text('More on this topic'),
                    )
                  else if (onStartNextDay != null)
                    FilledButton.icon(
                      onPressed: onStartNextDay,
                      icon: const Icon(Icons.play_arrow, size: 15),
                      label: Text(startNextDayLabel ?? 'Start next day early'),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPathFocusSection(
    BuildContext context,
    List<Map<String, dynamic>> pathChallenges,
    int currentStep, {
    bool includeCurrent = false,
  }) {
    final grouped = _groupChallengesByDay(pathChallenges);
    if (grouped.isEmpty) return const SizedBox.shrink();

    final dayKeys = grouped.keys.toList()..sort();
    var startIndex = dayKeys.indexWhere((d) => d >= currentStep);
    if (startIndex < 0) startIndex = 0;
    var focusDays = dayKeys.skip(startIndex).toList();
    if (!includeCurrent && focusDays.isNotEmpty) {
      focusDays = focusDays.where((d) => d != currentStep).toList();
    }
    if (focusDays.isEmpty) {
      focusDays = [currentStep];
    }
    focusDays = focusDays.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Next up',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                )),
        const SizedBox(height: 4),
        Text(
          'Upcoming days in your path',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        Column(
          children: focusDays.map((day) {
            final dayChallenges = grouped[day] ?? [];
            if (dayChallenges.isEmpty) return const SizedBox.shrink();
            final completedCount =
                dayChallenges.where((c) => c['completed'] == true).length;
            return _buildPathDayTile(
              context,
              day: day,
              primaryChallenge: dayChallenges.first,
              totalChallenges: dayChallenges.length,
              completedChallenges: completedCount,
              isCurrent: includeCurrent && day == currentStep,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTodaysChallengesSection(
    BuildContext context,
    List<Map<String, dynamic>> challenges, {
    String title = 'Today\'s challenges',
    String? subtitle,
  }) {
    if (challenges.isEmpty) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    final sorted = List<Map<String, dynamic>>.from(challenges)
      ..sort((a, b) {
        final aDone = a['completed'] == true;
        final bDone = b['completed'] == true;
        if (aDone == bDone) return 0;
        return aDone ? 1 : -1;
      });
    final visible = sorted.take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
            const Spacer(),
            Text('${visible.length} items',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    )),
          ],
        ),
        if (subtitle != null && subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
        const SizedBox(height: 12),
        Column(
          children: visible.map((challenge) {
            final topicName = challenge['topic']?.toString() ?? '';
            final title = challenge['title']?.toString().trim();
            final displayTitle = (title == null || title.isEmpty)
                ? _capitalizeTopicName(topicName)
                : title;
            final description =
                challenge['description']?.toString().trim() ?? '';
            final isCompleted = challenge['completed'] == true;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: topicName.isEmpty
                    ? null
                    : () {
                        final encodedTopic = Uri.encodeComponent(topicName);
                        context.push(
                          '/topic/$encodedTopic',
                          extra: {
                            'userPathChallengeId': challenge['_id']?.toString(),
                          },
                        );
                      },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: EdgeInsets.symmetric(
                      horizontal: 14, vertical: isCompleted ? 10 : 12),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? Colors.green.withValues(alpha: 0.10)
                        : colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isCompleted
                          ? Colors.green.withValues(alpha: 0.45)
                          : colorScheme.outline.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? Colors.green.withValues(alpha: 0.22)
                              : colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isCompleted ? Icons.check : Icons.play_arrow,
                          size: 18,
                          color:
                              isCompleted ? Colors.green : colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayTitle,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isCompleted
                                        ? Colors.green.shade300
                                        : null,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (isCompleted) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Completed',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: Colors.green.shade300,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ] else if (description.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                description,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isCompleted)
                            Icon(Icons.check_circle,
                                size: 16, color: Colors.green.shade300),
                          const SizedBox(width: 2),
                          Icon(Icons.chevron_right,
                              size: 18, color: colorScheme.onSurfaceVariant),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFreeModeCard(
    BuildContext context, {
    required VoidCallback onExplorePaths,
    required VoidCallback onFreeMode,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Switch modes',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onFreeMode,
                  icon: const Icon(Icons.explore_outlined),
                  label: const Text('Free Mode'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onExplorePaths,
                  icon: const Icon(Icons.route),
                  label: const Text('Explore Paths'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPathFocusSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 120,
          height: 18,
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 12),
        Column(
          children: List.generate(
            2,
            (_) => Container(
              width: double.infinity,
              height: 90,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserLoadFallback(BuildContext context,
      {required bool hasError}) {
    final message = hasError
        ? 'Could not load your profile data.'
        : 'Still connecting to your account.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasError ? Icons.error_outline : Icons.cloud_off,
              size: 40,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Tap retry to reconnect.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                ref.invalidate(userProvider);
                ref.invalidate(userStatsProvider);
                ref.invalidate(activeLearningPathProvider);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProvider);
    final userStatsAsync = ref.watch(userStatsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Neurobits'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.assessment_outlined),
            tooltip: 'Reports',
            onPressed: () {
              context.push('/reports?period=weekly');
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () {
              context.push('/profile');
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService.instance.logout(),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Builder(builder: (context) {
        final user = userAsync.valueOrNull;
        if (user != null) {
          return _buildContent(context, ref, user, userStatsAsync);
        }
        if (userAsync.isLoading) {
          return const _DashboardSkeleton();
        }
        if (userAsync.hasError) {
          return _buildUserLoadFallback(context, hasError: true);
        }
        return _buildUserLoadFallback(context, hasError: false);
      }),
    );
  }

  Widget _buildContent(
      BuildContext context,
      WidgetRef ref,
      Map<String, dynamic>? user,
      AsyncValue<Map<String, dynamic>> userStatsAsync) {
    if (user == null) return const _DashboardSkeleton();
    final userPathState = ref.watch(userPathProvider);
    final activePathAsync = ref.watch(activeLearningPathProvider);
    final activePath =
        activePathAsync.maybeWhen(data: (value) => value, orElse: () => null);
    final bool shouldUseActivePath = activePath != null &&
        (userPathState == null ||
            userPathState['user_path_id']?.toString() !=
                activePath['user_path_id']?.toString());
    final userPath = shouldUseActivePath ? activePath : userPathState;
    final isPathLoading = userPathState == null && activePathAsync.isLoading;
    if (shouldUseActivePath) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(userPathProvider.notifier).state = activePath;
      });
    }
    final challenges = ref.watch(challengesProvider);
    final userStats = userStatsAsync.valueOrNull ?? <String, dynamic>{};
    List<dynamic> filteredChallenges = [];
    filteredChallenges = challenges.value ?? [];

    final pathChallengesAsync =
        userPath != null && userPath['user_path_id'] != null
            ? ref.watch(userPathChallengesProvider(userPath['user_path_id']))
            : null;
    final String? userPathId =
        userPath?['user_path_id']?.toString() ?? userPath?['_id']?.toString();

    List<Map<String, dynamic>> pathChallenges = [];
    int currentStep = 1;
    String? currentTopicName;
    String? currentTopicDescription;
    int currentChallengeIndex = 0;
    int totalPathDays = 0;
    int currentDayCompleted = 0;
    int currentDayTotal = 0;
    bool isCurrentDayComplete = false;
    List<Map<String, dynamic>> currentDayChallengesList = [];
    int? previousIncompleteDay;
    List<Map<String, dynamic>> previousIncompleteChallenges = [];
    String? currentDayTopicForMore;
    String? nextDayTopic;
    int? nextDayNumber;
    String? nextDayChallengeId;

    final dayPathList =
        isConvexList(userPath?['path']) ? toList(userPath?['path']) : null;
    final dayPathMap = <int, Map<String, dynamic>>{};
    if (dayPathList != null) {
      for (final item in dayPathList) {
        if (item is Map) {
          final data = Map<String, dynamic>.from(item);
          final day = (data['day'] as num?)?.toInt();
          if (day != null) dayPathMap[day] = data;
        }
      }
    }

    if (userPath != null &&
        userPath['user_path_id'] != null &&
        pathChallengesAsync != null) {
      pathChallenges = pathChallengesAsync.when(
        data: (data) => data,
        loading: () => [],
        error: (_, __) => [],
      );

      if (userPathId != null && pathChallengesAsync.hasValue) {}

      currentStep = (userPath['current_step'] as num?)?.toInt() ?? 1;

      if (pathChallenges.isNotEmpty) {
        currentChallengeIndex = pathChallenges.indexWhere((c) {
          final day = (c['day'] as num?)?.toInt();
          return day == currentStep;
        });
        if (currentChallengeIndex < 0) {
          currentChallengeIndex = 0;
        }
      }

      final groupedChallenges = _groupChallengesByDay(pathChallenges);
      final todayChallenges = groupedChallenges[currentStep] ?? [];
      currentDayTotal = todayChallenges.length;
      currentDayCompleted =
          todayChallenges.where((c) => c['completed'] == true).length;
      final currentDayMinRequired =
          currentDayTotal > 0 ? ((currentDayTotal * 2) / 3).ceil() : 0;
      isCurrentDayComplete =
          currentDayTotal > 0 && currentDayCompleted >= currentDayMinRequired;
      currentDayChallengesList = todayChallenges;
      if (todayChallenges.isNotEmpty) {
        currentDayTopicForMore = todayChallenges.first['topic']?.toString();
      }

      if (groupedChallenges.isNotEmpty) {
        final dayKeys = groupedChallenges.keys.toList()..sort();
        final incompleteDays = dayKeys.where((day) {
          final items = groupedChallenges[day] ?? [];
          return items.any((c) => c['completed'] != true);
        }).toList();
        final previousDays = incompleteDays.where((d) => d < currentStep);
        if (previousDays.isNotEmpty) {
          previousIncompleteDay = previousDays.last;
          previousIncompleteChallenges =
              (groupedChallenges[previousIncompleteDay] ?? [])
                  .where((c) => c['completed'] != true)
                  .toList();
        }

        nextDayNumber = currentStep + 1;
        final nextDayData = dayPathMap[nextDayNumber];
        nextDayTopic = nextDayData?['topic']?.toString() ??
            nextDayData?['title']?.toString();
        final nextDayChallenges = groupedChallenges[nextDayNumber] ?? [];
        if (nextDayChallenges.isNotEmpty) {
          nextDayChallengeId = nextDayChallenges.first['_id']?.toString();
        }
      }

      if (dayPathList != null && dayPathList.isNotEmpty) {
        final currentDay = dayPathList.firstWhere(
          (d) => (d['day'] as num?)?.toInt() == currentStep,
          orElse: () => null,
        );
        if (currentDay != null) {
          currentTopicName = currentDay['title']?.toString() ??
              currentDay['topic']?.toString();
          currentTopicDescription = currentDay['description']?.toString();
        }
      }

      if (currentTopicName == null &&
          pathChallenges.isNotEmpty &&
          currentChallengeIndex < pathChallenges.length) {
        final currentChallenge = pathChallenges[currentChallengeIndex];
        currentTopicName = currentChallenge['topic'] as String?;
        currentTopicDescription = currentChallenge['description'] as String?;
      }

      if (dayPathList != null && dayPathList.isNotEmpty) {
        totalPathDays = dayPathList
            .map((d) => (d['day'] as num?)?.toInt() ?? 1)
            .toSet()
            .length;
      } else if (pathChallenges.isNotEmpty) {
        totalPathDays = pathChallenges
            .map((c) => (c['day'] as num?)?.toInt() ?? 1)
            .toSet()
            .length;
      }

      if (pathChallenges.isNotEmpty) {
        final pathTopicNames = pathChallenges
            .map((c) => c['topic']?.toString().toLowerCase())
            .where((t) => t != null && t.isNotEmpty)
            .toSet();

        filteredChallenges = filteredChallenges.where((c) {
          final challengeTopic = c['topic']?.toString().toLowerCase() ?? '';
          return pathTopicNames.contains(challengeTopic);
        }).toList();
      }
    }

    final bool isInLearningPathMode =
        userPath != null && userPath['user_path_id'] != null;
    final bool shouldRefreshRecs = !isInLearningPathMode &&
        ref.watch(pendingRecommendationsRefreshProvider);
    final bool isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
    if (shouldRefreshRecs && isCurrentRoute) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(refreshPracticeProvider.notifier).state = true;
        ref.read(refreshSuggestionsProvider.notifier).state = true;
        ref.read(pendingRecommendationsRefreshProvider.notifier).state = false;
        ref.invalidate(recommendationsCacheProvider);
        ref.invalidate(practiceRecommendationsProvider);
        ref.invalidate(enrichedPracticeProvider);
        ref.invalidate(suggestedNewTopicsWithReasonsProvider);
        ref.invalidate(suggestedNewTopicsProvider);
      });
    }
    final practiceRecs = isInLearningPathMode
        ? const AsyncValue.data(<Map<String, dynamic>>[])
        : ref.watch(enrichedPracticeProvider);
    final suggestedTopics = isInLearningPathMode
        ? const AsyncValue.data(<Map<String, dynamic>>[])
        : ref.watch(suggestedNewTopicsWithReasonsProvider);
    return RefreshIndicator(
        onRefresh: _refreshData,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 16),
                _buildLearnHubHeader(
                  context,
                  user: user,
                  stats: userStats,
                  isInLearningPathMode: isInLearningPathMode,
                ),
                const SizedBox(height: 16),
                if (isInLearningPathMode) ...[
                  LearningPathBanner(
                    path: userPath,
                    currentStep: currentStep,
                    totalSteps: totalPathDays,
                    onViewRoadmap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LearningPathRoadmapScreen(),
                        ),
                      );
                    },
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: _buildCurrentFocusCard(
                      context,
                      currentStep: currentStep,
                      totalSteps: totalPathDays,
                      topicName: currentTopicName,
                      topicDescription: currentTopicDescription,
                      completedChallenges: currentDayCompleted,
                      totalChallenges: currentDayTotal,
                      showCompletionActions: isCurrentDayComplete,
                      onMoreTopic: (currentDayTopicForMore?.isNotEmpty ?? false)
                          ? () {
                              final topic = currentDayTopicForMore ?? '';
                              final encoded = Uri.encodeComponent(topic);
                              context.push('/topic/$encoded');
                            }
                          : null,
                      onStartNextDay: (nextDayTopic?.isNotEmpty ?? false)
                          ? () {
                              final topic = nextDayTopic ?? '';
                              _startNextDayEarly(
                                currentDay: currentStep,
                                nextDayTopic: topic,
                                nextDayNumber: nextDayNumber,
                                nextDayChallengeId: nextDayChallengeId,
                                userPathId: userPathId,
                              );
                            }
                          : null,
                      startNextDayLabel: nextDayNumber != null
                          ? 'Start Day $nextDayNumber early'
                          : 'Start next day early',
                    ),
                  ),
                  if (currentDayChallengesList.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: _buildTodaysChallengesSection(
                        context,
                        currentDayChallengesList,
                      ),
                    ),
                  if (previousIncompleteChallenges.isNotEmpty &&
                      previousIncompleteDay != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: _buildTodaysChallengesSection(
                        context,
                        previousIncompleteChallenges,
                        title: 'Remaining from Day $previousIncompleteDay',
                        subtitle:
                            'Finish these to close out Day $previousIncompleteDay.',
                      ),
                    ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: _buildFreeModeCard(
                      context,
                      onExplorePaths: () async {
                        final bool? pathChanged = await Navigator.push<bool?>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LearningPathOnboardingScreen(),
                          ),
                        );
                        if (pathChanged == true && mounted) {
                          await _refreshData();
                        }
                      },
                      onFreeMode: () async {
                        try {
                          final pathRepo = ref.read(pathRepositoryProvider);
                          await pathRepo.selectFreeMode();
                          if (userPathId != null) {
                            ref.invalidate(
                                userPathChallengesProvider(userPathId));
                          }
                          ref.read(userPathProvider.notifier).state = null;
                          ref.invalidate(activeLearningPathProvider);
                          ref.invalidate(userPathDataProvider);
                          await ref.read(activeLearningPathProvider.future);
                          ref.read(userPathProvider.notifier).state = null;
                          if (!mounted) return;
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                                content: Text('Switched to Free Mode.')),
                          );
                        } catch (e) {
                          debugPrint('Failed to switch to free mode: $e');
                          if (!mounted) return;
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Failed to switch to Free Mode.')),
                          );
                        }
                      },
                    ),
                  ),
                ],
                if (!isInLearningPathMode && !isPathLoading) ...[
                  ref.watch(completedPathsProvider(user['_id'] ?? '')).when(
                        loading: () => const SizedBox(),
                        error: (e, _) => const SizedBox(),
                        data: (completedPaths) {
                          if (completedPaths.isEmpty) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 0.0),
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.history),
                              label: const Text('Review Completed Paths'),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const CompletedPathsScreen(),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                  const SizedBox(height: 16),
                ],
                if (!isInLearningPathMode && !isPathLoading)
                  Container(
                    width: double.infinity,
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .secondaryContainer
                          .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('What do you want to train on today?',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _topicController,
                                decoration: InputDecoration(
                                  hintText:
                                      'Enter topic (e.g., Python Functions)',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 14),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            _buildActionButton(context, ref),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text('Start a Learning Path'),
                            onPressed: () async {
                              final bool? pathSelected =
                                  await Navigator.push<bool?>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      LearningPathOnboardingScreen(),
                                ),
                              );
                              if (pathSelected == true && mounted) {
                                await _refreshData();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              foregroundColor:
                                  Theme.of(context).colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (isInLearningPathMode)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: pathChallengesAsync == null
                        ? const SizedBox.shrink()
                        : pathChallengesAsync.when(
                            data: (data) => _buildPathFocusSection(
                              context,
                              data,
                              currentStep,
                            ),
                            loading: _buildPathFocusSkeleton,
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                  ),
                if (!isInLearningPathMode) ...[
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: _buildPracticeSection(context, practiceRecs),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child:
                        _buildSuggestedTopicsSection(context, suggestedTopics),
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ));
  }

  Widget _buildPracticeSection(BuildContext context,
      AsyncValue<List<Map<String, dynamic>>> practiceRecs) {
    return practiceRecs.when(
      data: (recs) {
        if (recs.isEmpty) {
          return const SizedBox.shrink();
        }
        final hasHistory = recs
            .any((rec) => rec['accuracy'] != null || rec['attempts'] != null);
        final title = hasHistory ? 'Topics to revisit' : 'Topics to try';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        )),
                const Spacer(),
                Text('${recs.length} topics',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        )),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              children: recs
                  .map((rec) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _PracticeTopicCard(rec: rec),
                      ))
                  .toList(),
            ),
          ],
        );
      },
      loading: () => _buildPracticeSkeleton(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildSuggestedTopicsSection(BuildContext context,
      AsyncValue<List<Map<String, dynamic>>> suggestedTopics) {
    return suggestedTopics.when(
      data: (topics) {
        if (topics.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New topics you might like',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(right: 16),
                itemCount: topics.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final topic = topics[index];
                  final related = topic['relatedTopics'];
                  return _SuggestedTopicCard(
                    topicName: topic['name']?.toString() ?? '',
                    reason: topic['reason']?.toString() ?? '',
                    relatedTopics: related is List
                        ? related.map((t) => t.toString()).toList()
                        : <String>[],
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => _buildNewTopicsSkeleton(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildNewTopicsSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 200,
          height: 18,
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 3,
            itemBuilder: (_, __) => Container(
              width: 220,
              height: 140,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: _topicController.text.isEmpty
          ? null
          : () {
              final topic = _topicController.text.trim();
              if (topic.isNotEmpty) {
                final encodedTopic = Uri.encodeComponent(topic);
                context.push('/topic/$encodedTopic');
              }
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      child: const Icon(Icons.arrow_forward),
    );
  }

  Widget _buildPracticeSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 140,
          height: 18,
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 12),
        Column(
          children: List.generate(
            3,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 20,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 100,
                          height: 16,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                height: 56,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: 200,
                height: 24,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 3,
                itemBuilder: (_, __) => Container(
                  width: 280,
                  height: 200,
                  margin: const EdgeInsets.only(right: 16),
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PracticeTopicCard extends StatelessWidget {
  final Map<String, dynamic> rec;
  const _PracticeTopicCard({required this.rec});

  String _formatLastAttempted(int? epochMs) {
    if (epochMs == null) return '';
    final now = DateTime.now();
    final last = DateTime.fromMillisecondsSinceEpoch(epochMs);
    final diff = now.difference(last);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }

  Color _accuracyColor(double? accuracy) {
    if (accuracy == null) return Colors.grey;
    if (accuracy >= 0.8) return const Color(0xFF4CAF50);
    if (accuracy >= 0.5) return const Color(0xFFFF9800);
    return const Color(0xFFEF5350);
  }

  @override
  Widget build(BuildContext context) {
    final topicName = rec['topicName']?.toString() ?? '';
    final accuracy = (rec['accuracy'] as num?)?.toDouble();
    final attempts = (rec['attempts'] as num?)?.toInt();
    final lastAttemptedAt = (rec['lastAttemptedAt'] as num?)?.toInt();
    final pct = accuracy != null ? (accuracy * 100).round() : null;
    final lastText = _formatLastAttempted(lastAttemptedAt);
    final colorScheme = Theme.of(context).colorScheme;
    final accColor = _accuracyColor(accuracy);

    return GestureDetector(
      onTap: () {
        if (topicName.isNotEmpty) {
          final encodedTopic = Uri.encodeComponent(topicName);
          GoRouter.of(context).push('/topic/$encodedTopic');
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                topicName,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (pct != null) ...[
              Text(
                '$pct% accuracy',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: accColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(width: 8),
              if (attempts != null && attempts > 0)
                Text(
                  '$attempts ${attempts == 1 ? 'attempt' : 'attempts'} · $lastText',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                      ),
                ),
            ] else ...[
              Text(
                'You might like this',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                    ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }
}

class _SuggestedTopicCard extends StatelessWidget {
  final String topicName;
  final String reason;
  final List<String> relatedTopics;
  const _SuggestedTopicCard({
    required this.topicName,
    required this.reason,
    this.relatedTopics = const [],
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        if (topicName.isNotEmpty) {
          final encodedTopic = Uri.encodeComponent(topicName);
          GoRouter.of(context).push('/topic/$encodedTopic');
        }
      },
      child: Container(
        width: 220,
        height: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
            Text(
              topicName,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            if (reason.isNotEmpty)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Because',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      reason,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[500],
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              )
            else
              const Spacer(),
            if (relatedTopics.isNotEmpty)
              Text(
                'Related: ${relatedTopics.take(2).join(', ')}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}
