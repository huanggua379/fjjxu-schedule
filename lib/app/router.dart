import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/login_page.dart';
import '../features/grade/grade_detail_page.dart';
import '../features/grade/gpa_select_page.dart';
import '../features/shell/main_shell.dart';

/// 全局路由刷新信号：由 auth 状态驱动。
final _authRefresh = ValueNotifier<int>(0);

final routerProvider = Provider<GoRouter>((ref) {
  // 监听登录状态变化以触发 redirect
  ref.listen<AuthState>(authControllerProvider, (_, __) {
    _authRefresh.value++;
  });

  return GoRouter(
    initialLocation: '/',
    refreshListenable: _authRefresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loggingIn = state.matchedLocation == '/login';
      // 仍在初始化时不跳转，交给 splash 处理
      if (auth.status == AuthStatus.initial) return null;
      if (!auth.isAuthenticated && !loggingIn) return '/login';
      if (auth.isAuthenticated && loggingIn) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/', builder: (_, __) => const MainShell()),
      GoRoute(
        path: '/grade/:id',
        builder: (_, s) => GradeDetailPage(gradeId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/gpa-select',
        builder: (_, __) => const GpaSelectPage(),
      ),
    ],
  );
});
