import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neurobits/core/providers.dart' hide userPathChallengesProvider;
import 'package:go_router/go_router.dart';
import '../../services/supabase.dart';
import '../../services/groq_service.dart';
import '../onboarding/learning_path_onboarding_screen.dart';
import 'learning_path_banner.dart';
import 'path_topic_progress_bar.dart';
import 'learning_path_challenge_card.dart';
import 'completed_paths_screen.dart';
import '../../core/learning_path_providers.dart';
import '../learning_path/learning_path_roadmap_screen.dart';
import 'package:shimmer/shimmer.dart';
import 'package:neurobits/features/profile/screens/challenge_quiz_screen.dart';
import 'package:neurobits/features/challenges/screens/topic_customization_screen.dart';
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}
class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late final TextEditingController _topicController;
  bool _isRefreshing = false;
  bool _isGeneratingQuiz = false;
  @override
  void initState() {
    super.initState();
    _topicController = TextEditingController();
    _topicController.addListener(_onTopicChanged);
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
      final user = ref.read(userProvider).value;
      if (user != null) {
        await Future.wait([
          ref.refresh(userProvider.future),
          ref.refresh(activeLearningPathProvider(user['id']).future),
          ref.refresh(userPathDataProvider.future),
        ]);
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }
  void _onXpOrPointsChanged() {
    final user = ref.read(userProvider).value;
    if (user != null) {
      ref.invalidate(userStatsProvider);
      ref.invalidate(userProvider);
      ref.invalidate(userPathDataProvider);
    }
  }
  Future<List<Map<String, dynamic>>> _fetchCompletedPaths(String userId) async {
    try {
      final paths = await SupabaseService.client
          .from('user_learning_paths')
          .select('id')
          .eq('user_id', userId)
          .eq('is_complete', true);
      return List<Map<String, dynamic>>.from(paths);
    } catch (e) {
      debugPrint('Error fetching completed paths: $e');
      return [];
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
  List<Map<String, dynamic>> _filterChallengesByTopic(
      List<Map<String, dynamic>> challenges, String topic) {
    if (topic.isEmpty) return challenges;
    final exactMatches = challenges
        .where((challenge) =>
            challenge['topic']?.toString().toLowerCase() == topic.toLowerCase())
        .toList();
    if (exactMatches.isNotEmpty) {
      return exactMatches;
    }
    return challenges.where((challenge) {
      final challengeTopic = challenge['topic']?.toString().toLowerCase() ?? '';
      final challengeTitle = challenge['title']?.toString().toLowerCase() ?? '';
      final challengeQuestion =
          challenge['question']?.toString().toLowerCase() ?? '';
      return challengeTopic.contains(topic.toLowerCase()) ||
          challengeTitle.contains(topic.toLowerCase()) ||
          challengeQuestion.contains(topic.toLowerCase());
    }).toList();
  }
  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProvider.select((value) => value));
    final userStatsAsync = ref.watch(userStatsProvider);
    final trendingTopicsAsync = ref.watch(trendingTopicsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Neurobits'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () {
              context.push('/profile');
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => SupabaseService.signOut(),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: userAsync.when(
        data: (user) => _buildContent(
            context, ref, user, userStatsAsync, trendingTopicsAsync),
        loading: () => const _DashboardSkeleton(),
        error: (_, __) => const Center(child: Text('Error loading user')),
      ),
    );
  }
  Widget _buildContent(
      BuildContext context,
      WidgetRef ref,
      Map<String, dynamic>? user,
      AsyncValue<Map<String, dynamic>> userStatsAsync,
      AsyncValue<List<Map<String, dynamic>>> trendingTopicsAsync) {
    if (user == null) return const SizedBox.shrink();
    final userPath = ref.watch(userPathProvider);
    final challenges = ref.watch(challengesProvider);
    final trendingChallenges = ref.watch(trendingChallengesProvider);
    final mostSolvedChallenges = ref.watch(mostSolvedChallengesProvider);
    final userPoints = user['points'] ?? 0;
    List<dynamic> filteredChallenges = [];
    if (challenges is AsyncValue<List<Map<String, dynamic>>>) {
      filteredChallenges = challenges.value ?? [];
    }
    int currentStep = 1;
    int totalSteps = 1;
    String? currentTopicName;
    String? currentTopicDescription;
    List<Map<String, dynamic>> pathChallenges = [];
    int currentIndex = 0;
    if (userPath != null && userPath['user_path_id'] != null) {
      final pathChallengesAsync =
          ref.watch(userPathChallengesProvider(userPath['user_path_id']));
      pathChallengesAsync.whenData((challenges) {
        pathChallenges = challenges;
        totalSteps = challenges.length;
        if (userPath['current_step'] != null) {
          currentStep = userPath['current_step'];
          currentIndex = currentStep - 1;
          if (currentIndex < challenges.length) {
            final currentChallenge = challenges[currentIndex];
            currentTopicName = currentChallenge['topic'];
            currentTopicDescription = currentChallenge['description'];
          }
        }
      });
      final topics = userPath['topics'] as List<dynamic>?;
      if (topics != null && topics.isNotEmpty) {
        filteredChallenges = filteredChallenges.where((c) {
          final challengeTopic = c['topic']?.toString() ?? '';
          return topics.any((t) =>
              (t['topic']?.toString() ?? '').toLowerCase() ==
              challengeTopic.toLowerCase());
        }).toList();
      }
    }
    final bool isInLearningPathMode =
        userPath != null && userPath['user_path_id'] != null;
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),
            if (isInLearningPathMode) ...[
              LearningPathBanner(
                path: userPath,
                currentStep: pathChallenges
                    .where((challenge) => challenge['completed'] == true)
                    .length,
                totalSteps: pathChallenges.length,
                onChangePath: () async {
                  final bool? pathChanged = await Navigator.push<bool?>(
                    context,
                    MaterialPageRoute(
                        builder: (_) => LearningPathOnboardingScreen()),
                  );
                  if (pathChanged == true && mounted) {
                    await _refreshData();
                  }
                },
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: PathTopicProgressBar(
                        currentStep: pathChallenges
                            .where(
                                (challenge) => challenge['completed'] == true)
                            .length,
                        totalSteps: pathChallenges.length,
                        topicName: currentTopicName ?? 'No Topic',
                        topicDescription: currentTopicDescription ??
                            'No challenges available',
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.map),
                      tooltip: 'View Roadmap',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LearningPathRoadmapScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.explore_outlined),
                    label: const Text("Switch to Free Mode"),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Switch to Free Mode?'),
                          content: const Text(
                              'Your progress in the current path will be saved. You can select it again later from the Onboarding screen.'),
                          actions: [
                            TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text('Cancel')),
                            TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: const Text('Switch Mode')),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        ref.read(userPathProvider.notifier).state = null;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Switched to Free Mode.')),
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: Theme.of(context).colorScheme.primary),
                      foregroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              if (pathChallenges.isNotEmpty &&
                  currentIndex < pathChallenges.length)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: LearningPathChallengeCard(
                    challenge: pathChallenges[currentIndex],
                    isCurrent: true,
                  ),
                ),
            ],
            if (userPath == null || userPath['user_path_id'] == null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        user['email'].toString().substring(0, 1).toUpperCase(),
                        style:
                            const TextStyle(fontSize: 24, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome ${user['email']}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text('Points: $userPoints'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (user != null)
                ref.watch(completedPathsProvider(user['id'])).when(
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
                                  builder: (_) => const CompletedPathsScreen(),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
              const SizedBox(height: 16),
            ],
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .secondaryContainer
                    .withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (userPath == null || userPath['user_path_id'] == null) ...[
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
                              hintText: 'Enter topic (e.g., Python Functions)',
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
                    trendingTopicsAsync.when(
                      data: (topics) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Trending Topics:',
                              style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 8),
                          if (topics.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: topics.take(5).map((topicMap) {
                                final topic =
                                    topicMap['topic']?.toString() ?? '';
                                return ActionChip(
                                  label: Text(topic),
                                  onPressed: () {
                                    _topicController.text = topic;
                                  },
                                );
                              }).toList(),
                            )
                          else
                            Text('No trending topics yet.',
                                style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 12),
                          if (topics.isNotEmpty)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.shuffle),
                                label: const Text('Random Topic'),
                                onPressed: () {
                                  final random = (topics.toList()..shuffle())
                                          .first['topic'] ??
                                      '';
                                  if (random.isNotEmpty) {
                                    context.push('/topic/$random');
                                  }
                                },
                              ),
                            ),
                        ],
                      ),
                      loading: () => _Shimmer(
                        child: SizedBox(
                          height: 40,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: 5,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (_, __) => Container(
                              width: 80,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ),
                      error: (err, stackTrace) => Text(
                          'Failed to load trending topics',
                          style: TextStyle(color: Colors.red)),
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
                              builder: (_) => LearningPathOnboardingScreen(),
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
                  ] else ...[
                    Text('Suggested Topics:',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: pathChallenges
                          .skip(currentIndex)
                          .take(3)
                          .map((challenge) => ActionChip(
                                label: Text(_capitalizeTopicName(
                                    challenge['topic'] ?? '')),
                                onPressed: () {
                                  final topic = challenge['topic'] ?? '';
                                  if (topic.isNotEmpty) {
                                    context.push('/topic/$topic');
                                  }
                                },
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Trending Challenges',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 180,
              child: trendingChallenges.when(
                data: (challenges) {
                  final filteredChallenges = userPath != null &&
                          userPath['user_path_id'] != null &&
                          currentIndex < pathChallenges.length
                      ? _filterChallengesByTopic(challenges,
                          pathChallenges[currentIndex]['topic'] ?? '')
                      : challenges;
                  return filteredChallenges.isEmpty
                      ? const Center(
                          child: Text(
                              'No trending challenges available for this topic. Complete some challenges to see trending content!'))
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredChallenges.length,
                          itemBuilder: (context, index) => Card(
                            margin: const EdgeInsets.only(right: 16, bottom: 8),
                            elevation: 2,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                final challengeData = filteredChallenges[index];
                                final challengeId = challengeData['id'];
                                final questions = challengeData['questions'];
                                if (challengeId != null) {
                                  if (questions is List &&
                                      questions.isNotEmpty) {
                                    context.push(
                                      '/challenge/${challengeId.toString()}_loaded',
                                      extra: challengeData,
                                    );
                                  } else {
                                    context.push(
                                      '/challenge/${challengeId.toString()}',
                                      extra: challengeData,
                                    );
                                  }
                                } else {
                                  debugPrint(
                                      "Could not determine ID for trending challenge.");
                                }
                              },
                              child: Container(
                                width: 250,
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            filteredChallenges[index]['title'],
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _getDifficultyColor(
                                                filteredChallenges[index]
                                                    ['difficulty']),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '${filteredChallenges[index]['difficulty']} ★',
                                            style: const TextStyle(
                                                color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      filteredChallenges[index]['question'] ??
                                          'Test your brain with this challenge!',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const Spacer(),
                                    Row(
                                      children: [
                                        Icon(
                                          _getChallengeTypeIcon(
                                              filteredChallenges[index]
                                                  ['type']),
                                          size: 16,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _getChallengeTypeText(
                                              filteredChallenges[index]
                                                  ['type']),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                        const Spacer(),
                                        const Icon(Icons.timer, size: 16),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${filteredChallenges[index]['estimated_time_seconds'] ?? 30}s',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                },
                loading: () => _Shimmer(
                  child: SizedBox(
                    height: 180,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: 3,
                      itemBuilder: (_, __) => Container(
                        width: 250,
                        margin: const EdgeInsets.only(right: 16, bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
                error: (error, stackTrace) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text('Error loading trending challenges: $error',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Most Solved Challenges',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 180,
              child: mostSolvedChallenges.when(
                data: (challenges) {
                  final filteredChallenges = userPath != null &&
                          userPath['user_path_id'] != null &&
                          currentIndex < pathChallenges.length
                      ? _filterChallengesByTopic(challenges,
                          pathChallenges[currentIndex]['topic'] ?? '')
                      : challenges;
                  return filteredChallenges.isEmpty
                      ? const Center(
                          child: Text(
                              'No popular challenges for this topic yet. Start solving challenges to see what\'s popular!'))
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredChallenges.length,
                          itemBuilder: (context, index) => Card(
                            margin: const EdgeInsets.only(right: 16, bottom: 8),
                            elevation: 2,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                final challengeData = filteredChallenges[index];
                                final challengeId = challengeData['id'];
                                final questions = challengeData['questions'];
                                if (challengeId != null) {
                                  if (questions is List &&
                                      questions.isNotEmpty) {
                                    context.push(
                                      '/challenge/${challengeId.toString()}_loaded',
                                      extra: challengeData,
                                    );
                                  } else {
                                    context.push(
                                      '/challenge/${challengeId.toString()}',
                                      extra: challengeData,
                                    );
                                  }
                                } else {
                                  debugPrint(
                                      "Could not determine ID for most solved challenge.");
                                }
                              },
                              child: Container(
                                width: 250,
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            filteredChallenges[index]['title'],
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _getDifficultyColor(
                                                filteredChallenges[index]
                                                    ['difficulty']),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '${filteredChallenges[index]['difficulty']} ★',
                                            style: const TextStyle(
                                                color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.people,
                                            size: 16, color: Colors.white),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${filteredChallenges[index]['solve_count'] ?? 0}',
                                          style: const TextStyle(
                                              color: Colors.white),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      filteredChallenges[index]['question'] ??
                                          'Test your brain with this challenge!',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const Spacer(),
                                    Row(
                                      children: [
                                        Icon(
                                          _getChallengeTypeIcon(
                                              filteredChallenges[index]
                                                  ['type']),
                                          size: 16,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _getChallengeTypeText(
                                              filteredChallenges[index]
                                                  ['type']),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                        const Spacer(),
                                        const Icon(Icons.timer, size: 16),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${filteredChallenges[index]['estimated_time_seconds'] ?? 30}s',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                },
                loading: () => _Shimmer(
                  child: SizedBox(
                    height: 180,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: 3,
                      itemBuilder: (_, __) => Container(
                        width: 250,
                        margin: const EdgeInsets.only(right: 16, bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
                error: (error, stackTrace) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text('Error loading popular challenges: $error',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Color _getDifficultyColor(dynamic difficulty) {
    final difficultyStr =
        difficulty is int ? difficulty.toString() : difficulty;
    switch (difficultyStr.toLowerCase()) {
      case 'easy':
      case '1':
        return Colors.green;
      case 'medium':
      case '2':
        return Colors.orange;
      case 'hard':
      case '3':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
  IconData _getChallengeTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'quiz':
        return Icons.quiz;
      case 'code':
        return Icons.code;
      default:
        return Icons.lightbulb;
    }
  }
  String _getChallengeTypeText(String type) {
    switch (type.toLowerCase()) {
      case 'quiz':
        return 'Quiz Challenge';
      case 'code':
        return 'Coding Challenge';
      default:
        return 'Brain Challenge';
    }
  }
  Widget _buildActionButton(BuildContext context, WidgetRef ref) {
    final topic = mounted ? _topicController.text.trim() : "";
    final buttonHeight = 52.0;
    return SizedBox(
      height: buttonHeight,
      child: ElevatedButton.icon(
        onPressed: (topic.isEmpty || _isGeneratingQuiz)
            ? null
            : () async {
                setState(() => _isGeneratingQuiz = true);
                try {
                  final prefsAsync = ref.read(userPreferencesProvider.future);
                  final prefsData = await prefsAsync;
                  const defaultNumQuestions = 5;
                  const defaultTimePerQuestion = 60;
                  const defaultDifficulty = 'Medium';
                  const defaultTimedMode = false;
                  const defaultAllowedTypes = ['quiz'];
                  final quizData = await GroqService.prepareQuizData(
                    topic: topic,
                    questionCount:
                        prefsData?['default_num_questions'] as int? ??
                            defaultNumQuestions,
                    timePerQuestion:
                        prefsData?['default_time_per_question_sec'] as int? ??
                            defaultTimePerQuestion,
                    difficulty: prefsData?['default_difficulty'] as String? ??
                        defaultDifficulty,
                    timedMode: prefsData?['timed_mode_enabled'] as bool? ??
                        defaultTimedMode,
                    includeMcqs: (List<String>.from(
                            prefsData?['allowed_challenge_types']
                                    as List<dynamic>? ??
                                defaultAllowedTypes))
                        .contains('quiz'),
                    includeCodeChallenges: (List<String>.from(
                            prefsData?['allowed_challenge_types']
                                    as List<dynamic>? ??
                                defaultAllowedTypes))
                        .contains('code'),
                    includeInput: (List<String>.from(
                            prefsData?['allowed_challenge_types']
                                    as List<dynamic>? ??
                                defaultAllowedTypes))
                        .contains('input'),
                    includeFillBlank: (List<String>.from(
                            prefsData?['allowed_challenge_types']
                                    as List<dynamic>? ??
                                defaultAllowedTypes))
                        .contains('fill_blank'),
                    ref: ref,
                    totalTimeLimit: null,
                  );
                  final String routeKey = quizData['routeKey'];
                  final Map<String, dynamic> extraData = quizData['extraData'];
                  if (mounted) {
                    setState(() => _isGeneratingQuiz = false);
                    context.pushReplacement(
                      '/challenge/$routeKey/_loaded',
                      extra: extraData,
                    );
                  }
                } catch (e, stackTrace) {
                  debugPrint(
                      "[DashboardScreen] Error generating quiz: $e\n$stackTrace");
                  if (mounted) {
                    setState(() => _isGeneratingQuiz = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to start challenge: $e')),
                    );
                  }
                }
              },
        icon: _isGeneratingQuiz
            ? Container(
                width: 20,
                height: 20,
                padding: const EdgeInsets.all(2.0),
                child: const CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.play_arrow),
        label: const Text('Start'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 5,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, __) => Container(
                  width: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 3,
                itemBuilder: (_, __) => Container(
                  width: 250,
                  margin: const EdgeInsets.only(right: 16, bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 3,
                itemBuilder: (_, __) => Container(
                  width: 250,
                  margin: const EdgeInsets.only(right: 16, bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
class _Shimmer extends StatelessWidget {
  final Widget child;
  const _Shimmer({required this.child, Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: child,
    );
  }
}