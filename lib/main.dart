import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens/lock.dart';
import 'screens/onboarding.dart';
import 'screens/shell.dart';
import 'store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final store = AppStore();
  await store.load();
  runApp(ChangeNotifierProvider.value(value: store, child: const XpenseApp()));
}

class XpenseApp extends StatelessWidget {
  const XpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.select<AppStore, (int, ThemeMode, bool)>(
      (st) => (st.settings.accent, st.settings.themeMode, st.settings.onboarded && st.hasCycle),
    );
    final seed = Color(s.$1);
    return MaterialApp(
      title: 'Xpense',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(seed, Brightness.light),
      darkTheme: buildTheme(seed, Brightness.dark),
      themeMode: s.$2,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: s.$3 ? const LockGate(child: Shell()) : const OnboardingScreen(),
      ),
    );
  }
}
