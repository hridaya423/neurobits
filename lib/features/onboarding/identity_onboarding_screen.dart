import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neurobits/core/providers.dart';
import 'package:neurobits/core/widgets/facehash_avatar.dart';

class IdentityOnboardingScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;
  const IdentityOnboardingScreen({super.key, required this.onComplete});

  @override
  ConsumerState<IdentityOnboardingScreen> createState() =>
      _IdentityOnboardingScreenState();
}

class _IdentityOnboardingScreenState
    extends ConsumerState<IdentityOnboardingScreen> {
  late final TextEditingController _usernameController;
  bool _isSaving = false;
  String? _selectedAvatarSeed;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  List<String> _usernameSuggestions(String base, int hash) {
    final normalized = base.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final root = normalized.isNotEmpty ? normalized : 'learner';
    final adjectives = [
      'swift',
      'bright',
      'curious',
      'bold',
      'neat',
      'sharp',
      'steady',
      'lucky',
    ];
    final nouns = [
      'owl',
      'fox',
      'sage',
      'nova',
      'spark',
      'orbit',
      'flare',
      'wave',
    ];

    final picks = <String>{};
    final seed = hash % 1000;
    picks.add(root);
    picks.add('$root${(seed % 90) + 10}');
    picks.add('${adjectives[seed % adjectives.length]}$root');
    picks.add('$root${nouns[seed % nouns.length]}'.toLowerCase());
    picks.add(
        '${adjectives[(seed + 3) % adjectives.length]}${nouns[(seed + 5) % nouns.length]}');
    picks.add('${root}_${(seed % 900) + 100}');

    return picks.map((s) => s.toLowerCase()).toList().take(5).toList();
  }

  List<String> _avatarSeeds(String base, int hash) {
    final root = base.isNotEmpty ? base : 'learner';
    final n1 = (hash % 9) + 1;
    final n2 = ((hash ~/ 7) % 9) + 1;
    final n3 = ((hash ~/ 13) % 9) + 1;
    final candidates = <String>[
      root,
      '${root}_$n1',
      '$root$n2',
      '$n3$root',
      '${root}x',
      '${root}_alt',
      '$root${n1 + 10}',
      '$root${n2 + 20}',
      '$root${n3 + 30}',
      '${root}_plus',
      '${root}_star',
    ];

    final filtered = <String>[];
    for (final seed in candidates) {
      final data =
          computeFacehash(seed, colorsLength: kCossistantColors.length);
      if (_isPreferredFaceType(data.faceType)) {
        filtered.add(seed);
      }
      if (filtered.length >= 6) break;
    }

    if (filtered.isNotEmpty) return filtered;
    return candidates.take(6).toList();
  }

  bool _isPreferredFaceType(FacehashFaceType type) {
    return type == FacehashFaceType.round || type == FacehashFaceType.curved;
  }

  Future<void> _saveAndContinue(String baseName, int hash) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final userRepo = ref.read(userRepositoryProvider);
      final username = _usernameController.text.trim();
      final avatarSeed = _selectedAvatarSeed?.trim();
      await userRepo.updateProfile(
        username: username.isEmpty ? null : username,
        avatarSeed: avatarSeed,
      );
      ref.invalidate(userProvider);
      ref.invalidate(userStatsProvider);
      widget.onComplete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider).value;
    final email = user?['email']?.toString() ?? '';
    final emailLower = user?['emailLower']?.toString() ?? email.toLowerCase();
    final existingUsername = user?['username']?.toString() ?? '';
    final existingAvatarSeed = user?['avatarSeed']?.toString();
    final base =
        emailLower.contains('@') ? emailLower.split('@').first : emailLower;
    final hash = stringHash(base);
    final suggestions = _usernameSuggestions(base, hash);
    final avatarSeeds = _avatarSeeds(base, hash);
    if (_usernameController.text.isEmpty && existingUsername.isNotEmpty) {
      _usernameController.text = existingUsername;
    }
    _selectedAvatarSeed ??= existingAvatarSeed ?? avatarSeeds.first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose your identity'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pick a username',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: suggestions.map((name) {
                  return ActionChip(
                    label: Text(name),
                    onPressed: () {
                      _usernameController.text = name;
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Text(
                'Choose an avatar',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: avatarSeeds.map((seed) {
                  final isSelected = _selectedAvatarSeed == seed;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedAvatarSeed = seed),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withOpacity(0.4),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: FacehashAvatar(
                        name: seed,
                        size: 56,
                        variant: FacehashVariant.gradient,
                        intensity3d: FacehashIntensity.dramatic,
                        showInitial: false,
                        showMouth: true,
                        enableBlink: true,
                        shape: FacehashShape.round,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      _isSaving ? null : () => _saveAndContinue(base, hash),
                  child: _isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
