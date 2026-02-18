import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neurobits/core/providers.dart';

class BadgeGalleryScreen extends ConsumerStatefulWidget {
  const BadgeGalleryScreen({super.key});
  @override
  ConsumerState<BadgeGalleryScreen> createState() => _BadgeGalleryScreenState();
}

class _BadgeGalleryScreenState extends ConsumerState<BadgeGalleryScreen> {
  late Future<List<List<Map<String, dynamic>>>> _badgesFuture;

  @override
  void initState() {
    super.initState();
    final badgeRepo = ref.read(badgeRepositoryProvider);
    _badgesFuture = Future.wait([
      badgeRepo.listAll(),
      badgeRepo.listMine(),
    ]);
  }

  IconData _badgeIcon(String? iconKey) {
    final key = (iconKey ?? '').toLowerCase().trim();
    switch (key) {
      case 'star':
        return Icons.star;
      case 'trophy':
        return Icons.emoji_events;
      case 'medal':
        return Icons.military_tech;
      case 'crown':
        return Icons.workspace_premium;
      case 'fire':
      case 'flame':
        return Icons.local_fire_department;
      case 'check':
      case 'check-circle':
        return Icons.check_circle;
      case 'zap':
      case 'bolt':
        return Icons.bolt;
      default:
        return Icons.emoji_events;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Badge Gallery')),
      body: FutureBuilder<List<List<Map<String, dynamic>>>>(
        future: _badgesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final allBadges = snapshot.data![0];
          final userBadges = snapshot.data![1];
          final userBadgeIds = userBadges
              .map((b) {
                final badge = b['badge'] as Map<String, dynamic>?;
                return badge?['_id']?.toString();
              })
              .where((id) => id != null)
              .toSet();
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.85,
            ),
            itemCount: allBadges.length,
            itemBuilder: (context, idx) {
              final badge = allBadges[idx];
              final earned = userBadgeIds.contains(badge['_id']?.toString());
              return earned
                  ? Card(
                      elevation: 6,
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      child: _buildBadgeCardContent(badge, earned, context),
                    )
                  : ColorFiltered(
                      colorFilter: const ColorFilter.matrix(<double>[
                        0.2126,
                        0.7152,
                        0.0722,
                        0,
                        0,
                        0.2126,
                        0.7152,
                        0.0722,
                        0,
                        0,
                        0.2126,
                        0.7152,
                        0.0722,
                        0,
                        0,
                        0,
                        0,
                        0,
                        1,
                        0,
                      ]),
                      child: Card(
                        elevation: 1,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.07),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        child: _buildBadgeCardContent(badge, earned, context),
                      ),
                    );
            },
          );
        },
      ),
    );
  }

  Widget _buildBadgeCardContent(
      Map<String, dynamic> badge, bool earned, BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Icon(_badgeIcon(badge['icon']), size: 32),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(badge['name'] ?? '',
                      style: Theme.of(context).textTheme.titleLarge)),
            ],
          ),
          content: Text(badge['description'] ?? '',
              style: Theme.of(context).textTheme.bodyLarge),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_badgeIcon(badge['icon']), size: 40),
          const SizedBox(height: 8),
          Text(
            badge['name'] ?? '',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              badge['description'] ?? '',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey[800]),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (earned)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child:
                  Icon(Icons.check_circle, color: Colors.green[600], size: 22),
            ),
        ],
      ),
    );
  }
}
