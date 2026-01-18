import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neurobits/core/providers.dart' hide userPreferencesProvider;
import 'package:neurobits/services/supabase.dart';
import 'package:neurobits/services/badge_service.dart';
import '../widgets/badge_gallery.dart';
import 'package:neurobits/core/providers.dart'
    show userProvider, userPreferencesProvider;

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

void refreshProfileStats(WidgetRef ref) {
  ref.invalidate(userStatsProvider);
  ref.invalidate(userProvider);
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsyncValue = ref.watch(userProvider);
    final userStatsAsyncValue = ref.watch(userStatsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Settings'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ProfileOverviewTab(),
                _ProfileSettingsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileOverviewTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsyncValue = ref.watch(userProvider);
    final userStatsAsyncValue = ref.watch(userStatsProvider);
    return userAsyncValue.when(
      data: (user) {
        if (user == null) {
          return const Center(child: Text('Not logged in'));
        }
        return userStatsAsyncValue.when(
          data: (stats) {
            final points = user['points'] ?? 0;
            final level = user['level'] ?? 1;
            final xp = user['xp'] ?? 0;
            final currentStreak = user['current_streak'] ?? 0;
            final longestStreak = user['longest_streak'] ?? 0;
            final xpNeeded = stats['xp_needed'] ?? 100;
            final challengesAttempted = stats['challenges_attempted'] ?? 0;
            final challengesSolved = stats['challenges_solved'] ?? 0;
            final completedQuizzes = stats['completed_quizzes'] ?? 0;
            final averageAccuracy = stats['average_accuracy'] ?? 0.0;
            return SingleChildScrollView(
              child: Center(
                child: Card(
                  elevation: 4,
                  margin: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          child: Text(
                            user['email']?.substring(0, 1).toUpperCase() ?? '?',
                            style: const TextStyle(
                                fontSize: 30, color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          user['email'] ?? 'Unknown',
                          style: Theme.of(context).textTheme.titleLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.military_tech, color: Colors.amber[700]),
                            const SizedBox(width: 4),
                            Text('Level $level',
                                style: Theme.of(context).textTheme.bodyLarge),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _StreakInfoSection(stats: {
                          'current_streak': currentStreak,
                          'longest_streak': longestStreak,
                        }),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: xpNeeded > 0
                              ? (xp / xpNeeded).clamp(0.0, 1.0)
                              : 0,
                          minHeight: 10,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          xpNeeded > 0
                              ? '${xp.clamp(0, xpNeeded)} / $xpNeeded XP to next level'
                              : 'Max level reached',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 24),
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: BadgeService.getUserBadges(user['id']),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                            final badges = snapshot.data!;
                            if (badges.isEmpty) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12.0),
                                child: Text('No badges earned yet.',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium),
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text('Earned Badges',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                const SizedBox(height: 8),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 14,
                                  runSpacing: 10,
                                  children: badges
                                      .map((badge) => Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                badge['badge']['icon'] ?? '🏅',
                                                style: const TextStyle(
                                                    fontSize: 28),
                                              ),
                                              Text(
                                                badge['badge']['name'] ?? '',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall,
                                              ),
                                            ],
                                          ))
                                      .toList(),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => BadgeGalleryScreen(
                                            userId: user['id']),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.emoji_events),
                                  label: const Text('See All Badges'),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _ProfileStatCard(
                                icon: Icons.stars,
                                label: 'Points',
                                value: points,
                                color: Colors.amber,
                              ),
                              _ProfileStatCard(
                                icon: Icons.check_circle,
                                label: 'Solved',
                                value: challengesSolved,
                                color: Colors.green,
                              ),
                              _ProfileStatCard(
                                icon: Icons.quiz,
                                label: 'Quizzes',
                                value: completedQuizzes,
                                color: Colors.blue,
                              ),
                              _ProfileStatCard(
                                icon: Icons.flag,
                                label: 'Attempts',
                                value: challengesAttempted,
                                color: Colors.redAccent,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error loading stats: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Future.microtask(() {
                      ref.refresh(userStatsProvider);
                    });
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error loading user: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Future.microtask(() {
                  ref.refresh(userProvider);
                });
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSettingsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StreakGoalSection(),
        const SizedBox(height: 16),
        AdaptiveDifficultySection(),
        const SizedBox(height: 16),
        NotificationSettingsSection(),
        const SizedBox(height: 16),
        QuizSettingsSection(),
      ],
    );
  }
}

class StreakGoalSection extends ConsumerWidget {
  const StreakGoalSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsyncValue = ref.watch(userProvider);
    final streakOptions = [1, 3, 5, 7];
    return userAsyncValue.when(
      data: (user) {
        if (user == null) {
          return const Center(child: Text('Not logged in'));
        }
        int currentGoal = user['streak_goal'] ?? 1;
        return Card(
          child: ListTile(
            title: Text('Streak Goal'),
            subtitle: DropdownButton<int>(
              value: currentGoal,
              items: streakOptions
                  .map((goal) => DropdownMenuItem(
                        value: goal,
                        child: Text('$goal days'),
                      ))
                  .toList(),
              onChanged: (value) async {
                if (value != null) {
                   await SupabaseService.client
                       .from('users')
                       .update({'streak_goal': value}).eq('id', user['id']);
                   ref.refresh(userProvider);
                   ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(
                         content: Text('Streak goal updated to $value days!')),
                   );
                    // Refresh user stats and data
                    refreshProfileStats(ref);

                 }
               },
             ),

          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error loading user: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Future.microtask(() {
                  ref.refresh(userProvider);
                });
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class AdaptiveDifficultySection extends ConsumerWidget {
  const AdaptiveDifficultySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsyncValue = ref.watch(userProvider);
    return userAsyncValue.when(
      data: (user) {
        if (user == null) {
          return const Center(child: Text('Not logged in'));
        }
        bool adaptiveEnabled = user['adaptive_difficulty'] ?? false;
        return Card(
          child: SwitchListTile(
            title: Text('Adaptive Difficulty'),
            subtitle: Text('Enable or adjust adaptive quiz difficulty.'),
            value: adaptiveEnabled,
            onChanged: (value) async {
               await SupabaseService.client
                   .from('users')
                   .update({'adaptive_difficulty': value}).eq('id', user['id']);
               ref.refresh(userProvider);
               ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(
                     content: Text(
                         'Adaptive difficulty ${value ? 'enabled' : 'disabled'}!')),
               );
               refreshProfileStats(ref);
             },
           ),



        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error loading user: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Future.microtask(() {
                  ref.refresh(userProvider);
                });
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationSettingsSection extends ConsumerWidget {
  const NotificationSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsyncValue = ref.watch(userProvider);
    return userAsyncValue.when(
      data: (user) {
        if (user == null) {
          return const Center(child: Text('Not logged in'));
        }
        bool remindersEnabled = user['reminders_enabled'] ?? false;
        bool streaksEnabled = user['streak_notifications'] ?? false;
        return Card(
          child: Column(
            children: [
              SwitchListTile(
                title: Text('Reminders'),
                subtitle: Text('Enable daily quiz reminders.'),
                value: remindersEnabled,
                onChanged: (value) async {
                   await SupabaseService.client.from('users').update(
                       {'streak_notifications': value}).eq('id', user['id']);
                   ref.refresh(userProvider);
                   ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(
                         content: Text(
                             'Streak notifications ${value ? 'enabled' : 'disabled'}!')),
                   );
                   refreshProfileStats(ref);
                 },
               ),



              SwitchListTile(
                title: Text('Streak Notifications'),
                subtitle: Text('Enable notifications for streak milestones.'),
                value: streaksEnabled,
                onChanged: (value) async {
                   await SupabaseService.client.from('users').update(
                       {'streak_notifications': value}).eq('id', user['id']);
                   ref.refresh(userProvider);
                   ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(
                         content: Text(
                             'Streak notifications ${value ? 'enabled' : 'disabled'}!')),
                   );
                    // Refresh user stats and data
                    refreshProfileStats(ref);

                 },
               ),

            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error loading user: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Future.microtask(() {
                  ref.refresh(userProvider);
                });
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class QuizSettingsSection extends ConsumerWidget {
  QuizSettingsSection({super.key});
  final List<int> questionCountOptions = [3, 5, 10, 15, 20, 25, 50];
  final List<String> difficultyOptions = ['Easy', 'Medium', 'Hard'];
  final List<int> timePerQuestionOptions = [
    10,
    15,
    20,
    30,
    45,
    60,
    90,
    120,
    180,
    240
  ];
  final String quizType = 'quiz';
  final String codeType = 'code';
  final String inputType = 'input';
  final String fillBlankType = 'fill_blank';
  Future<void> _savePreference(WidgetRef ref, String key, dynamic value) async {
    final user = ref.read(userProvider).value;
    if (user == null) return;
    try {
      await SupabaseService.client.from('user_quiz_preferences').upsert({
        'user_id': user['id'],
        key: value,
      }, onConflict: 'user_id');
      ref.refresh(userPreferencesProvider);
    } catch (e) {
      debugPrint("Error saving preference '$key': $e");
    }
  }

  Future<void> _saveAllowedChallengeTypes(
      WidgetRef ref, List<String> types) async {
    await _savePreference(ref, 'allowed_challenge_types', types);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferencesAsync = ref.watch(userPreferencesProvider);
    return preferencesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) =>
          Center(child: Text('Error loading preferences: $err')),
      data: (prefsData) {
        final int currentQuestionCount =
            prefsData?['default_num_questions'] as int? ?? 5;
        final int currentTimePerQuestion =
            prefsData?['default_time_per_question_sec'] as int? ?? 60;
        final String currentDifficulty =
            prefsData?['default_difficulty'] as String? ?? 'Medium';
        final bool currentTimedMode =
            prefsData?['timed_mode_enabled'] as bool? ?? false;
        final List<String> currentAllowedTypes = List<String>.from(
            prefsData?['allowed_challenge_types'] as List<dynamic>? ??
                ['quiz']);
        return Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quiz Settings',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                Text('Default Quiz Options',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                    'These settings are used when generating quick quizzes from topics.',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                      labelText: 'Default Number of Questions',
                      border: OutlineInputBorder()),
                  value: questionCountOptions.contains(currentQuestionCount)
                      ? currentQuestionCount
                      : questionCountOptions.first,
                  items: questionCountOptions
                      .map((cnt) => DropdownMenuItem(
                          value: cnt, child: Text('$cnt questions')))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _savePreference(ref, 'default_num_questions', value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                      labelText: 'Default Time per Question',
                      border: OutlineInputBorder()),
                  value: timePerQuestionOptions.contains(currentTimePerQuestion)
                      ? currentTimePerQuestion
                      : timePerQuestionOptions[5],
                  items: timePerQuestionOptions
                      .map((t) =>
                          DropdownMenuItem(value: t, child: Text('$t seconds')))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _savePreference(
                          ref, 'default_time_per_question_sec', value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                      labelText: 'Default Difficulty',
                      border: OutlineInputBorder()),
                  value: difficultyOptions.contains(currentDifficulty)
                      ? currentDifficulty
                      : difficultyOptions[1],
                  items: difficultyOptions
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _savePreference(ref, 'default_difficulty', value);
                    }
                  },
                ),
                const SizedBox(height: 20),
                Text('Default Question Types Included:',
                    style: Theme.of(context).textTheme.titleSmall),
                CheckboxListTile(
                    title: const Text('Multiple Choice (MCQs)'),
                    value: currentAllowedTypes.contains(quizType),
                    onChanged: (value) {
                      if (value == null) return;
                      final updatedTypes =
                          List<String>.from(currentAllowedTypes);
                      if (value) {
                        updatedTypes.add(quizType);
                      } else {
                        updatedTypes.remove(quizType);
                      }
                      _saveAllowedChallengeTypes(
                          ref, updatedTypes.toSet().toList());
                    }),
                CheckboxListTile(
                    title: const Text('Code Challenges'),
                    value: currentAllowedTypes.contains(codeType),
                    onChanged: (value) {
                      if (value == null) return;
                      final updatedTypes =
                          List<String>.from(currentAllowedTypes);
                      if (value) {
                        updatedTypes.add(codeType);
                      } else {
                        updatedTypes.remove(codeType);
                      }
                      _saveAllowedChallengeTypes(
                          ref, updatedTypes.toSet().toList());
                    }),
                CheckboxListTile(
                    title: const Text('Input Questions'),
                    value: currentAllowedTypes.contains(inputType),
                    onChanged: (value) {
                      if (value == null) return;
                      final updatedTypes =
                          List<String>.from(currentAllowedTypes);
                      if (value) {
                        updatedTypes.add(inputType);
                      } else {
                        updatedTypes.remove(inputType);
                      }
                      _saveAllowedChallengeTypes(
                          ref, updatedTypes.toSet().toList());
                    }),
                CheckboxListTile(
                    title: const Text('Fill-in-the-Blank'),
                    value: currentAllowedTypes.contains(fillBlankType),
                    onChanged: (value) {
                      if (value == null) return;
                      final updatedTypes =
                          List<String>.from(currentAllowedTypes);
                      if (value) {
                        updatedTypes.add(fillBlankType);
                      } else {
                        updatedTypes.remove(fillBlankType);
                      }
                      _saveAllowedChallengeTypes(
                          ref, updatedTypes.toSet().toList());
                    }),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Default Timed Mode (per question)'),
                  subtitle: const Text('Enable question timers by default'),
                  value: currentTimedMode,
                  onChanged: (value) {
                    _savePreference(ref, 'timed_mode_enabled', value);
                  },
                  secondary: const Icon(Icons.timer_outlined),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProfileStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final dynamic value;
  final Color color;
  const _ProfileStatCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text('$value',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}

class _StreakInfoSection extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _StreakInfoSection({required this.stats});
  @override
  Widget build(BuildContext context) {
    final streak = stats['current_streak'] ?? 0;
    final longest = stats['longest_streak'] ?? 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _StreakBadge(
          icon: Icons.local_fire_department,
          label: 'Current Streak',
          value: streak,
          color: Colors.deepOrange,
        ),
        _StreakBadge(
          icon: Icons.emoji_events,
          label: 'Longest Streak',
          value: longest,
          color: Colors.amber[800]!,
        ),
      ],
    );
  }
}

class _StreakBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final dynamic value;
  final Color color;
  const _StreakBadge(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});
  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withOpacity(0.09),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 4),
            Text('$value',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey[700])),
          ],
        ),
      ),
    );
  }
}
