import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FamilyFinanceApp extends StatelessWidget {
  const FamilyFinanceApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Family Finance',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      routerConfig: router,
    );
  }
}
