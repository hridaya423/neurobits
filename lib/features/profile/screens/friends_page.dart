import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neurobits/core/providers.dart';
import 'package:neurobits/services/supabase.dart';
import 'package:neurobits/core/learning_path_providers.dart';
import 'challenge_quiz_screen.dart';
class FriendsPage extends ConsumerStatefulWidget {
  final bool showScaffold;
  const FriendsPage({Key? key, this.showScaffold = true}) : super(key: key);
  @override
  ConsumerState<FriendsPage> createState() => _FriendsPageState();
}
class _FriendsPageState extends ConsumerState<FriendsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<Map<String, dynamic>>> _friendsFuture;
  late Future<List<Map<String, dynamic>>> _requestsFuture;
  String? _userId;
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = ref.read(userProvider).value;
      if (user != null && user['id'] != null) {
        setState(() {
          _userId = user['id'];
          _friendsFuture = SupabaseService.getFriends(_userId!);
          _requestsFuture = SupabaseService.getFriendRequests(_userId!);
        });
      }
    });
  }
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider).value;
    if (_userId == null || user == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      appBar: widget.showScaffold
          ? AppBar(title: const Text('Friends'))
          : null,
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Friends'),
              Tab(text: 'Requests'),
              Tab(text: 'Search'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _friendsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final friends = snapshot.data ?? [];
                    if (friends.isEmpty) {
                      return const Center(child: Text('No friends yet.'));
                    }
                    return ListView.builder(
                      itemCount: friends.length,
                      itemBuilder: (context, i) {
                        final f = friends[i];
                        return ListTile(
                          leading: f['avatar_url'] != null
                              ? CircleAvatar(backgroundImage: NetworkImage(f['avatar_url']))
                              : const CircleAvatar(child: Icon(Icons.person)),
                          title: Text(f['username'] ?? ''),
                          subtitle: Text(f['email'] ?? ''),
                        );
                      },
                    );
                  },
                ),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _requestsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final requests = snapshot.data ?? [];
                    if (requests.isEmpty) {
                      return const Center(child: Text('No friend requests.'));
                    }
                    return ListView.builder(
                      itemCount: requests.length,
                      itemBuilder: (context, i) {
                        final r = requests[i];
                        return ListTile(
                          leading: r['avatar_url'] != null
                              ? CircleAvatar(backgroundImage: NetworkImage(r['avatar_url']))
                              : const CircleAvatar(child: Icon(Icons.person)),
                          title: Text(r['username'] ?? ''),
                          subtitle: Text(r['email'] ?? ''),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check, color: Colors.green),
                                onPressed: () {
                                  SupabaseService.respondToFriendRequest(
                                    userId: _userId!,
                                    friendId: r['id'],
                                    action: 'accept',
                                  );
                                  setState(() {
                                    _requestsFuture = SupabaseService.getFriendRequests(_userId!);
                                    _friendsFuture = SupabaseService.getFriends(_userId!);
                                  });
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: () {
                                  SupabaseService.respondToFriendRequest(
                                    userId: _userId!,
                                    friendId: r['id'],
                                    action: 'reject',
                                  );
                                  setState(() {
                                    _requestsFuture = SupabaseService.getFriendRequests(_userId!);
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
                Center(child: Text('Search for friends...')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
final friendsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(userProvider).value;
  if (user == null) return [];
  return await SupabaseService.getFriends(user?['id']);
});
final onlineFriendsProvider = FutureProvider<List<String>>((ref) async {
  final user = ref.watch(userProvider).value;
  if (user == null) return [];
  final online = await SupabaseService.getOnlineFriends(user?['id']);
  return online.map((f) => f['user_id'] as String).toList();
});
final friendRequestsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(userProvider).value;
  if (user == null) return [];
  final incoming = await SupabaseService.client.from('friends')
    .select('id, user_id, friend_id, status, created_at, users:user_id(id,username,email), friends:friend_id(id,username,email)')
    .eq('friend_id', user?['id'])
    .eq('status', 'pending');
  final outgoing = await SupabaseService.client.from('friends')
    .select('id, user_id, friend_id, status, created_at, users:user_id(id,username,email), friends:friend_id(id,username,email)')
    .eq('user_id', user?['id'])
    .eq('status', 'pending');
  return [
    ...incoming.map((req) => {...req, 'direction': 'incoming'}),
    ...outgoing.map((req) => {...req, 'direction': 'outgoing'}),
  ];
});
Stream<List<Map<String, dynamic>>> getChallengeStream(user) {
  if (user == null) return const Stream.empty();
  final pendingStream = SupabaseService.client
      .from('friend_challenges')
      .stream(primaryKey: ['id'])
      .eq('recipient_id', user?['id'])
      .eq('status', 'pending');
  final activeStream = SupabaseService.client
      .from('friend_challenges')
      .stream(primaryKey: ['id'])
      .eq('recipient_id', user?['id'])
      .eq('status', 'active');
  return pendingStream.asyncExpand((pending) =>
      activeStream.map((active) => [...pending, ...active]));
}
final incomingChallengeStreamProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(userProvider).value;
  return getChallengeStream(user);
});
class _FriendsListTab extends ConsumerWidget {
  const _FriendsListTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(friendsProvider);
    final onlineAsync = ref.watch(onlineFriendsProvider);
    final user = ref.watch(userProvider).value;
    final ValueNotifier<Map<String, dynamic>?> quizSelection = ValueNotifier(null);
    return Column(
      children: [
        ValueListenableBuilder<Map<String, dynamic>?>(
          valueListenable: quizSelection,
          builder: (context, selectedQuiz, _) {
            return selectedQuiz == null ? const SizedBox.shrink() : Card(
              margin: const EdgeInsets.all(12),
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(child: Text('Selected quiz: ${selectedQuiz['topic']} (${selectedQuiz['numQuestions']} questions, ${selectedQuiz['difficulty']})')),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => quizSelection.value = null,
                    )
                  ],
                ),
              ),
            );
          },
        ),
        ElevatedButton(
          onPressed: () async {
            final quiz = await showDialog<Map<String, dynamic>>(
              context: context,
              builder: (context) => _QuizSelectionDialog(),
            );
            if (quiz != null) quizSelection.value = quiz;
          },
          child: const Text('Select Quiz for Challenge'),
        ),
        Expanded(
          child: friendsAsync.when(
            data: (friends) {
              return onlineAsync.when(
                data: (onlineIds) {
                  if (friends.isEmpty) {
                    return const Center(child: Text('No friends yet. Add some!'));
                  }
                  return ListView.separated(
                    itemCount: friends.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final friend = friends[i];
                      final isOnline = onlineIds.contains(friend['id']);
                      return ListTile(
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              child: Text(friend['username']?.substring(0, 1).toUpperCase() ?? '?'),
                            ),
                            if (isOnline)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Text(friend['username'] ?? friend['email'] ?? 'Unknown'),
                        subtitle: isOnline ? const Text('Online', style: TextStyle(color: Colors.green)) : null,
                        trailing: ElevatedButton(
                          onPressed: isOnline && quizSelection.value != null
                              ? () async {
                                  final challenge = await SupabaseService.createFriendChallenge(
                                    initiatorId: user?['id'],
                                    recipientId: friend['id'],
                                    quizData: quizSelection.value!,
                                  );
                                  if (challenge != null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Challenge sent!')),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Failed to send challenge.')),
                                    );
                                  }
                                }
                              : null,
                          child: const Text('Challenge'),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('Error loading online friends: $e')),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error loading friends: $e')),
          ),
        ),
      ],
    );
  }
}
class _QuizSelectionDialog extends StatefulWidget {
  @override
  State<_QuizSelectionDialog> createState() => _QuizSelectionDialogState();
}
class _QuizSelectionDialogState extends State<_QuizSelectionDialog> {
  String _topic = 'General Knowledge';
  int _numQuestions = 5;
  String _difficulty = 'medium';
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Quiz'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: _topic,
            items: const [
              DropdownMenuItem(value: 'General Knowledge', child: Text('General Knowledge')),
              DropdownMenuItem(value: 'Science', child: Text('Science')),
              DropdownMenuItem(value: 'History', child: Text('History')),
            ],
            onChanged: (v) => setState(() => _topic = v!),
            decoration: const InputDecoration(labelText: 'Topic'),
          ),
          DropdownButtonFormField<int>(
            value: _numQuestions,
            items: const [
              DropdownMenuItem(value: 5, child: Text('5')),
              DropdownMenuItem(value: 10, child: Text('10')),
              DropdownMenuItem(value: 15, child: Text('15')),
            ],
            onChanged: (v) => setState(() => _numQuestions = v!),
            decoration: const InputDecoration(labelText: 'Questions'),
          ),
          DropdownButtonFormField<String>(
            value: _difficulty,
            items: const [
              DropdownMenuItem(value: 'easy', child: Text('Easy')),
              DropdownMenuItem(value: 'medium', child: Text('Medium')),
              DropdownMenuItem(value: 'hard', child: Text('Hard')),
            ],
            onChanged: (v) => setState(() => _difficulty = v!),
            decoration: const InputDecoration(labelText: 'Difficulty'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop({
              'topic': _topic,
              'numQuestions': _numQuestions,
              'difficulty': _difficulty,
            });
          },
          child: const Text('Select'),
        ),
      ],
    );
  }
}
class ChallengeInviteBanner extends ConsumerWidget {
  const ChallengeInviteBanner({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challengesAsync = ref.watch(incomingChallengeStreamProvider);
    final user = ref.watch(userProvider).value;
    return challengesAsync.when(
      data: (challenges) {
        if (challenges.isEmpty) return const SizedBox.shrink();
        final challenge = challenges.first;
        final fromUserId = challenge['initiator_id'];
        return FutureBuilder<Map<String, dynamic>?>(
          future: SupabaseService.getUserById(fromUserId),
          builder: (context, snapshot) {
            final fromUsername = snapshot.data?['username'] ?? fromUserId;
            return Card(
              color: Colors.amber[100],
              margin: const EdgeInsets.all(12),
              child: ListTile(
                leading: const Icon(Icons.sports_kabaddi),
                title: Text('Challenge from: $fromUsername'),
                subtitle: Text('Quiz: ${challenge['quiz_data']['topic']}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () async {
                        await SupabaseService.acceptFriendChallenge(challenge['id']);
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => ChallengeQuizScreen(
                            challenge: challenge,
                            quizData: challenge['quiz_data'],
                            userId: user?['id'],
                          ),
                        ));
                      },
                      child: const Text('Accept'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await SupabaseService.declineFriendChallenge(challenge['id']);
                      },
                      child: const Text('Decline'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
    );
  }
}
class _FriendRequestsTab extends ConsumerWidget {
  const _FriendRequestsTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(friendRequestsProvider);
    final user = ref.watch(userProvider).value;
    return requestsAsync.when(
      data: (requests) {
        if (requests.isEmpty) {
          return const Center(child: Text('No pending requests.'));
        }
        return ListView.separated(
          itemCount: requests.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final req = requests[i];
            final direction = req['direction'];
            final otherUser = direction == 'incoming' ? req['users'] : req['friends'];
            return ListTile(
              leading: CircleAvatar(
                child: Text(otherUser['username']?.substring(0, 1).toUpperCase() ?? '?'),
              ),
              title: Text(otherUser['username'] ?? otherUser['email'] ?? 'Unknown'),
              subtitle: Text(direction == 'incoming' ? 'Sent you a request' : 'Request sent'),
              trailing: direction == 'incoming'
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () async {
                            await SupabaseService.respondToFriendRequest(
                              userId: user?['id'],
                              friendId: otherUser['id'],
                              action: 'accept',
                            );
                            ref.refresh(friendRequestsProvider);
                            ref.refresh(friendsProvider);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () async {
                            await SupabaseService.respondToFriendRequest(
                              userId: user?['id'],
                              friendId: otherUser['id'],
                              action: 'decline',
                            );
                            ref.refresh(friendRequestsProvider);
                          },
                        ),
                      ],
                    )
                    : IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.grey),
                      onPressed: () async {
                        await SupabaseService.removeFriend(
                          userId: user?['id'],
                          friendId: otherUser['id'],
                        );
                        ref.refresh(friendRequestsProvider);
                      },
                    ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error loading requests: $e')),
    );
  }
}
class _AddFriendTab extends ConsumerStatefulWidget {
  const _AddFriendTab();
  @override
  ConsumerState<_AddFriendTab> createState() => _AddFriendTabState();
}
class _AddFriendTabState extends ConsumerState<_AddFriendTab> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (query.isEmpty) {
        setState(() => _results = []);
        return;
      }
      setState(() => _loading = true);
      final user = ref.read(userProvider).value;
      final results = await SupabaseService.searchUsersByUsernameOrEmail(query, excludeUserId: user?['id']);
      setState(() {
        _results = results;
        _loading = false;
      });
    });
  }
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider).value;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: const InputDecoration(
              labelText: 'Search by username or email',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 16),
          if (_loading) const CircularProgressIndicator(),
          if (!_loading && _results.isEmpty && _searchController.text.isNotEmpty)
            const Text('No users found.'),
          if (!_loading)
            Expanded(
              child: ListView.separated(
                itemCount: _results.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final res = _results[i];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(res['username']?.substring(0, 1).toUpperCase() ?? '?'),
                    ),
                    title: Text(res['username'] ?? res['email'] ?? 'Unknown'),
                    trailing: ElevatedButton(
                      onPressed: () async {
                        await SupabaseService.sendFriendRequest(
                          userId: user?['id'],
                          friendId: res['id'],
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Friend request sent!')),
                        );
                      },
                      child: const Text('Add'),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}