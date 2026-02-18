import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/learning_path_providers.dart';

class CompletedPathsScreen extends ConsumerWidget {
  const CompletedPathsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Completed Learning Paths')),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Not logged in'));
          }
          final userId = user['_id']?.toString() ?? user['id']?.toString();
          if (userId == null) {
            return const Center(child: Text('User ID not found'));
          }
          return ref.watch(completedPathsProvider(userId)).when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (paths) {
                  if (paths.isEmpty) {
                    return const Center(child: Text('No completed paths yet.'));
                  }
                  return ListView.separated(
                    itemCount: paths.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, i) {
                      final entry = Map<String, dynamic>.from(paths[i]);
                      final path = <String, dynamic>{
                        'name': entry['name'] ?? 'Unnamed Path',
                        'description': entry['description'] ?? '',
                      };
                      final completedAt = entry['completed_at'];
                      return ListTile(
                        title: Text(path['name'] ?? 'Unnamed Path'),
                        subtitle: Text(path['description'] ?? ''),
                        trailing: completedAt != null
                            ? Text(
                                'Completed: ${completedAt.toString().substring(0, 10)}')
                            : null,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CompletedPathDetailScreen(
                                path: path,
                                userPath: entry,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
        },
      ),
    );
  }
}

class CompletedPathDetailScreen extends StatelessWidget {
  final Map<String, dynamic> path;
  final Map<String, dynamic> userPath;
  const CompletedPathDetailScreen(
      {super.key, required this.path, required this.userPath});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(path['name'] ?? 'Path Details')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(path['description'] ?? '',
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 16),
            Text(
                'Completed on: ${userPath['completed_at']?.toString().substring(0, 10) ?? '-'}'),
            const SizedBox(height: 16),
            const Text('Challenges:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: Consumer(
                builder: (context, ref, _) {
                  final userPathId = userPath['user_path_id']?.toString() ??
                      userPath['id']?.toString() ??
                      '';
                  if (userPathId.isEmpty) {
                    return const Text('No path ID found.');
                  }
                  return ref.watch(userPathChallengesProvider(userPathId)).when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Center(child: Text('Error: $e')),
                        data: (challenges) {
                          if (challenges.isEmpty) {
                            return const Text(
                                'No challenges found for this path.');
                          }
                          return ListView.builder(
                            itemCount: challenges.length,
                            itemBuilder: (context, i) {
                              final c = challenges[i];
                              return ListTile(
                                title: Text(c['title'] ?? ''),
                                subtitle: Text(c['description'] ?? ''),
                                trailing: c['completed'] == true
                                    ? const Icon(Icons.check_circle,
                                        color: Colors.green)
                                    : const Icon(Icons.cancel,
                                        color: Colors.red),
                              );
                            },
                          );
                        },
                      );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
