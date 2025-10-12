import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neurobits/core/providers.dart';
import 'package:neurobits/services/user_analytics_service.dart';
import 'package:go_router/go_router.dart';
import '../../services/supabase.dart';
import '../onboarding/learning_path_onboarding_screen.dart';
import 'learning_path_banner.dart';
import 'path_topic_progress_bar.dart';
import 'learning_path_challenge_card.dart';
import 'personalized_topic_card.dart';
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
  final bool _isGeneratingQuiz = false;
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
    final personalizedRecommendationsAsync =
        ref.watch(personalizedRecommendationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Neurobits'),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
        data: (user) => _buildContent(context, ref, user, userStatsAsync,
            trendingTopicsAsync, personalizedRecommendationsAsync),
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
      AsyncValue<List<Map<String, dynamic>>> trendingTopicsAsync,
      AsyncValue<List<PersonalizedRecommendation>>
          personalizedRecommendationsAsync) {
    if (user == null) return const SizedBox.shrink();
    final userPath = ref.watch(userPathProvider);
    final challenges = ref.watch(challengesProvider);
    final trendingChallenges = ref.watch(trendingChallengesProvider);
    final mostSolvedChallenges = ref.watch(mostSolvedChallengesProvider);
    final userPoints = user['points'] ?? 0;
    List<dynamic> filteredChallenges = [];
    filteredChallenges = challenges.value ?? [];

    final pathChallengesAsync =
        userPath != null && userPath['user_path_id'] != null
            ? ref.watch(userPathChallengesProvider(userPath['user_path_id']))
            : null;

    List<Map<String, dynamic>> pathChallenges = [];
    int currentStep = 1;
    int totalSteps = 1;
    String? currentTopicName;
    String? currentTopicDescription;
    int currentChallengeIndex = 0;

    if (userPath != null &&
        userPath['user_path_id'] != null &&
        pathChallengesAsync != null) {
      pathChallenges = pathChallengesAsync.when(
        data: (data) => data,
        loading: () => [],
        error: (_, __) => [],
      );

      totalSteps = pathChallenges.length;
      currentStep = userPath['current_step'] ?? 1;

      if (pathChallenges.isNotEmpty) {
        currentChallengeIndex =
            (currentStep - 1).clamp(0, pathChallenges.length - 1);
      }

      if (pathChallenges.isNotEmpty &&
          currentChallengeIndex < pathChallenges.length) {
        final currentChallenge = pathChallenges[currentChallengeIndex];
        currentTopicName = currentChallenge['topic'] as String?;
        currentTopicDescription = currentChallenge['description'] as String?;
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
    return RefreshIndicator(
        onRefresh: _refreshData,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 16),
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF1a1a2e),
                        Color(0xFF16213e),
                        Color(0xFF0f4c75),
                        Color(0xFF3282b8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: [0.0, 0.3, 0.6, 1.0],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3282b8).withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: const Color(0xFF0f4c75).withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Text('🪄', style: TextStyle(fontSize: 32)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Yer a Wizard, ${user?['email']?.toString().split('@')[0].toUpperCase() ?? 'Harry'}!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Keep learning and unlock your magical potential ✨',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
                                .where((challenge) =>
                                    challenge['completed'] == true)
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
                                builder: (_) =>
                                    const LearningPathRoadmapScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
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
                          foregroundColor:
                              Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  if (pathChallenges.isNotEmpty &&
                      currentChallengeIndex < pathChallenges.length)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: LearningPathChallengeCard(
                        challenge: pathChallenges[currentChallengeIndex],
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
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          child: Text(
                            user['email']
                                .toString()
                                .substring(0, 1)
                                .toUpperCase(),
                            style: const TextStyle(
                                fontSize: 24, color: Colors.white),
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
                Container(
                  width: double.infinity,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      if (userPath == null ||
                          userPath['user_path_id'] == null) ...[
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
                      ] else ...[
                        Text('Suggested Topics:',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: pathChallenges
                              .skip(currentChallengeIndex)
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: personalizedRecommendationsAsync.when(
                    data: (recommendations) {
                      if (recommendations.isEmpty) {
                        return _buildFallbackTopics(
                            context, trendingTopicsAsync);
                      }
                      return _buildPersonalizedRecommendations(
                          context, recommendations);
                    },
                    loading: () => _buildRecommendationsSkeleton(),
                    error: (_, __) =>
                        _buildFallbackTopics(context, trendingTopicsAsync),
                  ),
                ),
              ],
            ),
          ),
        ));
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
        return 'Challenge';
    }
  }

  Widget _buildPersonalizedRecommendations(
      BuildContext context, List<PersonalizedRecommendation> recommendations) {
    final mightLove = recommendations
        .where((r) => r.category == 'might_love')
        .take(6)
        .toList();
    final touchAgain = recommendations
        .where((r) => r.category == 'touch_again')
        .take(6)
        .toList();

    final otherRecommendations = recommendations
        .where((r) => r.category != 'might_love' && r.category != 'touch_again')
        .take(6)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mightLove.isNotEmpty || otherRecommendations.isNotEmpty) ...[
          Row(
            children: [
              Icon(Icons.favorite_rounded,
                  size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'We think you might love these...',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: mightLove.isNotEmpty
                  ? mightLove.length
                  : otherRecommendations.length,
              itemBuilder: (context, index) {
                final list =
                    mightLove.isNotEmpty ? mightLove : otherRecommendations;
                return PersonalizedTopicCard(
                  recommendation: list[index],
                );
              },
            ),
          ),
          const SizedBox(height: 32),
        ],
        if (touchAgain.isNotEmpty) ...[
          Row(
            children: [
              Icon(Icons.refresh_rounded,
                  size: 20, color: Theme.of(context).colorScheme.secondary),
              const SizedBox(width: 8),
              Text(
                'Want to touch on these topics again?',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: touchAgain.length,
              itemBuilder: (context, index) {
                return PersonalizedTopicCard(
                  recommendation: touchAgain[index],
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFallbackTopics(BuildContext context,
      AsyncValue<List<Map<String, dynamic>>> trendingTopicsAsync) {
    return trendingTopicsAsync.when(
      data: (topics) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Popular Topics',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  )),
          const SizedBox(height: 16),
          if (topics.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: topics.take(5).map((topicMap) {
                final topic = topicMap['topic']?.toString() ?? '';
                return ActionChip(
                  label: Text(topic),
                  onPressed: () {
                    _topicController.text = topic;
                  },
                );
              }).toList(),
            )
          else
            Text('No topics available yet.',
                style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      loading: () => _buildRecommendationsSkeleton(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildRecommendationsSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 200,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 3,
            itemBuilder: (_, __) => Container(
              width: 280,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'might_love':
        return Icons.favorite_rounded;
      case 'touch_again':
        return Icons.refresh_rounded;
      default:
        return Icons.star_rounded;
    }
  }

  Widget _buildActionButton(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: _topicController.text.isEmpty
          ? null
          : () {
              final topic = _topicController.text.trim();
              if (topic.isNotEmpty) {
                context.push('/topic/$topic');
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

class _Shimmer extends StatelessWidget {
  final Widget child;
  const _Shimmer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: child,
    );
  }
}
