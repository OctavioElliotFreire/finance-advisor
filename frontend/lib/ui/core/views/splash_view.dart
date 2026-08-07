import 'package:flutter/material.dart';

import '../widgets/loading_state.dart';

class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: LoadingState());
  }
}
