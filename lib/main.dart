import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/providers.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'data/local/settings_store.dart' show ThemeModeSetting;
import 'features/auth/auth_controller.dart';
import 'features/background/background_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 注册后台周期同步任务（WorkManager）
  await BackgroundSync.register();

  runApp(const ProviderScope(child: KeBenApp()));
}

class KeBenApp extends ConsumerStatefulWidget {
  const KeBenApp({super.key});

  @override
  ConsumerState<KeBenApp> createState() => _KeBenAppState();
}

class _KeBenAppState extends ConsumerState<KeBenApp> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // 初始化网络/通知/时区，加载设置，恢复登录态
    await ref.read(networkClientProvider).init();
    await ref.read(reminderServiceProvider).init();
    await ref.read(settingsControllerProvider.notifier).load();
    await ref.read(authControllerProvider.notifier).restore();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    final router = ref.watch(routerProvider);
    final auth = ref.watch(authControllerProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: switch (settings.themeMode) {
        ThemeModeSetting.light => ThemeMode.light,
        ThemeModeSetting.dark => ThemeMode.dark,
        ThemeModeSetting.system => ThemeMode.system,
      },
      routerConfig: router,
      builder: (context, child) {
        // 初始化期间显示启动屏，避免 redirect 闪烁
        if (auth.status == AuthStatus.initial) {
          return const _Splash(child: SizedBox.shrink());
        }
        return child ?? const SizedBox.shrink();
      },
    );
  }
}

class _Splash extends StatelessWidget {
  final Widget child;
  const _Splash({required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school_rounded, size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(AppConstants.appName,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 4)),
            const SizedBox(height: 20),
            const SizedBox(
              width: 120,
              child: LinearProgressIndicator(minHeight: 2),
            ),
          ],
        ),
      ),
    );
  }
}
