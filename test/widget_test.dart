import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:neurobits/core/app_router.dart';
import 'package:neurobits/main.dart';

void main() {
  testWidgets('App boots when router provider is configured',
      (WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) {
            return const Scaffold(
              body: Center(child: Text('Test Home')),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          routerProvider.overrideWithValue(router),
        ],
        child: const MyApp(),
      ),
    );

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Test Home'), findsOneWidget);
  });
}
