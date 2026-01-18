import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NewLandingPage extends ConsumerStatefulWidget {
  const NewLandingPage({super.key});
  @override
  ConsumerState<NewLandingPage> createState() => _NewLandingPageState();
}

class _NewLandingPageState extends ConsumerState<NewLandingPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
    ));
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brandPurple = Theme.of(context).colorScheme.primary;
    final brandPurpleLight = Color.lerp(brandPurple, Colors.white, 0.3)!;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).colorScheme.surface,
                Theme.of(context).colorScheme.surface,
              ]),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Hero(
                      tag: 'app_logo',
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black26
                                  : brandPurple.withOpacity(0.18),
                              blurRadius: 18,
                              spreadRadius: 2,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(28),
                        child: Image.asset(
                          'assets/neurobiticon.png',
                          width: 90,
                          height: 90,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text(
                      'Neurobits',
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: isDark ? Colors.white : brandPurple,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Train your brain with AI-powered challenges',
                      style: TextStyle(
                        fontSize: 18,
                        color:
                            isDark ? Colors.white70 : const Color(0xFF3A3A3A),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 36),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LandingFeatureTile(
                          icon: Icons.bolt,
                          color: isDark ? Colors.amber : Colors.orange,
                          title: 'Boost Your Brain Power',
                          subtitle:
                              'Sharpen cognitive skills with daily unique questions.',
                        ),
                        const SizedBox(height: 16),
                        _LandingFeatureTile(
                          icon: Icons.school,
                          color: isDark
                              ? Colors.lightBlueAccent
                              : Color(0xFF4F8FFF),
                          title: 'Learn Any Topic',
                          subtitle:
                              'AI-curated quizzes for every interest and level.',
                        ),
                        const SizedBox(height: 16),
                        _LandingFeatureTile(
                          icon: Icons.emoji_events,
                          color:
                              isDark ? Colors.greenAccent : Color(0xFF43D19E),
                          title: 'Track Progress & Earn Points',
                          subtitle:
                              'Set streak goals and collect rewards as you grow.',
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              context.go('/auth/login');
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              textStyle: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w600),
                              side: BorderSide(color: brandPurple, width: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text('Log In',
                                style: TextStyle(color: brandPurple)),
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              context.go('/auth/signup');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: brandPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              textStyle: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w600),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 4,
                            ),
                            child: const Text('Get Started'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LandingFeatureTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _LandingFeatureTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: color.withOpacity(isDark ? 0.16 : 0.11),
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(13),
          child: Icon(icon, color: color, size: 32),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color:
                          isDark ? Colors.white70 : color.withOpacity(0.85))),
            ],
          ),
        ),
      ],
    );
  }
}
